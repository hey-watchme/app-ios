//
//  ChunkUploader.swift
//  ios_watchme_v9
//
//  Sends recording chunks to S3 and never gives up on one until the server has it.
//
//  - Every chunk is tracked in UploadJournal (on disk). A file is deleted only after
//    S3 answered 200 to the PUT.
//  - While the app is sure to be running (in the foreground, recording, or in the
//    short background time after either), the app sends each chunk itself, at once.
//    Only what is still unsent when the app is about to be suspended is handed to a
//    background URLSession. iOS treats a transfer handed over from the background as
//    discretionary and may hold it for hours (no Wi-Fi or no charger), which is what
//    left a locked 56-minute recording unsent for 4.5 hours on 2026-11-20.
//  - Each attempt first asks the server for a presigned URL (POST /upload/presign);
//    the pipeline starts when the object lands in S3, nothing else is needed from here.
//  - Failures back off (10 s, 20 s, ... up to 10 min) and are retried forever, except
//    4xx answers that a retry cannot fix, which park the chunk as `blocked` for a person.
//  See platform/docs/long-recording.md.
//

import Foundation
import Network
import UIKit

@MainActor
final class ChunkUploader: NSObject, ObservableObject {
    static let shared = ChunkUploader()

    static let backgroundSessionIdentifier = "me.hey-watch.upload"
    private let serverURL = "https://api.hey-watch.me"
    private let maxConcurrentUploads = 2
    private let maxBackoff: TimeInterval = 600

    /// Mirror of the journal for the UI (everything not yet confirmed by the server).
    @Published private(set) var pending: [ChunkRecord] = []

    /// Called after a chunk was confirmed by the server and its file deleted.
    var onChunkUploaded: ((ChunkRecord) -> Void)?
    /// Called when a chunk fails for the first time or becomes blocked (for a toast).
    var onChunkFailed: ((ChunkRecord) -> Void)?
    /// Handed over by the AppDelegate when iOS relaunches the app for finished background transfers.
    var backgroundCompletionHandler: (() -> Void)?

    private let journal = UploadJournal.shared
    private var inFlight = Set<String>()        // ids being presigned / handed to the session
    private var started = false
    private let pathMonitor = NWPathMonitor()
    private var periodicTimer: Timer?

    /// Uploads the app is sending itself (chunk id -> the transfer).
    private var directTasks: [String: Task<Void, Never>] = [:]
    /// Background transfers cancelled because the app took the chunk over; their
    /// cancellation is not a failure.
    private var takenOver = Set<String>()
    /// Background time asked for to finish sending after recording stopped or the app left the screen.
    private var finishingTask: UIBackgroundTaskIdentifier = .invalid
    private var kicking = false
    private var kickAgain = false

    /// Set by RecordingStore. While recording, the audio background mode keeps the app running.
    var isRecording = false {
        didSet {
            guard isRecording != oldValue else { return }
            if isRecording {
                kick()
            } else {
                keepRunningUntilSent()
            }
        }
    }

    /// True while the app is sure to keep running, so it can send chunks itself.
    private var canSendDirectly: Bool {
        UIApplication.shared.applicationState != .background || isRecording || finishingTask != .invalid
    }

