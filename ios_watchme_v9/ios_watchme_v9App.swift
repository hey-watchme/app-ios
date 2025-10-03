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
    @StateObject private var userAccountManager: UserAccountManager
    @StateObject private var dataManager: SupabaseDataManager
    
    init() {
        let deviceManager = DeviceManager()
        let userAccountManager = UserAccountManager(deviceManager: deviceManager)
        let dataManager = SupabaseDataManager(userAccountManager: userAccountManager)
        
        _deviceManager = StateObject(wrappedValue: deviceManager)
        _userAccountManager = StateObject(wrappedValue: userAccountManager)
        _dataManager = StateObject(wrappedValue: dataManager)
    }
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(userAccountManager)
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

// メインアプリビュー
struct MainAppView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @State private var showLogin = false
    @State private var showSignUp = false
    @State private var hasInitialized = false
    
    // フッターナビゲーション用の選択状態
    @State private var selectedTab: FooterTab = .home
    
    // フッタータブの定義
    enum FooterTab {
        case home
        case myPage
    }
    
    var body: some View {
        Group {
            if userAccountManager.isCheckingAuthStatus {
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
            } else if userAccountManager.isAuthenticated {
                // ログイン済み：メイン機能画面（単一のNavigationStackでラップ）
                NavigationStack {
                    VStack(spacing: 0) {
                        // コンテンツエリア（フッターの選択に応じて切り替え）
                        ZStack {
                            switch selectedTab {
                            case .home:
                                ContentView()
                                    .environmentObject(userAccountManager)
                                    .environmentObject(deviceManager)
                                    .environmentObject(dataManager)
                            case .myPage:
                                UserInfoView(userAccountManager: userAccountManager)
                                .environmentObject(deviceManager)
                                .environmentObject(dataManager)
                            }
                        }
                        
                        // カスタムフッターナビゲーション
                        CustomFooterNavigation(selectedTab: $selectedTab)
                    }
                    .edgesIgnoringSafeArea(.bottom)
                }
                .onAppear {
                    print("📱 MainAppView: 認証済み状態 - メイン画面表示")
                    // ユーザーに紐付く全デバイスを取得
                    if let userId = userAccountManager.currentUser?.id {
                        print("🔍 ユーザーの全デバイスを自動取得: \(userId)")
                        Task {
                            await deviceManager.fetchUserDevices(for: userId)
                        }
                    }
                }
            } else {
                // 未ログイン：新規登録とログインボタン
                VStack(spacing: 0) {
                    Spacer()

                    // ロゴを中央に配置
                    Image("WatchMeLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 70)

                    Spacer()

                    // ボタンを最下部に配置
                    VStack(spacing: 16) {
                        // 新規ではじめるボタン
                        Button(action: {
                            showSignUp = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("新規ではじめる")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.safeColor("AppAccentColor"))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }

                        // ログインボタン
                        Button(action: {
                            showLogin = true
                        }) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                Text("ログイン")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.safeColor("AppAccentColor"), lineWidth: 1.5)
                            )
                            .foregroundColor(Color.safeColor("AppAccentColor"))
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                }
                .onAppear {
                    print("📱 MainAppView: 未認証状態 - ログイン/サインアップ画面表示")
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
                .environmentObject(userAccountManager)
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
                .environmentObject(userAccountManager)
        }
        .onChange(of: userAccountManager.isAuthenticated) { oldValue, newValue in
            print("🔄 MainAppView: 認証状態変化 \(oldValue) → \(newValue)")
            if newValue {
                // ログイン/サインアップ成功時にシートを閉じる
                showLogin = false
                showSignUp = false
                print("✅ 認証成功 - メイン画面に遷移")
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
    }
    
    // checkAndRegisterDevice関数は削除されました（自動登録を行わないため）
}

// カスタムフッターナビゲーション
struct CustomFooterNavigation: View {
    @Binding var selectedTab: MainAppView.FooterTab
    
    var body: some View {
        HStack(spacing: 0) {
            // ホームタブ
            Button(action: {
                selectedTab = .home
            }) {
                VStack(spacing: 4) {
                    Image(systemName: selectedTab == .home ? "house.fill" : "house")
                        .font(.system(size: 24))
                    Text("ホーム")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(selectedTab == .home ? Color.primary : Color.secondary)
            }
            
            // マイページタブ
            Button(action: {
                selectedTab = .myPage
            }) {
                VStack(spacing: 4) {
                    Image(systemName: selectedTab == .myPage ? "person.circle.fill" : "person.circle")
                        .font(.system(size: 24))
                    Text("マイページ")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(selectedTab == .myPage ? Color.primary : Color.secondary)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 20) // セーフエリアの考慮
        .background(
            Color(.systemBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: -1)
        )
    }
}

