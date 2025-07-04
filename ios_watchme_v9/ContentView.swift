//
//  ContentView.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/06/11.
//

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var deviceManager: DeviceManager
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedRecording: RecordingModel?
    @State private var showUserIDChangeAlert = false
    @State private var newUserID = ""
    @State private var showLogoutConfirmation = false
    @State private var networkManager: NetworkManager?
    
    private func initializeNetworkManager() {
        // NetworkManagerを初期化（AuthManagerとDeviceManagerを渡す）
        networkManager = NetworkManager(authManager: authManager, deviceManager: deviceManager)
        
        if let authUser = authManager.currentUser {
            networkManager?.updateToAuthenticatedUserID(authUser.id)
        }
        
        print("🔧 NetworkManager初期化完了")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                // タイトル
                Text("WatchMe")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // 接続ステータス表示
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                    
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // アップロード進捗表示
                if networkManager?.connectionStatus == .uploading {
                    VStack(spacing: 8) {
                        HStack {
                            Text("📤 アップロード中...")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(Int((networkManager?.uploadProgress ?? 0.0) * 100))%")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        
                        ProgressView(value: networkManager?.uploadProgress ?? 0.0, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        
                        if let fileName = networkManager?.currentUploadingFile {
                            Text("ファイル: \(fileName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // サーバーURL & ユーザーID表示
                VStack(spacing: 12) {
                    // サーバーURL
                    VStack(alignment: .leading, spacing: 8) {
                        Text("サーバーURL:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(networkManager?.serverURL ?? "サーバーURL未設定")
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // ユーザー情報
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("ログインユーザー:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("ログアウト") {
                                showLogoutConfirmation = true
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if let user = authManager.currentUser {
                                Text("📧 \(user.email)")
                                    .font(.footnote)
                                    .fontWeight(.medium)
                                
                                Text("🆔 \(user.id)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                
                                // デバイス登録状態表示
                                if deviceManager.isDeviceRegistered {
                                    if let deviceInfo = deviceManager.getDeviceInfo() {
                                        Text("📱 デバイス: \(deviceInfo.deviceID.prefix(8))...")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                } else {
                                    Text("📱 デバイス: 未登録")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                
                                // デバイス登録エラー表示
                                if let error = deviceManager.registrationError {
                                    Text("❌ \(error)")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // 録音コントロール
                VStack(spacing: 16) {
                    if audioRecorder.isRecording {
                        // 録音中の表示
                        VStack(spacing: 8) {
                            Text("🔴 録音中...")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Text(audioRecorder.formatTime(audioRecorder.recordingTime))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                            
                            Text(audioRecorder.getCurrentSlotInfo())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        
                        // 録音停止ボタン
                        Button(action: {
                            audioRecorder.stopRecording()
                            // 録音停止後、少し待ってから自動アップロード
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                autoUploadAllPendingRecordings()
                            }
                        }) {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("録音停止")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    } else {
                        // 録音開始ボタン
                        VStack(spacing: 8) {
                            Button(action: audioRecorder.startRecording) {
                                HStack {
                                    Image(systemName: "mic.fill")
                                    Text("録音開始")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            
                            Text(audioRecorder.getCurrentSlotInfo())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 録音統計情報
                if !audioRecorder.recordings.isEmpty {
                    VStack(spacing: 8) {
                        // 統計情報
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("総録音数")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(audioRecorder.recordings.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .center, spacing: 4) {
                                Text("アップロード済み")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(audioRecorder.recordings.filter { $0.isUploaded }.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("アップロード待ち")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(audioRecorder.recordings.filter { !$0.isUploaded }.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // 録音一覧
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("録音ファイル一覧")
                                .font(.headline)
                            
                            Spacer()
                            
                            // 一括アップロードボタン
                            if audioRecorder.recordings.filter({ !$0.isUploaded && $0.canUpload }).count > 0 {
                                Button(action: {
                                    autoUploadAllPendingRecordings()
                                }) {
                                    HStack {
                                        Image(systemName: "icloud.and.arrow.up")
                                        Text("一括アップロード")
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .disabled(networkManager?.connectionStatus == .uploading)
                            }
                        }
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
                                    .background(Color.orange)
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
                                            networkManager: networkManager,
                                            onSelect: { selectedRecording = recording }
                                        ) { recording in
                                            audioRecorder.deleteRecording(recording)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                } else {
                    Text("録音ファイルがありません")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                }
                
                Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("録音アップロード")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            initializeNetworkManager()
            // ユーザーの確認状態をチェック
            authManager.fetchUserInfo()
        }
        .alert("結果", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert("ユーザーID変更", isPresented: $showUserIDChangeAlert) {
            TextField("新しいユーザーID", text: $newUserID)
            Button("キャンセル", role: .cancel) { 
                newUserID = ""
            }
            Button("変更") {
                if !newUserID.isEmpty {
                    networkManager?.setUserID(newUserID)
                    alertMessage = "ユーザーIDを「\(newUserID)」に変更しました"
                    showAlert = true
                    newUserID = ""
                }
            }
        } message: {
            Text("新しいユーザーIDを入力してください\n（例: user123, test_user）")
        }
        .alert("ログアウト確認", isPresented: $showLogoutConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("ログアウト", role: .destructive) {
                authManager.signOut()
                networkManager?.resetToFallbackUserID()
                alertMessage = "ログアウトしました"
                showAlert = true
            }
        } message: {
            Text("本当にログアウトしますか？")
        }
        .onChange(of: networkManager?.connectionStatus) { oldValue, newValue in
            // アップロード完了時の通知
            if newValue == .connected && networkManager?.currentUploadingFile != nil {
                alertMessage = "アップロードが完了しました！"
                showAlert = true
            } else if newValue == .failed && networkManager?.currentUploadingFile != nil {
                alertMessage = "アップロードに失敗しました。手動でリトライしてください。"
                showAlert = true
            }
        }
    }
    
    // 最新の録音を自動アップロード（改善版）
    private func autoUploadLatestRecording() {
        // アップロード可能な最新ファイルを取得
        let uploadableRecordings = audioRecorder.recordings.filter { $0.canUpload }
        guard let latestRecording = uploadableRecordings.max(by: { $0.date < $1.date }) else {
            print("🤖 自動アップロード: アップロード可能なファイルがありません")
            return
        }
        
        print("🤖 自動アップロード開始: \(latestRecording.fileName) (サイズ: \(latestRecording.fileSizeFormatted))")
        networkManager?.uploadRecording(latestRecording)
    }
    
    // すべてのアップロード可能ファイルを順次自動アップロード（改善版）
    private func autoUploadAllPendingRecordings() {
        // アップロード可能なファイルを取得
        let uploadableRecordings = audioRecorder.recordings.filter { $0.canUpload }
        
        guard !uploadableRecordings.isEmpty else {
            print("🤖 自動アップロード: アップロード可能なファイルがありません")
            
            // アップロード不可能なファイルの理由を表示
            let failedRecordings = audioRecorder.recordings.filter { !$0.isUploaded }
            if !failedRecordings.isEmpty {
                print("📄 アップロード不可能なファイル: \(failedRecordings.count)個")
                for recording in failedRecordings {
                    let reason = !recording.fileExists() ? "ファイル不存在" : 
                                recording.uploadAttempts >= 3 ? "最大試行回数超過" : "不明"
                    print("   - \(recording.fileName): \(reason) (試行: \(recording.uploadAttempts)/3)")
                }
            }
            return
        }
        
        // 作成日時順（古い順）でアップロード
        let sortedRecordings = uploadableRecordings.sorted { $0.date < $1.date }
        
        print("🤖 自動アップロード開始: \(sortedRecordings.count)個のファイルを順次処理")
        for (index, recording) in sortedRecordings.enumerated() {
            print("   \(index + 1). \(recording.fileName) (サイズ: \(recording.fileSizeFormatted), 試行: \(recording.uploadAttempts))")
        }
        
        // 最初のファイルからアップロード開始
        processNextUpload(from: sortedRecordings, currentIndex: 0)
    }
    
    // 順次アップロード処理
    private func processNextUpload(from recordings: [RecordingModel], currentIndex: Int) {
        guard currentIndex < recordings.count else {
            print("🎉 自動アップロード完了: 全てのファイル処理が終了しました")
            return
        }
        
        let currentRecording = recordings[currentIndex]
        print("🤖 自動アップロード進行中: [\(currentIndex + 1)/\(recordings.count)] \(currentRecording.fileName)")
        
        // アップロード開始
        networkManager?.uploadRecording(currentRecording)
        
        // アップロード結果を監視（ConnectionStatusの変化を待つ）
        var observer: AnyCancellable?
        observer = networkManager?.$connectionStatus
            .sink { status in
                
                switch status {
                case .connected:
                    // アップロード成功
                    if networkManager?.currentUploadingFile == currentRecording.fileName {
                        print("✅ 自動アップロード成功: \(currentRecording.fileName)")
                        print("📋 アップロード状態が永続化されました")
                        
                        // ファイルは保持し、アップロード状態のみ更新（既にRecordingModel側で実施済み）
                        
                        // 次のファイルへ
                        observer?.cancel()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.processNextUpload(from: recordings, currentIndex: currentIndex + 1)
                        }
                    }
                    
                case .failed:
                    // アップロード失敗
                    if networkManager?.currentUploadingFile == currentRecording.fileName {
                        print("❌ 自動アップロード失敗: \(currentRecording.fileName) - ファイルを保持（手動リトライ用）")
                        
                        // 次のファイルへ（失敗したファイルは保持）
                        observer?.cancel()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.processNextUpload(from: recordings, currentIndex: currentIndex + 1)
                        }
                    }
                    
                default:
                    break
                }
            }
    }
    
    // 接続ステータスに応じた色
    private var statusColor: Color {
        switch networkManager?.connectionStatus ?? .unknown {
        case .unknown:
            return .gray
        case .connected:
            return .green
        case .disconnected:
            return .red
        case .uploading:
            return .orange
        case .failed:
            return .red
        }
    }
    
    // 接続ステータスのテキスト
    private var statusText: String {
        switch networkManager?.connectionStatus ?? .unknown {
        case .unknown:
            return "状態不明"
        case .connected:
            return "接続済み"
        case .disconnected:
            return "切断中"
        case .uploading:
            return "アップロード中..."
        case .failed:
            return "エラー"
        }
    }
}

// MARK: - 録音ファイル行のビュー
struct RecordingRowView: View {
    let recording: RecordingModel
    let isSelected: Bool
    let networkManager: NetworkManager?
    let onSelect: () -> Void
    let onDelete: (RecordingModel) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recording.fileName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(recording.fileSizeFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(DateFormatter.display.string(from: recording.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    // アップロード状態
                    Text("アップロード: \(recording.isUploaded ? "✅" : "❌")")
                        .font(.caption)
                        .foregroundColor(recording.isUploaded ? .green : .red)
                    
                    if !recording.isUploaded {
                        // 試行回数表示
                        if recording.uploadAttempts > 0 {
                            Text("試行: \(recording.uploadAttempts)/3")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        // アップロード可能チェック
                        if !recording.canUpload {
                            Text("アップロード不可")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Spacer()
                }
                
                // エラー情報表示
                if let error = recording.lastUploadError {
                    Text("エラー: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                // アップロードボタン（手動リトライ用）
                if recording.canUpload {
                    Button(action: {
                        onSelect()
                        print("📤 手動アップロード開始: \(recording.fileName)")
                        networkManager?.uploadRecording(recording)
                    }) {
                        Image(systemName: "icloud.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                    .disabled(networkManager?.connectionStatus == .uploading)
                } else if !recording.isUploaded {
                    // アップロード不可の場合はリセットボタンを表示
                    Button(action: {
                        recording.resetUploadStatus()
                        print("🔄 アップロード状態リセット: \(recording.fileName)")
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.orange)
                    }
                }
                
                // 削除ボタン
                Button(action: { onDelete(recording) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
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
    static let display: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

#Preview {
    ContentView()
}
