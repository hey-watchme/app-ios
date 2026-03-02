//
//  UserAccountManager.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/07/04.
//

import SwiftUI
import Foundation
import Supabase
import AuthenticationServices
#if canImport(Security)
import Security
#endif
#if os(iOS)
import UIKit
#endif

// Supabaseクライアントをシングルトンとして遅延初期化
class SupabaseClientManager {
    static let shared = SupabaseClientManager()

    private(set) lazy var client: SupabaseClient = {
        let startTime = Date()
        print("⏱️ [SUPABASE-LAZY] Supabaseクライアント遅延初期化開始（事前初期化されていない場合）: \(startTime)")

        let client = SupabaseClient(
            supabaseURL: URL(string: "https://qvtlwotzuzbavrzqhyvt.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dGx3b3R6dXpiYXZyenFoeXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzODAzMzAsImV4cCI6MjA2Njk1NjMzMH0.g5rqrbxHPw1dKlaGqJ8miIl9gCXyamPajinGCauEI3k",
            options: SupabaseClientOptions(
                auth: .init(
                    redirectToURL: URL(string: "watchme://auth/callback")
                )
            )
        )

        print("⏱️ [SUPABASE-LAZY] Supabaseクライアント遅延初期化完了: \(Date().timeIntervalSince(startTime))秒")
        return client
    }()

    private init() {}
}

// 後方互換性のため、グローバル変数として公開
var supabase: SupabaseClient {
    SupabaseClientManager.shared.client
}

// ユーザー認証状態（シンプル設計）
enum UserAuthState: Equatable {
    case unauthenticated                   // 未認証（起動直後、ログアウト後）
    case authenticated(userId: String)     // 認証済み（匿名含む）

    var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }

    var canWrite: Bool {
        return isAuthenticated
    }

    var canEditAvatar: Bool {
        return isAuthenticated
    }
}

// ユーザーアカウント管理クラス（認証とプロファイル）
class UserAccountManager: ObservableObject {
    @Published var authState: UserAuthState = .unauthenticated
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: SupabaseUser? = nil
    @Published var authError: String? = nil
    @Published var signUpSuccess: Bool = false
    @Published var isLoading: Bool = false
    @Published var isCheckingAuthStatus: Bool = true  // 認証状態確認中フラグ
    @Published var guestId: String? = nil  // ゲストID（分析用、必須ではない）
    
    // DeviceManagerへの参照
    private let deviceManager: DeviceManager
    
    // Supabase設定
    private let supabaseURL = "https://qvtlwotzuzbavrzqhyvt.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dGx3b3R6dXpiYXZyenFoeXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzODAzMzAsImV4cCI6MjA2Njk1NjMzMH0.g5rqrbxHPw1dKlaGqJ8miIl9gCXyamPajinGCauEI3k"
    
    // トークンリフレッシュタイマー
    private var refreshTimer: Timer?
    private let tokenRefreshInterval: TimeInterval = 45 * 60 // 45分（1時間のトークンに対して15分前にリフレッシュ）
    
    init(deviceManager: DeviceManager) {
        let startTime = Date()
        print("⏱️ [UAM-INIT] UserAccountManager初期化開始")

        self.deviceManager = deviceManager
        print("⏱️ [UAM-INIT] deviceManager設定完了: \(Date().timeIntervalSince(startTime))秒")

        // アプリがフォアグラウンドに戻った時の処理を設定
        setupNotificationObservers()
        print("⏱️ [UAM-INIT] 通知オブザーバー設定完了: \(Date().timeIntervalSince(startTime))秒")

        // 認証チェックはMainAppViewの.taskで非同期に実行
        print("⏱️ [UAM-INIT] UserAccountManager初期化完了: \(Date().timeIntervalSince(startTime))秒")
    }

    /// 実運用で利用するユーザーID（public.users優先、未取得時はauth.usersをフォールバック）
    var effectiveUserId: String? {
        currentUser?.profile?.userId ?? currentUser?.id
    }
    
    // MARK: - アクセストークン取得
    func getAccessToken() -> String? {
        // トークンの有効期限をチェックして、必要ならリフレッシュ
        Task { @MainActor in
            await ensureValidToken()
        }
        return currentUser?.accessToken
    }
    
