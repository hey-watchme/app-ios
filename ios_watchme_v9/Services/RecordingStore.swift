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
    var recordingDuration: TimeInterval = 0
    var currentSessionId: String?
    var sessionChunksFinished = 0   // closed so far in this session
    var sessionChunksDelivered = 0  // confirmed by the server so far in this session

    // Sending: everything on the device the server has not confirmed (not the chunk being written)
    var pending: [ChunkRecord] = []

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
    static let maxMinutes = Int(AudioRecorderService.maxSessionSeconds / 60)

    private let audioService: AudioRecorderService
    private let uploader: ChunkUploader
    private let deviceManager: DeviceManager
    private let userAccountManager: UserAccountManager

    private var cancellables = Set<AnyCancellable>()
    private var recordingTimer: Timer?
    private var lastPendingReminderAt: Date?
    private var lastSessionId: String?
    private var lastSessionChunks = 0

    init(
        audioService: AudioRecorderService? = nil,
        deviceManager: DeviceManager,
        userAccountManager: UserAccountManager
    ) {
        self.audioService = audioService ?? AudioRecorderService()
        self.uploader = ChunkUploader.shared
        self.deviceManager = deviceManager
        self.userAccountManager = userAccountManager

        setupBindings()
        uploader.defaultDeviceId = { [weak deviceManager] in deviceManager?.selectedDeviceID }
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
            .sink { [weak self] id in self?.handleChunkFinished(id) }
            .store(in: &cancellables)

        audioService.sessionEnded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reason in self?.handleSessionEnded(reason) }
            .store(in: &cancellables)

        audioService.interruptionChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] interrupted in self?.state.isInterrupted = interrupted }
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
        guard let deviceId = deviceManager.selectedDeviceID else {
            presentError("デバイスが選択されていません")
            return
        }
        guard await requestMicrophonePermissionIfNeeded() else {
            presentError("マイクへのアクセスが許可されていません。設定アプリから許可してください。")
            return
        }

        do {
            try audioService.configureAudioSession()
            let sessionId = try audioService.startSession(deviceId: deviceId, timezone: deviceManager.selectedDeviceTimezone)
            state.isRecording = true
            state.isInterrupted = false
            state.recordingStartTime = Date()
            state.recordingDuration = 0
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

    func stopRecording() async {
        guard state.isRecording else { return }
        audioService.stopSession()   // state is updated from sessionEnded
    }

    /// Import an audio or video file: cut it into 5-minute chunks stamped with when it was
    /// recorded, journal them and send them like a live recording. No length limit.
    func importFile(at url: URL, originalDates: AudioImporter.FileDates?) async throws {
        guard let deviceId = deviceManager.selectedDeviceID else {
            throw AudioImportError.readFailed("デバイスが選択されていません")
        }
        var shown = -1
        let result = try await AudioImporter.importFile(
            at: url, originalDates: originalDates, deviceId: deviceId, timezone: deviceManager.selectedDeviceTimezone
        ) { progress in
            let percent = Int(progress * 100)
            guard percent != shown else { return }
            shown = percent
            ToastManager.shared.showProgressWithPhase(phase: "音声を取り込み中...", subtitle: "\(percent)%", progress: progress)
        }

        importSessions[result.sessionId] = result.chunkCount
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = deviceManager.selectedDeviceTimezone
        formatter.dateFormat = "M/d HH:mm"
        let minutes = Int((result.durationSeconds / 60).rounded())
        ToastManager.shared.announce(
            title: "\(formatter.string(from: result.startedAt)) の録音として取り込みました",
            subtitle: "\(result.startSource.label)・約\(minutes)分を\(result.chunkCount)本に分けて送ります"
        )
        announceImportDeliveredIfDone(result.sessionId)
    }

    private var importSessions: [String: Int] = [:]   // sessionId -> chunk count, until all are delivered

    private func announceImportDeliveredIfDone(_ sessionId: String) {
        guard let count = importSessions[sessionId],
              !uploader.pending.contains(where: { $0.sessionId == sessionId }) else { return }
        importSessions[sessionId] = nil
        ToastManager.shared.showSuccess(
            title: "取り込んだ録音を送り終えました",
            subtitle: "\(count)本を送りました。分析結果をお待ちください"
        )
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

    private func handleChunkFinished(_ id: String) {
        uploader.activeRecordingIds.remove(id)
        state.sessionChunksFinished += 1
        lastSessionChunks = state.sessionChunksFinished
        Task { await uploader.chunkFinished(id: id) }
    }

    private func handleSessionEnded(_ reason: RecordingEndReason) {
        lastSessionId = state.currentSessionId
        state.isRecording = false
        state.isInterrupted = false
        state.currentSessionId = nil
        stopRecordingTimer()

        switch reason {
        case .stopped:
            ToastManager.shared.showInfo(title: "録音を送っています", subtitle: "届き次第お知らせします")
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
        let count = max(lastSessionChunks, (record.sequence ?? 0) + 1)
        ToastManager.shared.showSuccess(
            title: "録音を送り終えました",
            subtitle: count > 1 ? "\(count)本の断片を送りました。分析結果をお待ちください" : "分析結果をお待ちください"
        )
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
                self.state.recordingDuration = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        state.recordingStartTime = nil
        state.recordingDuration = 0
    }
}
