//
//  RecordingView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/25.
//

import SwiftUI
import Combine

struct RecordingView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @ObservedObject var networkManager: NetworkManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var authManager: SupabaseAuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedRecording: RecordingModel?
    @State private var uploadingTotalCount = 0
    @State private var uploadingCurrentIndex = 0
    @State private var showDeviceLinkAlert = false
    @State private var isLinkingDevice = false
    @State private var currentTimeSlot = SlotTimeUtility.getCurrentSlot()
    @State private var timer: Timer?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                // 音声分析説明セクション
                VStack(spacing: 12) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(Color.safeColor("PrimaryActionColor"))
                    
                    Text("あなたの音（音声META情報）から、発達特性、認知傾向、メンタルヘルスを可視化します。")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                Divider()
                    .padding(.vertical, 8)
            
            // 録音時間の説明
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("ただいま録音されたデータは \(currentTimeSlot) の時間のデータポイントとしてグラフに表示されます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            
            // 録音開始/停止ボタン
            if audioRecorder.isRecording {
                // 録音停止ボタン
                Button(action: {
                    audioRecorder.stopRecording()
                }) {
                    HStack {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                        Text("録音を停止")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            } else {
                // 録音開始ボタン
                Button(action: {
                    // デバイスが連携されているか確認
                    if deviceManager.localDeviceIdentifier == nil {
                        showDeviceLinkAlert = true
                    } else {
                        audioRecorder.startRecording()
                    }
                }) {
                    HStack {
                        Image(systemName: "mic.circle.fill")
                            .font(.title2)
                        Text("録音を開始")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.safeColor("RecordingActive"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            
            // アップロード進捗表示
            if networkManager.connectionStatus == .uploading {
                VStack(spacing: 8) {
                    HStack {
                        if uploadingTotalCount > 0 {
                            Text("📤 アップロード中 (\(uploadingCurrentIndex)/\(uploadingTotalCount)件)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        } else {
                            Text("📤 アップロード中...")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        Text("\(Int(networkManager.uploadProgress * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    
                    ProgressView(value: networkManager.uploadProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color.safeColor("UploadActive")))
                    
                    if let fileName = networkManager.currentUploadingFile {
                        Text("ファイル: \(fileName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.safeColor("UploadActive").opacity(0.1))
                .cornerRadius(12)
            }
            
            // 録音状態の表示エリア
            if audioRecorder.isRecording {
                // 録音中の表示
                VStack(spacing: 8) {
                    Text("🔴 録音中...")
                        .font(.headline)
                        .foregroundColor(Color.safeColor("RecordingActive"))
                    
                    Text(audioRecorder.formatTime(audioRecorder.recordingTime))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.safeColor("RecordingActive"))
                    
                    Text(audioRecorder.getCurrentSlotInfo())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.safeColor("RecordingActive").opacity(0.1))
                .cornerRadius(12)
            }
            
            // 録音一覧（アップロード失敗またはアップロード待ちのファイルのみ）
            if !audioRecorder.recordings.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("録音ファイル（未送信）")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        // 古いファイルクリーンアップボタン
                        if audioRecorder.recordings.contains(where: { $0.fileName.hasPrefix("recording_") }) {
                            Button(action: {
                                audioRecorder.cleanupOldFiles()
                                alertMessage = "古い形式のファイルを削除しました"
                                showAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text("古いファイルを一括削除")
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.safeColor("WarningColor"))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(audioRecorder.recordings, id: \.fileName) { recording in
                                    RecordingRowView(
                                        recording: recording,
                                        isSelected: selectedRecording?.fileName == recording.fileName,
                                        onSelect: { selectedRecording = recording },
                                        onDelete: { recording in
                                            audioRecorder.deleteRecording(recording)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: 300)
                        
                        // 一括アップロードボタン（最下部に大きく表示）
                        if audioRecorder.recordings.filter({ !$0.isUploaded && $0.canUpload }).count > 0 {
                            Button(action: {
                                manualBatchUpload()
                            }) {
                                HStack {
                                    Image(systemName: "icloud.and.arrow.up")
                                        .font(.title3)
                                    Text("すべてアップロード")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.safeColor("UploadActive"))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .disabled(networkManager.connectionStatus == .uploading)
                        }
                    }
                }
            } else {
                Text("未送信の録音ファイルはありません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            }
                }
                .padding()
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
        .alert("通知", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("デバイス連携が必要です", isPresented: $showDeviceLinkAlert) {
            Button("はい") {
                // デバイス連携を実行
                linkDeviceAndStartRecording()
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("デバイスが連携されていないため録音できません。\nこのデバイスを連携しますか？")
        }
        .overlay(
            // デバイス連携中の表示
            Group {
                if isLinkingDevice {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("デバイスを連携しています...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(40)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(20)
                    }
                }
            }
        )
        .onAppear {
            // タイマーを開始して時間スロットを更新
            timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
                currentTimeSlot = SlotTimeUtility.getCurrentSlot()
            }
        }
        .onDisappear {
            // タイマーを停止
            timer?.invalidate()
            timer = nil
            
            // ビューが非表示になったら録音を停止
            if audioRecorder.isRecording {
                audioRecorder.stopRecording()
            }
        }
    }
    
    // デバイス連携後に録音を開始する
    private func linkDeviceAndStartRecording() {
        guard let userId = authManager.currentUser?.id else {
            alertMessage = "ユーザー情報が取得できません"
            showAlert = true
            return
        }
        
        isLinkingDevice = true
        
        // デバイス連携を実行
        deviceManager.registerDevice(userId: userId)
        
        // デバイス連携の完了を監視
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            checkDeviceLinkingStatus()
        }
    }
    
    // デバイス連携の状態を定期的にチェック
    private func checkDeviceLinkingStatus() {
        if deviceManager.isLoading {
            // まだ連携中なので、再度チェック
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                checkDeviceLinkingStatus()
            }
        } else {
            // 連携完了
            isLinkingDevice = false
            
            if let error = deviceManager.registrationError {
                // エラーが発生した場合
                alertMessage = "デバイス連携に失敗しました: \(error)"
                showAlert = true
            } else if deviceManager.isDeviceRegistered {
                // 連携成功
                alertMessage = "デバイス連携が完了しました"
                showAlert = true
                
                // ユーザーのデバイス一覧を再取得
                Task {
                    if let userId = authManager.currentUser?.id {
                        await deviceManager.fetchUserDevices(for: userId)
                    }
                    
                    // 少し待ってから録音を開始
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        audioRecorder.startRecording()
                    }
                }
            } else {
                // 予期しない状態
                alertMessage = "デバイス連携の状態が不明です"
                showAlert = true
            }
        }
    }
    
    // シンプルな一括アップロード（NetworkManagerを直接使用）- 逐次実行版
    private func manualBatchUpload() {
        // アップロード対象のリストを取得
        let recordingsToUpload = audioRecorder.recordings.filter { $0.canUpload }
        
        guard !recordingsToUpload.isEmpty else {
            alertMessage = "アップロード対象のファイルがありません。"
            showAlert = true
            return
        }
        
        print("📤 一括アップロード開始: \(recordingsToUpload.count)件")
        
        // アップロード件数を設定
        uploadingTotalCount = recordingsToUpload.count
        uploadingCurrentIndex = 0
        
        // 最初のファイルからアップロードを開始する
        uploadSequentially(recordings: recordingsToUpload)
    }
    
    // 再帰的にファイルを1つずつアップロードする関数
    private func uploadSequentially(recordings: [RecordingModel]) {
        // アップロードするリストが空になったら処理を終了
        guard let recording = recordings.first else {
            print("✅ 全ての一括アップロードが完了しました。")
            DispatchQueue.main.async {
                self.alertMessage = "すべての一括アップロードが完了しました。"
                self.showAlert = true
                // カウンターをリセット
                self.uploadingTotalCount = 0
                self.uploadingCurrentIndex = 0
            }
            return
        }
        
        // リストの残りを次の処理のために準備
        var remainingRecordings = recordings
        remainingRecordings.removeFirst()
        
        // 現在のアップロード番号を更新
        uploadingCurrentIndex = uploadingTotalCount - recordings.count + 1
        
        print("📤 アップロード中: \(recording.fileName) (\(uploadingCurrentIndex)/\(uploadingTotalCount))")
        
        // 1つのファイルをアップロード
        networkManager.uploadRecording(recording) { success in
            if success {
                print("✅ 一括アップロード成功: \(recording.fileName)")
                
                // アップロードが成功したので、このファイルを削除する
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("🗑️ 送信済みファイルを削除します:\(recording.fileName)")
                    self.audioRecorder.deleteRecording(recording)
                }
            } else {
                print("❌ 一括アップロード失敗: \(recording.fileName)")
            }
            
            // 成功・失敗にかかわらず、次のファイルのアップロードを再帰的に呼び出す
            self.uploadSequentially(recordings: remainingRecordings)
        }
    }
}

// MARK: - 録音ファイル行のビュー
struct RecordingRowView: View {
    @ObservedObject var recording: RecordingModel
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: (RecordingModel) -> Void
    @EnvironmentObject var deviceManager: DeviceManager
    
    // ファイル名から日付と時間スロットを抽出
    private var recordingDateTime: String {
        // ファイル名形式: "2025-08-19/22-00.wav"
        let components = recording.fileName.split(separator: "/")
        guard components.count == 2 else { return recording.fileName }
        
        let dateString = String(components[0])
        let timeComponent = String(components[1]).replacingOccurrences(of: ".wav", with: "")
        
        // 日付をパース
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = deviceManager.selectedDeviceTimezone
        
        guard let date = dateFormatter.date(from: dateString) else {
            return recording.fileName
        }
        
        // 日本語形式で日付を表示
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy年M月d日"
        displayFormatter.locale = Locale(identifier: "ja_JP")
        displayFormatter.timeZone = deviceManager.selectedDeviceTimezone
        
        // 時間スロットを整形 (22-00 -> 22:00)
        let timeFormatted = timeComponent.replacingOccurrences(of: "-", with: ":")
        
        return "\(displayFormatter.string(from: date)) \(timeFormatted)"
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // わかりやすい日時表示
                    Text(recordingDateTime)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(recording.fileSizeFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // アップロード失敗時のみエラー情報を表示
                if recording.uploadAttempts > 0 && !recording.isUploaded {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(Color.safeColor("WarningColor"))
                        
                        Text("アップロード失敗 (試行: \(recording.uploadAttempts)/3)")
                            .font(.caption)
                            .foregroundColor(Color.safeColor("WarningColor"))
                        
                        Spacer()
                    }
                    
                    // 詳細なエラー情報
                    if let error = recording.lastUploadError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                // 最大試行回数に達した場合はリセットボタンを表示
                if recording.uploadAttempts >= 3 {
                    Button(action: {
                        recording.resetUploadStatus()
                        print("🔄 アップロード状態リセット: \(recording.fileName)")
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Color.safeColor("WarningColor"))
                    }
                }
                
                // 削除ボタン
                Button(action: { onDelete(recording) }) {
                    Image(systemName: "trash")
                        .foregroundColor(Color.safeColor("RecordingActive"))
                }
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(8)
        .onTapGesture {
            onSelect()
        }
    }
}

// 日付フォーマッター
extension DateFormatter {
    static func display(for deviceManager: DeviceManager) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = Locale.current
        // デバイスのタイムゾーンを使用
        formatter.timeZone = deviceManager.selectedDeviceTimezone
        return formatter
    }
}

#Preview {
    let deviceManager = DeviceManager()
    let authManager = SupabaseAuthManager(deviceManager: deviceManager)
    return RecordingView(
        audioRecorder: AudioRecorder(),
        networkManager: NetworkManager(
            authManager: authManager,
            deviceManager: deviceManager
        )
    )
}