    // MARK: - 通知オブザーバーの設定
    private func setupNotificationObservers() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif
    }
    
    @objc private func appWillEnterForeground() {
        print("📱 アプリがフォアグラウンドに復帰")
        Task { @MainActor in
            await refreshTokenIfNeeded()
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 認証状態確認
    func checkAuthStatus() {
        let checkStartTime = Date()
        print("⏱️ [AUTH-CHECK] 認証チェック開始")

        // 非同期処理をバックグラウンドで開始（メインスレッドをブロックしない）
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            print("⏱️ [AUTH-CHECK] Task開始: \(Date().timeIntervalSince(checkStartTime))秒")

            let loadStart = Date()
            let savedUser = await Task { @MainActor in
                self.loadUserFromDefaults()
            }.value
            print("⏱️ [AUTH-CHECK] UserDefaults読み込み完了: \(Date().timeIntervalSince(loadStart))秒")

            if let savedUser = savedUser {
                print("⏱️ [AUTH-CHECK] 認証情報あり - ユーザー: \(savedUser.email)")
                // 📊 Phase 2-A: トークン有効期限のローカルチェック
                if let expiresAt = savedUser.expiresAt, expiresAt > Date().addingTimeInterval(7200) {
                    // まだ2時間以上有効 → リフレッシュ不要
                    print("✅ [Phase 2-A] トークンは有効（有効期限: \(expiresAt)）- リフレッシュスキップ")

                    await MainActor.run {
                        self.currentUser = savedUser
                        self.isAuthenticated = true
                        self.authState = .authenticated(userId: savedUser.id)
                    }

                    // トークンリフレッシュタイマーを開始（メインスレッドで実行）
                    await MainActor.run {
                        self.startTokenRefreshTimer()
                    }

                    // 統一初期化フローを実行
                    await self.initializeAuthenticatedUser(authUserId: savedUser.id)

                    await MainActor.run {
                        self.isCheckingAuthStatus = false
                    }
                    return
                }

                // トークンが期限切れまたは有効期限情報なし → リフレッシュ実行
                print("⚠️ [Phase 2-A] トークンの有効期限切れまたは情報なし - リフレッシュ実行")

                // リフレッシュトークンチェック（早期return）
                guard let refreshToken = savedUser.refreshToken else {
                    // リフレッシュトークンがない → 即座にゲストモードへ
                    print("⚠️ リフレッシュトークンなし - ゲストモードに移行")
                    await self.clearLocalAuthData()
                    await MainActor.run {
                        self.initializeGuestMode()
                        self.isCheckingAuthStatus = false
                    }
                    return
                }

                // 保存されたトークンでセッションを復元
                do {
                    // まずリフレッシュトークンでトークンを更新してみる
                    let success = await self.refreshTokenWithRetry(refreshToken: refreshToken, maxRetries: 1)  // 📊 Phase 2-A: 2回→1回に削減

                    if !success {
                        // リフレッシュ失敗時は保存されたトークンで復元を試みる
                        _ = try await supabase.auth.setSession(
                            accessToken: savedUser.accessToken,
                            refreshToken: refreshToken
                        )

                        await MainActor.run {
                            self.currentUser = savedUser
                            self.isAuthenticated = true
                            self.authState = .authenticated(userId: savedUser.id)
                        }
                    }
                    // refreshTokenWithRetryが成功した場合は、その中で既にcurrentUserとisAuthenticatedが設定済み

                    let isAuthenticated = await MainActor.run { self.isAuthenticated }
                    if isAuthenticated {
                        print("✅ 保存された認証状態を復元: \(savedUser.email)")
                        print("🔄 認証状態復元: authState = authenticated")
                        print("🔑 セッショントークンも復元しました")

                        // トークンリフレッシュタイマーを開始
                        await MainActor.run {
                            self.startTokenRefreshTimer()
                        }

                        // 統一初期化フローを実行
                        let userId = await MainActor.run { self.currentUser?.id ?? savedUser.id }
                        await self.initializeAuthenticatedUser(authUserId: userId)
                    }

                    await MainActor.run {
                        self.isCheckingAuthStatus = false  // 認証確認完了
                    }

                } catch {
                    print("❌ セッション復元エラー: \(error)")
                    print("🔄 リフレッシュトークンでの再試行を開始...")

                    // エラー時はリフレッシュトークンで再試行
                    if let refreshToken = savedUser.refreshToken {
                        let success = await self.refreshTokenWithRetry(refreshToken: refreshToken, maxRetries: 1)  // 📊 Phase 2-A: 2回→1回に削減
                        if !success {
                            print("⚠️ 再ログインが必要です - ゲストモードに移行")
                            await self.clearLocalAuthData()
                            await MainActor.run {
                                self.initializeGuestMode()
                            }
                        }
                    } else {
                        await self.clearLocalAuthData()
                        await MainActor.run {
                            self.initializeGuestMode()
                        }
                    }
                    await MainActor.run {
                        self.isCheckingAuthStatus = false  // 認証確認完了
                    }
                }
            } else {
                print("⏱️ [AUTH-CHECK] 認証情報なし - ゲストモードへ: \(Date().timeIntervalSince(checkStartTime))秒")
                let guestStart = Date()
                await MainActor.run {
                    self.initializeGuestMode()
                }
                print("⏱️ [AUTH-CHECK] ゲストモード初期化完了: \(Date().timeIntervalSince(guestStart))秒")
                await MainActor.run {
                    self.isCheckingAuthStatus = false  // 認証確認完了
                }
                print("⏱️ [AUTH-CHECK] 認証チェック完了（ゲスト）: \(Date().timeIntervalSince(checkStartTime))秒")
            }
        }
    }

    // MARK: - ゲストモード管理（権限ベース設計）
    func initializeGuestMode() {
        let guestInitStart = Date()
        print("⏱️ [GUEST-INIT] Read-Only Mode (Guest) 初期化開始")

        // 状態を閲覧専用に設定（@MainActorで実行）
        Task { @MainActor in
            self.authState = .unauthenticated
            self.isAuthenticated = false
            self.currentUser = nil

            // DeviceManagerの状態をクリア
            self.deviceManager.clearState()
            print("⏱️ [GUEST-INIT] DeviceManager状態クリア: \(Date().timeIntervalSince(guestInitStart))秒")

            // ゲストモード用に空のデバイスリストで利用可能状態にする
            self.deviceManager.state = .available([])
            print("📱 [GUEST-INIT] DeviceManager状態を.available([])に設定")

            print("⏱️ [GUEST-INIT] Read-Only Mode初期化完了: \(Date().timeIntervalSince(guestInitStart))秒")
        }

        // ゲストIDは分析用に生成（必須ではない）
        if guestId == nil {
            createGuestUser()
        }

        // サンプルデバイスの自動選択は行わない
        // ユーザーがガイド画面で「サンプルを見る」を選択したときのみデバイスを選択
    }

    func createGuestUser() {
        let newGuestId = UUID().uuidString
        UserDefaults.standard.set(newGuestId, forKey: "guest_id")
        guestId = newGuestId
        print("✨ 新規ゲストID生成（分析用）: \(newGuestId)")
    }

    // 書き込み権限が必要かチェック（権限ベース設計）
    func requireWritePermission() -> Bool {
        return !authState.canWrite
    }

    // 後方互換性のため残す（非推奨）
    @available(*, deprecated, message: "Use requireWritePermission() instead")
    func requireAuthentication() -> Bool {
        return requireWritePermission()
    }

    // Check if current user is anonymous
    var isAnonymousUser: Bool {
        guard let user = currentUser else { return false }

        // Check auth_provider first (most explicit signal)
        if let authProvider = user.profile?.authProvider?.lowercased(), authProvider == "anonymous" {
            return true
        }

        // Fallback to sentinel email used by legacy/current guest flows
        if user.email.lowercased() == "anonymous" {
            return true
        }

        if let profileEmail = user.profile?.email?.lowercased(), profileEmail == "anonymous" {
            return true
        }

        return false
    }

    // Get user status label for display
    var userStatusLabel: String {
        guard let user = currentUser else { return "未認証" }

        if isAnonymousUser {
            return "ゲストユーザー"
        }

        // Check auth_provider from profile first
        if let authProvider = user.profile?.authProvider?.lowercased() {
            switch authProvider {
            case "google":
                return "Googleアカウント連携"
            case "email":
                return "メールアドレス連携"
            case "apple":
                return "Appleアカウント連携"
            default:
                return authProvider.capitalized + "アカウント連携"
            }
        }

        return "認証済み"
    }

    // MARK: - ログイン機能
    func signIn(email: String, password: String) {
        Task { @MainActor in
            await performSignIn(email: email, password: password)
        }
    }

    // 内部用の async ログイン処理
    private func performSignIn(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            authError = nil
        }

        print("🔐 ログイン試行: \(email)")

        do {
            // Supabaseクライアントの組み込みメソッドを使用
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            print("✅ ログイン成功: \(email)")
            print("📡 認証レスポンス取得完了")

            // 📊 Phase 2-A: 有効期限を計算（1時間後）
            let expiresAt = Date().addingTimeInterval(3600)

            // 認証情報を保存
            let user = SupabaseUser(
                id: session.user.id.uuidString,
                email: session.user.email ?? email,
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                profile: nil,
                expiresAt: expiresAt  // 📊 Phase 2-A: 有効期限を設定
            )

            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true

                // ✅ 権限ベース設計: 閲覧専用 → 全権限モードへアップグレード
                self.authState = .authenticated(userId: user.id)
                self.saveUserToDefaults(user)

                print("🔄 認証状態を更新: authState = authenticated")
                print("✅ Read-Only Mode → Full Access Mode へアップグレード")

                // ゲストIDをクリア（もう不要）
                UserDefaults.standard.removeObject(forKey: "guest_id")
                self.guestId = nil

                // ✅ DeviceManagerの状態を明示的にリセット
                self.deviceManager.resetState()
                print("🔄 DeviceManager状態リセット完了")

                // トークンリフレッシュタイマーを開始
                self.startTokenRefreshTimer()

                self.isLoading = false
            }

            // 統一初期化フローを実行
            await self.initializeAuthenticatedUser(authUserId: user.id)

        } catch {
            await MainActor.run {
                self.isLoading = false

                // エラーハンドリング
                self.authError = "ログインに失敗しました: \(error.localizedDescription)"

                print("❌ ログインエラー: \(error)")
            }
        }
    }
    
    // MARK: - 匿名認証機能
    func signInAnonymously() async {
        await MainActor.run {
            isLoading = true
            authError = nil
        }

        print("🔐 匿名ログイン開始")

        // 念のため端末内の既存セッションを破棄してから匿名ログインする。
        // これによりログアウト直後でも同一ゲストが再開されるケースを防ぐ。
        do {
            try await supabase.auth.signOut(scope: .local)
        } catch {
            print("⚠️ 匿名ログイン前のローカルサインアウトに失敗: \(error)")
        }
        clearSupabaseSessionFromKeychain()

        do {
            let session = try await supabase.auth.signInAnonymously()

            print("✅ 匿名ログイン成功")

            // Valid token for 1 hour
            let expiresAt = Date().addingTimeInterval(3600)

            let user = SupabaseUser(
                id: session.user.id.uuidString,
                email: "anonymous",  // Mark as anonymous
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                profile: nil,
                expiresAt: expiresAt
            )

            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.authState = .authenticated(userId: user.id)
                self.saveUserToDefaults(user)
                self.isLoading = false
            }

            print("🔄 Authentication state updated: authState = authenticated (anonymous)")

            // Create profile in public.users table
            await createAnonymousUserProfile(userId: user.id)

            // Start token refresh timer
            startTokenRefreshTimer()

            // Initialize authenticated user flow
            await initializeAuthenticatedUser(authUserId: user.id)

        } catch {
            await MainActor.run {
                self.isLoading = false
                self.authError = "匿名ログインに失敗しました: \(error.localizedDescription)"
                print("❌ 匿名ログインエラー: \(error)")
            }
        }
    }

    // Create anonymous user profile in public.users table
    private func createAnonymousUserProfile(userId: String) async {
        struct AnonymousUserProfile: Encodable {
            let user_id: String
            let name: String
            let email: String
            let created_at: String
            let auth_provider: String
        }

        struct AnonymousUserProfileWithRole: Encodable {
            let user_id: String
            let name: String
            let email: String
            let created_at: String
            let auth_provider: String
            let role: String
        }

        let createdAt = ISO8601DateFormatter().string(from: Date())
        let baseProfile = AnonymousUserProfile(
            user_id: userId,
            name: "ゲストユーザー",
            email: "anonymous",
            created_at: createdAt,
            auth_provider: "anonymous"
        )

        do {
            try await supabase
                .from("users")
                .insert(baseProfile)
                .execute()

            print("✅ 匿名ユーザープロファイル作成成功 (auth_provider: anonymous)")
            await fetchUserProfile(userId: userId)
            return
        } catch {
            guard isUsersRoleConstraintError(error) else {
                print("❌ 匿名ユーザープロファイル作成エラー: \(error)")
                return
            }

            // 環境ごとに public.users.role のCHECK制約が異なるため候補を順番に試す
            let roleCandidates = ["viewer", "individual", "user", "guest", "staff", "parent", "admin"]
            for role in roleCandidates {
                do {
                    let profileWithRole = AnonymousUserProfileWithRole(
                        user_id: userId,
                        name: "ゲストユーザー",
                        email: "anonymous",
                        created_at: createdAt,
                        auth_provider: "anonymous",
                        role: role
                    )

                    try await supabase
                        .from("users")
                        .insert(profileWithRole)
                        .execute()

                    print("✅ 匿名ユーザープロファイル作成成功 (auth_provider: anonymous, role: \(role))")
                    await fetchUserProfile(userId: userId)
                    return
                } catch {
                    if !isUsersRoleConstraintError(error) {
                        print("❌ 匿名ユーザープロファイル作成エラー（role=\(role)）: \(error)")
                        return
                    }
                }
            }

            print("❌ 匿名ユーザープロファイル作成失敗: users_role_check に適合する role 値が見つかりません")
            // Continue even if profile creation fails
        }
    }

    private func isUsersRoleConstraintError(_ error: Error) -> Bool {
        guard let postgrestError = error as? PostgrestError else { return false }
        return postgrestError.code == "23514" &&
            postgrestError.message.contains("users_role_check")
    }

    // MARK: - Google OAuth認証
    func signInWithGoogle() async {
        await MainActor.run {
            isLoading = true
            authError = nil
        }

        print("🔐 Google認証開始")

        do {
            // Start OAuth flow (redirects to Safari/Chrome)
            // redirectToURL is configured globally in SupabaseClientManager
            try await supabase.auth.signInWithOAuth(provider: .google)

            // OAuth flow continues in browser
            // Callback is handled by handleOAuthCallback()
            print("✅ Google認証フロー開始（ブラウザにリダイレクト）")

            await MainActor.run {
                self.isLoading = false
            }

        } catch {
            await MainActor.run {
                self.isLoading = false
                self.authError = "Google認証に失敗しました: \(error.localizedDescription)"
                print("❌ Google認証エラー: \(error)")
            }
        }
    }

    // Handle OAuth callback from browser
    func handleOAuthCallback(url: URL) async {
        print("🔗 OAuth callback受信: \(url)")

        await MainActor.run {
            self.isLoading = true
        }

        // Parse URL fragment (Implicit Flow: #access_token=...)
        guard let fragment = url.fragment else {
            await MainActor.run {
                self.isLoading = false
                self.authError = "認証URLが無効です"
                print("❌ URLフラグメントがありません")
            }
            return
        }

        // Parse fragment as query parameters
        let params = fragment.components(separatedBy: "&").reduce(into: [String: String]()) { result, component in
            let parts = component.components(separatedBy: "=")
            if parts.count == 2 {
                result[parts[0]] = parts[1]
            }
        }

        guard let accessToken = params["access_token"],
              let refreshToken = params["refresh_token"] else {
            await MainActor.run {
                self.isLoading = false
                self.authError = "認証トークンの取得に失敗しました"
                print("❌ access_tokenまたはrefresh_tokenがありません")
            }
            return
        }

        print("✅ トークン抽出成功")

        do {
            // Set session with tokens
            let session = try await supabase.auth.setSession(
                accessToken: accessToken,
                refreshToken: refreshToken
            )

            print("✅ Google認証成功: \(session.user.email ?? "")")

            // Extract Google avatar URL from user metadata
            var googleAvatarUrl: String?
            if case let .string(pictureValue) = session.user.userMetadata["picture"] {
                googleAvatarUrl = pictureValue
            } else if case let .string(avatarUrlValue) = session.user.userMetadata["avatar_url"] {
                googleAvatarUrl = avatarUrlValue
            }
            print("🖼️ Google avatar URL: \(googleAvatarUrl ?? "none")")

            let expiresAt = Date().addingTimeInterval(3600)

            let user = SupabaseUser(
                id: session.user.id.uuidString,
                email: session.user.email ?? "",
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                profile: nil,
                expiresAt: expiresAt
            )

            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.authState = .authenticated(userId: user.id)
                self.saveUserToDefaults(user)
                self.isLoading = false
            }

            print("🔄 認証状態を更新: authState = authenticated (Google)")

            // Create or update profile in public.users
            await createOrUpdateUserProfile(userId: user.id, email: user.email, avatarUrl: googleAvatarUrl)

            // Start token refresh timer
            startTokenRefreshTimer()

            // Initialize authenticated user flow
            await initializeAuthenticatedUser(authUserId: user.id)

        } catch {
            await MainActor.run {
                self.isLoading = false
                self.authError = "認証の完了に失敗しました: \(error.localizedDescription)"
                print("❌ OAuth callback処理エラー: \(error)")
            }
        }
    }

    // Create or update user profile (for OAuth users)
    private func createOrUpdateUserProfile(userId: String, email: String, avatarUrl: String? = nil) async {
        do {
            // Check if profile exists
            let existingProfiles: [UserProfile] = try await supabase
                .from("users")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            if existingProfiles.isEmpty {
                // Create new profile
                struct NewUserProfile: Encodable {
                    let user_id: String
                    let name: String
                    let email: String
                    let created_at: String
                    let auth_provider: String
                    let avatar_url: String?
                }

                let displayName = email.components(separatedBy: "@").first ?? "ユーザー"
                let profileData = NewUserProfile(
                    user_id: userId,
                    name: displayName,
                    email: email,
                    created_at: ISO8601DateFormatter().string(from: Date()),
                    auth_provider: "google",
                    avatar_url: avatarUrl
                )

                try await supabase
                    .from("users")
                    .insert(profileData)
                    .execute()

                print("✅ Googleユーザープロファイル作成成功 (auth_provider: google, avatar_url: \(avatarUrl ?? "none"))")
            } else {
                // Update existing profile (for anonymous upgrade)
                let existingProfile = existingProfiles.first!

                // Check if this is an anonymous user being upgraded
                if existingProfile.email == "anonymous" {
                    struct UpdateUserProfile: Encodable {
                        let email: String
                        let auth_provider: String
                        let avatar_url: String?
                    }

                    let updateData = UpdateUserProfile(
                        email: email,
                        auth_provider: "google",
                        avatar_url: avatarUrl
                    )

                    try await supabase
                        .from("users")
                        .update(updateData)
                        .eq("user_id", value: userId)
                        .execute()

                    print("✅ 匿名ユーザーをGoogleアカウントにアップグレード: \(email), avatar_url: \(avatarUrl ?? "none")")
                } else {
                    // Update avatar_url for existing Google users
                    if let avatarUrl = avatarUrl {
                        struct UpdateAvatar: Encodable {
                            let avatar_url: String
                        }

                        let updateData = UpdateAvatar(avatar_url: avatarUrl)

                        try await supabase
                            .from("users")
                            .update(updateData)
                            .eq("user_id", value: userId)
                            .execute()

                        print("✅ 既存プロファイルのアバター更新: \(avatarUrl)")
                    } else {
                        print("✅ 既存プロファイルを使用")
                    }
                }
            }

            // Fetch profile
            await fetchUserProfile(userId: userId)

        } catch {
            print("❌ プロファイル作成/更新エラー: \(error)")
            // Continue even if profile creation fails
        }
    }

    // MARK: - サインアップ機能
    func signUp(email: String, password: String, displayName: String = "", newsletter: Bool = false) async {
        await MainActor.run {
            isLoading = true
            authError = nil
        }

        print("📝 サインアップ試行: \(email)")

        do {
            // Step 1: auth.usersテーブルにユーザー作成
            let authResponse = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: [
                    "display_name": .string(displayName),
                    "newsletter_subscription": .bool(newsletter)
                ]
            )

            print("✅ auth.users作成成功 - User ID: \(authResponse.user.id)")
            print("📧 メール確認状態: \(authResponse.user.confirmedAt != nil ? "確認済み" : "未確認")")

            // Step 2: public.usersテーブルにプロファイル作成
            do {
                // 認証完了を待つ
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒待機

                struct UserProfile: Encodable {
                    let user_id: String
                    let name: String
                    let email: String
                    let newsletter_subscription: Bool
                    let created_at: String
                    let auth_provider: String
                }

                let profileData = UserProfile(
                    user_id: authResponse.user.id.uuidString,
                    name: displayName,
                    email: email,
                    newsletter_subscription: newsletter,
                    created_at: ISO8601DateFormatter().string(from: Date()),
                    auth_provider: "email"
                )

                try await supabase
                    .from("users")
                    .insert(profileData)
                    .execute()

                print("✅ public.usersプロファイル作成成功 (auth_provider: email)")

            } catch {
                print("❌ プロファイル作成エラー: \(error)")
                await MainActor.run {
                    self.authError = "認証は成功しましたが、プロファイル情報の保存に失敗しました。"
                }
            }

            // サインアップ成功後の処理
            // メール確認状態に関係なく、常に自動ログインを実行
            print("📧 サインアップ成功 - 自動ログイン実行（メール確認状態: \(authResponse.user.confirmedAt != nil ? "確認済み" : "未確認")）")
            await self.performSignIn(email: email, password: password)

        } catch {
            await MainActor.run {
                self.isLoading = false

                // エラーハンドリング
                if let postgrestError = error as? PostgrestError {
                    if postgrestError.message.contains("User already registered") ||
                       postgrestError.message.contains("already exists") {
                        self.authError = "このメールアドレスは既に登録されています。ログインページからサインインしてください。"
                    } else {
                        self.authError = "サインアップに失敗しました: \(postgrestError.message)"
                    }
                } else {
                    self.authError = "サインアップに失敗しました: \(error.localizedDescription)"
                }

                print("❌ サインアップエラー: \(error)")
            }
        }
    }
    
    // MARK: - ユーザー情報取得（確認状態チェック用）
    func fetchUserInfo() {
        isLoading = true
        
        Task { @MainActor in
            do {
                // Supabase SDKの標準メソッドを使用して現在のユーザー情報を取得
                let user = try await supabase.auth.session.user
                
                print("📡 ユーザー情報取得成功")
                print("📧 メール: \(user.email ?? "なし")")
                print("📧 メール確認状態: \(user.confirmedAt != nil ? "確認済み" : "未確認")")
                
                if user.confirmedAt == nil {
                    self.authError = "メール確認が完了していません"
                }
                
                self.isLoading = false
                
            } catch {
                print("❌ ユーザー情報取得エラー: \(error)")
                self.isLoading = false
                
                // セッションエラーの場合は再ログインを促す
                if case AuthError.sessionMissing = error {
                    self.authError = "セッションの有効期限が切れました。再度ログインしてください。"
                    await self.clearLocalAuthData()
                }
            }
        }
    }
    
    // MARK: - ログアウト機能
    func signOut() async {
        print("🚪 ログアウト開始")
        let wasAuthenticated = authState.isAuthenticated

        // ✅ レイヤー1: OSレベルでプッシュ通知の登録を解除
        #if os(iOS)
        await MainActor.run {
            UIApplication.shared.unregisterForRemoteNotifications()
            print("✅ [PUSH] APNs通知の登録を解除しました")
        }
        #endif

        // ✅ レイヤー2: DBからAPNsトークンを削除（ID解決可能な場合のみ）
        if let userId = effectiveUserId {
            await removeAPNsToken(userId: userId)
        }

        // トークンリフレッシュタイマーを停止
        refreshTimer?.invalidate()
        refreshTimer = nil

        // Supabase SDKセッションを常に破棄（未認証表示中でも再利用を防ぐ）
        do {
            try await supabase.auth.signOut()
            print("✅ Supabaseセッション破棄成功")
        } catch {
            print("⚠️ Supabaseセッション破棄エラー: \(error)")
        }
        clearSupabaseSessionFromKeychain()

        // ローカル状態をクリア
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
            self.authState = .unauthenticated
            self.authError = nil
            self.deviceManager.clearState()

            // 未認証モードからのログアウト操作時は、初期画面へ戻す
            if !wasAuthenticated {
                self.shouldResetToWelcome = true
            }
        }

        // 保存された認証情報を削除
        UserDefaults.standard.removeObject(forKey: "supabase_user")
        UserDefaults.standard.removeObject(forKey: "current_user_id")
        UserDefaults.standard.removeObject(forKey: "guest_id")
        UserDefaults.standard.removeObject(forKey: "pending_apns_token")
        print("💾 UserDefaultsクリア完了（supabase_user, current_user_id, guest_id, pending_apns_token）")
        print("👋 ログアウト完了: authState = unauthenticated")
    }

    // ゲストユーザー用：初期画面に戻る処理
    // 注意：ユーザーには「ログアウト」と表示されるが、内部的にはリセット処理
    @Published var shouldResetToWelcome: Bool = false

    func resetToWelcomeScreen() {
        // ✅ @Published プロパティの更新は @MainActor で実行
        Task { @MainActor in
            // MainAppViewでこのフラグを監視して、onboardingCompleted = falseにリセット
            self.shouldResetToWelcome = true
            print("✅ 初期画面へのリセットフラグを設定")
        }
    }
    
    // クライアント側認証データクリア（セッション期限切れ時に使用）
    private func clearLocalAuthData() async {
        print("🧹 ローカル認証データクリア開始")

        // ✅ @Published プロパティの更新は @MainActor で実行
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
            self.authState = .unauthenticated
            self.authError = nil

            print("👋 ローカル認証データクリア完了: authState = unauthenticated")

            // DeviceManagerの状態もクリア
            self.deviceManager.clearState()
            // ゲストモード用に空のデバイスリストで利用可能状態にする
            self.deviceManager.state = .available([])

            // トークンリフレッシュタイマーを停止
            self.refreshTimer?.invalidate()
            self.refreshTimer = nil
        }

        // 保存された認証情報を削除
        UserDefaults.standard.removeObject(forKey: "supabase_user")
        UserDefaults.standard.removeObject(forKey: "current_user_id")
        UserDefaults.standard.removeObject(forKey: "guest_id")
        UserDefaults.standard.removeObject(forKey: "pending_apns_token")
        clearSupabaseSessionFromKeychain()
    }

    /// Supabase Swift SDKが既定で利用するKeychainセッションを削除する
    /// service: "supabase.gotrue.swift"
    /// keys: "supabase.auth.token" (現行), "supabase.session" (旧互換)
    private func clearSupabaseSessionFromKeychain() {
        #if canImport(Security)
        let keys = ["supabase.auth.token", "supabase.session"]
        for key in keys {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "supabase.gotrue.swift",
                kSecAttrAccount as String: key
            ]
            let status = SecItemDelete(query as CFDictionary)
            if status == errSecSuccess || status == errSecItemNotFound {
                print("🔐 Keychainセッション削除: \(key)")
            } else {
                print("⚠️ Keychainセッション削除失敗(\(key)): \(status)")
            }
        }
        #endif
    }
    
    // MARK: - 認証成功後の統一初期化フロー
    /// 認証成功後にプロファイルとデバイスを取得する統一処理
    /// - Parameter authUserId: auth.usersテーブルのユーザーID
    private func initializeAuthenticatedUser(authUserId: String) async {
        print("🚀 認証成功後の初期化フロー開始: \(authUserId)")

        // 1. プロファイル取得
        await fetchUserProfile(userId: authUserId)

        // 匿名ユーザーでプロファイルが未作成の場合は再作成を試行
        if currentUser?.profile?.userId == nil,
           (currentUser?.email == "anonymous" || currentUser?.email.isEmpty == true) {
            print("⚠️ 匿名ユーザープロファイルが未取得のため、作成を再試行します")
            await createAnonymousUserProfile(userId: authUserId)
        }

        // 2. デバイス取得（public.usersのuser_id優先、未取得時はauth user_idにフォールバック）
        if let userId = effectiveUserId {
            if currentUser?.profile?.userId != nil {
                print("✅ プロファイル取得成功 - デバイス一覧を取得: \(userId)")
            } else {
                print("⚠️ プロファイル未取得のためauth user_idでフォールバック: \(userId)")
            }

            // ユーザーIDをUserDefaultsに保存（APNsトークン保存で使用）
            UserDefaults.standard.set(userId, forKey: "current_user_id")
            print("💾 current_user_id を保存: \(userId)")

            // 保留中のAPNsトークンがあれば保存
            if let pendingToken = UserDefaults.standard.string(forKey: "pending_apns_token") {
                print("🔔 [PUSH] ログイン後、保留中のAPNsトークンを保存します")
                await saveAPNsTokenToUsers(token: pendingToken, userId: userId)
            } else {
                // 保留トークンがない場合は新規にAPNs登録を要求
                print("🔔 [PUSH] APNs通知の登録を要求します")
                await requestAPNsRegistration()
            }

            // デバイス一覧を読み込み
            await deviceManager.loadDevices(for: userId)

            // デバイスが0件の場合は自動登録
            if !deviceManager.hasRealDevices {
                print("📱 デバイスが0件のため、自動登録を実行")
                do {
                    let _ = try await deviceManager.registerDevice(userId: userId)
                    // 再度デバイス一覧を読み込み
                    await deviceManager.loadDevices(for: userId)
                } catch {
                    print("❌ デバイス自動登録に失敗: \(error)")
                }
            } else {
                print("✅ 既存デバイスあり（\(deviceManager.devices.count)件）")
            }
        } else {
            print("⚠️ プロファイル取得に失敗 - デバイス初期化をスキップしてフォールバックに移行")

            // プロファイル未取得でもUIが無限ローディングにならないようにフォールバック
            await MainActor.run {
                self.deviceManager.clearState()
                self.deviceManager.state = .available([])
            }
            UserDefaults.standard.removeObject(forKey: "current_user_id")
        }

        print("🎯 認証成功後の初期化フロー完了")
    }

    // MARK: - ユーザープロファイル取得
    func fetchUserProfile(userId: String) async {
        print("👤 ユーザープロファイル取得開始: \(userId)")

        do {
            // Supabase SDKの標準メソッドを使用
            let profiles: [UserProfile] = try await supabase
                .from("users")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value

            if let profile = profiles.first {
                // currentUserにプロファイルを設定
                await MainActor.run {
                    if var updatedUser = self.currentUser {
                        updatedUser.profile = profile
                        self.currentUser = updatedUser
                        self.saveUserToDefaults(updatedUser)
                    }
                }

                print("✅ プロファイル取得成功")
                print("   - 名前: \(profile.name ?? "未設定")")
                print("   - ステータス: \(profile.status ?? "未設定")")
                print("   - ニュースレター: \(String(describing: profile.newsletter))")
                print("   - user_id: \(profile.userId)")
            } else {
                print("⚠️ プロファイルが見つかりません")
            }

        } catch {
            print("❌ プロファイル取得エラー: \(error)")
            // データベースエラーの詳細を表示
            if let dbError = error as? PostgrestError {
                print("   - コード: \(dbError.code ?? "不明")")
                print("   - メッセージ: \(dbError.message)")
            }
        }
    }
    
    // MARK: - 確認メール再送機能
    func resendConfirmationEmail(email: String) {
        isLoading = true
        authError = nil
        
        print("📧 確認メール再送: \(email)")
        
        Task { @MainActor in
            do {
                // Supabase SDKの標準メソッドを使用
                try await supabase.auth.resend(
                    email: email,
                    type: .signup
                )
                
                self.authError = "確認メールを再送しました。メールボックスをご確認ください。"
                print("✅ 確認メール再送成功")
                
                self.isLoading = false
                
            } catch {
                self.isLoading = false
                self.authError = "確認メール再送に失敗しました: \(error.localizedDescription)"
                print("❌ 確認メール再送エラー: \(error)")
            }
        }
    }
    
    // MARK: - UserDefaults保存・読み込み
    private func saveUserToDefaults(_ user: SupabaseUser) {
        do {
            let data = try JSONEncoder().encode(user)
            UserDefaults.standard.set(data, forKey: "supabase_user")
            print("💾 ユーザー情報を保存")
        } catch {
            print("❌ ユーザー情報保存エラー: \(error)")
        }
    }
    
    private func loadUserFromDefaults() -> SupabaseUser? {
        guard let data = UserDefaults.standard.data(forKey: "supabase_user") else {
            return nil
        }
        
        do {
            let user = try JSONDecoder().decode(SupabaseUser.self, from: data)
            return user
        } catch {
            print("❌ ユーザー情報読み込みエラー: \(error)")
            return nil
        }
    }
    
    // MARK: - ユーザープロファイル更新
    func updateUserProfile(newsletterSubscription: Bool? = nil) {
        guard let currentUser = currentUser else {
            print("❌ ログインしていません")
            return
        }
        
        print("📝 ユーザープロファイル更新開始: \(currentUser.id)")
        
        Task { @MainActor in
            do {
                struct ProfileUpdate: Codable {
                    let newsletter_subscription: Bool?
                    let updated_at: String
                }
                
                let now = ISO8601DateFormatter().string(from: Date())
                let profileUpdate = ProfileUpdate(
                    newsletter_subscription: newsletterSubscription,
                    updated_at: now
                )
                
                // Supabase SDKの標準メソッドを使用
                try await supabase
                    .from("users")
                    .update(profileUpdate)
                    .eq("user_id", value: currentUser.id)
                    .execute()
                
                print("✅ プロファイル更新成功")

                // 更新後のプロファイルを再取得（auth.users.idを使用）
                await self.fetchUserProfile(userId: currentUser.id)
                
            } catch {
                print("❌ プロファイル更新エラー: \(error)")
                self.authError = "プロファイルの更新に失敗しました: \(error.localizedDescription)"
                
                // PostgrestErrorの詳細を表示
                if let dbError = error as? PostgrestError {
                    print("   - コード: \(dbError.code ?? "不明")")
                    print("   - メッセージ: \(dbError.message)")
                }
            }
        }
    }
    
    // MARK: - トークンリフレッシュ機能
    
    // トークンリフレッシュタイマーの開始
    private func startTokenRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: tokenRefreshInterval, repeats: true) { _ in
            Task { @MainActor in
                print("⏰ 定期トークンリフレッシュを実行")
                await self.refreshTokenIfNeeded()
            }
        }
    }
    
    // トークンの有効性を確保
    func ensureValidToken() async {
        guard isAuthenticated else { return }
        
        // トークンが有効期限に近づいているかチェック
        // Supabase SDKの機能を活用してセッションを確認
        do {
            _ = try await supabase.auth.session
            print("✅ 現在のトークンは有効です")
        } catch {
            print("⚠️ トークンの有効性チェック失敗: \(error)")
            await refreshTokenIfNeeded()
        }
    }
    
    // 必要に応じてトークンをリフレッシュ
    private func refreshTokenIfNeeded() async {
        guard let refreshToken = currentUser?.refreshToken else {
            print("❌ リフレッシュトークンがありません")
            return
        }
        
        _ = await refreshTokenWithRetry(refreshToken: refreshToken)
    }
    
    // リトライ機能付きトークンリフレッシュ
    @discardableResult
    private func refreshTokenWithRetry(refreshToken: String, maxRetries: Int = 1) async -> Bool {  // 📊 Phase 2-A: デフォルト2回→1回
        for attempt in 1...maxRetries {
            print("🔄 [Phase 2-A] トークンリフレッシュ試行 \(attempt)/\(maxRetries)")

            do {
                // Supabase SDKのリフレッシュ機能を使用
                let session = try await supabase.auth.refreshSession()

                // 新しいトークンで情報を更新
                if let email = session.user.email {
                    // 📊 Phase 2-A: 有効期限を計算して保存（デフォルト1時間）
                    let expiresAt = Date().addingTimeInterval(3600)  // 現在時刻 + 1時間

                    let updatedUser = SupabaseUser(
                        id: session.user.id.uuidString,
                        email: email,
                        accessToken: session.accessToken,
                        refreshToken: session.refreshToken,
                        profile: currentUser?.profile,
                        expiresAt: expiresAt  // 📊 Phase 2-A: 有効期限を設定
                    )

                    // ✅ @Published プロパティの更新は @MainActor で実行
                    await MainActor.run {
                        self.currentUser = updatedUser
                        self.isAuthenticated = true
                        self.authState = .authenticated(userId: session.user.id.uuidString)
                        self.saveUserToDefaults(updatedUser)
                    }

                    print("✅ [Phase 2-A] トークンリフレッシュ成功（有効期限: \(expiresAt)）")
                    print("📅 新しいアクセストークンを取得")

                    return true
                }
            } catch {
                print("❌ トークンリフレッシュエラー (試行 \(attempt)): \(error)")

                // 📊 Phase 2-A: 待機時間を短縮（1秒→0.5秒に）
                if attempt < maxRetries {
                    let delay = 0.5  // 0.5秒（従来: 1秒、2秒）
                    print("⏳ [Phase 2-A] \(delay)秒後に再試行...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        print("❌ トークンリフレッシュが\(maxRetries)回失敗しました")
        return false
    }
    
    // 401エラー時の自動リカバリー
    func handleAuthenticationError() async -> Bool {
        print("🚨 認証エラーを検出 - 自動リカバリーを開始")
        
        guard let refreshToken = currentUser?.refreshToken else {
            print("❌ リフレッシュトークンがないため再ログインが必要です")
            await clearLocalAuthData()
            return false
        }
        
        // トークンリフレッシュを試行
        let success = await refreshTokenWithRetry(refreshToken: refreshToken)
        
        if !success {
            print("❌ 自動リカバリー失敗 - 再ログインが必要です")
            await clearLocalAuthData()
            authError = "セッションの有効期限が切れました。再度ログインしてください。"
        } else {
            print("✅ 自動リカバリー成功 - 処理を継続できます")
        }
        
        return success
    }

    // MARK: - APNs通知関連

    /// APNs通知の登録を要求（ログイン後に実行）
    private func requestAPNsRegistration() async {
        #if os(iOS)
        await MainActor.run {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if granted {
                    print("✅ [PUSH] 通知権限が許可されました")
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                } else {
                    print("⚠️ [PUSH] 通知権限が拒否されました: \(error?.localizedDescription ?? "不明")")
                }
            }
        }
        #endif
    }

    /// APNsトークンをusersテーブルに保存
    private func saveAPNsTokenToUsers(token: String, userId: String) async {
        do {
            let supabase = SupabaseClientManager.shared.client

            print("🔍 [PUSH-DEBUG] APNsトークン保存開始")
            print("🔍 [PUSH-DEBUG] userId = '\(userId)'")
            print("🔍 [PUSH-DEBUG] token = '\(token.prefix(20))...'")

            // ✅ Step 1: 他のユーザーから同じAPNsトークンを削除（1台のiPhoneで複数アカウント対策）
            struct APNsTokenUpdate: Encodable {
                let apns_token: String?
            }

            let cleanupResponse = try await supabase
                .from("users")
                .update(APNsTokenUpdate(apns_token: nil))
                .neq("user_id", value: userId)  // 自分以外
                .eq("apns_token", value: token)  // 同じトークン
                .execute()

            print("✅ [PUSH] 他のユーザーから同じAPNsトークンを削除: \(cleanupResponse.count ?? 0)件")

            // ✅ Step 2: 自分のユーザーにAPNsトークンを保存
            try await supabase
                .from("users")
                .update(["apns_token": token])
                .eq("user_id", value: userId)
                .execute()

            print("✅ [PUSH] APNsトークン保存成功: userId=\(userId)")

            // 🔍 デバッグ: 保存後のデータを確認
            struct UserAPNsCheck: Decodable {
                let user_id: String
                let apns_token: String?
            }

            let verifyResponse: [UserAPNsCheck] = try await supabase
                .from("users")
                .select("user_id, apns_token")
                .eq("user_id", value: userId)
                .execute()
                .value

            if let user = verifyResponse.first {
                print("🔍 [PUSH-DEBUG] 保存後の確認: apns_token = \(user.apns_token?.prefix(20) ?? "NULL")...")
            } else {
                print("⚠️ [PUSH-DEBUG] 保存後の確認: ユーザーが見つかりません")
            }

            // 一時保存を削除
            await MainActor.run {
                UserDefaults.standard.removeObject(forKey: "pending_apns_token")
            }
        } catch {
            print("❌ [PUSH] APNsトークン保存失敗: \(error)")
        }
    }

    /// APNsトークンをusersテーブルから削除（ログアウト時）
    private func removeAPNsToken(userId: String) async {
        do {
            let supabase = SupabaseClientManager.shared.client

            print("🔍 [PUSH-DEBUG] APNsトークン削除開始")
            print("🔍 [PUSH-DEBUG] userId = '\(userId)'")
            print("🔍 [PUSH-DEBUG] userId length = \(userId.count)")

            struct APNsTokenRemove: Encodable {
                let apns_token: String?
            }

            // UPDATE文を実行
            try await supabase
                .from("users")
                .update(APNsTokenRemove(apns_token: nil))
                .eq("user_id", value: userId)
                .execute()

            print("✅ [PUSH] APNsトークン削除実行完了: userId=\(userId)")

            // 🔍 デバッグ: 削除後のデータを確認
            struct UserAPNsCheck: Decodable {
                let user_id: String
                let apns_token: String?
            }

            let verifyResponse: [UserAPNsCheck] = try await supabase
                .from("users")
                .select("user_id, apns_token")
                .eq("user_id", value: userId)
                .execute()
                .value

            if let user = verifyResponse.first {
                if user.apns_token == nil {
                    print("✅ [PUSH-DEBUG] 削除確認: apns_token = NULL")
                } else {
                    print("⚠️ [PUSH-DEBUG] 削除失敗: apns_token = \(user.apns_token?.prefix(20) ?? "")... (削除されていない)")
                }
            } else {
                print("⚠️ [PUSH-DEBUG] 削除確認: ユーザーが見つかりません (user_id=\(userId))")
            }
        } catch {
            print("❌ [PUSH] APNsトークン削除失敗: \(error)")
            if let postgrestError = error as? PostgrestError {
                print("❌ [PUSH-DEBUG] PostgrestError message: \(postgrestError.message)")
            }
        }
    }
}

// MARK: - データモデル

struct SupabaseUser: Codable {
    let id: String
    let email: String
    let accessToken: String
    let refreshToken: String?
    var profile: UserProfile?
    var expiresAt: Date?  // 📊 Phase 2-A: トークン有効期限（ローカルチェック用）
}

struct UserProfile: Codable {
    let userId: String
    let name: String?
    let email: String?
    let avatarUrl: String?
    let status: String?
    let subscriptionPlan: String?
    let createdAt: String?
    let updatedAt: String?
    let newsletter: Bool?
    let authProvider: String?  // Authentication provider (anonymous, email, google, apple, etc.)

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case email
        case avatarUrl = "avatar_url"
        case status
        case subscriptionPlan = "subscription_plan"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case newsletter = "newsletter_subscription"
        case authProvider = "auth_provider"
    }
}

struct SupabaseAuthResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let user: SupabaseAuthUser
}

