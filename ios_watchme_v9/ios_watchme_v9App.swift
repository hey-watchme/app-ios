//
//  ios_watchme_v9App.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/06/11.
//

import SwiftUI
import AVFoundation

@main
struct ios_watchme_v9App: App {
    @StateObject private var deviceManager = DeviceManager()
    @StateObject private var authManager: SupabaseAuthManager
    // dataManagerは状態を持たないサービスになったため、StateObjectとして管理しない
    private let dataManager = SupabaseDataManager()
    
    init() {
        let deviceManager = DeviceManager()
        let authManager = SupabaseAuthManager(deviceManager: deviceManager)
        
        _deviceManager = StateObject(wrappedValue: deviceManager)
        _authManager = StateObject(wrappedValue: authManager)
    }
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(authManager)
                .environmentObject(deviceManager)
                // dataManagerはEnvironmentObjectとして渡さない
                .onAppear {
                    requestMicrophonePermission()
                }
        }
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    print("マイクアクセスが許可されました")
                } else {
                    print("マイクアクセスが拒否されました")
                }
            }
        }
    }
}

// メインアプリビュー（ログイン状態に応じて画面切り替え）
struct MainAppView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var deviceManager: DeviceManager
    // dataManagerは削除（状態を持たないサービスのため）
    @State private var showLogin = false
    @State private var hasInitialized = false
    
    var body: some View {
        Group {
            if authManager.isCheckingAuthStatus {
                // 認証状態確認中：ローディング画面
                VStack {
                    Spacer()
                    
                    // ロゴを表示
                    Image("WatchMeLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 70)
                    
                    // ローディングインジケーター
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .padding(.top, 40)
                    
                    Text("認証状態を確認中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                    
                    Spacer()
                }
            } else if authManager.isAuthenticated {
                // ログイン済み：メイン機能画面
                ContentView()
                    .environmentObject(authManager)
                    .environmentObject(deviceManager)
                    .environmentObject(dataManager)
                    .onAppear {
                        print("📱 MainAppView: 認証済み状態 - ContentView表示")
                        // デバイスの自動登録は削除されました
                        // ユーザーに紐付く全デバイスを取得
                        if let userId = authManager.currentUser?.id {
                            print("🔍 ユーザーの全デバイスを自動取得: \(userId)")
                            Task {
                                await deviceManager.fetchUserDevices(for: userId)
                            }
                        }
                    }
            } else {
                // 未ログイン：ログイン画面表示ボタン
                VStack(spacing: 0) {
                    Spacer()
                    
                    // ロゴを中央に配置
                    Image("WatchMeLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 70)
                    
                    Spacer()
                    
                    // ログインボタンを最下部に配置
                    Button(action: {
                        showLogin = true
                    }) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                            Text("ログイン / サインアップ")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                }
                .onAppear {
                    print("📱 MainAppView: 未認証状態 - ログイン画面表示")
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .onChange(of: authManager.isAuthenticated) { oldValue, newValue in
            print("🔄 MainAppView: 認証状態変化 \(oldValue) → \(newValue)")
            if newValue && showLogin {
                // ログイン成功時にシートを閉じる
                showLogin = false
                print("✅ ログイン成功 - メイン画面に遷移")
            }
        }
        .onAppear {
            initializeApp()
        }
        // デバイス登録エラーアラートは削除（自動登録を行わないため）
    }
    
    // MARK: - アプリ初期化
    private func initializeApp() {
        guard !hasInitialized else { return }
        hasInitialized = true
        
        print("🚀 MainAppView: アプリ初期化開始")
        
        // デバイスの自動登録は削除されました
        if !deviceManager.isDeviceRegistered {
            print("📱 未登録デバイス検知 - ユーザーの明示的な操作を待機")
        } else {
            print("📱 既存デバイス確認済み")
        }
    }
    
    // checkAndRegisterDevice関数は削除されました（自動登録を行わないため）
}

