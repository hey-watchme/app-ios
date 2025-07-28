//
//  SupabaseAuthManager.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/07/04.
//

import SwiftUI
import Foundation
import Supabase

// Supabaseクライアントをグローバルに定義
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://qvtlwotzuzbavrzqhyvt.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dGx3b3R6dXpiYXZyenFoeXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzODAzMzAsImV4cCI6MjA2Njk1NjMzMH0.g5rqrbxHPw1dKlaGqJ8miIl9gCXyamPajinGCauEI3k"
)

// Supabase認証管理クラス
class SupabaseAuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: SupabaseUser? = nil
    @Published var authError: String? = nil
    @Published var isLoading: Bool = false
    
    // DeviceManagerへの参照
    private let deviceManager: DeviceManager
    
    // Supabase設定
    private let supabaseURL = "https://qvtlwotzuzbavrzqhyvt.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dGx3b3R6dXpiYXZyenFoeXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzODAzMzAsImV4cCI6MjA2Njk1NjMzMH0.g5rqrbxHPw1dKlaGqJ8miIl9gCXyamPajinGCauEI3k"
    
    init(deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
        // 保存された認証状態を確認
        checkAuthStatus()
    }
    
    // MARK: - 認証状態確認
    private func checkAuthStatus() {
        if let savedUser = loadUserFromDefaults() {
            self.currentUser = savedUser
            self.isAuthenticated = true
            print("✅ 保存された認証状態を復元: \(savedUser.email)")
            print("🔄 認証状態復元: isAuthenticated = true")
            
            // プロファイルを取得
            fetchUserProfile(userId: savedUser.id)
            
            // デバイス情報を取得
            deviceManager.checkAndRegisterDevice(for: savedUser.id)
        } else {
            print("⚠️ 保存された認証状態なし: isAuthenticated = false")
        }
    }
    
    // MARK: - ログイン機能
    func signIn(email: String, password: String) {
        isLoading = true
        authError = nil
        
        print("🔐 ログイン試行: \(email)")
        
        let signInData = [
            "email": email,
            "password": password
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: signInData) else {
            authError = "リクエストデータの作成に失敗しました"
            isLoading = false
            return
        }
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=password") else {
            authError = "無効なURL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.authError = "ネットワークエラー: \(error.localizedDescription)"
                    print("❌ ログインエラー: \(error)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.authError = "無効なレスポンス"
                    return
                }
                
                print("📡 認証レスポンスステータス: \(httpResponse.statusCode)")
                
                if let data = data {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📡 認証レスポンス: \(responseString)")
                    }
                    
                    if httpResponse.statusCode == 200 {
                        // ログイン成功
                        if let authResponse = try? JSONDecoder().decode(SupabaseAuthResponse.self, from: data) {
                            let user = SupabaseUser(
                                id: authResponse.user.id,
                                email: authResponse.user.email,
                                accessToken: authResponse.access_token,
                                refreshToken: authResponse.refresh_token
                            )
                            
                            self?.currentUser = user
                            self?.isAuthenticated = true
                            self?.saveUserToDefaults(user)
                            
                            print("✅ ログイン成功: \(user.email)")
                            print("🔄 認証状態を更新: isAuthenticated = true")
                            
                            // ユーザープロファイルを取得
                            self?.fetchUserProfile(userId: user.id)
                            
                            // デバイス登録とユーザーデバイス取得を実行
                            self?.deviceManager.checkAndRegisterDevice(for: user.id)
                        } else {
                            self?.authError = "レスポンス解析エラー"
                        }
                    } else {
                        // ログイン失敗
                        if let errorResponse = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data) {
                            self?.authError = errorResponse.error_description ?? "ログインに失敗しました"
                        } else {
                            self?.authError = "ログインに失敗しました (ステータス: \(httpResponse.statusCode))"
                        }
                    }
                } else {
                    self?.authError = "レスポンスデータが空です"
                }
            }
        }.resume()
    }
    
    // MARK: - サインアップ機能
    func signUp(email: String, password: String) {
        isLoading = true
        authError = nil
        
        print("📝 サインアップ試行: \(email)")
        
        let signUpData = [
            "email": email,
            "password": password
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: signUpData) else {
            authError = "リクエストデータの作成に失敗しました"
            isLoading = false
            return
        }
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/signup") else {
            authError = "無効なURL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.authError = "ネットワークエラー: \(error.localizedDescription)"
                    print("❌ サインアップエラー: \(error)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.authError = "無効なレスポンス"
                    return
                }
                
                print("📡 サインアップレスポンスステータス: \(httpResponse.statusCode)")
                
                if let data = data {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📡 サインアップレスポンス: \(responseString)")
                    }
                    
                    if httpResponse.statusCode == 200 {
                        // サインアップ成功
                        self?.authError = nil
                        print("✅ サインアップ成功 - メール確認が必要な場合があります")
                        
                        // サインアップ後、自動的にログインを試行
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self?.signIn(email: email, password: password)
                        }
                    } else {
                        // サインアップ失敗
                        if let errorResponse = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data) {
                            self?.authError = errorResponse.error_description ?? "サインアップに失敗しました"
                        } else {
                            self?.authError = "サインアップに失敗しました (ステータス: \(httpResponse.statusCode))"
                        }
                    }
                } else {
                    self?.authError = "レスポンスデータが空です"
                }
            }
        }.resume()
    }
    
    // MARK: - ユーザー情報取得（確認状態チェック用）
    func fetchUserInfo() {
        guard let currentUser = currentUser else { return }
        
        isLoading = true
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/user") else {
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(currentUser.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("❌ ユーザー情報取得エラー: \(error)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ 無効なレスポンス")
                    return
                }
                
                if let data = data,
                   let responseString = String(data: data, encoding: .utf8) {
                    print("📡 ユーザー情報: \(responseString)")
                    
                    if httpResponse.statusCode == 403 && responseString.contains("token is expired") {
                        print("🔄 トークン期限切れ検知 - リフレッシュ試行")
                        self?.refreshToken()
                        return
                    }
                    
                    if httpResponse.statusCode == 200 {
                        // JSONをパースしてemail_confirmed_atを確認
                        if let jsonData = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            let emailConfirmedAt = jsonData["email_confirmed_at"] as? String
                            print("📧 メール確認状態: \(emailConfirmedAt ?? "未確認")")
                            
                            if emailConfirmedAt == nil {
                                self?.authError = "メール確認が完了していません"
                            }
                        }
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - トークンリフレッシュ
    func refreshToken() {
        guard let currentUser = currentUser,
              let refreshToken = currentUser.refreshToken else {
            print("❌ リフレッシュトークンが利用できません")
            signOut()
            return
        }
        
        print("🔄 トークンリフレッシュ開始")
        
        let refreshData = [
            "refresh_token": refreshToken
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: refreshData) else {
            print("❌ リフレッシュリクエストデータ作成失敗")
            return
        }
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=refresh_token") else {
            print("❌ リフレッシュURL無効")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ トークンリフレッシュエラー: \(error)")
                    self?.signOut()
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ リフレッシュレスポンス無効")
                    self?.signOut()
                    return
                }
                
                if let data = data,
                   let responseString = String(data: data, encoding: .utf8) {
                    print("📡 リフレッシュレスポンス(\(httpResponse.statusCode)): \(responseString)")
                    
                    if httpResponse.statusCode == 200 {
                        if let authResponse = try? JSONDecoder().decode(SupabaseAuthResponse.self, from: data) {
                            let refreshedUser = SupabaseUser(
                                id: authResponse.user.id,
                                email: authResponse.user.email,
                                accessToken: authResponse.access_token,
                                refreshToken: authResponse.refresh_token
                            )
                            
                            self?.currentUser = refreshedUser
                            self?.saveUserToDefaults(refreshedUser)
                            print("✅ トークンリフレッシュ成功")
                            
                            // プロファイルを再取得
                            self?.fetchUserProfile(userId: refreshedUser.id)
                        } else {
                            print("❌ リフレッシュレスポンス解析失敗")
                            self?.signOut()
                        }
                    } else {
                        print("❌ トークンリフレッシュ失敗 - ログアウト実行")
                        self?.signOut()
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - ログアウト機能
    func signOut() {
        print("🚪 ログアウト開始")
        
        // サーバー側ログアウト処理
        if let currentUser = currentUser {
            performServerLogout(accessToken: currentUser.accessToken)
        } else {
            // currentUserがない場合は直接ローカルデータをクリア
            clearLocalAuthData()
        }
    }
    
    // サーバー側ログアウト処理
    private func performServerLogout(accessToken: String) {
        guard let url = URL(string: "\(supabaseURL)/auth/v1/logout") else {
            print("❌ ログアウトURL無効")
            clearLocalAuthData()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("📡 サーバー側ログアウトリクエスト送信")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ サーバー側ログアウトエラー: \(error.localizedDescription)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("📡 サーバー側ログアウトレスポンス: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 204 || httpResponse.statusCode == 200 {
                        print("✅ サーバー側ログアウト成功")
                    } else {
                        print("⚠️ サーバー側ログアウト部分的失敗 (ステータス: \(httpResponse.statusCode))")
                        // サーバーエラーでもローカルデータはクリアする
                    }
                }
                
                // サーバー側の結果に関わらず、ローカルデータはクリア
                self?.clearLocalAuthData()
            }
        }.resume()
    }
    
    // クライアント側認証データクリア
    private func clearLocalAuthData() {
        print("🧹 ローカル認証データクリア開始")
        currentUser = nil
        isAuthenticated = false
        authError = nil
        
        // 保存された認証情報を削除
        UserDefaults.standard.removeObject(forKey: "supabase_user")
        
        print("👋 ログアウト完了: isAuthenticated = false")
    }
    
    // MARK: - ユーザープロファイル取得
    func fetchUserProfile(userId: String) {
        guard let currentUser = currentUser else { return }
        
        print("👤 ユーザープロファイル取得開始: \(userId)")
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/users?user_id=eq.\(userId)&select=*") else {
            print("❌ プロファイルURL無効")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(currentUser.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ プロファイル取得エラー: \(error)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ プロファイルレスポンス無効")
                    return
                }
                
                if let data = data {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📡 プロファイルレスポンス(\(httpResponse.statusCode)): \(responseString)")
                    }
                    
                    // JWTトークン期限切れの場合はリフレッシュ
                    if httpResponse.statusCode == 401 {
                        print("🔄 プロファイル取得時にトークン期限切れ検知 - リフレッシュ後に再試行")
                        self?.refreshToken()
                        return
                    }
                    
                    if httpResponse.statusCode == 200 {
                        do {
                            let profiles = try JSONDecoder().decode([UserProfile].self, from: data)
                            if let profile = profiles.first {
                                // currentUserにプロファイルを設定
                                self?.currentUser?.profile = profile
                                self?.saveUserToDefaults(self?.currentUser ?? currentUser)
                                
                                print("✅ プロファイル取得成功")
                            }
                        } catch {
                            print("❌ プロファイル解析エラー: \(error)")
                        }
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - 確認メール再送機能
    func resendConfirmationEmail(email: String) {
        isLoading = true
        authError = nil
        
        print("📧 確認メール再送: \(email)")
        
        let resendData = [
            "email": email,
            "type": "signup"
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: resendData) else {
            authError = "リクエストデータの作成に失敗しました"
            isLoading = false
            return
        }
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/resend") else {
            authError = "無効なURL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.authError = "ネットワークエラー: \(error.localizedDescription)"
                    print("❌ 確認メール再送エラー: \(error)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.authError = "無効なレスポンス"
                    return
                }
                
                print("📡 確認メール再送レスポンスステータス: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    self?.authError = "確認メールを再送しました。メールボックスをご確認ください。"
                    print("✅ 確認メール再送成功")
                } else {
                    self?.authError = "確認メール再送に失敗しました"
                }
            }
        }.resume()
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
}

// MARK: - データモデル

struct SupabaseUser: Codable {
    let id: String
    let email: String
    let accessToken: String
    let refreshToken: String?
    var profile: UserProfile?
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
        case newsletter
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