struct SupabaseAuthUser: Codable {
    let id: String
    let email: String
}

struct SupabaseErrorResponse: Codable {
    let error: String?
    let error_description: String?
}

// MARK: - ASWebAuthenticationSession Support
#if os(iOS)
// Helper class for ASWebAuthenticationSession presentation context
class WebAuthenticationPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

extension UserAccountManager {
    enum AnonymousUpgradeResult: Equatable {
        case upgraded
        case cancelled
        case notAnonymousUser
        case switchedToExistingGoogleAccount
        case oauthFailed(String)
        case unknownFailure
    }

    // Direct implementation using ASWebAuthenticationSession (Alternative to Supabase SDK)
    // This ensures that the OAuth callback URL is properly received by the app
    func signInWithGoogleDirect() async {
        await MainActor.run {
            isLoading = true
            authError = nil
        }

        print("🔐 Google認証開始 (ASWebAuthenticationSession direct implementation)")

        // Build OAuth URL with scopes for profile and email
        // Request additional scopes to get user profile information including avatar
        let scopes = "openid email profile"
        let encodedScopes = scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scopes
        let authURL = URL(string: "\(supabaseURL)/auth/v1/authorize?provider=google&redirect_to=watchme://auth/callback&scopes=\(encodedScopes)")!
        print("🔗 OAuth URL: \(authURL)")

        await MainActor.run {
            let contextProvider = WebAuthenticationPresentationContextProvider()

            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "watchme"
            ) { callbackURL, error in
                Task {
                    if let error = error {
                        await MainActor.run {
                            self.isLoading = false
                            // User cancelled or error occurred
                            if (error as NSError).code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                                self.authError = "Google認証に失敗しました: \(error.localizedDescription)"
                                print("❌ Google認証エラー: \(error)")
                            } else {
                                print("ℹ️ ユーザーがGoogle認証をキャンセルしました")
                            }
                        }
                        return
                    }

                    if let callbackURL = callbackURL {
                        print("✅ OAuth callback received: \(callbackURL)")
                        await self.handleOAuthCallback(url: callbackURL)
                    }
                }
            }

