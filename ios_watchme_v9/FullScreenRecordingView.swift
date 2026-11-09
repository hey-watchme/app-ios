//
//  FullScreenRecordingView.swift
//  ios_watchme_v9
//
//  全画面録音UI（ChatGPT音声モード風）
//  完全ネイティブ実装
//

import SwiftUI

struct FullScreenRecordingView: View {
    // MARK: - Properties
    @EnvironmentObject var store: RecordingStore
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var userAccountManager: UserAccountManager

    // 音声モニタリング（録音の有無に関わらず常に動作）
    @StateObject private var audioMonitor = AudioMonitorService()

    // UI状態
    @State private var showDeviceRegistrationConfirm = false
    @State private var showSignUpPrompt = false
    @State private var showVideoPicker = false
    @State private var showAudioFilePicker = false
    @State private var videoProcessingStarted = false  // 動画処理開始フラグ
    @State private var audioFileProcessingStarted = false  // 音声ファイル処理開始フラグ

    // MARK: - Body
    var body: some View {
        ZStack {
            // 紫背景
            Color.accentPurple
                .ignoresSafeArea()

            VStack {
                Spacer()

                // エラー表示
                if store.state.showError, let errorMessage = store.state.errorMessage {
                    ErrorMessageView(message: errorMessage) {
                        store.clearError()
                    }
                    .padding(.bottom, 40)
                }

                // 音声ビジュアライザー（常に音声に反応）
                AudioBarVisualizerView(audioLevel: audioMonitor.audioLevel)
                    .padding(.bottom, 40)

                // 録音状態に応じた表示
                if store.state.isRecording {
                    // 録音時間表示
                    Text(formatTime(store.state.recordingDuration))
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.bottom, 20)

                    Text(store.state.isInterrupted ? "中断中（電話などが終わると再開します）" : "録音中...")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))

                    Text(sessionProgressText)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 6)
                }

                Spacer()

                // 録音制御ボタンとビデオ選択ボタン
                VStack(spacing: 20) {
                    // ビデオ選択ボタン（録音していない時のみ表示）
                    if !store.state.isRecording {
                        VStack(spacing: 12) {
                            if !store.state.pending.isEmpty {
                                PendingRecordingsPanel()
                            }

                            HStack(spacing: 12) {
                                Button(action: {
                                    showVideoPicker = true
                                }) {
                                    Text("カメラロール")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.2))
                                                .overlay(
                                                    Capsule()
                                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }

                                Button(action: {
                                    showAudioFilePicker = true
                                }) {
                                    Text("ファイル")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.2))
                                                .overlay(
                                                    Capsule()
                                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }
                            }

                            Text("カメラロールの撮影動画から音声を抽出して分析できます。また、ファイルにある音声ファイルも分析できます。")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                        .padding(.horizontal, 24)
                        .transition(.scale.combined(with: .opacity))
                    }

                    // 録音制御ボタン
                    RecordingButton(
                        isRecording: store.state.isRecording,
                        action: handleRecordingButtonTapped
                    )
                }
                .padding(.bottom, 60)
            }

            // 閉じるボタン（右上）
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            // 音声モニタリング開始（録音の有無に関わらず）
            audioMonitor.startMonitoring()

            Task {
                await store.initialize()
            }
        }
        .onDisappear {
            // 音声モニタリング停止
            audioMonitor.stopMonitoring()
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
        .sheet(isPresented: $showVideoPicker) {
            VideoPickerView(onVideoProcessingStarted: {
                // ビデオ処理開始フラグを立てる
                videoProcessingStarted = true
            })
                .environmentObject(deviceManager)
                .environmentObject(userAccountManager)
                .environmentObject(store)
        }
        .sheet(isPresented: $showAudioFilePicker) {
            AudioFilePickerView(onAudioProcessingStarted: {
                audioFileProcessingStarted = true
            })
            .environmentObject(deviceManager)
            .environmentObject(userAccountManager)
        }
        .onChange(of: videoProcessingStarted) { oldValue, newValue in
            // 動画処理が開始されたら録音モーダルを閉じる
            if newValue {
                dismiss()
            }
        }
        .onChange(of: audioFileProcessingStarted) { oldValue, newValue in
            // 音声ファイル処理が開始されたら録音モーダルを閉じる
            if newValue {
                dismiss()
            }
        }
    }

    // MARK: - Private Methods

    private func handleRecordingButtonTapped() {
        if store.state.isRecording {
            // 録音停止
            Task {
                await store.stopRecording()
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
        guard let userId = userAccountManager.effectiveUserId else {
            store.presentError("ユーザー情報が取得できないため、デバイス連携に失敗しました")
            print("❌ デバイス連携失敗: userIdを解決できません")
            return
        }

        do {
            let _ = try await deviceManager.registerDevice(userId: userId)
            await deviceManager.loadDevices(for: userId)

            // 登録成功後、録音を開始
            Task {
                await store.startRecording()
            }
        } catch {
            print("❌ デバイス登録エラー: \(error)")
            store.presentError("デバイス連携に失敗しました: \(error.localizedDescription)")
        }
    }

    private var sessionProgressText: String {
        let finished = store.state.sessionChunksFinished
        let delivered = store.state.sessionChunksDelivered
        let base = "\(RecordingStore.chunkMinutes)分ごとに送られます・最長\(RecordingStore.maxMinutes)分"
        return finished > 0 ? "送信済み \(delivered) / \(finished)・\(base)" : base
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Subviews

/// 端末に残っている（サーバーがまだ受け取っていない）録音の一覧と、まとめて再送するボタン
struct PendingRecordingsPanel: View {
    @EnvironmentObject var store: RecordingStore
    @State private var recordToDelete: ChunkRecord?

    private let maxVisibleRows = 3

    var body: some View {
        let pending = store.state.pending
        let sending = pending.contains { $0.state == .uploading }

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: sending ? "arrow.up.circle" : "exclamationmark.triangle.fill")
                    .foregroundColor(.accentTealMuted)
                Text("未送信の録音 \(pending.count)件")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }

            ForEach(pending.prefix(maxVisibleRows)) { record in
                row(for: record)
            }

            if pending.count > maxVisibleRows {
                Text("ほか \(pending.count - maxVisibleRows)件")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.75))
            }

            Button(action: {
                Task { await store.retryAllNow() }
            }) {
                HStack(spacing: 8) {
                    if sending {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(sending ? "送信中..." : "今すぐ再送")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                )
            }
            .disabled(sending)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.25), lineWidth: 1))
        )
        .confirmationDialog(
            "この録音を削除しますか？",
            isPresented: Binding(
                get: { recordToDelete != nil },
                set: { if !$0 { recordToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                if let record = recordToDelete {
                    Task { await store.deleteRecording(record) }
                }
                recordToDelete = nil
            }
            Button("キャンセル", role: .cancel) {
                recordToDelete = nil
            }
        } message: {
            Text("送信していない録音は元に戻せません")
        }
    }

    private func row(for record: ChunkRecord) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title(for: record))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white)

                Text(statusText(for: record))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(2)
            }

            Spacer()

            Button(action: { recordToDelete = record }) {
                Image(systemName: "trash")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(4)
            }
            .disabled(record.state == .uploading)
        }
    }

    private func title(for record: ChunkRecord) -> String {
        var parts = [Self.dateText(record.recordedAt)]
        if let duration = record.durationSeconds {
            parts.append(Self.durationText(duration))
        }
        if let sequence = record.sequence {
            parts.append("断片 \(sequence + 1)")
        }
        return parts.joined(separator: "・")
    }

    private func statusText(for record: ChunkRecord) -> String {
        switch record.state {
        case .uploading:
            return "送信中"
        case .blocked:
            return "要確認: \(record.lastError ?? "送信できません")"
        case .recorded:
            if let error = record.lastError {
                return "再送待ち: \(error)"
            }
            return record.recovered ? "前回の録音から復旧。送信待ち" : "送信待ち"
        case .recording:
            return "録音中"
        }
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }

    private static func durationText(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return total >= 60 ? "\(total / 60)分\(total % 60)秒" : "\(total)秒"
    }
}

