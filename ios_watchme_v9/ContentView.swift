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
        
        // NetworkManagerの設定は不要（既に親ビューから渡されている）
        
        print("🔧 NetworkManager初期化完了")
    }
    
    var body: some View {
        if let networkManager = networkManager {
            TabView {
                // 心理グラフタブ (Vibe Graph)
                NavigationView {
                    HomeView(
                        networkManager: networkManager,
                        showAlert: $showAlert,
                        alertMessage: $alertMessage,
                        showUserInfoSheet: $showUserInfoSheet
                    )
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .tabItem {
                    Label("心理グラフ", systemImage: "brain")
                }
                
                // 行動グラフタブ (Behavior Graph)
                NavigationView {
                    BehaviorGraphView()
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .tabItem {
                    Label("行動グラフ", systemImage: "figure.walk.motion")
                }
                
                // 感情グラフタブ (Emotion Graph)
                NavigationView {
                    EmotionGraphView()
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .tabItem {
                    Label("感情グラフ", systemImage: "heart.text.square")
                }
                
                // 録音タブ
                NavigationView {
                    RecordingView(audioRecorder: audioRecorder, networkManager: networkManager)
                        .navigationTitle("録音")
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
                .navigationViewStyle(StackNavigationViewStyle())
                .tabItem {
                    Label("録音", systemImage: "mic.circle.fill")
                }
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
                        networkManager.setUserID(newUserID)
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
                    networkManager.resetToFallbackUserID()
                    alertMessage = "ログアウトしました"
                    showAlert = true
                }
            } message: {
                Text("本当にログアウトしますか？")
            }
            .sheet(isPresented: $showUserInfoSheet) {
                UserInfoSheetView(authManager: authManager, deviceManager: deviceManager, showLogoutConfirmation: $showLogoutConfirmation)
            }
            .onChange(of: networkManager.connectionStatus) { oldValue, newValue in
                // アップロード完了時の通知
                if newValue == .connected && networkManager.currentUploadingFile != nil {
                    alertMessage = "アップロードが完了しました！"
                    showAlert = true
                } else if newValue == .failed && networkManager.currentUploadingFile != nil {
                    alertMessage = "アップロードに失敗しました。手動でリトライしてください。"
                    showAlert = true
                }
            }
        } else {
            ProgressView("初期化中...")
                .onAppear {
                    initializeNetworkManager()
                }
        }
    }
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
                        // ユーザーのデバイス一覧
                        if !deviceManager.userDevices.isEmpty {
                            ForEach(Array(deviceManager.userDevices.enumerated()), id: \.element.device_id) { index, device in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("デバイス \(index + 1)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    InfoRow(label: "デバイスID", value: device.device_id, icon: "iphone")
                                    if device.device_id == deviceManager.selectedDeviceID {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text("現在選択中")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                        .padding(.leading, 20)
                                    }
                                }
                                if index < deviceManager.userDevices.count - 1 {
                                    Divider()
                                        .padding(.vertical, 4)
                                }
                            }
                        } else {
                            InfoRow(label: "状態", value: "デバイス情報を取得中...", icon: "arrow.clockwise", valueColor: .orange)
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
            .onAppear {
                // デバイス情報を再取得
                if deviceManager.userDevices.isEmpty, let userId = authManager.currentUser?.id {
                    print("📱 UserInfoSheet: デバイス情報を取得")
                    Task {
                        await deviceManager.fetchUserDevices(for: userId)
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
