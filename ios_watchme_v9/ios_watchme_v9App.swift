//
//  ios_watchme_v9App.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/06/11.
//

import SwiftUI
import AVFoundation

// アプリ起動の最初のログ
fileprivate let appLaunchTime: Date = {
    let time = Date()
    print("⏱️ [SYSTEM] @main構造体がロードされました: \(time)")
    return time
}()

@main
struct ios_watchme_v9App: App {
    @StateObject private var deviceManager = DeviceManager()
    @StateObject private var userAccountManager: UserAccountManager
    @StateObject private var dataManager: SupabaseDataManager

    init() {
        let startTime = Date()
        print("⏱️ [APP-INIT] アプリ初期化開始: \(startTime)")

        let deviceManager = DeviceManager()
        print("⏱️ [APP-INIT] DeviceManager初期化完了: \(Date().timeIntervalSince(startTime))秒")

        let userAccountManager = UserAccountManager(deviceManager: deviceManager)
        print("⏱️ [APP-INIT] UserAccountManager初期化完了: \(Date().timeIntervalSince(startTime))秒")

        let dataManager = SupabaseDataManager(userAccountManager: userAccountManager)
        print("⏱️ [APP-INIT] SupabaseDataManager初期化完了: \(Date().timeIntervalSince(startTime))秒")

        _deviceManager = StateObject(wrappedValue: deviceManager)
        _userAccountManager = StateObject(wrappedValue: userAccountManager)
        _dataManager = StateObject(wrappedValue: dataManager)

        print("⏱️ [APP-INIT] アプリ初期化完了: \(Date().timeIntervalSince(startTime))秒")
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
    @State private var showOnboarding = false
    @State private var onboardingCompleted = false  // オンボーディング完了フラグ

    // フッターナビゲーション用の選択状態
    @State private var selectedTab: FooterTab = .home

    // パフォーマンス計測用
    @State private var viewStartTime = Date()
    
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
                .onAppear {
                    // 認証チェック完了後にオンボーディング表示判定
                    print("⏱️ [VIEW] ロゴ画面表示: \(Date().timeIntervalSince(viewStartTime))秒")
                }
            } else if userAccountManager.authState == .authenticated {
                // ログイン済み：メイン機能画面（単一のNavigationStackでラップ）
                NavigationStack {
                    VStack(spacing: 0) {
                        // コンテンツエリア（ビューを保持したまま表示/非表示を切り替え）
                        ZStack {
                            ContentView()
                                .environmentObject(userAccountManager)
                                .environmentObject(deviceManager)
                                .environmentObject(dataManager)
                                .opacity(selectedTab == .home ? 1 : 0)
                                .zIndex(selectedTab == .home ? 1 : 0)

                            UserInfoView(userAccountManager: userAccountManager)
                                .environmentObject(deviceManager)
                                .environmentObject(dataManager)
                                .opacity(selectedTab == .myPage ? 1 : 0)
                                .zIndex(selectedTab == .myPage ? 1 : 0)
                        }

                        // カスタムフッターナビゲーション
                        CustomFooterNavigation(selectedTab: $selectedTab)
                    }
                    .edgesIgnoringSafeArea(.bottom)
                }
                .onAppear {
                    print("📱 MainAppView: 認証済み状態 - メイン画面表示")
                    // デバイス取得は認証成功時（onChange）で実行済み
                }
            } else {
                // ゲストモード
                if onboardingCompleted {
                    // オンボーディング完了後：ガイド画面（ダッシュボード）
                    NavigationStack {
                        VStack(spacing: 0) {
                            // コンテンツエリア（ビューを保持したまま表示/非表示を切り替え）
                            ZStack {
                                ContentView()
                                    .environmentObject(userAccountManager)
                                    .environmentObject(deviceManager)
                                    .environmentObject(dataManager)
                                    .opacity(selectedTab == .home ? 1 : 0)
                                    .zIndex(selectedTab == .home ? 1 : 0)

                                UserInfoView(userAccountManager: userAccountManager)
                                    .environmentObject(deviceManager)
                                    .environmentObject(dataManager)
                                    .opacity(selectedTab == .myPage ? 1 : 0)
                                    .zIndex(selectedTab == .myPage ? 1 : 0)
                            }

                            // カスタムフッターナビゲーション
                            CustomFooterNavigation(selectedTab: $selectedTab)
                        }
                        .edgesIgnoringSafeArea(.bottom)
                    }
                    .onAppear {
                        print("📱 MainAppView: ゲストモード - ガイド画面表示")
                    }
                } else {
                    // 初期画面（「はじめる」「ログイン」）
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
                            // はじめるボタン → オンボーディング表示
                            Button(action: {
                                showOnboarding = true
                            }) {
                                Text("はじめる")
                                    .fontWeight(.semibold)
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
                                Text("ログイン")
                                    .fontWeight(.semibold)
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
                        print("⏱️ [VIEW] 初期画面表示（はじめる/ログイン）: \(Date().timeIntervalSince(viewStartTime))秒")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
                .environmentObject(userAccountManager)
        }
        .onChange(of: showOnboarding) { oldValue, newValue in
            // オンボーディングが閉じられた時
            if oldValue == true && newValue == false {
                print("✅ オンボーディング完了")
                onboardingCompleted = true
            }
        }
        .task {
            // アプリ起動時に非同期で認証チェック
            viewStartTime = Date()
            print("⏱️ [VIEW] MainAppView表示開始 - 認証チェック呼び出し")
            userAccountManager.checkAuthStatus()
        }
        .onChange(of: userAccountManager.authState) { oldValue, newValue in
            print("🔄 MainAppView: 認証状態変化 \(oldValue) → \(newValue)")
            if newValue == .authenticated {
                // ログイン/サインアップ成功時
                // シートを閉じる
                showLogin = false
                // ホーム画面にリセット
                selectedTab = .home
                print("✅ 認証成功 - ホーム画面に遷移")

                // 📊 Phase 2-B: デバイス取得の重複を排除
                // UserAccountManager内で既にfetchUserDevicesが実行されているため、ここでは不要
                // L239-245を削除（重複処理）
            } else if newValue == .guest {
                // ゲストモードに移行（ログアウト時）
                selectedTab = .home
                onboardingCompleted = false  // オンボーディング完了フラグをリセット
                print("🔄 ゲストモード - 初期状態にリセット")
            }
        }
        .onChange(of: userAccountManager.shouldResetToWelcome) { oldValue, newValue in
            // ゲストユーザーの「ログアウト」処理
            // 注意：ユーザーには「ログアウト」と表示されるが、内部的には初期画面へのリセット
            if newValue == true {
                print("🔄 ゲストユーザーのログアウト - 初期画面に戻る")
                selectedTab = .home
                onboardingCompleted = false
                // フラグをリセット
                userAccountManager.shouldResetToWelcome = false
            }
        }
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

