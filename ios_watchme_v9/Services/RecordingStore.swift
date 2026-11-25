//
//  RecordingStore.swift
//  ios_watchme_v9
//
//  The one place the UI talks to for recording and sending. Drives
//  AudioRecorderService (5-minute chunks) and ChunkUploader (journal + background
//  transfers) and turns their events into state and messages for the person.
//

import Foundation
import Combine
import AVFoundation
import UIKit

// MARK: - State

struct RecordingState {
    // Recording
    var isRecording = false
    var isInterrupted = false
    var recordingStartTime: Date?
    var recordingDuration: TimeInterval = 0   // time actually recorded (stops while interrupted)
    var currentSessionId: String?
    var sessionChunksFinished = 0   // closed so far in this session
    var sessionChunksDelivered = 0  // confirmed by the server so far in this session

    // Sending: everything on the device the server has not confirmed (not the chunk being written)
    var pending: [ChunkRecord] = []

    // This month's recording time (nil until read, or when it could not be read)
    var quota: RecordingQuota?
    var stoppedByQuota = false

    // Errors shown inside the recording sheet
    var errorMessage: String?
    var showError = false

    var isInitialized = false
}

// MARK: - RecordingStore

@MainActor
final class RecordingStore: ObservableObject {
    @Published private(set) var state = RecordingState()

    static let chunkMinutes = Int(AudioRecorderService.chunkSeconds / 60)
    static var maxMinutes: Int { RecordingLimits.maxMinutes }

    private let audioService: AudioRecorderService
    private let uploader: ChunkUploader
    private let subjectManager: SubjectManager
    private let userAccountManager: UserAccountManager

    private var cancellables = Set<AnyCancellable>()
    private var recordingTimer: Timer?
    private var lastPendingReminderAt: Date?
    private var lastSessionId: String?
    private var lastSessionChunks = 0

    init(
        audioService: AudioRecorderService? = nil,
        subjectManager: SubjectManager,
        userAccountManager: UserAccountManager
    ) {
        self.audioService = audioService ?? AudioRecorderService()
        self.uploader = ChunkUploader.shared
        self.subjectManager = subjectManager
        self.userAccountManager = userAccountManager

        setupBindings()
        uploader.defaultSubjectId = { [weak subjectManager] in subjectManager?.selectedSubjectID }
        uploader.start()
    }

    // MARK: - Bindings