            session.presentationContextProvider = contextProvider
            session.prefersEphemeralWebBrowserSession = false  // Allow persistent login
            session.start()

            print("✅ ASWebAuthenticationSession started")
        }
    }

    // MARK: - Anonymous User Upgrade

    /// Upgrade anonymous user to Google account
    /// Returns explicit result for all expected routes
    func upgradeAnonymousToGoogle() async -> AnonymousUpgradeResult {
        // Check if current user is anonymous
        guard isAnonymousUser else {
            await MainActor.run {
                authError = "現在のユーザーは匿名ユーザーではありません"
            }
            return .notAnonymousUser
        }

        await MainActor.run {
            isLoading = true
            authError = nil
        }

        let originalAnonymousUser = currentUser
        let originalAnonymousUserId = originalAnonymousUser?.id

        print("🔐 匿名ユーザーアップグレード開始 (Google)")

        // Build OAuth URL for linking with scopes for profile and email
        let scopes = "openid email profile"
        let encodedScopes = scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scopes
        let authURL = URL(string: "\(supabaseURL)/auth/v1/authorize?provider=google&redirect_to=watchme://auth/callback&scopes=\(encodedScopes)")!
        print("🔗 OAuth URL: \(authURL)")

        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                let contextProvider = WebAuthenticationPresentationContextProvider()

                let session = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: "watchme"
                ) { callbackURL, error in
                    Task {
                        if let error = error {
                            let isCancelled = (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue
                            await MainActor.run {
                                self.isLoading = false
                                // User cancelled or error occurred
                                if !isCancelled {
                                    self.authError = "Google連携に失敗しました: \(error.localizedDescription)"
                                    print("❌ Google連携エラー: \(error)")
                                } else {
                                    print("ℹ️ ユーザーがGoogle連携をキャンセルしました")
                                }
                            }
                            if isCancelled {
                                continuation.resume(returning: .cancelled)
                            } else {
                                continuation.resume(returning: .oauthFailed(error.localizedDescription))
                            }
                            return
                        }

                        if let callbackURL = callbackURL {
                            print("✅ OAuth callback received: \(callbackURL)")
                            await self.handleOAuthCallback(url: callbackURL)

                            // Guard: if auth user id changed, this is not an in-place upgrade.
                            // It means user signed in to another existing Google account.
                            let switchedToAnotherAccount = await MainActor.run { () -> Bool in
                                guard let originalId = originalAnonymousUserId,
                                      let currentId = self.currentUser?.id else {
                                    return false
                                }
                                return originalId != currentId
                            }

                            if switchedToAnotherAccount {
                                print("⚠️ アップグレード中に別アカウントへ切り替わりました。アップグレードを失敗扱いにします。")

                                _ = await self.restoreAnonymousSessionAfterUpgradeFailure(originalAnonymousUser)

                                await MainActor.run {
                                    self.isLoading = false
                                    // この結果は upgradeAnonymousToGoogle() の戻り値で呼び出し元UIが通知する
                                    // (グローバルauthErrorを使うと通知が二重表示される)
                                }
                                continuation.resume(returning: .switchedToExistingGoogleAccount)
                                return
                            }

                            // Check if upgrade was successful
                            let success = await MainActor.run {
                                self.isAuthenticated && !self.isAnonymousUser
                            }
                            await MainActor.run {
                                self.isLoading = false
                            }
                            continuation.resume(returning: success ? .upgraded : .unknownFailure)
                        } else {
                            await MainActor.run {
                                self.isLoading = false
                            }
                            continuation.resume(returning: .unknownFailure)
                        }
                    }
                }

                session.presentationContextProvider = contextProvider
                session.prefersEphemeralWebBrowserSession = false
                session.start()

                print("✅ ASWebAuthenticationSession started for upgrade")
            }
        }
    }

    // Restore original anonymous session when upgrade flow switched to another account.
    private func restoreAnonymousSessionAfterUpgradeFailure(_ originalUser: SupabaseUser?) async -> Bool {
        guard let originalUser else {
            print("⚠️ 元の匿名ユーザー情報がないためセッション復元をスキップ")
            return false
        }

        guard let refreshToken = originalUser.refreshToken else {
            print("⚠️ 元の匿名ユーザーのrefresh tokenがないためセッション復元に失敗")
            return false
        }

        do {
            _ = try await supabase.auth.setSession(
                accessToken: originalUser.accessToken,
                refreshToken: refreshToken
            )

            await MainActor.run {
                self.currentUser = originalUser
                self.isAuthenticated = true
                self.authState = .authenticated(userId: originalUser.id)
                self.saveUserToDefaults(originalUser)
            }

            await fetchUserProfile(userId: originalUser.id)
            await initializeAuthenticatedUser(authUserId: originalUser.id)
            print("✅ 匿名セッションの復元に成功")
            return true
        } catch {
            print("❌ 匿名セッション復元失敗: \(error)")
            return false
        }
    }
}
#endif
