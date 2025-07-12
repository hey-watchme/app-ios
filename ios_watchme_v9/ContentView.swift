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
    // @StateObject private var uploadManager = UploadManager.shared
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedRecording: RecordingModel?
    @State private var showUserIDChangeAlert = false
    @State private var newUserID = ""
    @State private var showLogoutConfirmation = false
    @State private var showUserInfoSheet = false
    @State private var networkManager: NetworkManager?
    
    private func initializeNetworkManager() {
        // NetworkManagerを初期化（AuthManagerとDeviceManagerを渡す）
        networkManager = NetworkManager(authManager: authManager, deviceManager: deviceManager)
        
        if let authUser = authManager.currentUser {
            networkManager?.updateToAuthenticatedUserID(authUser.id)
        }
        
        // UploadManagerにNetworkManagerを設定
        if let networkManager = networkManager {
            // uploadManager.configure(networkManager: networkManager)
        }
        
        print("🔧 NetworkManager初期化完了")
    }
    
    var body: some View {
        NavigationView {
            scrollContent
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            initializeNetworkManager()
        }
        .alert("通知", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("ユーザーID変更", isPresented: $showUserIDChangeAlert) {
            TextField("新しいユーザーID", text: $newUserID)
            Button("変更") {
                if !newUserID.isEmpty {
                    networkManager?.setUserID(newUserID)
                    alertMessage = "ユーザーIDを変更しました: \(newUserID)"
                    showAlert = true
                }
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("新しいユーザーIDを入力してください")
        }
        .confirmationDialog("ログアウト確認", isPresented: $showLogoutConfirmation) {
            Button("ログアウト", role: .destructive) {
                authManager.signOut()
                networkManager?.resetToFallbackUserID()
                alertMessage = "ログアウトしました"
                showAlert = true
            }
        } message: {
            Text("本当にログアウトしますか？")
        }
        .sheet(isPresented: $showUserInfoSheet) {
            UserInfoSheetView(authManager: authManager, deviceManager: deviceManager, showLogoutConfirmation: $showLogoutConfirmation)
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
    
    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 統計情報（録音数・アップロード済み・アップロード待ち）
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
                                let uploadedCount = audioRecorder.recordings.filter { $0.isUploaded }.count
                                Text("\(uploadedCount)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                    .onAppear {
                                        print("🔍 [ContentView] 初期アップロード済み数: \(uploadedCount)")
                                    }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("アップロード待ち")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                let pendingCount = audioRecorder.recordings.filter { !$0.isUploaded }.count
                                Text("\(pendingCount)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                                    .onAppear {
                                        print("🔍 [ContentView] 初期アップロード待ち数: \(pendingCount)")
                                    }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
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
                            
                            // if uploadManager.isProcessing {
                            //     Text("\(Int(uploadManager.totalProgress * 100))%")
                            //         .font(.caption)
                            //         .fontWeight(.bold)
                            // } else {
                            Text("\(Int((networkManager?.uploadProgress ?? 0.0) * 100))%")
                                .font(.caption)
                                .fontWeight(.bold)
                            // }
                        }
                        
                        // UploadManager無効化: NetworkManagerのみ使用
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
                            // 自動アップロード機能を削除 - 手動アップロードのみ対応
                            print("💾 録音停止完了 - 手動でアップロードしてください")
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
                        }
                    }
                }
                
                // 録音一覧
                if !audioRecorder.recordings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("録音ファイル")
                                .font(.headline)
                            
                            Spacer()
                            
                            // 一括アップロードボタン（手動処理）
                            if audioRecorder.recordings.filter({ !$0.isUploaded && $0.canUpload }).count > 0 {
                                Button(action: {
                                    manualBatchUpload()
                                }) {
                                    HStack {
                                        Image(systemName: "icloud.and.arrow.up")
                                        Text("すべてアップロード")
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
                                            onSelect: { selectedRecording = recording },
                                            onDelete: { recording in
                                                audioRecorder.deleteRecording(recording)
                                            }
                                        )
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
                
                Spacer(minLength: 20)
                
                // フッターエリア - テスト用機能
                VStack(spacing: 16) {
                    Divider()
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        Text("🔧 開発・テスト用機能")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        // サーバーURL表示
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
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // 接続テストボタン
                        Button(action: {
                            testServerConnection()
                        }) {
                            HStack {
                                Image(systemName: "network")
                                Text("サーバー接続テスト")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .background(
                    Color(.systemGray6)
                        .opacity(0.3)
                        .ignoresSafeArea(.container, edges: .bottom)
                )
                }
                .padding()
            }
            .navigationTitle("WatchMe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showUserInfoSheet = true
                    }) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
        }
    }
    
    // サーバー接続テスト
    private func testServerConnection() {
        guard let networkManager = networkManager else {
            alertMessage = "NetworkManagerが初期化されていません"
            showAlert = true
            return
        }
        
        print("🔍 サーバー接続テスト開始")
        
        networkManager.testServerConnection { success, message in
            DispatchQueue.main.async {
                self.alertMessage = """
                サーバー接続テスト結果:
                
                \(success ? "✅ 成功" : "❌ 失敗")
                
                詳細: \(message)
                
                サーバーURL: \(networkManager.serverURL)
                デバイス登録: \(self.deviceManager.isDeviceRegistered ? "済み" : "未登録")
                認証状態: \(self.authManager.isAuthenticated ? "済み" : "未認証")
                """
                self.showAlert = true
            }
        }
    }
    
    // シンプルな一括アップロード（NetworkManagerを直接使用）- 逐次実行版
    private func manualBatchUpload() {
        guard let networkManager = self.networkManager else { return }
        
        // アップロード対象のリストを取得
        let recordingsToUpload = audioRecorder.recordings.filter { $0.canUpload }
        
        guard !recordingsToUpload.isEmpty else {
            alertMessage = "アップロード対象のファイルがありません。"
            showAlert = true
            return
        }
        
        alertMessage = "\(recordingsToUpload.count)件のアップロードを開始します..."
        showAlert = true
        
        print("📤 一括アップロード開始: \(recordingsToUpload.count)件")
        
        // 最初のファイルからアップロードを開始する
        uploadSequentially(recordings: recordingsToUpload, networkManager: networkManager)
    }
    
    // 再帰的にファイルを1つずつアップロードする関数
    private func uploadSequentially(recordings: [RecordingModel], networkManager: NetworkManager) {
        // アップロードするリストが空になったら処理を終了
        guard let recording = recordings.first else {
            print("✅ 全ての一括アップロードが完了しました。")
            DispatchQueue.main.async {
                self.alertMessage = "すべての一括アップロードが完了しました。"
                self.showAlert = true
            }
            return
        }
        
        // リストの残りを次の処理のために準備
        var remainingRecordings = recordings
        remainingRecordings.removeFirst()
        
        print("📤 アップロード中: \(recording.fileName) (残り: \(remainingRecordings.count)件)")
        
        // 1つのファイルをアップロード
        networkManager.uploadRecording(recording) { success in
            if success {
                print("✅ 一括アップロード成功: \(recording.fileName)")
            } else {
                print("❌ 一括アップロード失敗: \(recording.fileName)")
            }
            
            // 成功・失敗にかかわらず、次のファイルのアップロードを再帰的に呼び出す
            // これにより、1つが完了してから次が始まることが保証される
            self.uploadSequentially(recordings: remainingRecordings, networkManager: networkManager)
        }
    }
    
    /*
    // 新しいUploadManagerを使用した手動アップロード（旧実装）
    private func manualBatchUploadWithUploadManager() {
        // アップロード可能なファイルを取得
        let uploadableRecordings = audioRecorder.recordings.filter { $0.canUpload }
        
        guard !uploadableRecordings.isEmpty else {
            print("💾 手動アップロード: アップロード可能なファイルがありません")
            
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
        
        // 作成日時順（古い順）でソート
        let sortedRecordings = uploadableRecordings.sorted { $0.date < $1.date }
        
        print("💾 UploadManager経由で手動アップロード開始: \(sortedRecordings.count)個のファイル")
        
        // デバッグ: AudioRecorder内のRecordingModelのObjectIdentifierを確認
        print("🔍 [ContentView] AudioRecorder内のRecordingModel:")
        for recording in sortedRecordings {
            print("   - \(recording.fileName): ObjectIdentifier = \(ObjectIdentifier(recording)), isUploaded = \(recording.isUploaded)")
        }
        
        // UploadManagerのキューに追加
        uploadManager.addMultipleToQueue(sortedRecordings)
        
        // 手動でアップロード処理を開始
        uploadManager.startManualProcessing()
        
        // アップロード状態を表示
        alertMessage = "\(sortedRecordings.count)個のファイルの手動アップロードを開始しました"
        showAlert = true
    }
    */
    
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
    @ObservedObject var recording: RecordingModel
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
                        .onChange(of: recording.isUploaded) { oldValue, newValue in
                            print("🔍 [RecordingRowView] isUploaded変更検知: \(recording.fileName) - \(oldValue) → \(newValue)")
                        }
                    
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
                // アップロードボタン（未アップロードファイルのみ表示）
                if !recording.isUploaded && recording.fileExists() && recording.uploadAttempts < 3 {
                    Button(action: {
                        onSelect()
                        print("📤 手動アップロード開始: \(recording.fileName)")
                        networkManager?.uploadRecording(recording) { success in
                            DispatchQueue.main.async {
                                print("個別アップロード完了: \(recording.fileName), 成功: \(success)")
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "icloud.and.arrow.up")
                        }
                        .foregroundColor(.blue)
                    }
                    .disabled(networkManager?.connectionStatus == .uploading)
                } else if recording.uploadAttempts >= 3 {
                    // 最大試行回数に達した場合はリセットボタンを表示
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

// MARK: - ユーザー情報シートビュー
struct UserInfoSheetView: View {
    let authManager: SupabaseAuthManager
    let deviceManager: DeviceManager
    @Binding var showLogoutConfirmation: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // ユーザーアイコン
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top, 20)
                
                // ユーザー情報セクション
                VStack(spacing: 16) {
                    // ユーザーアカウント情報
                    InfoSection(title: "ユーザーアカウント情報") {
                        if let user = authManager.currentUser {
                            InfoRow(label: "メールアドレス", value: user.email, icon: "envelope.fill")
                            InfoRow(label: "ユーザーID", value: user.id, icon: "person.text.rectangle.fill")
                        } else {
                            InfoRow(label: "状態", value: "ログインしていません", icon: "exclamationmark.triangle.fill", valueColor: .red)
                        }
                    }
                    
                    // デバイス情報
                    InfoSection(title: "デバイス情報") {
                        if let deviceInfo = deviceManager.getDeviceInfo() {
                            InfoRow(label: "デバイスID", value: deviceInfo.deviceID, icon: "iphone")
                            InfoRow(label: "デバイスタイプ", value: deviceInfo.deviceType, icon: "tag.fill")
                            InfoRow(label: "プラットフォーム", value: deviceInfo.platformType, icon: "gear")
                            InfoRow(label: "登録状態", value: deviceManager.isDeviceRegistered ? "登録済み" : "未登録", 
                                   icon: deviceManager.isDeviceRegistered ? "checkmark.circle.fill" : "xmark.circle.fill",
                                   valueColor: deviceManager.isDeviceRegistered ? .green : .orange)
                        } else {
                            InfoRow(label: "状態", value: "デバイス情報取得エラー", icon: "exclamationmark.triangle.fill", valueColor: .red)
                        }
                        
                        // デバイス登録エラー表示
                        if let error = deviceManager.registrationError {
                            InfoRow(label: "エラー", value: error, icon: "exclamationmark.triangle.fill", valueColor: .red)
                        }
                    }
                    
                    // 認証状態
                    InfoSection(title: "認証状態") {
                        InfoRow(label: "認証状態", value: authManager.isAuthenticated ? "認証済み" : "未認証", 
                               icon: authManager.isAuthenticated ? "checkmark.shield.fill" : "xmark.shield.fill",
                               valueColor: authManager.isAuthenticated ? .green : .red)
                    }
                }
                
                Spacer()
                
                // ログアウトボタン
                if authManager.isAuthenticated {
                    Button(action: {
                        dismiss()
                        showLogoutConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                            Text("ログアウト")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("ユーザー情報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 情報セクション
struct InfoSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                content
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

// MARK: - 情報行
struct InfoRow: View {
    let label: String
    let value: String
    let icon: String
    let valueColor: Color
    
    init(label: String, value: String, icon: String, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.icon = icon
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

#Preview {
    ContentView()
}
