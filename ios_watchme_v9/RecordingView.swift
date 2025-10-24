//
//  RecordingView.swift
//  ios_watchme_v9
//
//  録音機能のUI層（View-Store-Serviceアーキテクチャ）
//  RecordingStoreの状態を表示するだけのシンプルなView
//

import SwiftUI

struct RecordingView: View {
    // MARK: - Properties
    @EnvironmentObject var store: RecordingStore
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var userAccountManager: UserAccountManager

    // UI状態
    @State private var showDeviceRegistrationConfirm = false
    @State private var showSignUpPrompt = false

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                Color(.systemGray6)
                    .ignoresSafeArea()

                // メインコンテンツ
                VStack(spacing: 0) {
                    // エラー表示
                    if store.state.showError, let errorMessage = store.state.errorMessage {
                        ErrorBanner(message: errorMessage) {
                            store.dismissError()
                        }
                    }

                    // スクロール可能なコンテンツ
                    ScrollView {
                        VStack(spacing: 16) {
                            // 録音セクション
                            RecordingSection(store: store)
                                .padding(.horizontal)

                            // 録音ファイルセクション
                            RecordingFilesSection(store: store)
                                .padding(.horizontal)
                        }
                        .padding(.bottom, 100)
                    }
                }

                // 録音ボタン（下部固定）
                VStack {
                    Spacer()
                    RecordingControlButton(store: store) {
                        handleRecordingButtonTapped()
                    }
                }
            }
            .navigationTitle("録音")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                // 初期化（重い処理を事前実行）
                await store.initialize()
            }
        }
        .sheet(isPresented: $showSignUpPrompt) {
            SignUpView()
                .environmentObject(userAccountManager)
        }
        .confirmationDialog("デバイスを連携", isPresented: $showDeviceRegistrationConfirm) {
            Button("連携") {
                Task {
                    await registerDevice()
                }
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("このデバイスのマイクを使って音声情報を分析します")
        }
    }

    // MARK: - Private Methods

    private func handleRecordingButtonTapped() {
        if store.state.isRecording {
            // 録音停止 → シートを閉じる
            Task {
                await store.stopRecording()
                // 録音停止後、シートを閉じる
                dismiss()
            }
        } else {
            // 権限チェック
            if userAccountManager.requireWritePermission() {
                showSignUpPrompt = true
                return
            }

            // デバイスチェック
            if deviceManager.selectedDeviceID == nil {
                showDeviceRegistrationConfirm = true
                return
            }

            // 録音開始
            Task {
                await store.startRecording()
            }
        }
    }

    private func registerDevice() async {
        guard let userId = userAccountManager.currentUser?.profile?.userId else {
            return
        }

        await deviceManager.registerDevice(userId: userId)

        if deviceManager.registrationError == nil {
            // 登録成功後、録音を開始
            Task {
                await store.startRecording()
            }
        }
    }
}

// MARK: - Subviews

