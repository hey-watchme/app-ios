//
//  RecordingStore.swift
//  ios_watchme_v9
//
//  録音機能の状態管理とビジネスロジックを一元管理する司令塔
//  View-Store-Serviceアーキテクチャの中核
//

import Foundation
import Combine
import AVFoundation
import UIKit

// MARK: - State（単一の信頼できる状態）
struct RecordingState {
    // 録音状態
    var isRecording = false
    var recordingStartTime: Date?
    var recordingDuration: TimeInterval = 0
    var currentSlot: String = ""
    var currentRecordingFileName: String?

    // 録音ファイル管理（端末に残っている＝まだ送れていない録音）
    var recordings: [RecordingModel] = []
    var autoUploadingFileName: String?
    var uploadErrors: [String: String] = [:]  // fileName -> last error message

    // アップロード状態
    var isUploading = false
    var uploadQueue: [RecordingModel] = []
    var uploadProgress: Double = 0.0
    var uploadStats: (success: Int, failure: Int) = (0, 0)
    var currentUploadingFile: String?

    // バナー通知
    var bannerType: BannerType? = nil
    var bannerProgress: Double? = nil

    // エラー状態
    var errorMessage: String?
    var showError = false

    // 初期化状態
    var isAudioSessionPrepared = false
    var isInitialized = false
}

// MARK: - BannerType（バナー通知の種類）
enum BannerType: Equatable {
    case uploading(fileName: String)  // 送信中
    case uploadSuccess                // 送信完了
    case uploadFailure                // 送信失敗
    case pushNotification(message: String)  // プッシュ通知
}

// MARK: - RecordingStore（司令塔）
@MainActor
final class RecordingStore: ObservableObject {
    // MARK: - Published State
    @Published private(set) var state = RecordingState()

    // MARK: - Services（手足）
    private let audioService: AudioRecorderService
    private let uploaderService: UploaderService
    private let deviceManager: DeviceManager
    private let userAccountManager: UserAccountManager

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var recordingTimer: Timer?
    private var lastPendingReminderAt: Date?

    // MARK: - Initialization
    init(
        audioService: AudioRecorderService? = nil,
        uploaderService: UploaderService? = nil,
        deviceManager: DeviceManager,
        userAccountManager: UserAccountManager
    ) {
        self.audioService = audioService ?? AudioRecorderService()
        self.uploaderService = uploaderService ?? UploaderService()
        self.deviceManager = deviceManager
        self.userAccountManager = userAccountManager

        setupBindings()
    }

    // MARK: - Setup
    private func setupBindings() {
        // AudioRecorderServiceからの通知を監視
        audioService.recordingCompletedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.handleRecordingCompleted(result)
            }
            .store(in: &cancellables)

