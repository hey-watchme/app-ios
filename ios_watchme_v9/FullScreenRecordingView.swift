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
    @EnvironmentObject var subjectManager: SubjectManager
    @EnvironmentObject var userAccountManager: UserAccountManager

    // 音声モニタリング（録音の有無に関わらず常に動作）
    @StateObject private var audioMonitor = AudioMonitorService()

    // UI状態
    @State private var showSignUpPrompt = false
    @State private var showVideoPicker = false
    @State private var showAudioFilePicker = false
    @State private var videoProcessingStarted = false  // 動画処理開始フラグ
    @State private var audioFileProcessingStarted = false  // 音声ファイル処理開始フラグ

    // MARK: - Body
    var body: some View {
        ZStack {
            // 紫背景（マイクを取られて録音が止まっている間は暗くする）
            (store.state.isInterrupted ? Color(white: 0.22) : Color.accentPurple)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: store.state.isInterrupted)

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

                    if store.state.isInterrupted {
                        Text("録音停止中")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                        Text("ほかのアプリや電話がマイクを使っています。\n使い終わると自動で続きを録音します")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    } else {
                        Text("録音中...")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Text(sessionProgressText)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 6)
                }

                if let quota = store.state.quota, !quota.isUnlimited {
                    Text(quota.summary)
                        .font(.footnote)
                        .foregroundColor(quota.isUsedUp ? .accentCoral : .white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
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
                    CloseButton { dismiss() }
                        .padding(16)
                }
                Spacer()
            }
        }
        .onAppear {
            // 音声モニタリング開始（録音中は録音側のレベルを表示する。下の onChange）
            if !store.state.isRecording {
                audioMonitor.startMonitoring()
            }

            Task {
                await store.initialize()
                await store.refreshQuota()
            }
        }
        .onDisappear {
            // 音声モニタリング停止
            audioMonitor.stopFollowing()
            audioMonitor.stopMonitoring()
        }
        .onChange(of: store.state.isRecording, initial: true) { _, recording in
            // While recording, the meter shows the recorder's level instead of opening the mic again
            if recording {
                audioMonitor.follow { [store] in MainActor.assumeIsolated { store.currentLevel() } }
            } else {
                audioMonitor.stopFollowing()
                audioMonitor.startMonitoring()
            }
        }
        .sheet(isPresented: $showSignUpPrompt) {
            SignUpView()
                .environmentObject(userAccountManager)
        }
        .sheet(isPresented: $showVideoPicker) {
            VideoPickerView(onVideoProcessingStarted: {
                // ビデオ処理開始フラグを立てる
                videoProcessingStarted = true
            })
                .environmentObject(subjectManager)
                .environmentObject(userAccountManager)
                .environmentObject(store)
        }
        .sheet(isPresented: $showAudioFilePicker) {
            AudioFilePickerView(onAudioProcessingStarted: {
                audioFileProcessingStarted = true
            })
            .environmentObject(subjectManager)
            .environmentObject(userAccountManager)
            .environmentObject(store)
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

            // No subject yet: make an unnamed one (名称未設定) and record to it.
            if subjectManager.selectedSubjectID == nil {
                Task { await createSubjectAndRecord() }
                return
            }

            // 録音開始
            Task {
                await store.startRecording()
            }
        }
    }

    private func createSubjectAndRecord() async {
        guard let userId = userAccountManager.effectiveUserId else {
            store.presentError("ユーザー情報が取得できないため、録音を始められませんでした")
            return
        }
        do {
            let subjectId = try await subjectManager.createSubject()
            await subjectManager.loadSubjects(for: userId)
            await MainActor.run { subjectManager.selectSubject(subjectId) }
            await store.startRecording()
        } catch {
            print("❌ Subject creation failed: \(error)")
            store.presentError("分析対象を用意できませんでした: \(error.localizedDescription)")
        }
    }

    /// While recording, only "sending" now and then: the 5-minute pieces are the machine's business.
    private var sessionProgressText: String {
        let limit = "\(store.sessionLimitMinutes)分で自動的に終了します"
        guard let sessionId = store.state.currentSessionId else { return limit }
        let sending = store.state.pending.contains { $0.sessionId == sessionId }
        return sending ? "録音データを送信中・\(limit)" : limit
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
    let subjectManager = SubjectManager()
    let userAccountManager = UserAccountManager(subjectManager: subjectManager)
    let recordingStore = RecordingStore(subjectManager: subjectManager, userAccountManager: userAccountManager)

    FullScreenRecordingView()
        .environmentObject(subjectManager)
        .environmentObject(userAccountManager)
        .environmentObject(recordingStore)
}
