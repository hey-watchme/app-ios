//
//  ios_watchme_v9App.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/06/11.
//

import SwiftUI
import AVFoundation
import UserNotifications

// アプリ起動の最初のログ
fileprivate let appLaunchTime: Date = {
    let time = Date()
    print("⏱️ [SYSTEM] @main構造体がロードされました: \(time)")
    return time
}()

@main
struct ios_watchme_v9App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var deviceManager = DeviceManager()
    @StateObject private var userAccountManager: UserAccountManager
    @StateObject private var dataManager: SupabaseDataManager
    @StateObject private var toastManager = ToastManager.shared
    @StateObject private var recordingStore: RecordingStore

    init() {
        let startTime = Date()
        print("⏱️ [APP-INIT] アプリ初期化開始: \(startTime)")

        // ✅ Supabaseクライアントを非同期で事前初期化（UIをブロックしない）
        Task.detached(priority: .high) {
            let initStart = Date()
            _ = SupabaseClientManager.shared.client
            print("✅ [SUPABASE-PRELOAD] Supabaseクライアント事前初期化完了: \(Date().timeIntervalSince(initStart))秒")
        }

        let deviceManager = DeviceManager()
        print("⏱️ [APP-INIT] DeviceManager初期化完了: \(Date().timeIntervalSince(startTime))秒")

        let userAccountManager = UserAccountManager(deviceManager: deviceManager)
        print("⏱️ [APP-INIT] UserAccountManager初期化完了: \(Date().timeIntervalSince(startTime))秒")

        let dataManager = SupabaseDataManager(userAccountManager: userAccountManager)
        dataManager.setDeviceManager(deviceManager)  // 🚀 DeviceManager参照を設定（パフォーマンス最適化）
        print("⏱️ [APP-INIT] SupabaseDataManager初期化完了: \(Date().timeIntervalSince(startTime))秒")

        let recordingStore = RecordingStore(
            deviceManager: deviceManager,
            userAccountManager: userAccountManager
        )
        print("⏱️ [APP-INIT] RecordingStore初期化完了: \(Date().timeIntervalSince(startTime))秒")

        _deviceManager = StateObject(wrappedValue: deviceManager)
        _userAccountManager = StateObject(wrappedValue: userAccountManager)
        _dataManager = StateObject(wrappedValue: dataManager)
        _recordingStore = StateObject(wrappedValue: recordingStore)

        print("⏱️ [APP-INIT] アプリ初期化完了: \(Date().timeIntervalSince(startTime))秒")
    }

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(userAccountManager)
                .environmentObject(deviceManager)
                .environmentObject(dataManager)
                .environmentObject(toastManager)
                .environmentObject(recordingStore)
        }
    }
}