        audioService.interruptedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.handleRecordingInterrupted()
            }
            .store(in: &cancellables)

        // アプリを開くたびに、送れていない録音が残っていれば知らせる
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.remindPendingRecordingsIfAny() }
            }
            .store(in: &cancellables)

        // Note: AudioLevelは現在使用していない（AudioMonitorServiceが直接UIに提供）
    }

    /// Recordings left on the device were never sent (upload failed, or the app was closed while
    /// recording). Say so whenever the app comes to the foreground, at most every 5 minutes.
    private func remindPendingRecordingsIfAny() async {
        guard !state.isRecording, !state.isUploading, state.autoUploadingFileName == nil else { return }
        if let last = lastPendingReminderAt, Date().timeIntervalSince(last) < 300 { return }

        await loadRecordings()
        guard !state.recordings.isEmpty else { return }

        lastPendingReminderAt = Date()
        ToastManager.shared.showError(
            title: "未送信の録音が\(state.recordings.count)件あります",
            subtitle: "録音画面から再送するか削除できます"
        )
    }

    // MARK: - Public Methods（UIからの指示を受け取るインターフェース）

    /// 初期化（View表示時に一度だけ呼ぶ）
    func initialize() async {
        guard !state.isInitialized else { return }

        // 録音ファイル読み込みのみ実行
        // オーディオセッション準備は録音開始時まで遅延（AudioMonitorServiceとの競合回避）
        await loadRecordings()

        // 初期化完了
        state.isInitialized = true
        print("✅ RecordingStore: 初期化完了")
    }

    /// 録音開始
    func startRecording() async {
        guard !state.isRecording else {
            print("⚠️ RecordingStore: 既に録音中です")
            return
        }

        // 権限チェック（ゲストユーザーは録音不可）
        guard !userAccountManager.requireWritePermission() else {
            state.errorMessage = "録音には会員登録が必要です"
            state.showError = true
            return
        }

        // デバイスチェック
        guard deviceManager.selectedDeviceID != nil else {
            state.errorMessage = "デバイスが選択されていません"
            state.showError = true
            return
        }

        // マイクパーミッションチェック（初回録音時に要求）
        let permissionGranted = await requestMicrophonePermissionIfNeeded()
        guard permissionGranted else {
            state.errorMessage = "マイクへのアクセスが許可されていません。設定アプリから許可してください。"
            state.showError = true
            print("❌ RecordingStore: マイクパーミッション拒否")
            return
        }

        // オーディオセッション準備ができていない場合はリトライ
        if !state.isAudioSessionPrepared {
            print("⚠️ RecordingStore: オーディオセッション未準備、リトライ中...")
            do {
                try await audioService.prepareAudioSession()
                state.isAudioSessionPrepared = true
            } catch {
                // 準備失敗時は録音を中断
                state.errorMessage = "オーディオセッションの準備に失敗しました"
                state.showError = true
                print("❌ RecordingStore: オーディオセッション準備失敗、録音中断 - \(error)")
                return
            }
        }

        // UI即座更新（ユーザーへの即時フィードバック）
        state.isRecording = true
        state.recordingStartTime = Date()
        state.recordingDuration = 0
        state.currentSlot = getCurrentSlot()
        state.errorMessage = nil

        // 録音タイマー開始
        startRecordingTimer()

        // 実際の録音開始（非同期、軽量）
        do {
            let fileName = generateFileName()
            state.currentRecordingFileName = fileName
            try await audioService.startRecording(fileName: fileName)
            print("✅ RecordingStore: 録音開始成功")
        } catch {
            // エラー時はUIを戻す
            state.isRecording = false
            state.recordingStartTime = nil
            state.currentRecordingFileName = nil
            stopRecordingTimer()

            state.errorMessage = "録音開始に失敗しました: \(error.localizedDescription)"
            state.showError = true
            print("❌ RecordingStore: 録音開始失敗 - \(error)")
        }
    }

    /// 録音停止
    func stopRecording() async {
        guard state.isRecording else {
            print("⚠️ RecordingStore: 録音中ではありません")
            return
        }

        // UI即座更新
        state.isRecording = false
        stopRecordingTimer()

        // 実際の録音停止
        do {
            let fileURL = try await audioService.stopRecording()
            print("✅ RecordingStore: 録音停止成功 - \(fileURL)")

            // 録音完了処理はrecordingCompletedPublisher経由で受け取る
        } catch {
            // The sheet closes right after stopping, so an in-sheet message would never be seen
            ToastManager.shared.showError(
                title: "録音を止められませんでした",
                subtitle: error.localizedDescription
            )
            print("❌ RecordingStore: 録音停止失敗 - \(error)")
        }
    }

    /// 一括アップロード開始
    func startBatchUpload() async {
        guard !state.isUploading, state.autoUploadingFileName == nil else {
            print("⚠️ RecordingStore: 既にアップロード中です")
            return
        }

        // アップロード対象を選定（大きすぎて今は送れないものは端末に残す）
        let uploadTargets = state.recordings.filter {
            !$0.isUploaded && $0.fileExists() && $0.fileSize > 0 && !Self.exceedsUploadLimit($0)
        }

        guard !uploadTargets.isEmpty else {
            state.errorMessage = "アップロード対象のファイルがありません"
            state.showError = true
            return
        }

        // 状態更新
        state.isUploading = true
        state.uploadQueue = uploadTargets
        state.uploadStats = (success: 0, failure: 0)
        state.uploadProgress = 0.0

        print("📤 RecordingStore: 一括アップロード開始 - \(uploadTargets.count)件")

        // キューベースのアップロード処理
        await processUploadQueue()
    }

    /// 端末に残っている（まだ送れていない）録音を読み直す。録音画面を開くたびに呼ぶ
    func reloadPendingRecordings() async {
        await loadRecordings()
    }

    /// サーバーが今は受け取れない大きさか（S3 への直接アップロードに変えるまでの制限）
    static func exceedsUploadLimit(_ recording: RecordingModel) -> Bool {
        recording.fileSize > UploaderService.maxUploadBytes
    }

    /// エラーをクリア
    func clearError() {
        state.showError = false
        state.errorMessage = nil
    }

    /// 任意のエラーメッセージを表示
    func presentError(_ message: String) {
        state.errorMessage = message
        state.showError = true
    }

    /// 録音ファイル削除
    func deleteRecording(_ recording: RecordingModel) async {
        // リストから即座に削除（UI更新）
        state.recordings.removeAll { $0.fileName == recording.fileName }
        state.uploadErrors[recording.fileName] = nil

        // 実際のファイル削除
        do {
            try await audioService.deleteRecordingFile(url: recording.getFileURL())
            print("✅ RecordingStore: ファイル削除成功 - \(recording.fileName)")
        } catch {
            // 削除失敗してもリストには戻さない（UX優先）
            print("❌ RecordingStore: ファイル削除失敗 - \(error)")
        }
    }

    // MARK: - Private Methods

    /// マイクパーミッションを必要に応じて要求
    private func requestMicrophonePermissionIfNeeded() async -> Bool {
        let audioSession = AVAudioSession.sharedInstance()

        switch audioSession.recordPermission {
        case .granted:
            // 既に許可済み
            print("✅ RecordingStore: マイクパーミッション既に許可済み")
            return true

        case .denied:
            // ユーザーが以前に拒否済み
            print("❌ RecordingStore: マイクパーミッション拒否済み")
            return false

        case .undetermined:
            // 初回：パーミッション要求
            print("🔔 RecordingStore: マイクパーミッション要求中...")
            return await withCheckedContinuation { continuation in
                audioSession.requestRecordPermission { granted in
                    if granted {
                        print("✅ RecordingStore: マイクパーミッション許可")
                    } else {
                        print("❌ RecordingStore: マイクパーミッション拒否")
                    }
                    continuation.resume(returning: granted)
                }
            }

        @unknown default:
            print("⚠️ RecordingStore: 未知のパーミッション状態")
            return false
        }
    }

    private func getCurrentSlot() -> String {
        return SlotTimeUtility.getCurrentSlot(timezone: deviceManager.selectedDeviceTimezone)
    }

    /// YYYY-MM-DD/HH-mm-ss.wav. Down to the second so a new recording never overwrites
    /// an earlier one that is still waiting to be sent (30-minute slot names did).
    private func generateFileName() -> String {
        let now = Date()
        let timezone = deviceManager.selectedDeviceTimezone
        let dateString = SlotTimeUtility.getDateString(from: now, timezone: timezone)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH-mm-ss"
        formatter.timeZone = timezone
        return "\(dateString)/\(formatter.string(from: now)).wav"
    }

    private func startRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let startTime = self.state.recordingStartTime else { return }
                self.state.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        state.recordingDuration = 0
    }

    /// A call or Siri took the microphone. The service already finished the file, and the
    /// completion handler uploads it; here only the UI state is brought back.
    private func handleRecordingInterrupted() {
        // The session has to be set up again before the next recording
        state.isAudioSessionPrepared = false
        guard state.isRecording else { return }
        state.isRecording = false
        stopRecordingTimer()
        ToastManager.shared.showError(
            title: "録音が中断されました",
            subtitle: "電話などでマイクが使われたため、そこまでの録音を送信します"
        )
    }

    private func handleRecordingCompleted(_ result: Result<RecordingInfo, Error>) {
        state.currentRecordingFileName = nil
        switch result {
        case .success(let info):
            print("📝 RecordingStore: 録音完了 - \(info.fileName)")

            // RecordingModelを作成
            let recording = RecordingModel(fileName: info.fileName, date: info.date)

            // 自動アップロードを試行
            Task {
                await attemptAutoUpload(recording)
            }

        case .failure(let error):
            // The sheet is usually closed by now, so use a toast
            state.isRecording = false
            stopRecordingTimer()
            ToastManager.shared.showError(
                title: "録音に失敗しました",
                subtitle: error.localizedDescription
            )
            print("❌ RecordingStore: 録音失敗 - \(error)")
        }
    }

    private func attemptAutoUpload(_ recording: RecordingModel) async {
        print("🚀 RecordingStore: 自動アップロード開始 - \(recording.fileName)")
        state.autoUploadingFileName = recording.fileName
        defer { state.autoUploadingFileName = nil }

        // トースト表示（送信中 0% - 100%）
        ToastManager.shared.showProgressWithPhase(
            phase: "送信中...",
            subtitle: recording.fileName,
            progress: 0.0
        )

        do {
            // Store層がUploadRequestを構築
            let uploadRequest = createUploadRequest(for: recording)

            // プログレス更新（50%）
            ToastManager.shared.showProgressWithPhase(
                phase: "送信中...",
                subtitle: recording.fileName,
                progress: 0.5
            )

            // アップロード実行
            try await uploaderService.upload(uploadRequest)

            // プログレス更新（100%）
            ToastManager.shared.showProgressWithPhase(
                phase: "送信中...",
                subtitle: recording.fileName,
                progress: 1.0
            )

            // 成功。消せなかったときは未送信に見えるが、再送すると 409 で送信済みとして消える
            do {
                try await audioService.deleteRecordingFile(url: recording.getFileURL())
            } catch {
                print("⚠️ RecordingStore: uploaded, but the local file could not be deleted - \(error)")
            }
            print("✅ RecordingStore: 自動アップロード成功、ファイル削除済み")

            // Brief delay to show 100% before showing success
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s

            // 成功トースト表示
            ToastManager.shared.showSuccess(
                title: "送信完了",
                subtitle: "分析結果をお待ちください"
            )

        } catch {
            // 失敗：端末に残し、録音画面の「未送信の録音」に出す
            state.recordings.removeAll { $0.fileName == recording.fileName }
            state.recordings.insert(recording, at: 0)
            state.uploadErrors[recording.fileName] = error.localizedDescription
            print("❌ RecordingStore: 自動アップロード失敗、リストに追加 - \(error)")

            // 失敗トースト表示（サーバーからのエラーメッセージを表示）
            let reason = error.localizedDescription.trimmingCharacters(in: CharacterSet(charactersIn: "。."))
            let isTooLarge: Bool
            if case UploadError.tooLarge = error { isTooLarge = true } else { isTooLarge = false }
            ToastManager.shared.showError(
                title: "送信できませんでした",
                subtitle: isTooLarge
                    ? "\(reason)。録音は端末に残しました"
                    : "\(reason)。録音は端末に残っていて、録音画面から再送できます"
            )
        }
    }

    private func processUploadQueue() async {
        while !state.uploadQueue.isEmpty {
            guard let recording = state.uploadQueue.first else { break }

            // キューから削除
            state.uploadQueue.removeFirst()

            // 進捗更新
            let total = state.uploadStats.success + state.uploadStats.failure + state.uploadQueue.count + 1
            let progress = Double(state.uploadStats.success + state.uploadStats.failure) / Double(total)

            // トースト更新（送信中）
            state.currentUploadingFile = recording.fileName
            ToastManager.shared.showProgressWithPhase(
                phase: "送信中...",
                subtitle: recording.fileName,
                progress: progress
            )

            do {
                // Store層がUploadRequestを構築
                let uploadRequest = createUploadRequest(for: recording)

                // アップロード実行
                try await uploaderService.upload(uploadRequest)

                // 成功
                state.uploadStats.success += 1
                state.uploadErrors[recording.fileName] = nil

                // リストから削除
                state.recordings.removeAll { $0.fileName == recording.fileName }

                // ファイル削除
                try? await audioService.deleteRecordingFile(url: recording.getFileURL())

                print("✅ RecordingStore: アップロード成功 - \(recording.fileName)")

            } catch {
                // 失敗
                state.uploadStats.failure += 1
                state.uploadErrors[recording.fileName] = error.localizedDescription
                print("❌ RecordingStore: アップロード失敗 - \(recording.fileName): \(error)")
            }
        }

        // 完了処理
        state.isUploading = false
        state.currentUploadingFile = nil

        // 結果トースト表示
        if state.uploadStats.failure == 0 {
            ToastManager.shared.showSuccess(
                title: "送信完了",
                subtitle: "すべてアップロードしました（\(state.uploadStats.success)件）"
            )
        } else if state.uploadStats.success > 0 {
            ToastManager.shared.showError(
                title: "一部失敗",
                subtitle: "成功: \(state.uploadStats.success)件、失敗: \(state.uploadStats.failure)件"
            )
        } else {
            ToastManager.shared.showError(
                title: "送信失敗",
                subtitle: "アップロードに失敗しました"
            )
        }

        print("📊 RecordingStore: アップロード結果 - 成功: \(state.uploadStats.success), 失敗: \(state.uploadStats.failure)")
    }


    private func loadRecordings() async {
        do {
            let busy = Set([state.currentRecordingFileName, state.autoUploadingFileName].compactMap { $0 })
            let recordings = try await audioService.loadRecordings().filter { !busy.contains($0.fileName) }
            state.recordings = recordings.sorted { $0.date > $1.date }
            print("📋 RecordingStore: 録音ファイル読み込み完了 - \(recordings.count)件")
        } catch {
            print("❌ RecordingStore: 録音ファイル読み込み失敗 - \(error)")
            ToastManager.shared.showError(
                title: "端末の録音を読み込めませんでした",
                subtitle: error.localizedDescription
            )
        }
    }

    // MARK: - Upload Request Factory（Store層の責務）

    private func createUploadRequest(for recording: RecordingModel) -> UploadRequest {
        // Store層がすべての依存関係からデータを収集
        let userID = getUserID()
        let deviceID = deviceManager.selectedDeviceID ?? "unknown"

        return UploadRequest(
            fileURL: recording.getFileURL(),
            fileName: recording.fileName,
            userID: userID,
            deviceID: deviceID,
            recordedAt: recording.date,
            timezone: deviceManager.selectedDeviceTimezone
        )
    }

    private func getUserID() -> String {
        // 認証済みユーザーIDを優先
        if let authenticatedUser = userAccountManager.currentUser {
            return authenticatedUser.profile?.userId ?? authenticatedUser.id
        } else {
            // フォールバック
            let userDefaults = UserDefaults.standard
            let userIDKey = "app_user_id"

            if let existingUserID = userDefaults.string(forKey: userIDKey) {
                return existingUserID
            } else {
                let newUserID = "user_\(UUID().uuidString.prefix(8))"
                userDefaults.set(newUserID, forKey: userIDKey)
                return newUserID
            }
        }
    }
}

// MARK: - Helper Types
struct RecordingInfo {
    let fileName: String
    let date: Date
    let fileURL: URL
}
