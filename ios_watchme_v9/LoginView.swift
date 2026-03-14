//
//  LoginView.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/07/04.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var toastManager: ToastManager
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var showOnboarding: Bool = false
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
                VStack(spacing: 16) {
                    // Googleログインボタン（メイン）
                    Button(action: {
                        focusedField = nil
                        signInWithGoogle()
                    }) {
                        HStack(spacing: 10) {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "globe")
                            }

                            Text("Google でログイン")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white)
                        .foregroundColor(Color.black.opacity(0.88))
                        .cornerRadius(14)
                        .shadow(color: Color.white.opacity(0.10), radius: 8, x: 0, y: 4)
                    }
                    .disabled(userAccountManager.isLoading || isProcessing)

                    // 区切り
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.secondary.opacity(0.24))
                        Text("またはメールアドレス・パスワード")
                            .font(.caption)
                            .foregroundColor(Color(white: 0.56))
                            .padding(.horizontal, 8)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.secondary.opacity(0.24))
                    }
                    .padding(.vertical, 4)

                    // メールアドレス入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text("メールアドレス")
                            .font(.caption)
                            .foregroundColor(Color(white: 0.60))

                        HStack(spacing: 10) {
                            Image(systemName: "envelope")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.accentTeal.opacity(0.85))

                            TextField("メールアドレスを入力", text: $email)
                                .textFieldStyle(.plain)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .foregroundColor(.brightText)
                                .focused($focusedField, equals: .email)
                                .onSubmit {
                                    focusedField = .password
                                }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.darkSurface.opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(focusedField == .email ? Color.accentTeal.opacity(0.9) : Color.white.opacity(0.12), lineWidth: focusedField == .email ? 1.6 : 1)
                        )
                        .cornerRadius(14)

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
                        Text("パスワード")
                            .font(.caption)
                            .foregroundColor(Color(white: 0.60))

                        HStack(spacing: 10) {
                            Image(systemName: "lock")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.accentTeal.opacity(0.85))

                            Group {
                                if showPassword {
                                    TextField("パスワードを入力", text: $password)
                                        .textFieldStyle(.plain)
                                        .foregroundColor(.brightText)
                                        .focused($focusedField, equals: .password)
                                        .onSubmit {
                                            focusedField = nil
                                            handleLogin()
                                        }
                                } else {
                                    SecureField("パスワードを入力", text: $password)
                                        .textFieldStyle(.plain)
                                        .textContentType(.password)
                                        .foregroundColor(.brightText)
                                        .focused($focusedField, equals: .password)
                                        .onSubmit {
                                            focusedField = nil
                                            handleLogin()
                                        }
                                }
                            }

                            Button(action: {
                                showPassword.toggle()
                            }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(white: 0.72))
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.darkSurface.opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(focusedField == .password ? Color.accentTeal.opacity(0.9) : Color.white.opacity(0.12), lineWidth: focusedField == .password ? 1.6 : 1)
                        )
                        .cornerRadius(14)

                        if showValidationErrors && password.isEmpty {
                            Text("パスワードを入力してください")
                                .font(.caption2)
                                .foregroundColor(.accentCoral)
                        }
                    }

                    // ログインボタン
                    Button(action: {
                        focusedField = nil
                        handleLogin()
                    }) {
                        HStack {
                            if userAccountManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }

                            Text("メールアドレスでログイン")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentTeal)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(color: Color.accentTeal.opacity(0.26), radius: 10, x: 0, y: 5)
                    }
                    .disabled(userAccountManager.isLoading)

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

                                    Text("Gmailの+1は、Supabaseでは別のメールアドレスとして認識されます。\n通常のメールアドレス（matsumotokaya@gmail.com）でサインアップしてください。")
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
                Button(action: {
                    showOnboarding = true
                }) {
                    Text("新規ではじめる")
                        .font(.footnote)
                        .foregroundColor(Color.accentTeal)
                }
                .padding(.top, 16)

                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            AuthFlowView(isPresented: $showOnboarding)
                .environmentObject(userAccountManager)
                .environmentObject(deviceManager)
                .environmentObject(toastManager)
        }
        .onChange(of: userAccountManager.isAuthenticated) { oldValue, newValue in
            print("🔍 LoginView - isAuthenticated変更検知: \(oldValue) → \(newValue)")
            if newValue {
                print("🔄 ログイン成功 - LoginViewからdismiss実行")
                // Note: デバイス登録はUserAccountManager.initializeAuthenticatedUser()で実行される
                // オンボーディングシートを閉じる
                showOnboarding = false
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
