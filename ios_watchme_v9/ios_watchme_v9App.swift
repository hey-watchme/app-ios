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
    @StateObject private var authManager = SupabaseAuthManager()
    @StateObject private var deviceManager = DeviceManager()
    @StateObject private var dataManager = SupabaseDataManager()
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(authManager)
                .environmentObject(deviceManager)
                .environmentObject(dataManager)
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
    @EnvironmentObject var dataManager: SupabaseDataManager
    @State private var showLogin = false
    @State private var hasInitialized = false
    @State private var showDeviceRegistrationError = false
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // ログイン済み：メイン機能画面
                ContentView()
                    .environmentObject(authManager)
                    .environmentObject(deviceManager)
                    .environmentObject(dataManager)
                    .onAppear {
                        print("📱 MainAppView: 認証済み状態 - ContentView表示")
                        checkAndRegisterDevice()
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
        .alert("デバイス登録エラー", isPresented: $showDeviceRegistrationError) {
            Button("再試行") {
                let ownerUserID = authManager.currentUser?.id
                deviceManager.registerDevice(ownerUserID: ownerUserID)
            }
            Button("スキップ", role: .cancel) {
                // デバイス登録をスキップして続行
            }
        } message: {
            Text(deviceManager.registrationError ?? "デバイス登録に失敗しました。再試行してください。")
        }
        .onChange(of: deviceManager.registrationError) { oldValue, newValue in
            if newValue != nil {
                showDeviceRegistrationError = true
            }
        }
    }
    
    // MARK: - アプリ初期化
    private func initializeApp() {
        guard !hasInitialized else { return }
        hasInitialized = true
        
        print("🚀 MainAppView: アプリ初期化開始")
        
        // 認証状態に関係なく、未登録デバイスの場合は登録を実行
        if !deviceManager.isDeviceRegistered {
            print("📱 未登録デバイス検知 - デバイス登録を実行")
            let ownerUserID = authManager.currentUser?.id
            deviceManager.registerDevice(ownerUserID: ownerUserID)
        } else {
            print("📱 既存デバイス確認済み")
        }
    }
    
    // MARK: - デバイス登録確認（認証済み状態で呼ばれる）
    private func checkAndRegisterDevice() {
        // 認証済みの場合、オーナーユーザーIDを更新する場合の処理
        if !deviceManager.isDeviceRegistered {
            print("📱 認証済み状態でのデバイス登録実行")
            deviceManager.registerDevice(ownerUserID: authManager.currentUser?.id)
        }
        
        // ユーザーに紐付く全デバイスを取得
        if let userId = authManager.currentUser?.id {
            print("🔍 ユーザーの全デバイスを自動取得: \(userId)")
            Task {
                await deviceManager.fetchUserDevices(for: userId)
            }
        }
    }
}