    private func setupBindings() {
        audioService.chunkStarted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] record in self?.handleChunkStarted(record) }
            .store(in: &cancellables)

        audioService.chunkFinished
            .receive(on: DispatchQueue.main)
            .sink { [weak self] finished in self?.handleChunkFinished(finished.id, isFinal: finished.isFinal) }
            .store(in: &cancellables)

        audioService.sessionEnded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reason in self?.handleSessionEnded(reason) }
            .store(in: &cancellables)

        audioService.interruptionChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] interrupted in self?.handleInterruptionChanged(interrupted) }
            .store(in: &cancellables)

        uploader.$pending
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pending in self?.handlePendingChanged(pending) }
            .store(in: &cancellables)

        uploader.onChunkUploaded = { [weak self] record in self?.handleChunkUploaded(record) }
        uploader.onChunkFailed = { [weak self] record in self?.handleChunkFailed(record) }

        // Whenever the app comes to the foreground, say if recordings are still waiting
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.remindPendingIfAny() }
            .store(in: &cancellables)
    }

    // MARK: - Commands from the UI

    func initialize() async {
        guard !state.isInitialized else { return }
        await uploader.refresh()
        state.isInitialized = true
    }

    func startRecording() async {
        guard !state.isRecording else { return }

        guard !userAccountManager.requireWritePermission() else {
            presentError("録音には会員登録が必要です")
            return
        }
        guard let subjectId = subjectManager.selectedSubjectID else {
            presentError("分析対象が選ばれていません")
            return
        }
        guard !subjectManager.isSampleSelected else {
            presentError("サンプルには録音できません。ご自分の分析対象を選んでください")
            return
        }
        guard await requestMicrophonePermissionIfNeeded() else {
            presentError("マイクへのアクセスが許可されていません。設定アプリから許可してください。")
            return
        }

        // The month's recording time: refuse when it is used up, stop when it runs out.
        // When it cannot be read, the server still refuses a recording past the limit.
        let quota = await RecordingQuota.fetch()
        if let quota { state.quota = quota }
        if let quota, quota.isUsedUp {
            presentError(quota.usedUpMessage)
            return
        }
        let remaining = quota?.remainingSeconds
        state.stoppedByQuota = false

        do {
            try audioService.configureAudioSession()
            let sessionId = try audioService.startSession(subjectId: subjectId, timezone: subjectManager.selectedTimezone,
                                                          limitSeconds: remaining)
            quotaEndsSession = remaining.map { $0 < AudioRecorderService.maxSessionSeconds } ?? false
            sessionLimitSeconds = quotaEndsSession ? remaining : nil
            state.isRecording = true
            uploader.isRecording = true
            state.isInterrupted = false
            state.recordingStartTime = Date()
            state.recordingDuration = 0
            recordedBeforeSegment = 0
            state.currentSessionId = sessionId
            state.sessionChunksFinished = 0
            state.sessionChunksDelivered = 0
            state.errorMessage = nil
            startRecordingTimer()
        } catch {
            presentError("録音を始められませんでした: \(error.localizedDescription)")
            print("❌ RecordingStore: start failed - \(error)")
        }
    }

    /// Read this month's recording time again (the recording screen shows it).
    func refreshQuota() async {
        if let quota = await RecordingQuota.fetch() { state.quota = quota }
    }

    private var quotaEndsSession = false
    private var sessionLimitSeconds: TimeInterval?

    /// How long the current recording can run: the per-recording limit, or what is left of the month.
    var sessionLimitMinutes: Int {
        Int(((sessionLimitSeconds ?? AudioRecorderService.maxSessionSeconds) / 60).rounded(.down))
    }

    func stopRecording() async {
        guard state.isRecording else { return }
        audioService.stopSession()   // state is updated from sessionEnded
    }

    /// Import an audio or video file: cut it into 5-minute chunks stamped with when it was
    /// recorded, journal them and send them like a live recording. No length limit.
    func importFile(at url: URL, originalDates: AudioImporter.FileDates?) async throws {
        guard let subjectId = subjectManager.selectedSubjectID else {
            throw AudioImportError.readFailed("分析対象が選ばれていません")
        }
        guard !subjectManager.isSampleSelected else {
            throw AudioImportError.readFailed("サンプルには取り込めません。ご自分の分析対象を選んでください")
        }
        if let quota = await RecordingQuota.fetch() {
            state.quota = quota
            if quota.isUsedUp { throw AudioImportError.readFailed(quota.usedUpMessage) }
        }
        var shown = -1
        let result = try await AudioImporter.importFile(
            at: url, originalDates: originalDates, subjectId: subjectId, timezone: subjectManager.selectedTimezone
        ) { progress in
            let percent = Int(progress * 100)
            guard percent != shown else { return }
            shown = percent
            ToastManager.shared.showProgressWithPhase(phase: "音声を取り込み中...", subtitle: "\(percent)%", progress: progress)
        }

        importSessions[result.sessionId] = result.chunkCount
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = subjectManager.selectedTimezone
        formatter.dateFormat = "M/d HH:mm"
        let minutes = Int((result.durationSeconds / 60).rounded())
        ToastManager.shared.announce(
            title: "\(formatter.string(from: result.startedAt)) の録音として取り込みました",
            subtitle: "\(result.startSource.label)・約\(minutes)分の録音を送ります"
        )
        announceImportDeliveredIfDone(result.sessionId)
    }

    private var importSessions: [String: Int] = [:]   // sessionId -> chunk count, until all are delivered

    private func announceImportDeliveredIfDone(_ sessionId: String) {
        guard importSessions[sessionId] != nil,
              !uploader.pending.contains(where: { $0.sessionId == sessionId }) else { return }
        importSessions[sessionId] = nil
        ToastManager.shared.showSuccess(title: "取り込んだ録音を送り終えました", subtitle: "分析結果をお待ちください")
    }

    /// Resend everything waiting, now (also chunks parked as blocked).
    func retryAllNow() async {
        await uploader.retryAllNow()
    }

    func deleteRecording(_ record: ChunkRecord) async {
        await uploader.delete(id: record.id)
    }

    func clearError() {
        state.showError = false
        state.errorMessage = nil
    }

    func presentError(_ message: String) {
        state.errorMessage = message
        state.showError = true
    }

    // MARK: - Recorder events

    private func handleChunkStarted(_ record: ChunkRecord) {
        uploader.activeRecordingIds.insert(record.id)
        Task { await uploader.chunkStarted(record) }
    }

    private func handleChunkFinished(_ id: String, isFinal: Bool) {
        uploader.activeRecordingIds.remove(id)
        state.sessionChunksFinished += 1
        lastSessionChunks = state.sessionChunksFinished
        Task { await uploader.chunkFinished(id: id, isFinal: isFinal) }
    }

    private func handleSessionEnded(_ reason: RecordingEndReason) {
        lastSessionId = state.currentSessionId
        state.isRecording = false
        uploader.isRecording = false
        state.isInterrupted = false
        state.currentSessionId = nil
        stopRecordingTimer()

        switch reason {
        case .stopped:
            ToastManager.shared.showInfo(title: "録音を送っています", subtitle: "届き次第お知らせします")
        case .limitReached where quotaEndsSession:
            state.stoppedByQuota = true
            ToastManager.shared.announce(
                title: "今月の録音時間を使い切ったので録音を止めました",
                subtitle: "ここまでの録音を送ります。\(state.quota?.renewsOn ?? "")から再び録音できます"
            )
        case .limitReached:
            ToastManager.shared.announce(
                title: "\(Self.maxMinutes)分に達したので録音を止めました",
                subtitle: "ここまでの録音を送ります。続けるにはもう一度録音を始めてください"
            )
        case .interrupted:
            ToastManager.shared.showError(
                title: "録音が中断されました",
                subtitle: "電話などでマイクが使われ、再開できませんでした。そこまでの録音を送ります"
            )
        case .failed(let error):
            ToastManager.shared.showError(
                title: "録音を続けられませんでした",
                subtitle: "\(error.localizedDescription)。そこまでの録音を送ります"
            )
        }
    }

    /// The count stops while the microphone is taken and goes on when it is back.
    private func handleInterruptionChanged(_ interrupted: Bool) {
        guard state.isRecording, interrupted != state.isInterrupted else {
            state.isInterrupted = interrupted
            return
        }
        state.isInterrupted = interrupted
        if interrupted {
            if let start = state.recordingStartTime {
                recordedBeforeSegment += Date().timeIntervalSince(start)
            }
            state.recordingStartTime = nil
            state.recordingDuration = recordedBeforeSegment
            ToastManager.shared.showError(
                title: "録音が止まっています",
                subtitle: "ほかのアプリや電話がマイクを使っています。使い終わると自動で続きを録音します"
            )
        } else {
            state.recordingStartTime = Date()
            ToastManager.shared.announce(title: "録音を再開しました", subtitle: nil)
        }
    }

    /// Recorded time before the current stretch (sum of the stretches between interruptions).
    private var recordedBeforeSegment: TimeInterval = 0

    /// The input level while recording, for the meter.
    func currentLevel() -> Float? { audioService.currentLevel() }

    // MARK: - Uploader events

    private func handlePendingChanged(_ pending: [ChunkRecord]) {
        state.pending = pending.filter { !uploader.activeRecordingIds.contains($0.id) }
        if let sessionId = state.currentSessionId ?? lastSessionId {
            let waiting = pending.filter { $0.sessionId == sessionId && $0.state != .recording }.count
            state.sessionChunksDelivered = max(0, lastSessionChunks - waiting)
        }
    }

    private func handleChunkUploaded(_ record: ChunkRecord) {
        if let sessionId = record.sessionId, importSessions[sessionId] != nil {
            announceImportDeliveredIfDone(sessionId)
            return
        }
        if record.sessionId == nil {
            ToastManager.shared.showSuccess(title: "送信完了", subtitle: "分析結果をお待ちください")
            return
        }
        // The whole session is delivered once nothing of it is left and recording has stopped
        guard record.sessionId == lastSessionId, !state.isRecording,
              !uploader.pending.contains(where: { $0.sessionId == record.sessionId }) else { return }
        // One recording, one result: the 5-minute pieces are not the person's concern.
        ToastManager.shared.showSuccess(title: "録音を送り終えました", subtitle: "分析結果をお待ちください")
    }

    private func handleChunkFailed(_ record: ChunkRecord) {
        let reason = record.lastError ?? "原因不明"
        if record.state == .blocked {
            ToastManager.shared.showError(title: "送信できません", subtitle: "\(reason)。録音は端末に残っています")
        } else {
            ToastManager.shared.showError(title: "送信をやり直します", subtitle: "\(reason)。つながり次第もう一度送ります")
        }
    }

    /// At most every 5 minutes, when the app comes to the foreground and nothing is in progress.
    private func remindPendingIfAny() {
        guard !state.isRecording else { return }
        if let last = lastPendingReminderAt, Date().timeIntervalSince(last) < 300 { return }
        let waiting = state.pending.filter { $0.state != .uploading }
        guard !waiting.isEmpty else { return }
        lastPendingReminderAt = Date()
        let blocked = waiting.filter { $0.state == .blocked }.count
        ToastManager.shared.showError(
            title: "未送信の録音が\(waiting.count)件あります",
            subtitle: blocked > 0 ? "\(blocked)件は確認が必要です。録音画面で見られます" : "つながり次第送ります。録音画面で見られます"
        )
    }

    // MARK: - Helpers

    private func requestMicrophonePermissionIfNeeded() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await AVAudioApplication.requestRecordPermission()
        @unknown default:
            return false
        }
    }

    private func startRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.state.recordingStartTime else { return }
                self.state.recordingDuration = self.recordedBeforeSegment + Date().timeIntervalSince(start)
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        state.recordingStartTime = nil
        state.recordingDuration = 0
        recordedBeforeSegment = 0
    }
}
