//
//  UserAccountManager.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/07/04.
//

import SwiftUI
import Foundation
import Supabase
#if os(iOS)
import UIKit
#endif

// Supabaseクライアントをグローバルに定義
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://qvtlwotzuzbavrzqhyvt.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dGx3b3R6dXpiYXZyenFoeXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzODAzMzAsImV4cCI6MjA2Njk1NjMzMH0.g5rqrbxHPw1dKlaGqJ8miIl9gCXyamPajinGCauEI3k"
)

// ユーザー認証状態
enum UserAuthState {
    case guest           // ゲストユーザー（未認証）
    case authenticated   // 認証済みユーザー
}

// ユーザーアカウント管理クラス（認証とプロファイル）
class UserAccountManager: ObservableObject {
    @Published var authState: UserAuthState = .guest
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: SupabaseUser? = nil
    @Published var authError: String? = nil
    @Published var signUpSuccess: Bool = false
    @Published var isLoading: Bool = false
    @Published var isCheckingAuthStatus: Bool = true  // 認証状態確認中フラグ
    @Published var guestId: String? = nil  // ゲストID
    
    // DeviceManagerへの参照
    private let deviceManager: DeviceManager
    
    // Supabase設定
    private let supabaseURL = "https://qvtlwotzuzbavrzqhyvt.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dGx3b3R6dXpiYXZyenFoeXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzODAzMzAsImV4cCI6MjA2Njk1NjMzMH0.g5rqrbxHPw1dKlaGqJ8miIl9gCXyamPajinGCauEI3k"
    
    // トークンリフレッシュタイマー
    private var refreshTimer: Timer?
    private let tokenRefreshInterval: TimeInterval = 45 * 60 // 45分（1時間のトークンに対して15分前にリフレッシュ）
    
