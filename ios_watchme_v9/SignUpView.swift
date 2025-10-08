//
//  SignUpView.swift
//  ios_watchme_v9
//
//  新規会員登録画面
//

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var passwordConfirm: String = ""
    @State private var showPassword: Bool = false
    @State private var showPasswordConfirm: Bool = false
    @State private var agreeToTerms: Bool = false
    @State private var subscribeNewsletter: Bool = true
    @State private var showSuccessView: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
                VStack(spacing: 20) {
                    // アプリロゴ・タイトル
                    VStack(spacing: 15) {
                        // PNGロゴを表示
                        Image("WatchMeLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 180, height: 63)

                        Text("新規会員登録")
                            .font(.title2)
                            .foregroundColor(.secondary)

                        Text("基本機能は無料でご利用いただけます")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)

                    // 登録フォーム
                    VStack(spacing: 16) {
                        // 表示名入力
                        VStack(alignment: .leading, spacing: 8) {
                            Text("表示名")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("", text: $displayName)
                                .textContentType(.name)
                                .autocorrectionDisabled()
                                .foregroundColor(.primary)
                                .font(.body)
                                .padding()
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(.separator), lineWidth: 1)
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemBackground))
                                )
                        }

                        // メールアドレス入力
                        VStack(alignment: .leading, spacing: 8) {
                            Text("メールアドレス")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("", text: $email)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .foregroundColor(.primary)
                                .font(.body)
                                .padding()
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(.separator), lineWidth: 1)
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemBackground))
                                )
                        }

                        // パスワード入力
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("パスワード")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Button(action: {
                                    showPassword.toggle()
                                }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .font(.caption)
                                        .foregroundColor(Color.primary)
                                }
                            }

                            HStack {
                                if showPassword {
                                    TextField("8文字以上の英数字", text: $password)
                                        .font(.body)
                                        .padding()
                                        .frame(height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color(.separator), lineWidth: 1)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color(.systemBackground))
                                                )
                                        )
                                } else {
                                    SecureField("8文字以上の英数字", text: $password)
                                        .textContentType(.newPassword)
                                        .font(.body)
                                        .padding()
                                        .frame(height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color(.separator), lineWidth: 1)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color(.systemBackground))
                                                )
                                        )
                                }
                            }

                            Text("8文字以上、英数字を含む")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        // パスワード確認入力
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("パスワード確認")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Button(action: {
                                    showPasswordConfirm.toggle()
                                }) {
                                    Image(systemName: showPasswordConfirm ? "eye.slash" : "eye")
                                        .font(.caption)
                                        .foregroundColor(Color.primary)
                                }
                            }

                            HStack {
                                if showPasswordConfirm {
                                    TextField("パスワードを再入力", text: $passwordConfirm)
                                        .font(.body)
                                        .padding()
                                        .frame(height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color(.separator), lineWidth: 1)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color(.systemBackground))
                                                )
                                        )
                                } else {
                                    SecureField("パスワードを再入力", text: $passwordConfirm)
                                        .textContentType(.newPassword)
                                        .font(.body)
                                        .padding()
                                        .frame(height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color(.separator), lineWidth: 1)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color(.systemBackground))
                                                )
                                        )
                                }
                            }
                        }

                        // 利用規約同意チェックボックス
                        HStack(alignment: .top, spacing: 12) {
                            Button(action: {
                                agreeToTerms.toggle()
                            }) {
                                Image(systemName: agreeToTerms ? "checkmark.square.fill" : "square")
                                    .foregroundColor(agreeToTerms ? Color.primary : Color.secondary)
                                    .font(.title3)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Button(action: {
                                        if let url = URL(string: "https://hey-watch.me/terms") {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        Text("利用規約")
                                            .font(.caption)
                                            .foregroundColor(Color.primary)
                                            .underline()
                                    }

                                    Text("と")
                                        .font(.caption)
                                        .foregroundColor(.primary)

                                    Button(action: {
                                        if let url = URL(string: "https://hey-watch.me/privacy") {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        Text("プライバシーポリシー")
                                            .font(.caption)
                                            .foregroundColor(Color.primary)
                                            .underline()
                                    }
                                }

                                Text("に同意します")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                        // ニュースレター購読チェックボックス
                        HStack(alignment: .top, spacing: 12) {
                            Button(action: {
                                subscribeNewsletter.toggle()
                            }) {
                                Image(systemName: subscribeNewsletter ? "checkmark.square.fill" : "square")
                                    .foregroundColor(subscribeNewsletter ? Color.primary : Color.secondary)
                                    .font(.title3)
                            }

                            Text("新機能やアップデート情報を受け取る（任意）")
                                .font(.caption)
                                .foregroundColor(.primary)

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // エラーメッセージ
                        if let errorMessage = userAccountManager.authError {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(Color.red)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                        }

                        // 登録ボタン
                        Button(action: {
                            Task {
                                await handleSignUp()
                            }
                        }) {
                            HStack {
                                if userAccountManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }

                                Text(userAccountManager.isLoading ? "登録中..." : "アカウントを作成")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(isFormValid() ? Color.primary : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!isFormValid() || userAccountManager.isLoading)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 40)

                    // ログインリンク
                    HStack(spacing: 4) {
                        Text("すでにアカウントをお持ちですか？")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        Button(action: {
                            dismiss()
                        }) {
                            Text("ログイン")
                                .font(.footnote)
                                .foregroundColor(Color.primary)
                        }
                    }
                    .padding(.top, 20)

                    Spacer(minLength: 40)
                }
            }
        .fullScreenCover(isPresented: $showSuccessView) {
            SignUpSuccessView(userEmail: email)
                .onDisappear {
                    // 案内画面を閉じた後、SignUpViewも閉じる
                    dismiss()
                }
        }
        .onChange(of: userAccountManager.signUpSuccess) { oldValue, newValue in
            if newValue {
                print("🔄 サインアップ成功")
                // メール確認が無効化されている場合は案内画面を表示しない
                // showSuccessView = true  // コメントアウト：メール確認不要なので案内画面は不要
                // フラグをリセット
                userAccountManager.signUpSuccess = false
            }
        }
        .onChange(of: userAccountManager.isAuthenticated) { oldValue, newValue in
            print("🔍 SignUpView - isAuthenticated変更検知: \(oldValue) → \(newValue)")
            if newValue {
                print("🔄 ログイン成功 - SignUpViewからdismiss実行")
                dismiss()
            }
        }
    }

    // フォームバリデーション
    private func isFormValid() -> Bool {
        return !displayName.isEmpty &&
               displayName.count >= 2 &&
               !email.isEmpty &&
               isValidEmail(email) &&
               !password.isEmpty &&
               password.count >= 8 &&
               password == passwordConfirm &&
               agreeToTerms
    }

    // メールアドレスバリデーション
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    // サインアップ処理
    private func handleSignUp() async {
        await userAccountManager.signUp(
            email: email,
            password: password,
            displayName: displayName,
            newsletter: subscribeNewsletter
        )
    }
}