    /// Transfers the app sends itself. They work in the background as long as the app runs.
    private lazy var directSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true         // a dead spot waits instead of failing at once
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 10 * 60
        return URLSession(configuration: config)
    }()

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.backgroundSessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.timeoutIntervalForResource = 12 * 3600   // then the attempt fails and we presign again
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    private override init() {
        super.init()
    }

    // MARK: - Lifecycle

    /// Call once at launch: rebuilds state from the journal, repairs crashed chunks and starts sending.
    func start() {
        guard !started else { return }
        started = true
        _ = session  // create it early so a relaunch for background events finds its delegate

        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in self?.kick() }
        }
        pathMonitor.start(queue: DispatchQueue(label: "upload.path"))

        periodicTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.kick() }
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.endFinishingTask()   // in the foreground the app runs anyway
                await self?.reconcile()
                self?.kick()
            }
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.keepRunningUntilSent() }
        }

        Task {
            await reconcile()
            kick()
        }
    }

    // MARK: - Enqueue

    /// A chunk whose file is being written. Journaled at once so a crash can be recovered.
    func chunkStarted(_ record: ChunkRecord) async {
        await journal.add(record)
        await refresh()
    }

    /// The file is closed: queue it for sending. `isFinal` marks a session's last chunk.
    func chunkFinished(id: String, isFinal: Bool? = nil) async {
        let record = await journal.update(id: id) { record in
            record.state = .recorded
            if record.sessionId != nil, let isFinal {
                record.isFinal = isFinal
            }
            record.nextRetryAt = nil
            if let url = Optional(record.fileURL), let duration = WAVFile.duration(of: url) {
                record.durationSeconds = duration
            }
        }
        await refresh()
        if record != nil { kick() }
    }

    /// YYYY-MM-DD/HH-mm-ss.ext in the device's timezone (the same layout the recorder uses).
    nonisolated static func fileName(for date: Date, timezone: TimeZone, extension ext: String = "wav") -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd'/'HH-mm-ss"
        return "\(formatter.string(from: date)).\(ext)"
    }

    // MARK: - Commands from the UI

    /// Retry everything that is waiting, ignoring backoff. Blocked chunks are retried too
    /// (the person may have fixed the cause, e.g. linked the device again).
    func retryAllNow() async {
        for record in await journal.all() where record.state == .recorded || record.state == .blocked {
            await journal.update(id: record.id) { $0.nextRetryAt = nil; $0.state = .recorded }
        }
        await refresh()
        kick()
    }

    func delete(id: String) async {
        if let record = await journal.record(id: id) {
            try? FileManager.default.removeItem(at: record.fileURL)
        }
        await journal.remove(id: id)
        await refresh()
    }

    func refresh() async {
        pending = await journal.all()
    }

    // MARK: - Reconcile (launch / foreground)

    /// Make the journal match reality: repair chunks left open by a crash, re-queue uploads
    /// whose background task no longer exists, and adopt stray recordings on disk.
    private func reconcile() async {
        // 1. Chunks still marked "recording" were cut off by a crash or a kill.
        for record in await journal.records(in: .recording) where !isRecordingNow(record.id) {
            await recover(record)
        }

        // 2. "uploading" without a live task: the attempt is gone, try again.
        let liveIds = Set(await session.allTasks.compactMap { $0.taskDescription })
        for record in await journal.records(in: .uploading)
        where !liveIds.contains(record.id) && !inFlight.contains(record.id) && directTasks[record.id] == nil {
            await journal.update(id: record.id) { $0.state = .recorded; $0.nextRetryAt = nil }
        }

        // 3. Files whose record is gone (journal lost) or that predate the journal.
        await adoptStrayFiles()

        // 4. Records whose file is gone cannot be sent: drop them.
        for record in await journal.all() where !record.fileExists && record.state != .recording {
            await journal.remove(id: record.id)
        }

        await refresh()
    }

    /// Chunks being written right now (by the recorder or an import), so reconcile() does not "repair" a live file.
    var activeRecordingIds = Set<String>()

    private func isRecordingNow(_ id: String) -> Bool {
        activeRecordingIds.contains(id)
    }

    private func recover(_ record: ChunkRecord) async {
        do {
            let duration = try WAVFile.repairHeader(at: record.fileURL)
            await journal.update(id: record.id) {
                $0.state = .recorded
                $0.durationSeconds = duration
                $0.recovered = true
                $0.nextRetryAt = nil
            }
            print("🩹 [Uploader] recovered a chunk cut off by a crash: \(record.fileName) (\(Int(duration)) s)")
            ToastManager.shared.showInfo(title: "前回の録音を復旧しました", subtitle: "途中で終わった録音（約\(Int(duration))秒）を送ります")
        } catch WAVFile.RepairError.tooShort {
            try? FileManager.default.removeItem(at: record.fileURL)
            await journal.remove(id: record.id)
            print("🗑️ [Uploader] dropped a crashed chunk with no audio: \(record.fileName)")
        } catch {
            await journal.update(id: record.id) {
                $0.state = .blocked
                $0.lastError = "復旧できませんでした: \(error.localizedDescription)"
            }
            print("❌ [Uploader] could not recover \(record.fileName): \(error)")
        }
    }

    /// Any .wav / .m4a under Documents/<date>/ that no record points to.
    private func adoptStrayFiles() async {
        guard let subjectId = defaultSubjectId?() else { return }
        let known = Set(await journal.all().map(\.fileName))
        let root = UploadJournal.documentsDirectory
        guard let dirs = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else { return }
        for dir in dirs where dir.lastPathComponent.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
            guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey]) else { continue }
            for file in files where ["wav", "m4a"].contains(file.pathExtension.lowercased()) {
                let fileName = "\(dir.lastPathComponent)/\(file.lastPathComponent)"
                guard !known.contains(fileName) else { continue }
                let created = (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()
                // A stray WAV may have been cut off by a crash before the journal knew it: fix the header sizes
                // from the file length (harmless on a complete file).
                if file.pathExtension.lowercased() == "wav" {
                    _ = try? WAVFile.repairHeader(at: file)
                }
                // Old leftovers (from before the journal existed) are not sent on their own: the person decides.
                let isOld = Date().timeIntervalSince(created) > 7 * 24 * 3600
                var record = ChunkRecord(id: UUID().uuidString, fileName: fileName, subjectId: subjectId, recordedAt: created,
                                         sessionId: nil, sequence: nil, durationSeconds: WAVFile.duration(of: file),
                                         state: isOld ? .blocked : .recorded)
                if isOld {
                    record.lastError = "以前の録音が端末に残っていました。送るには「今すぐ再送」、要らなければ削除"
                }
                await journal.add(record)
                print("📎 [Uploader] adopted a stray recording: \(fileName)\(isOld ? " (old, blocked)" : "")")
            }
        }
    }

    /// The device to attribute stray files to (the selected one). Set by RecordingStore.
    var defaultSubjectId: (() -> String?)?

    // MARK: - Sending

    /// Start as many waiting uploads as the concurrency limit allows.
    func kick() {
        Task { await kickAsync() }
    }

    private func kickAsync() async {
        // One pass at a time; a kick during a pass runs one more pass after it
        guard !kicking else { kickAgain = true; return }
        kicking = true
        defer { kicking = false }
        repeat {
            kickAgain = false
            await kickOnce()
        } while kickAgain
    }

    private func kickOnce() async {
        let direct = canSendDirectly
        if direct {
            await takeOverBackgroundUploads()
        }

        let now = Date()
        let uploading = await journal.records(in: .uploading).count
        let slots = maxConcurrentUploads - uploading - inFlight.count
        guard slots > 0 else { return }

        let waiting = await journal.records(in: .recorded)
            .filter { ($0.nextRetryAt ?? .distantPast) <= now && !inFlight.contains($0.id) }
            .sorted { $0.recordedAt < $1.recordedAt }
            .prefix(slots)
        for record in waiting {
            inFlight.insert(record.id)
        }
        // Wait for the presigns, so that a hand-over finishes before the app is suspended
        await withTaskGroup(of: Void.self) { group in
            for record in waiting {
                group.addTask { await self.beginUpload(record, direct: direct) }
            }
        }
    }

    /// A transfer handed to iOS may sit there for hours. While the app can send itself,
    /// it cancels those and sends the chunks again. S3 keeps one copy per key, and the
    /// server counts a chunk once however often it arrives.
    private func takeOverBackgroundUploads() async {
        let stuck = await journal.records(in: .uploading)
            .filter { directTasks[$0.id] == nil && !inFlight.contains($0.id) }
        guard !stuck.isEmpty else { return }
        let ids = Set(stuck.map(\.id))
        for task in await session.allTasks {
            if let id = task.taskDescription, ids.contains(id) {
                takenOver.insert(id)
                task.cancel()
            }
        }
        for id in ids {
            await journal.update(id: id) { $0.state = .recorded; $0.nextRetryAt = nil }
        }
        print("🔁 [Uploader] took over \(ids.count) transfer(s) waiting in the background session")
    }

    private func beginUpload(_ record: ChunkRecord, direct: Bool) async {
        defer { inFlight.remove(record.id) }
        guard record.fileExists, record.fileSize > 0 else {
            await journal.remove(id: record.id)
            await refresh()
            return
        }

        do {
            let presigned = try await presign(record)
            var request = URLRequest(url: presigned.url)
            request.httpMethod = "PUT"
            for (name, value) in presigned.headers {
                request.setValue(value, forHTTPHeaderField: name)
            }
            await journal.update(id: record.id) {
                $0.state = .uploading
                $0.s3Key = presigned.key
                $0.attempts += 1
            }
            // The mode may have changed while presigning (the app went to the background)
            if direct && canSendDirectly {
                sendDirectly(record, request: request)
            } else {
                let task = session.uploadTask(with: request, fromFile: record.fileURL)
                task.taskDescription = record.id
                task.resume()
            }
            print("📤 [Uploader] PUT started (\(direct ? "direct" : "background")): \(record.fileName) -> \(presigned.key)")
        } catch let error as PresignError where error.isPermanent {
            await fail(record.id, message: error.localizedDescription, permanent: true)
        } catch {
            await fail(record.id, message: error.localizedDescription, permanent: false)
        }
        await refresh()
    }

    private struct Presigned {
        let url: URL
        let key: String
        let headers: [String: String]
    }

    private enum PresignError: LocalizedError {
        case http(Int, String?)
        case badResponse

        var isPermanent: Bool {
            // 401: the session may just need refreshing, so it is retried like a network error.
            if case .http(let status, _) = self { return (400...499).contains(status) && ![401, 408, 429].contains(status) }
            return false
        }

        var errorDescription: String? {
            switch self {
            case .http(404, _): return "この分析対象がサーバーに見つかりません。分析対象を選び直してください"
            case .http(401, _): return "ログインの確認ができませんでした。ログインし直すと送られます"
            case .http(403, let detail) where detail?.contains("used up") == true:
                return "今月の録音時間を使い切ったため、送れませんでした"
            case .http(403, _): return "この分析対象を録音する権限がありません"
            case .http(let status, let detail): return "サーバーが受け付けませんでした（\(status)\(detail.map { ": \($0)" } ?? "")）"
            case .badResponse: return "サーバーの応答が読めませんでした"
            }
        }
    }

    private func presign(_ record: ChunkRecord) async throws -> Presigned {
        var request = URLRequest(url: URL(string: "\(serverURL)/upload/presign")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer = await SupabaseClientManager.shared.bearerToken() {
            request.setValue(bearer, forHTTPHeaderField: "Authorization")
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var body: [String: Any] = [
            "subject_id": record.subjectId,
            "recorded_at": formatter.string(from: record.recordedAt),
            "content_type": record.fileName.hasSuffix(".m4a") ? "audio/mp4" : "audio/wav",
            "device_id": ThisDevice.id,
            "device_model": ThisDevice.model,
        ]
        if let sessionId = record.sessionId {
            body["session_id"] = sessionId
            if let sequence = record.sequence { body["sequence"] = sequence }
        }
        if let duration = record.durationSeconds { body["duration_seconds"] = duration }
        if record.sessionId != nil {
            if let isFinal = record.isFinal { body["final"] = isFinal }
            if let startedAt = record.sessionStartedAt { body["session_started_at"] = formatter.string(from: startedAt) }
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PresignError.badResponse }
        guard http.statusCode == 200 else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
            throw PresignError.http(http.statusCode, detail)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urlString = json["url"] as? String, let url = URL(string: urlString),
              let key = json["key"] as? String,
              let headers = json["headers"] as? [String: String] else {
            throw PresignError.badResponse
        }
        return Presigned(url: url, key: key, headers: headers)
    }

    private func sendDirectly(_ record: ChunkRecord, request: URLRequest) {
        let id = record.id
        let file = record.fileURL
        directTasks[id] = Task { @MainActor in
            defer {
                self.directTasks[id] = nil
                self.endFinishingTaskIfIdle()
            }
            do {
                let (_, response) = try await self.directSession.upload(for: request, fromFile: file)
                guard !Task.isCancelled else { return }   // handed over meanwhile
                await self.finished(id, status: (response as? HTTPURLResponse)?.statusCode, error: nil)
            } catch {
                guard !Task.isCancelled else { return }
                await self.finished(id, status: nil, error: error)
            }
        }
    }

    /// The end of one PUT, sent directly or through the background session.
    private func finished(_ id: String, status: Int?, error: Error?) async {
        if error == nil, let status, (200...299).contains(status) {
            await succeed(id)
        } else if let error {
            await fail(id, message: error.localizedDescription, permanent: false)
            kick()
        } else {
            // 403 is usually an expired presigned URL: a fresh one is one retry away.
            let message = status == 403 ? "送信の許可が切れたので取り直します" : "S3 が受け取りませんでした（\(status ?? 0)）"
            await fail(id, message: message, permanent: false)
            if status == 403 {
                await journal.update(id: id) { $0.nextRetryAt = nil }
            }
            kick()
        }
    }

    // MARK: - Background time to finish sending

    /// Recording stopped or the app left the screen: ask iOS for time to send what is left
    /// directly, and hand whatever is still unsent to the background session before it runs out.
    private func keepRunningUntilSent() {
        guard UIApplication.shared.applicationState == .background, !isRecording, finishingTask == .invalid else { return }
        finishingTask = UIApplication.shared.beginBackgroundTask(withName: "finish-uploads") { [weak self] in
            // Last resort, called on the main thread: whatever is unsent is resent from the journal later
            MainActor.assumeIsolated { self?.handOver(expiring: true) }
        }
        guard finishingTask != .invalid else { kick(); return }
        kick()
        Task { @MainActor in
            // iOS gives about 30 seconds; hand over with time to spare
            try? await Task.sleep(for: .seconds(20))
            self.handOver(expiring: false)
        }
        endFinishingTaskIfIdle()
    }

    /// Stop sending directly. Unless time is up, the unsent chunks go to the background session.
    private func handOver(expiring: Bool) {
        let id = finishingTask
        guard id != .invalid else { return }
        finishingTask = .invalid
        guard UIApplication.shared.applicationState == .background, !isRecording else {
            UIApplication.shared.endBackgroundTask(id)   // the app runs anyway
            return
        }
        let cancelled = Array(directTasks.keys)
        directTasks.values.forEach { $0.cancel() }
        directTasks.removeAll()
        if expiring {
            // No time for more: the journal still says "uploading", and reconcile() resends on the next launch
            UIApplication.shared.endBackgroundTask(id)
            return
        }
        Task { @MainActor in
            for chunk in cancelled {
                await self.journal.update(id: chunk) { $0.state = .recorded; $0.nextRetryAt = nil }
            }
            // A pass already running would only queue another one: let it end first
            while self.kicking { try? await Task.sleep(for: .milliseconds(200)) }
            await self.kickAsync()   // canSendDirectly is false now: this hands the rest to iOS
            await self.refresh()
            UIApplication.shared.endBackgroundTask(id)
        }
    }

    private func endFinishingTaskIfIdle() {
        guard finishingTask != .invalid else { return }
        Task { @MainActor in
            guard self.finishingTask != .invalid, self.directTasks.isEmpty, self.inFlight.isEmpty else { return }
            // A chunk still being closed counts too: it is about to be sent
            let unsent = await self.journal.all().filter { $0.state != .blocked }
            guard unsent.isEmpty else { return }
            self.endFinishingTask()
        }
    }

    private func endFinishingTask() {
        guard finishingTask != .invalid else { return }
        let id = finishingTask
        finishingTask = .invalid
        UIApplication.shared.endBackgroundTask(id)
    }

    /// Record a failed attempt: back off (or park as blocked) and tell the UI the first time.
    private func fail(_ id: String, message: String, permanent: Bool) async {
        guard let record = await journal.update(id: id, { record in
            record.lastError = message
            if permanent {
                record.state = .blocked
                record.nextRetryAt = nil
            } else {
                record.state = .recorded
                record.attempts = max(record.attempts, 1)
                let delay = min(10 * pow(2, Double(record.attempts - 1)), self.maxBackoff)
                record.nextRetryAt = Date().addingTimeInterval(delay)
                record.attempts += 1
            }
        }) else { return }
        print("❌ [Uploader] \(record.fileName): \(message) (attempt \(record.attempts), \(permanent ? "blocked" : "retry at \(record.nextRetryAt!)"))")
        if permanent || record.attempts <= 2 {
            onChunkFailed?(record)
        }
        await refresh()
    }

    private func succeed(_ id: String) async {
        guard let record = await journal.record(id: id) else { return }
        do {
            try FileManager.default.removeItem(at: record.fileURL)
        } catch {
            // The server has it; a leftover file is adopted and re-sent later, and the server
            // treats the repeat as the same recording. Not worth bothering the person.
            print("⚠️ [Uploader] uploaded but could not delete \(record.fileName): \(error)")
        }
        await journal.remove(id: id)
        await refresh()
        print("✅ [Uploader] delivered: \(record.fileName)")
        onChunkUploaded?(record)
        kick()
    }
}

// MARK: - URLSessionDelegate (background transfers)

extension ChunkUploader: URLSessionTaskDelegate, URLSessionDelegate {
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let id = task.taskDescription
        let status = (task.response as? HTTPURLResponse)?.statusCode
        Task { @MainActor in
            guard let id else { return }
            // Cancelled because the app sends it itself now: not a failure
            if self.takenOver.remove(id) != nil, error != nil { return }
            await self.finished(id, status: status, error: error)
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}
