//
//  LoginView.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/07/04.
//

import SwiftUI

struct LoginView: View {
    /// "新規ではじめる": close this and start the onboarding. nil hides the link
    /// (e.g. when opened from the sign-up sheet in sample mode).
    var onStartNew: (() -> Void)? = nil
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var toastManager: ToastManager
    @EnvironmentObject var subjectManager: SubjectManager
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showValidationErrors: Bool = false
    @State private var isProcessing: Bool = false
    @Environment(\.dismiss) private var dismiss

    // フォーカス管理
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case email
        case password
    }

    // 静的なEmailバリデーター（毎回作成しない）
    private static let emailPredicate = NSPredicate(format: "SELF MATCHES %@", "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")

    var body: some View {
        ZStack {
            Color.darkBase.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // アプリロゴ・タイトル
                VStack(spacing: 16) {
                    Color.white
                        .frame(width: 238, height: 86)
                        .mask(
                            Image("WatchMeLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 238, height: 86)
                        )
                        .shadow(color: Color.white.opacity(0.16), radius: 10, x: 0, y: 4)

                    Text("ログイン")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(white: 0.64))
                }
                .padding(.top, 72)

                Spacer()

                // ログインフォーム
                VStack(spacing: 14) {
                    AppleSignInButton(purpose: .signIn)

                    AppFormButton(title: "Google でログイン", systemImage: "globe", style: .dark, isLoading: isProcessing) {
                        focusedField = nil
                        signInWithGoogle()
                    }
                    .disabled(userAccountManager.isLoading || isProcessing)

                    AppFormSectionTitle(text: "またはメールアドレスでログイン")
                        .padding(.top, 6)

                    // メールアドレス入力
                    VStack(alignment: .leading, spacing: 8) {
                        AppFieldLabel(text: "メールアドレス")

                        AppTextField("メールアドレスを入力", text: $email, icon: "envelope",
                                     focus: $focusedField, field: .email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { focusedField = .password }

                        if showValidationErrors && email.isEmpty {
                            Text("メールアドレスを入力してください")
                                .font(.caption2)
                                .foregroundColor(.accentCoral)
                        } else if showValidationErrors && !isValidEmail(email) {
                            Text("正しいメールアドレスの形式で入力してください")
                                .font(.caption2)
                                .foregroundColor(.accentCoral)
                        }
                    }

                    // パスワード入力
                    VStack(alignment: .leading, spacing: 8) {
                        AppFieldLabel(text: "パスワード")

                        AppTextField("パスワードを入力", text: $password, icon: "lock", isSecure: true,
                                     focus: $focusedField, field: .password)
                            .textContentType(.password)
                            .onSubmit {
                                focusedField = nil
                                handleLogin()
                            }

                        if showValidationErrors && password.isEmpty {
                            Text("パスワードを入力してください")
                                .font(.caption2)
                                .foregroundColor(.accentCoral)
                        }
                    }

                    AppFormButton(title: "メールアドレスでログイン", style: .accent,
                                  isLoading: userAccountManager.isLoading) {
                        focusedField = nil
                        handleLogin()
                    }
                    .disabled(userAccountManager.isLoading)
                    .padding(.top, 4)

                    // エラーメッセージ
                    if let errorMessage = userAccountManager.authError {
                        VStack(spacing: 8) {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.accentCoral)
                                .multilineTextAlignment(.center)

                            // メール確認エラーの場合の説明
                            if errorMessage.contains("Email not confirmed") || errorMessage.contains("email_not_confirmed") {
                                VStack(spacing: 8) {
                                    Text("📧 メール確認が必要です")
                                        .font(.caption)
                                        .foregroundColor(.accentTealMuted)
                                        .fontWeight(.medium)

                                    Text("登録したメールアドレスに届いた確認メールのリンクを開いてから、もう一度ログインしてください。")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)

                                    Button(action: {
                                        userAccountManager.resendConfirmationEmail(email: email)
                                    }) {
                                        Text("📬 確認メールを再送")
                                            .font(.caption)
                                            .foregroundColor(.accentTeal)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.accentTeal.opacity(0.1))
                                            .cornerRadius(6)
                                    }
                                    .disabled(email.isEmpty || userAccountManager.isLoading)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)

                // 新規登録リンク
                if let onStartNew {
                    Button(action: {
                        dismiss()
                        onStartNew()
                    }) {
                        Text("新規ではじめる")
                            .font(.footnote)
                            .foregroundColor(Color.accentTeal)
                    }
                    .padding(.top, 16)
                }

                Spacer()
            }
        }
        .onChange(of: userAccountManager.isAuthenticated) { oldValue, newValue in
            print("🔍 LoginView - isAuthenticated変更検知: \(oldValue) → \(newValue)")
            if newValue {
                print("🔄 ログイン成功 - LoginViewからdismiss実行")
                // Note: デバイス登録はUserAccountManager.initializeAuthenticatedUser()で実行される
                // LoginView自体も閉じる
                dismiss()
            }
        }
        .onOpenURL { url in
            // Handle OAuth callback
            print("🔗 [LoginView] URL received: \(url)")
            Task {
                await userAccountManager.handleOAuthCallback(url: url)
            }
        }
    }

    // メールアドレスバリデーション
    private func isValidEmail(_ email: String) -> Bool {
        return Self.emailPredicate.evaluate(with: email)
    }

    // ログイン処理
    private func handleLogin() {
        // バリデーションチェック
        if email.isEmpty || !isValidEmail(email) || password.isEmpty {
            showValidationErrors = true
            return
        }

        // バリデーション成功
        showValidationErrors = false
        userAccountManager.signIn(email: email, password: password)
    }

    // Googleログイン処理
    private func signInWithGoogle() {
        isProcessing = true
        Task {
            // Use direct ASWebAuthenticationSession implementation
            await userAccountManager.signInWithGoogleDirect()

            // Note: OAuth flow continues in browser
            // This view stays open until callback is received
            await MainActor.run {
                isProcessing = false
            }
        }
    }
}