/// エラーバナー
struct ErrorBanner: View {
    let message: String
    let onClose: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color.safeColor("ErrorColor"))
            Text(message)
                .font(.subheadline)
                .foregroundColor(Color.safeColor("ErrorColor"))
            Spacer()
            Button("閉じる", action: onClose)
                .font(.caption)
        }
        .padding()
        .background(Color.safeColor("ErrorColor").opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

/// 録音セクション
struct RecordingSection: View {
    @ObservedObject var store: RecordingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // タイトル
            HStack {
                Text("録音データ")
                    .font(.system(size: 24, weight: .bold))
                Text("\(store.state.recordings.count)件")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // 録音中の表示
            if store.state.isRecording {
                RecordingIndicator(
                    duration: store.state.recordingDuration,
                    audioLevels: store.state.audioLevels
                )
            } else if store.state.recordings.isEmpty {
                // プレースホルダー
                EmptyRecordingPlaceholder()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

/// 録音中インジケーター
struct RecordingIndicator: View {
    let duration: TimeInterval
    let audioLevels: [CGFloat]

    var body: some View {
        VStack(spacing: 16) {
            // 波形表示
            HStack(spacing: 3) {
                ForEach(0..<audioLevels.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.safeColor("RecordingActive"))
                        .frame(width: 4, height: max(4, audioLevels[index] * 60))
                        .animation(.easeInOut(duration: 0.1), value: audioLevels[index])
                }
            }
            .frame(height: 60)

            VStack(spacing: 8) {
                Text("録音中")
                    .font(.headline)
                    .foregroundColor(Color.safeColor("RecordingActive"))

                Text(formatTime(duration))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.safeColor("RecordingActive"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.safeColor("RecordingActive").opacity(0.1))
        .cornerRadius(12)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, milliseconds)
    }
}

/// 空の録音プレースホルダー
struct EmptyRecordingPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 40))
                .foregroundColor(Color.secondary.opacity(0.5))
            Text("音声から、気分・行動・感情を分析します")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("録音データがありません")
                .font(.caption)
                .foregroundColor(Color.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

/// 録音ファイルセクション
struct RecordingFilesSection: View {
    @ObservedObject var store: RecordingStore

    var body: some View {
        VStack(spacing: 8) {
            // ファイルリスト
            ForEach(store.state.recordings, id: \.fileName) { recording in
                RecordingFileRow(recording: recording) {
                    Task {
                        await store.deleteRecording(recording)
                    }
                }
            }

            // アップロードボタン
            if !store.state.recordings.isEmpty {
                Button(action: {
                    Task {
                        await store.startBatchUpload()
                    }
                }) {
                    HStack {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(.title3)
                        Text("アップロード")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.safeColor("AppAccentColor"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(store.state.isUploading)
                .padding(.top, 8)
            }
        }
    }
}

/// 録音ファイル行
struct RecordingFileRow: View {
    let recording: RecordingModel
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(getDateString())
                    .font(.caption2)
                    .foregroundColor(.secondary)

                HStack {
                    Text(getTimeRange())
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    if recording.isRecordingFailed {
                        Text("録音失敗")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(Color.safeColor("ErrorColor"))
                    } else {
                        Text(recording.fileSizeFormatted)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(Color.safeColor("RecordingActive"))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func getDateString() -> String {
        let components = recording.fileName.split(separator: "/")
        guard components.count == 2 else { return "" }

        let dateString = String(components[0])
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        formatter.dateFormat = "yyyy年M月d日"
        formatter.locale = Locale(identifier: "ja_JP")

        return formatter.string(from: date)
    }

    private func getTimeRange() -> String {
        let components = recording.fileName.split(separator: "/")
        guard components.count == 2 else { return recording.fileName }

        let timeComponent = String(components[1]).replacingOccurrences(of: ".wav", with: "")
        let parts = timeComponent.split(separator: "-")

        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return timeComponent
        }

        let startTime = String(format: "%02d:%02d", hour, minute)

        var endHour = hour
        var endMinute = minute + 30
        if endMinute >= 60 {
            endHour += 1
            endMinute -= 60
        }
        if endHour >= 24 {
            endHour = 0
        }
        let endTime = String(format: "%02d:%02d", endHour, endMinute)

        return "\(startTime)-\(endTime)"
    }
}

/// 録音制御ボタン
struct RecordingControlButton: View {
    @ObservedObject var store: RecordingStore
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            Button(action: action) {
                HStack {
                    Image(systemName: store.state.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                    Text(store.state.isRecording ? "録音を停止" : "録音を開始")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(store.state.isRecording ? Color.black : Color.safeColor("RecordingActive"))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - BannerType Extension（UnifiedBanner連携）
extension BannerType {
    func toUnifiedStyle() -> BannerStyle {
        switch self {
        case .uploading(let fileName):
            return .detailed(
                title: "送信中...",
                subtitle: fileName,
                icon: "arrow.up.circle.fill",
                iconColor: .blue,
                progress: 0.0  // RecordingStoreから実際の進捗を受け取る
            )
        case .uploadSuccess:
            return .detailed(
                title: "送信完了",
                subtitle: "分析結果をお待ちください",
                icon: "checkmark.circle.fill",
                iconColor: .green,
                progress: nil
            )
        case .uploadFailure:
            return .detailed(
                title: "送信失敗",
                subtitle: "ネットワークのある環境でもう一度送信してください",
                icon: "exclamationmark.triangle.fill",
                iconColor: .orange,
                progress: nil
            )
        case .pushNotification(let message):
            return .simple(
                message: message,
                icon: "sparkles"
            )
        }
    }

    func shouldAutoDismiss() -> Bool {
        switch self {
        case .uploading:
            return false  // 送信中は自動非表示しない
        case .uploadSuccess, .uploadFailure, .pushNotification:
            return true  // 完了/失敗/プッシュ通知は8秒後に自動非表示
        }
    }
}

// MARK: - RecordingStore Extension

extension RecordingStore {
    @MainActor
    func dismissError() {
        // stateのプロパティを直接変更せず、専用メソッドを追加する必要がある
        clearError()
    }
}

// MARK: - Preview

#Preview {
    let deviceManager = DeviceManager()
    let userAccountManager = UserAccountManager(deviceManager: deviceManager)
    let recordingStore = RecordingStore(deviceManager: deviceManager, userAccountManager: userAccountManager)

    RecordingView()
        .environmentObject(deviceManager)
        .environmentObject(userAccountManager)
        .environmentObject(recordingStore)
}