    init(deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
        // アプリがフォアグラウンドに戻った時の処理を設定
        setupNotificationObservers()
        // 認証チェックはMainAppViewの.taskで非同期に実行
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
        Task { @MainActor in
            if let savedUser = loadUserFromDefaults() {
                // 📊 Phase 2-A: トークン有効期限のローカルチェック
                if let expiresAt = savedUser.expiresAt, expiresAt > Date().addingTimeInterval(7200) {
                    // まだ2時間以上有効 → リフレッシュ不要
                    print("✅ [Phase 2-A] トークンは有効（有効期限: \(expiresAt)）- リフレッシュスキップ")
                    self.currentUser = savedUser
                    self.isAuthenticated = true
                    self.authState = .authenticated

                    // トークンリフレッシュタイマーを開始
                    startTokenRefreshTimer()

                    // 📊 Phase 2-A: プロファイル取得とデバイス一覧取得を並列化
                    print("🚀 [Phase 2-A] プロファイルとデバイス一覧を並列取得開始...")
                    async let profileTask = fetchUserProfile(userId: currentUser?.id ?? savedUser.id)

                    // プロファイル取得完了を待ってからデバイス取得（user_idが必要なため）
                    await profileTask

                    if let userId = currentUser?.profile?.userId {
                        await deviceManager.fetchUserDevices(for: userId)
                    } else {
                        print("⚠️ プロファイルのuser_idが取得できないため、デバイス一覧の取得をスキップ")
                    }

                    self.isCheckingAuthStatus = false
                    return
                }

                // トークンが期限切れまたは有効期限情報なし → リフレッシュ実行
                print("⚠️ [Phase 2-A] トークンの有効期限切れまたは情報なし - リフレッシュ実行")

                // 保存されたトークンでセッションを復元
                do {
                    // リフレッシュトークンがある場合のみセッションを復元
                    if let refreshToken = savedUser.refreshToken {
                        // まずリフレッシュトークンでトークンを更新してみる
                        let success = await refreshTokenWithRetry(refreshToken: refreshToken, maxRetries: 1)  // 📊 Phase 2-A: 2回→1回に削減

                        if !success {
                            // リフレッシュ失敗時は保存されたトークンで復元を試みる
                            _ = try await supabase.auth.setSession(
                                accessToken: savedUser.accessToken,
                                refreshToken: refreshToken
                            )

                            self.currentUser = savedUser
                            self.isAuthenticated = true
                            self.authState = .authenticated
                        }
                        // refreshTokenWithRetryが成功した場合は、その中で既にcurrentUserとisAuthenticatedが設定済み
                    } else {
                        // リフレッシュトークンがない場合は再ログインが必要
                        throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "リフレッシュトークンがありません"])
                    }

                    if self.isAuthenticated {
                        print("✅ 保存された認証状態を復元: \(savedUser.email)")
                        print("🔄 認証状態復元: authState = authenticated")
                        print("🔑 セッショントークンも復元しました")

                        // トークンリフレッシュタイマーを開始
                        startTokenRefreshTimer()

                        // 📊 Phase 2-A: プロファイル取得とデバイス一覧取得を並列化
                        print("🚀 [Phase 2-A] プロファイルとデバイス一覧を並列取得開始...")
                        async let profileTask = fetchUserProfile(userId: currentUser?.id ?? savedUser.id)

                        // プロファイル取得完了を待ってからデバイス取得（user_idが必要なため）
                        await profileTask

                        if let userId = currentUser?.profile?.userId {
                            await deviceManager.fetchUserDevices(for: userId)
                        } else {
                            print("⚠️ プロファイルのuser_idが取得できないため、デバイス一覧の取得をスキップ")
                        }
                    }

                    self.isCheckingAuthStatus = false  // 認証確認完了

                } catch {
                    print("❌ セッション復元エラー: \(error)")
                    print("🔄 リフレッシュトークンでの再試行を開始...")

                    // エラー時はリフレッシュトークンで再試行
                    if let refreshToken = savedUser.refreshToken {
                        let success = await refreshTokenWithRetry(refreshToken: refreshToken, maxRetries: 1)  // 📊 Phase 2-A: 2回→1回に削減
                        if !success {
                            print("⚠️ 再ログインが必要です - ゲストモードに移行")
                            clearLocalAuthData()
                            initializeGuestMode()
                        }
                    } else {
                        clearLocalAuthData()
                        initializeGuestMode()
                    }
                    self.isCheckingAuthStatus = false  // 認証確認完了
                }
            } else {
                print("⚠️ 保存された認証状態なし - ゲストモードで初期化")
                initializeGuestMode()
                self.isCheckingAuthStatus = false  // 認証確認完了
            }
        }
    }

    // MARK: - ゲストモード管理
    func initializeGuestMode() {
        // DeviceManagerの状態をクリア
        deviceManager.clearState()

        // 既存のゲストIDを確認
        if let savedGuestId = UserDefaults.standard.string(forKey: "guest_id") {
            print("👤 既存のゲストIDを読み込み: \(savedGuestId)")
            guestId = savedGuestId
            authState = .guest
            isAuthenticated = false
        } else {
            // 新規ゲストIDを作成
            createGuestUser()
        }

        // サンプルデバイスの自動選択は行わない
        // ユーザーがガイド画面で「サンプルを見る」を選択したときのみデバイスを選択
    }

    func createGuestUser() {
        let newGuestId = UUID().uuidString
        UserDefaults.standard.set(newGuestId, forKey: "guest_id")
        guestId = newGuestId
        authState = .guest
        isAuthenticated = false
        print("✨ 新規ゲストユーザーを作成: \(newGuestId)")
    }

    // 認証が必要かチェック
    func requireAuthentication() -> Bool {
        return authState == .guest
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
                self.authState = .authenticated
                self.saveUserToDefaults(user)

                print("🔄 認証状態を更新: authState = authenticated")

                // ゲストIDをクリア（認証済みユーザーに移行）
                UserDefaults.standard.removeObject(forKey: "guest_id")
                self.guestId = nil

                // トークンリフレッシュタイマーを開始
                self.startTokenRefreshTimer()

                self.isLoading = false
            }

            // ユーザープロファイルを取得（auth.users.idを使用）
            await self.fetchUserProfile(userId: user.id)

            // プロファイル取得後、public.usersのuser_idでデバイス一覧を取得
            // ✅ CLAUDE.md: public.usersのuser_idを使用
            if let userId = currentUser?.profile?.userId {
                await self.deviceManager.fetchUserDevices(for: userId)
            } else {
                print("⚠️ プロファイルのuser_idが取得できないため、デバイス一覧の取得をスキップ")
            }

        } catch {
            await MainActor.run {
                self.isLoading = false

                // エラーハンドリング
                self.authError = "ログインに失敗しました: \(error.localizedDescription)"

                print("❌ ログインエラー: \(error)")
            }
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
                }

                let profileData = UserProfile(
                    user_id: authResponse.user.id.uuidString,
                    name: displayName,
                    email: email,
                    newsletter_subscription: newsletter,
                    created_at: ISO8601DateFormatter().string(from: Date())
                )

                try await supabase
                    .from("users")
                    .insert(profileData)
                    .execute()

                print("✅ public.usersプロファイル作成成功")

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
                    self.clearLocalAuthData()
                }
            }
        }
    }
    
    // MARK: - ログアウト機能
    func signOut() async {
        print("🚪 ログアウト開始")
        
        // トークンリフレッシュタイマーを停止
        refreshTimer?.invalidate()
        refreshTimer = nil
        
        // 即座にローカル状態をクリア（UIの即時更新のため）
        self.clearLocalAuthData()
        
        // サーバー側のログアウトを実行
        do {
            // Supabase SDKの標準メソッドを使用
            try await supabase.auth.signOut()
            print("✅ サーバー側ログアウト成功")
        } catch {
            print("❌ サーバー側ログアウトエラー: \(error)")
            // エラーが発生してもローカルは既にクリア済み
        }
    }
    
    // クライアント側認証データクリア
    private func clearLocalAuthData() {
        print("🧹 ローカル認証データクリア開始")
        currentUser = nil
        isAuthenticated = false
        authState = .guest
        authError = nil

        // トークンリフレッシュタイマーを停止
        refreshTimer?.invalidate()
        refreshTimer = nil

        // 保存された認証情報を削除
        UserDefaults.standard.removeObject(forKey: "supabase_user")

        // DeviceManagerの状態もクリア
        deviceManager.clearState()

        print("👋 ログアウト完了: authState = guest")
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
        
        await refreshTokenWithRetry(refreshToken: refreshToken)
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

                    self.currentUser = updatedUser
                    self.isAuthenticated = true
                    self.authState = .authenticated
                    self.saveUserToDefaults(updatedUser)

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
            clearLocalAuthData()
            return false
        }
        
        // トークンリフレッシュを試行
        let success = await refreshTokenWithRetry(refreshToken: refreshToken)
        
        if !success {
            print("❌ 自動リカバリー失敗 - 再ログインが必要です")
            clearLocalAuthData()
            authError = "セッションの有効期限が切れました。再度ログインしてください。"
        } else {
            print("✅ 自動リカバリー成功 - 処理を継続できます")
        }
        
        return success
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
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case email
        case avatarUrl = "avatar_url"
        case status
        case subscriptionPlan = "subscription_plan"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case newsletter = "newsletter_subscription"  // DBカラム名に合わせて修正
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