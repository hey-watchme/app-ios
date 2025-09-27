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
    @EnvironmentObject var userAccountManager: UserAccountManager
    @Environment(\.dismiss) private var dismiss
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedRecording: RecordingModel?
    @State private var uploadingTotalCount = 0
    @State private var uploadingCurrentIndex = 0
    @State private var showDeviceLinkAlert = false
    @State private var isLinkingDevice = false
    @State private var currentTimeSlot = SlotTimeUtility.getCurrentSlot()
    @State private var deviceCurrentTime = ""
    @State private var timer: Timer?
    
    var body: some View {
        NavigationView {
            ZStack {
                // メインコンテンツ
                VStack(spacing: 0) {
                    // 上部説明セクション（固定）
                    VStack(spacing: 16) {
                        // 音声分析説明
                        VStack(spacing: 12) {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 100)) // 2倍サイズ
                                .foregroundColor(Color.safeColor("AppAccentColor"))
                                .padding(.top, 50) // 上側余白50ピクセル
                            
                            Text("音声から、気分・行動・感情を分析します。")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary)
                        }
                        
                        Divider()
                        
                        // デバイスタイムゾーン情報（1行）
                        HStack {
                            Image(systemName: "globe")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("デバイスタイムゾーン:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(deviceManager.selectedDeviceTimezone.identifier)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        
                        // 現在時刻（1行）
                        HStack {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("現在時刻:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(deviceCurrentTime)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        // 録音データポイント（1行）
                        HStack {
                            Image(systemName: "waveform.path")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("録音データポイント:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(currentTimeSlot)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
            
            // 録音エラー表示
            if let errorMessage = audioRecorder.recordingError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color.safeColor("ErrorColor"))
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(Color.safeColor("ErrorColor"))
                    Spacer()
                    Button("閉じる") {
                        audioRecorder.recordingError = nil
                    }
                    .font(.caption)
                }
                .padding()
                .background(Color.safeColor("ErrorColor").opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
                    
                    // スクロール可能なコンテンツエリア
                    ScrollView {
                        VStack(spacing: 16) {
            
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
            
            // 録音データセクション
            VStack(alignment: .leading, spacing: 12) {
                // タイトル
                HStack {
                    Text("録音データ")
                        .font(.headline)
                    Text("\(audioRecorder.recordings.count)件")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    // 古いファイルクリーンアップボタン
                    if audioRecorder.recordings.contains(where: { $0.fileName.hasPrefix("recording_") }) {
                        Button(action: {
                            audioRecorder.cleanupOldFiles()
                            alertMessage = "古い形式のファイルを削除しました"
                            showAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("古いファイル削除")
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.safeColor("WarningColor"))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                
                // 録音状態の表示エリア
                if audioRecorder.isRecording {
                    // 録音中の表示
                    VStack(spacing: 16) {
                        // 波形表示
                        HStack(spacing: 3) {
                            ForEach(0..<audioRecorder.audioLevels.count, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.safeColor("RecordingActive"))
                                    .frame(width: 4, height: max(4, audioRecorder.audioLevels[index] * 60))
                                    .animation(.easeInOut(duration: 0.05), value: audioRecorder.audioLevels[index])
                            }
                        }
                        .frame(height: 60)
                        
                        VStack(spacing: 8) {
                            Text("録音中")
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
                    }
                    .padding()
                    .background(Color.safeColor("RecordingActive").opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // 録音ファイルリストまたはプレースホルダー
                if audioRecorder.recordings.isEmpty && !audioRecorder.isRecording {
                    // プレースホルダー
                    VStack(spacing: 16) {
                        Image(systemName: "waveform")
                            .font(.system(size: 40))
                            .foregroundColor(Color.secondary.opacity(0.5))
                        Text("録音データがありません")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("録音ボタンをタップして開始")
                            .font(.caption)
                            .foregroundColor(Color.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else if !audioRecorder.recordings.isEmpty {
                    // 録音ファイルリスト
                    VStack(spacing: 8) {
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
                    
                    // 一括アップロードボタン
                    if audioRecorder.recordings.filter({ !$0.isRecordingFailed && !$0.isUploaded && $0.canUpload }).count > 0 {
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
                            .background(Color.safeColor("AppAccentColor"))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .disabled(networkManager.connectionStatus == .uploading)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding()
                        }
                        .padding(.bottom, 100) // 録音ボタンのスペースを確保
                    }
                }
                
                // 下部固定ボタン
                VStack {
                    Spacer()
                    VStack(spacing: 0) {
                        Divider()
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
                            .padding()
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
                            .padding()
                        }
                    }
                    .background(Color(.systemBackground))
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
            // AudioRecorderにDeviceManagerの参照を設定
            audioRecorder.deviceManager = deviceManager
            
            // 初期値を設定
            updateTimeInfo()
            
            // タイマーを開始して時間スロットとデバイス時刻を更新
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                updateTimeInfo()
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
    
    // 時刻とスロット情報を更新
    private func updateTimeInfo() {
        // デバイスのタイムゾーンを考慮した現在時刻を取得
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 HH:mm:ss"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = deviceManager.selectedDeviceTimezone
        
        deviceCurrentTime = formatter.string(from: Date())
        // デバイスのタイムゾーンを使用してスロットを計算
        currentTimeSlot = SlotTimeUtility.getCurrentSlot(timezone: deviceManager.selectedDeviceTimezone)
    }
    
    // デバイス連携後に録音を開始する
    private func linkDeviceAndStartRecording() {
        guard let userId = userAccountManager.currentUser?.id else {
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
                    if let userId = userAccountManager.currentUser?.id {
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
        // アップロード対象のリストを取得（録音失敗ファイルを除外）
        let recordingsToUpload = audioRecorder.recordings.filter { !$0.isRecordingFailed && $0.canUpload }
        
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
                    
                    // 録音失敗ファイルの場合は「録音失敗」を表示
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
                
                // 録音失敗ファイルの場合の説明
                if recording.isRecordingFailed {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(Color.safeColor("ErrorColor"))
                        
                        Text("音声データの録音に失敗しました。ファイルは自動的に削除されます。")
                            .font(.caption)
                            .foregroundColor(Color.safeColor("ErrorColor"))
                        
                        Spacer()
                    }
                }
                
                // アップロード失敗時のみエラー情報を表示（録音失敗ファイル以外）
                if !recording.isRecordingFailed && recording.uploadAttempts > 0 && !recording.isUploaded {
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
    let userAccountManager = UserAccountManager(deviceManager: deviceManager)
    return RecordingView(
        audioRecorder: AudioRecorder(),
        networkManager: NetworkManager(
            userAccountManager: userAccountManager,
            deviceManager: deviceManager
        )
    )
}