/// エラーメッセージ表示
struct ErrorMessageView: View {
    let message: String
    let onClose: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.accentTealMuted)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentCoral.opacity(0.3))
        )
        .padding(.horizontal, 24)
    }
}

/// 録音ボタン（0.8倍に縮小）
struct RecordingButton: View {
    let isRecording: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // 外側のリング（0.8倍）- 完全な白
                Circle()
                    .stroke(Color.white, lineWidth: 3.2)
                    .frame(width: 80, height: 80)

                // 内側のボタン
                if isRecording {
                    // 停止ボタン（四角、0.8倍）
                    RoundedRectangle(cornerRadius: 6.4)
                        .fill(Color.white)
                        .frame(width: 32, height: 32)
                } else {
                    // 録音ボタン（円、0.8倍）
                    Circle()
                        .fill(Color.white)
                        .frame(width: 64, height: 64)
                }
            }
        }
        .scaleEffect(isRecording ? 0.9 : 1.0)
        .animation(.spring(response: 0.3), value: isRecording)
    }
}

// MARK: - Preview
#Preview {
    let deviceManager = DeviceManager()
    let userAccountManager = UserAccountManager(deviceManager: deviceManager)
    let recordingStore = RecordingStore(deviceManager: deviceManager, userAccountManager: userAccountManager)

    FullScreenRecordingView()
        .environmentObject(deviceManager)
        .environmentObject(userAccountManager)
        .environmentObject(recordingStore)
}