// メインアプリビュー
struct MainAppView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var toastManager: ToastManager
    @EnvironmentObject var recordingStore: RecordingStore
    @State private var showLogin = false
    @State private var showOnboarding = false
    @State private var onboardingCompleted = false  // オンボーディング完了フラグ


    // フッターナビゲーション用の選択状態
    @State private var selectedTab: FooterTab = .home

    // パフォーマンス計測用
    @State private var viewStartTime = Date()

    // フッタータブの定義
    enum FooterTab {
        case home  // ホーム
        case report  // レポート
        case subject  // 観測対象
    }

    var body: some View {
        ZStack {
            // メインコンテンツ
            mainContent

            // グローバルトーストオーバーレイ（最前面）
            ToastOverlay(toastManager: toastManager)
        }
    }

    private var mainContent: some View {
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
            } else if userAccountManager.authState.isAuthenticated {
                // 全権限モード：メイン機能画面（単一のNavigationStackでラップ）
                NavigationStack {
                    VStack(spacing: 0) {
                        // コンテンツエリア（ビューを保持したまま表示/非表示を切り替え）
                        ZStack {
                            ContentView()
                                .environmentObject(userAccountManager)
                                .environmentObject(deviceManager)
                                .environmentObject(dataManager)
                                .environmentObject(recordingStore)
                                .opacity(selectedTab == .home ? 1 : 0)
                                .zIndex(selectedTab == .home ? 1 : 0)

                            ReportView()
                                .environmentObject(userAccountManager)
                                .environmentObject(deviceManager)
                                .environmentObject(dataManager)
                                .opacity(selectedTab == .report ? 1 : 0)
                                .zIndex(selectedTab == .report ? 1 : 0)

                            SubjectTabView()
                                .environmentObject(userAccountManager)
                                .environmentObject(deviceManager)
                                .environmentObject(dataManager)
                                .opacity(selectedTab == .subject ? 1 : 0)
                                .zIndex(selectedTab == .subject ? 1 : 0)
                        }

                        // カスタムフッターナビゲーション
                        CustomFooterNavigation(selectedTab: $selectedTab)
                    }
                    .edgesIgnoringSafeArea(.bottom)
                }
                .onAppear {
                    print("📱 MainAppView: 全権限モード - メイン画面表示")
                    // デバイス取得は認証成功時（onChange）で実行済み
                }
            } else {
                // 閲覧専用モード（Read-Only Mode）
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
                                    .environmentObject(recordingStore)
                                    .opacity(selectedTab == .home ? 1 : 0)
                                    .zIndex(selectedTab == .home ? 1 : 0)

                                ReportView()
                                    .environmentObject(userAccountManager)
                                    .environmentObject(deviceManager)
                                    .environmentObject(dataManager)
                                    .opacity(selectedTab == .report ? 1 : 0)
                                    .zIndex(selectedTab == .report ? 1 : 0)

                                SubjectTabView()
                                    .environmentObject(userAccountManager)
                                    .environmentObject(deviceManager)
                                    .environmentObject(dataManager)
                                    .opacity(selectedTab == .subject ? 1 : 0)
                                    .zIndex(selectedTab == .subject ? 1 : 0)
                            }

                            // カスタムフッターナビゲーション
                            CustomFooterNavigation(selectedTab: $selectedTab)
                        }
                        .edgesIgnoringSafeArea(.bottom)
                    }
                    .onAppear {
                        print("📱 MainAppView: 閲覧専用モード - ガイド画面表示")
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
                .environmentObject(userAccountManager)
                .environmentObject(deviceManager)
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
            print("🔄 MainAppView: 権限レベル変化 \(oldValue) → \(newValue)")
            if newValue.isAuthenticated {
                // 全権限モードへ移行（ログイン/サインアップ成功時）
                // シートを閉じる
                showLogin = false
                // ホーム画面にリセット
                selectedTab = .home
                print("✅ 全権限モード - ホーム画面に遷移")

                // 📊 Phase 2-B: デバイス取得の重複を排除
                // UserAccountManager内で既にfetchUserDevicesが実行されているため、ここでは不要
                // L239-245を削除（重複処理）
            } else {
                // 閲覧専用モードに移行（ログアウト時）
                selectedTab = .home
                onboardingCompleted = false  // オンボーディング完了フラグをリセット
                print("🔄 閲覧専用モード - 初期状態にリセット")
            }
        }
        .onChange(of: userAccountManager.shouldResetToWelcome) { oldValue, newValue in
            // 閲覧専用モードの「ログアウト」処理
            // 注意：ユーザーには「ログアウト」と表示されるが、内部的には初期画面へのリセット
            if newValue == true {
                print("🔄 閲覧専用モード - 初期画面に戻る")
                selectedTab = .home
                onboardingCompleted = false
                // フラグをリセット
                userAccountManager.shouldResetToWelcome = false
            }
        }
        .onOpenURL { url in
            // Handle OAuth callback from browser
            print("🔗 URL受信: \(url)")
            print("🔗 URL Scheme: \(url.scheme ?? "なし")")
            print("🔗 URL Host: \(url.host ?? "なし")")
            print("🔗 URL Path: \(url.path)")

            Task {
                await userAccountManager.handleOAuthCallback(url: url)

                // Close onboarding modal if OAuth succeeded
                if userAccountManager.isAuthenticated {
                    print("✅ 認証成功 - onboardingモーダルを閉じます")
                    await MainActor.run {
                        showOnboarding = false
                        onboardingCompleted = true
                        selectedTab = .home
                    }
                } else {
                    print("⚠️ 認証失敗 - isAuthenticated = false")
                    print("⚠️ authError: \(userAccountManager.authError ?? "なし")")
                }
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
                    Image(systemName: "house.fill")
                        .font(.system(size: 24))
                    Text("ホーム")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(selectedTab == .home ? Color.primary : Color.secondary)
            }

            // レポートタブ
            Button(action: {
                selectedTab = .report
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 24))
                    Text("レポート")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(selectedTab == .report ? Color.primary : Color.secondary)
            }

            // 観測対象タブ
            Button(action: {
                selectedTab = .subject
            }) {
                VStack(spacing: 4) {
                    Image(systemName: selectedTab == .subject ? "person.fill" : "person")
                        .font(.system(size: 24))
                    Text("観測対象")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(selectedTab == .subject ? Color.primary : Color.secondary)
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

// MARK: - AppDelegate for Push Notifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        print("🚀 [PUSH] AppDelegate起動")

        // UNUserNotificationCenterのデリゲートを設定
        UNUserNotificationCenter.current().delegate = self
        print("📱 [PUSH] UNUserNotificationCenterデリゲート設定完了")

        // サイレント通知のみ使用（権限リクエスト不要）
        // 将来的にユーザー向け通知が必要になったら、ここで権限リクエストを追加
        application.registerForRemoteNotifications()
        print("📱 [PUSH] デバイストークン登録リクエスト送信（サイレント通知モード）")

        return true
    }

    // MARK: - デバイストークン取得成功

    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 [PUSH] APNsデバイストークン取得成功: \(token)")

        // TODO: SupabaseのdevicesテーブルにAPNsトークンを保存
        saveDeviceToken(token)
    }

    // MARK: - デバイストークン取得失敗

    func application(_ application: UIApplication,
                    didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ [PUSH] APNsデバイストークン取得失敗: \(error.localizedDescription)")
    }

    // MARK: - サイレント通知受信（フォアグラウンド/バックグラウンド両対応）

    func application(_ application: UIApplication,
                    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        print("📬 [PUSH] サイレント通知受信: \(userInfo)")
        print("📱 [PUSH] アプリ状態: \(application.applicationState == .active ? "フォアグラウンド" : "バックグラウンド")")

        // dashboard_summary更新通知の場合
        if let action = userInfo["action"] as? String, action == "refresh_dashboard" {
            handleDashboardUpdate(userInfo)
            completionHandler(.newData)
        } else {
            print("⚠️ [PUSH] 未知のアクション")
            completionHandler(.noData)
        }
    }

    // MARK: - フォアグラウンド通知受信（レイヤー2: 権限チェック）

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo

        print("📬 [PUSH] フォアグラウンド通知受信: \(userInfo)")

        // ✅ レイヤー2: 認証済みユーザーのみ通知を表示
        let userId = UserDefaults.standard.string(forKey: "current_user_id")
        guard userId != nil else {
            print("⚠️ [PUSH] ログアウト中のため通知を無視")
            return []  // 通知を表示しない
        }

        // ✅ 通知の対象デバイスが現在選択中のデバイスか確認
        if let targetDeviceId = userInfo["device_id"] as? String {
            let selectedDeviceId = UserDefaults.standard.string(forKey: "selected_device_id")
            guard targetDeviceId == selectedDeviceId else {
                print("⚠️ [PUSH] 別デバイス(\(targetDeviceId))の通知のため無視（現在選択: \(selectedDeviceId ?? "なし")）")
                return []
            }
        }

        // dashboard_summary更新通知の場合
        if let action = userInfo["action"] as? String, action == "refresh_dashboard" {
            // ✅ 軽い振動フィードバックを発生
            await MainActor.run {
                let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
                feedbackGenerator.impactOccurred()
                print("✨ [PUSH] 軽い振動フィードバック発生")
            }

            handleDashboardUpdate(userInfo)
            // フォアグラウンドではバナーと音で通知
            return [.banner, .sound]
        }

        return []
    }

    // MARK: - ダッシュボード更新処理

    private func handleDashboardUpdate(_ userInfo: [AnyHashable: Any]) {
        guard let deviceId = userInfo["device_id"] as? String,
              let date = userInfo["date"] as? String else {
            print("⚠️ [PUSH] 無効な通知ペイロード")
            return
        }

        print("🔄 [PUSH] ダッシュボード更新通知: deviceId=\(deviceId), date=\(date)")

        // apsペイロードからメッセージ本文を取得
        var messageBody: String?
        if let aps = userInfo["aps"] as? [String: Any],
           let alert = aps["alert"] as? [String: Any],
           let body = alert["body"] as? String {
            messageBody = body
            print("📝 [PUSH] メッセージ本文: \(body)")
        }

        // NotificationCenterで通知を送信（SimpleDashboardViewで監視）
        var notificationUserInfo: [String: Any] = [
            "device_id": deviceId,
            "date": date
        ]
        if let messageBody = messageBody {
            notificationUserInfo["message"] = messageBody
        }

        NotificationCenter.default.post(
            name: NSNotification.Name("RefreshDashboard"),
            object: nil,
            userInfo: notificationUserInfo
        )
    }

    // MARK: - デバイストークン保存

    private func saveDeviceToken(_ token: String) {
        // UserDefaultsにトークンを保存（後でデバイス選択時にSupabaseに保存）
        UserDefaults.standard.set(token, forKey: "apns_device_token")
        print("💾 [PUSH] デバイストークンをUserDefaultsに保存: \(token)")

        // NotificationCenterで通知（DeviceManagerで受信してSupabaseに保存）
        NotificationCenter.default.post(
            name: NSNotification.Name("APNsTokenReceived"),
            object: nil,
            userInfo: ["token": token]
        )
    }
}

