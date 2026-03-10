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
            VStack(spacing: 15) {
                // PNGロゴを表示
                Image("WatchMeLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 63)

                Text("ログイン")
                    .font(.title2)
                    .foregroundColor(Color(white: 0.56))
            }
            .padding(.top, 80)

            Spacer()

            // ログインフォーム
            VStack(spacing: 16) {
                // メールアドレス入力
                VStack(alignment: .leading, spacing: 8) {
                    Text("メールアドレス")
                        .font(.caption)
                        .foregroundColor(Color(white: 0.56))

                    TextField("メールアドレスを入力", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .onSubmit {
                            focusedField = .password
                        }

                    if showValidationErrors && email.isEmpty {
                        Text("メールアドレスを入力してください")
                            .font(.caption2)
                            .foregroundColor(.red)
                    } else if showValidationErrors && !isValidEmail(email) {
                        Text("正しいメールアドレスの形式で入力してください")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }

                // パスワード入力
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("パスワード")
                            .font(.caption)
                            .foregroundColor(Color(white: 0.56))

                        Spacer()

                        Button(action: {
                            showPassword.toggle()
                        }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }

                    Group {
                        if showPassword {
                            TextField("パスワードを入力", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($focusedField, equals: .password)
                                .onSubmit {
                                    focusedField = nil
                                    handleLogin()
                                }
                        } else {
                            SecureField("パスワードを入力", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .onSubmit {
                                    focusedField = nil
                                    handleLogin()
                                }
                        }
                    }

                    if showValidationErrors && password.isEmpty {
                        Text("パスワードを入力してください")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }

                // エラーメッセージ
                if let errorMessage = userAccountManager.authError {
                    VStack(spacing: 8) {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)

                        // メール確認エラーの場合の説明
                        if errorMessage.contains("Email not confirmed") || errorMessage.contains("email_not_confirmed") {
                            VStack(spacing: 8) {
                                Text("📧 メール確認が必要です")
                                    .font(.caption)
                                    .foregroundColor(.orange)
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
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                .disabled(email.isEmpty || userAccountManager.isLoading)
                            }
                            .padding(.top, 4)
                        }
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

                        Text("ログイン")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.accentTeal)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(userAccountManager.isLoading)

                // 区切り
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("または")
                        .font(.caption)
                        .foregroundColor(Color(white: 0.56))
                        .padding(.horizontal, 8)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.secondary.opacity(0.3))
                }
                .padding(.vertical, 16)

                // Googleログインボタン
                Button(action: {
                    focusedField = nil
                    signInWithGoogle()
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }

                        Image(systemName: "globe")
                        Text("Google でログイン")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.darkElevated)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                }
                .disabled(userAccountManager.isLoading || isProcessing)
            }
            .padding(.horizontal, 40)

            // 新規登録リンク
            Button(action: {
                showOnboarding = true
            }) {
                Text("新規ではじめる")
                    .font(.footnote)
                    .foregroundColor(Color.accentTeal)
            }
            .padding(.top, 20)

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