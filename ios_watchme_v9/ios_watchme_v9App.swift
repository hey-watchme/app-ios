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

        // ⚡ キーボード最適化は個別のTextFieldで実施
        // UIAppearanceは使用しない（スレッド安全性の問題を回避）

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
    @State private var showAuthFlow = false  // 統合認証フロー（オンボーディング + アカウント選択）
    @State private var authFlowCompleted = false  // 認証フロー完了フラグ
    @State private var showRecordingSheet = false
    @State private var showFirstLaunchGuide = false
    @AppStorage("has_seen_first_launch_guide") private var hasSeenFirstLaunchGuide = false
    @State private var showMicTip = false
    @AppStorage("has_seen_mic_tip") private var hasSeenMicTip = false


    // フッターナビゲーション用の選択状態
    @State private var selectedTab: FooterTab = .home

    // パフォーマンス計測用
    @State private var viewStartTime = Date()

    // フッタータブの定義
    enum FooterTab {
        case home  // ホーム
        case report  // レポート
        case subject  // 分析対象
    }

    var body: some View {
        ZStack {
            // メインコンテンツ
            mainContent

            // グローバルトーストオーバーレイ（最前面）
            ToastOverlay(toastManager: toastManager)

            if showFirstLaunchGuide && userAccountManager.authState.isAuthenticated {
                FirstLaunchGuideSheet(onDismiss: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showFirstLaunchGuide = false
                    }
                    hasSeenFirstLaunchGuide = true
                    if !hasSeenMicTip {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showMicTip = true
                        }
                    }
                })
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
    }

    // MARK: - Extracted Views

    private var homeContent: some View {
        ContentView(showRecordingSheet: $showRecordingSheet)
            .environmentObject(userAccountManager)
            .environmentObject(deviceManager)
            .environmentObject(dataManager)
            .environmentObject(recordingStore)
    }

    private var reportContent: some View {
        ReportView()
            .environmentObject(userAccountManager)
            .environmentObject(deviceManager)
            .environmentObject(dataManager)
    }

    private var subjectContent: some View {
        SubjectTabView()
            .environmentObject(userAccountManager)
            .environmentObject(deviceManager)
            .environmentObject(dataManager)
    }

    /// 共通化されたタブビュー構造
    private var mainTabView: some View {
        NavigationStack {
            ZStack {
                // コンテンツエリア（ビューを保持したまま表示/非表示を切り替え）
                ZStack {
                    homeContent
                        .opacity(selectedTab == .home ? 1 : 0)
                        .zIndex(selectedTab == .home ? 1 : 0)
                        .allowsHitTesting(selectedTab == .home)

                    reportContent
                        .opacity(selectedTab == .report ? 1 : 0)
                        .zIndex(selectedTab == .report ? 1 : 0)
                        .allowsHitTesting(selectedTab == .report)

                    subjectContent
                        .opacity(selectedTab == .subject ? 1 : 0)
                        .zIndex(selectedTab == .subject ? 1 : 0)
                        .allowsHitTesting(selectedTab == .subject)
                }
            }
            .overlay(alignment: .bottom) {
                // スワイプ体験を維持するため、コンテンツ構造は変えずにフッターのみ浮島化
                CustomFooterNavigation(
                    selectedTab: $selectedTab,
                    showRecordButton: deviceManager.shouldShowFAB,
                    showMicTip: showMicTip,
                    onDismissMicTip: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showMicTip = false
                        }
                        hasSeenMicTip = true
                    },
                    onRecordTap: {
                        showRecordingSheet = true
                    }
                )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .sheet(isPresented: $showRecordingSheet) {
                ZStack {
                    FullScreenRecordingView()
                        .environmentObject(deviceManager)
                        .environmentObject(userAccountManager)
                        .environmentObject(recordingStore)

                    VStack {
                        ToastOverlay(toastManager: ToastManager.shared)
                        Spacer()
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var mainContent: some View {
        ZStack {
            if userAccountManager.isCheckingAuthStatus {
                loadingView
            } else if userAccountManager.authState.isAuthenticated {
                authenticatedView
            } else {
                unauthenticatedView
            }
        }
        .fullScreenCover(isPresented: $showAuthFlow) {
            AuthFlowView(isPresented: $showAuthFlow)
                .environmentObject(userAccountManager)
                .environmentObject(deviceManager)
                .environmentObject(toastManager)
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
                .environmentObject(userAccountManager)
        }
        .onChange(of: showAuthFlow) { oldValue, newValue in
            if oldValue == true && newValue == false {
                print("✅ 認証フロー完了")
                authFlowCompleted = true
            }
        }
        .task {
            viewStartTime = Date()
            print("⏱️ [VIEW] MainAppView表示開始 - 認証チェック呼び出し")
            userAccountManager.checkAuthStatus()
        }
        .onChange(of: userAccountManager.authState) { oldValue, newValue in
            print("🔄 MainAppView: 権限レベル変化 \(oldValue) → \(newValue)")
            if newValue.isAuthenticated {
                showLogin = false
                showAuthFlow = false
                authFlowCompleted = true
                selectedTab = .home
                print("✅ 全権限モード - すべてのモーダルを閉じてホーム画面に遷移")
                if !hasSeenFirstLaunchGuide {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showFirstLaunchGuide = true
                    }
                }
            } else {
                selectedTab = .home
                authFlowCompleted = false
                print("🔄 閲覧専用モード - 初期状態にリセット")
            }
        }
        .onChange(of: userAccountManager.shouldResetToWelcome) { oldValue, newValue in
            if newValue == true {
                print("🔄 閲覧専用モード - 初期画面に戻る")
                selectedTab = .home
                authFlowCompleted = false
                userAccountManager.shouldResetToWelcome = false
            }
        }
        .onChange(of: userAccountManager.authError) { oldValue, newValue in
            if let error = newValue, !error.isEmpty {
                toastManager.showError(title: "認証エラー", subtitle: error)
                print("🍞 [Toast] 認証エラー表示: \(error)")
            }
        }
        .onOpenURL { url in
            print("🔗 [MainAppView] URL受信: \(url)")
            Task {
                await userAccountManager.handleOAuthCallback(url: url)
            }
        }
    }

    private var loadingView: some View {
        ZStack {
            Color.darkBase.ignoresSafeArea()

            // ロゴは常に中央固定（Launch Screenとの視覚差分を減らす）
            Image("WatchMeLogoWhite")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 70)
                .shadow(color: Color.white.opacity(0.16), radius: 10, x: 0, y: 4)

            VStack(spacing: 10) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.2)
                    .tint(Color.white.opacity(0.85))

                Text("認証チェック中...")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.70))
            }
            .padding(.top, 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            print("⏱️ [VIEW] ロゴ画面表示: \(Date().timeIntervalSince(viewStartTime))秒")
        }
    }

    private var authenticatedView: some View {
        mainTabView
            .onAppear {
                print("📱 MainAppView: 全権限モード - メイン画面表示")
            }
    }

    private var unauthenticatedView: some View {
        Group {
            if authFlowCompleted {
                mainTabView
                    .onAppear {
                        print("📱 MainAppView: 閲覧専用モード - ガイド画面表示")
                    }
            } else {
                initialView
            }
        }
    }

    private var initialView: some View {
        ZStack {
            LoopingVideoBackgroundView(
                resourceName: "app-opening-video_001",
                fallbackColor: Color.darkBase
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()

                // ロゴを中央に配置
                Image("WatchMeLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 70)
                    // ※ロゴが黒文字の場合はダークモード用に白抜き画像にするなどの調整が必要ですが、ここではそのままにしています

                Spacer()

                // ボタンを最下部に配置
                VStack(spacing: 16) {
                    // はじめるボタン → 認証フロー表示
                    Button(action: {
                        showAuthFlow = true
                    }) {
                        Text("はじめる")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.accentTeal)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    // ログインボタン
                    Button(action: {
                        showLogin = true
                    }) {
                        Text("ログイン")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.darkElevated)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            print("⏱️ [VIEW] 初期画面表示（はじめる/ログイン）: \(Date().timeIntervalSince(viewStartTime))秒")
        }
    }

    // checkAndRegisterDevice関数は削除されました（自動登録を行わないため）
}

// カスタムフッターナビゲーション
struct CustomFooterNavigation: View {
    @Binding var selectedTab: MainAppView.FooterTab
    let showRecordButton: Bool
    let showMicTip: Bool
    let onDismissMicTip: () -> Void
    let onRecordTap: () -> Void
    @EnvironmentObject var deviceManager: DeviceManager
    private let glassBaseOpacity: Double = 0.62
    private let glassMaterialOpacity: Double = 0.40

    private var isDeviceSelected: Bool {
        deviceManager.selectedDeviceID != nil
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                footerTabButton(.home, activeIcon: "house.fill", inactiveIcon: "house", title: "ホーム")
                footerTabButton(.report, activeIcon: "heart.text.square.fill", inactiveIcon: "heart.text.square", title: "レポート")
                footerTabButton(.subject, activeIcon: "person.fill", inactiveIcon: "person", title: "分析対象")
            }
            .frame(maxWidth: .infinity)

            if showRecordButton {
                recordButton
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .opacity(isDeviceSelected ? 1.0 : 0.65)
        .frame(maxWidth: 460)
        .background(
            Capsule()
                .fill(Color.black.opacity(glassBaseOpacity))
                .overlay(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .opacity(glassMaterialOpacity)
                )
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 8)
    }

    private func footerTabButton(
        _ tab: MainAppView.FooterTab,
        activeIcon: String,
        inactiveIcon: String,
        title: String
    ) -> some View {
        let isSelected = selectedTab == tab

        return Button(action: {
            if showMicTip {
                onDismissMicTip()
            }
            selectedTab = tab
        }) {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? activeIcon : inactiveIcon)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundColor(tabForegroundColor(isSelected: isSelected))
            .background(
                Capsule()
                    .fill(Color.white.opacity(isSelected ? 0.08 : 0.001))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isDeviceSelected)
    }

    private func tabForegroundColor(isSelected: Bool) -> Color {
        guard isDeviceSelected else { return Color.gray.opacity(0.55) }
        return isSelected ? Color.accentTeal.opacity(0.9) : Color.white.opacity(0.76)
    }

    private var recordButton: some View {
        Button(action: {
            if showMicTip {
                onDismissMicTip()
            }
            onRecordTap()
        }) {
            Image(systemName: "mic.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.accentTeal.opacity(0.95))
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!isDeviceSelected)
        .frame(width: 52, height: 52)
        .overlay(alignment: .topTrailing) {
            if showMicTip && isDeviceSelected {
                MicTipBubble(
                    text: "まずは音声の\n分析を始めてみましょう。",
                    onClose: onDismissMicTip
                )
                .frame(width: 220)
                .offset(y: -78)
            }
        }
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

    // MARK: - フォアグラウンド通知受信（統一ハンドラー）

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo

        print("📬 [PUSH] Foreground notification received")

        // Permission check: Authenticated users only
        guard UserDefaults.standard.string(forKey: "current_user_id") != nil else {
            print("⚠️ [PUSH] Notification ignored (user not authenticated)")
            return []
        }

        // Device filter: Current selected device only
        if let targetDeviceId = userInfo["device_id"] as? String {
            let selectedDeviceId = UserDefaults.standard.string(forKey: "watchme_selected_device_id")
            guard targetDeviceId == selectedDeviceId else {
                print("⚠️ [PUSH] Notification ignored (different device: target=\(targetDeviceId), selected=\(selectedDeviceId ?? "nil"))")
                return []
            }
        }

        // Delegate to PushNotificationManager
        let handled = PushNotificationManager.shared.handleAPNsPayload(userInfo)

        if handled {
            // Light haptic feedback for user experience
            await MainActor.run {
                let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
                feedbackGenerator.impactOccurred()
                print("✨ [PUSH] Haptic feedback triggered")
            }

            return [.banner, .sound]
        }

        return []
    }

    // MARK: - 通知タップ時（バックグラウンド/終了状態）

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo

        print("📲 [PUSH] Notification tapped")

        // Permission check: Authenticated users only
        guard UserDefaults.standard.string(forKey: "current_user_id") != nil else {
            print("⚠️ [PUSH] Tap ignored (user not authenticated)")
            return
        }

        // Device filter: selected device is known and different -> ignore
        if let targetDeviceId = userInfo["device_id"] as? String,
           let selectedDeviceId = UserDefaults.standard.string(forKey: "watchme_selected_device_id"),
           targetDeviceId != selectedDeviceId {
            print("⚠️ [PUSH] Tap ignored (different device: target=\(targetDeviceId), selected=\(selectedDeviceId))")
            return
        }

        // Delegate to PushNotificationManager so dashboard can refresh on app open
        let handled = PushNotificationManager.shared.handleAPNsPayload(userInfo)
        print(handled ? "✅ [PUSH] Tap payload handled" : "⚠️ [PUSH] Tap payload not handled")
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
