//
//  ChunkUploader.swift
//  ios_watchme_v9
//
//  Sends recording chunks to S3 and never gives up on one until the server has it.
//
//  - Every chunk is tracked in UploadJournal (on disk). A file is deleted only after
//    S3 answered 200 to the PUT.
//  - The PUT goes through a background URLSession, so it continues when the app is
//    suspended or killed, and the OS waits for connectivity on its own.
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
                await self?.reconcile()
                self?.kick()
            }
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

    /// The file is closed: queue it for sending.
    func chunkFinished(id: String) async {
        let record = await journal.update(id: id) { record in
            record.state = .recorded
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
        for record in await journal.records(in: .uploading) where !liveIds.contains(record.id) && !inFlight.contains(record.id) {
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
        guard let deviceId = defaultDeviceId?() else { return }
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
                var record = ChunkRecord(id: UUID().uuidString, fileName: fileName, deviceId: deviceId, recordedAt: created,
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
    var defaultDeviceId: (() -> String?)?

    // MARK: - Sending

    /// Start as many waiting uploads as the concurrency limit allows.
    func kick() {
        Task { await kickAsync() }
    }

    private func kickAsync() async {
        let now = Date()
        let uploading = await journal.records(in: .uploading).count
        var slots = maxConcurrentUploads - uploading - inFlight.count
        guard slots > 0 else { return }

        let waiting = await journal.records(in: .recorded)
            .filter { ($0.nextRetryAt ?? .distantPast) <= now && !inFlight.contains($0.id) }
            .sorted { $0.recordedAt < $1.recordedAt }
        for record in waiting.prefix(slots) {
            slots -= 1
            inFlight.insert(record.id)
            Task { await self.beginUpload(record) }
        }
    }

    private func beginUpload(_ record: ChunkRecord) async {
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
            let task = session.uploadTask(with: request, fromFile: record.fileURL)
            task.taskDescription = record.id
            await journal.update(id: record.id) {
                $0.state = .uploading
                $0.s3Key = presigned.key
                $0.attempts += 1
            }
            task.resume()
            print("📤 [Uploader] PUT started: \(record.fileName) -> \(presigned.key)")
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
            case .http(404, _): return "このデバイスがサーバーに登録されていません。デバイスを連携し直してください"
            case .http(401, _): return "ログインの確認ができませんでした。ログインし直すと送られます"
            case .http(403, _): return "このデバイスはこのアカウントに連携されていません"
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
            "device_id": record.deviceId,
            "recorded_at": formatter.string(from: record.recordedAt),
            "content_type": record.fileName.hasSuffix(".m4a") ? "audio/mp4" : "audio/wav",
        ]
        if let sessionId = record.sessionId {
            body["session_id"] = sessionId
            if let sequence = record.sequence { body["sequence"] = sequence }
        }
        if let duration = record.durationSeconds { body["duration_seconds"] = duration }
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
            if error == nil, let status, (200...299).contains(status) {
                await self.succeed(id)
            } else if let error {
                await self.fail(id, message: error.localizedDescription, permanent: false)
                self.kick()
            } else {
                // 403 is usually an expired presigned URL: a fresh one is one retry away.
                let message = status == 403 ? "送信の許可が切れたので取り直します" : "S3 が受け取りませんでした（\(status ?? 0)）"
                await self.fail(id, message: message, permanent: false)
                if status == 403 {
                    await self.journal.update(id: id) { $0.nextRetryAt = nil }
                }
                self.kick()
            }
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}
