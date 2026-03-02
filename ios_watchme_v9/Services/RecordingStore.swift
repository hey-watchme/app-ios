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

// MARK: - State（単一の信頼できる状態）
struct RecordingState {
    // 録音状態
    var isRecording = false
    var recordingStartTime: Date?
    var recordingDuration: TimeInterval = 0
    var currentSlot: String = ""

    // 録音ファイル管理
    var recordings: [RecordingModel] = []

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

        // Note: AudioLevelは現在使用していない（AudioMonitorServiceが直接UIに提供）
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
            try await audioService.startRecording(fileName: fileName)
            print("✅ RecordingStore: 録音開始成功")
        } catch {
            // エラー時はUIを戻す
            state.isRecording = false
            state.recordingStartTime = nil
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
            state.errorMessage = "録音停止に失敗しました: \(error.localizedDescription)"
            state.showError = true
            print("❌ RecordingStore: 録音停止失敗 - \(error)")
        }
    }

    /// 一括アップロード開始
    func startBatchUpload() async {
        guard !state.isUploading else {
            print("⚠️ RecordingStore: 既にアップロード中です")
            return
        }

        // アップロード対象を選定
        let uploadTargets = state.recordings.filter { !$0.isUploaded && $0.fileExists() && $0.fileSize > 0 }

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

    private func generateFileName() -> String {
        let dateString = SlotTimeUtility.getDateString(from: Date(), timezone: deviceManager.selectedDeviceTimezone)
        let slot = getCurrentSlot()
        return "\(dateString)/\(slot).wav"
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

    private func handleRecordingCompleted(_ result: Result<RecordingInfo, Error>) {
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
            state.errorMessage = "録音に失敗しました: \(error.localizedDescription)"
            state.showError = true
            print("❌ RecordingStore: 録音失敗 - \(error)")
        }
    }

    private func attemptAutoUpload(_ recording: RecordingModel) async {
        print("🚀 RecordingStore: 自動アップロード開始 - \(recording.fileName)")

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

            // 成功
            try await audioService.deleteRecordingFile(url: recording.getFileURL())
            print("✅ RecordingStore: 自動アップロード成功、ファイル削除済み")

            // Brief delay to show 100% before showing success
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s

            // 成功トースト表示
            ToastManager.shared.showSuccess(
                title: "送信完了",
                subtitle: "分析結果をお待ちください"
            )

        } catch {
            // 失敗：リストに追加
            state.recordings.insert(recording, at: 0)
            print("❌ RecordingStore: 自動アップロード失敗、リストに追加 - \(error)")

            // エラーメッセージを取得（サーバーからの詳細メッセージを優先）
            let errorMessage = error.localizedDescription

            // 失敗トースト表示（サーバーからのエラーメッセージを表示）
            ToastManager.shared.showError(
                title: "送信失敗",
                subtitle: errorMessage
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

                // リストから削除
                state.recordings.removeAll { $0.fileName == recording.fileName }

                // ファイル削除
                try? await audioService.deleteRecordingFile(url: recording.getFileURL())

                print("✅ RecordingStore: アップロード成功 - \(recording.fileName)")

            } catch {
                // 失敗
                state.uploadStats.failure += 1
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
            let recordings = try await audioService.loadRecordings()
            state.recordings = recordings.sorted { $0.date > $1.date }
            print("📋 RecordingStore: 録音ファイル読み込み完了 - \(recordings.count)件")
        } catch {
            print("❌ RecordingStore: 録音ファイル読み込み失敗 - \(error)")
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
