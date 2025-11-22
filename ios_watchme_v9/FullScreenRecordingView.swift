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

    // MARK: - Body
    var body: some View {
        ZStack {
            // 半透明の黒背景
            Color.black.opacity(0.8)
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
                // ※ BlobVisualizerView を使用（AudioVisualizerViewは旧バージョン）
                BlobVisualizerView(audioLevel: audioMonitor.audioLevel)
                    .padding(.bottom, 40)

                // 録音状態に応じた表示
                if store.state.isRecording {
                    // 録音時間表示
                    Text(formatTime(store.state.recordingDuration))
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.bottom, 20)

                    Text("録音中...")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // 録音制御ボタン
                RecordingButton(
                    isRecording: store.state.isRecording,
                    action: handleRecordingButtonTapped
                )
                .padding(.bottom, 60)
            }

            // 閉じるボタン（右上）- シンプルな白い×
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

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Subviews

/// エラーメッセージ表示
struct ErrorMessageView: View {
    let message: String
    let onClose: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
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
                .fill(Color.red.opacity(0.3))
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
                        .fill(Color.red)
                        .frame(width: 32, height: 32)
                } else {
                    // 録音ボタン（円、0.8倍）
                    Circle()
                        .fill(Color.red)
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
