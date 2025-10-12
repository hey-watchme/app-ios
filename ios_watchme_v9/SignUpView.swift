//
//  SignUpView.swift
//  ios_watchme_v9
//
//  ユーザ登録画面
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
    @State private var isFormValidState: Bool = false
    @State private var showLogin: Bool = false
    @State private var showValidationErrors: Bool = false
    @Environment(\.dismiss) private var dismiss

    // フォーカス管理
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case displayName
        case email
        case password
        case passwordConfirm
    }

    // 静的なEmailバリデーター（毎回作成しない）
    private static let emailPredicate = NSPredicate(format: "SELF MATCHES %@", "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // アプリロゴ・タイトル
                VStack(spacing: 15) {
                    // PNGロゴを表示
                    Image("WatchMeLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 180, height: 63)

                    Text("アカウント登録")
                        .font(.title2)
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

                        TextField("お名前を入力", text: $displayName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.name)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .displayName)
                            .onSubmit {
                                focusedField = .email
                            }

                        if showValidationErrors && displayName.isEmpty {
                            Text("表示名を入力してください")
                                .font(.caption2)
                                .foregroundColor(.red)
                        } else if showValidationErrors && displayName.count < 2 {
                            Text("表示名は2文字以上で入力してください")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }

                    // メールアドレス入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text("メールアドレス")
                            .font(.caption)
                            .foregroundColor(.secondary)

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

                        Group {
                            if showPassword {
                                TextField("8文字以上の英数字", text: $password)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .focused($focusedField, equals: .password)
                                    .onSubmit {
                                        focusedField = .passwordConfirm
                                    }
                            } else {
                                SecureField("8文字以上の英数字", text: $password)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textContentType(.newPassword)
                                    .focused($focusedField, equals: .password)
                                    .onSubmit {
                                        focusedField = .passwordConfirm
                                    }
                            }
                        }

                        if showValidationErrors && password.isEmpty {
                            Text("パスワードを入力してください")
                                .font(.caption2)
                                .foregroundColor(.red)
                        } else if showValidationErrors && password.count < 8 {
                            Text("パスワードは8文字以上で入力してください")
                                .font(.caption2)
                                .foregroundColor(.red)
                        } else {
                            Text("8文字以上、英数字を含む")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
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

                        Group {
                            if showPasswordConfirm {
                                TextField("パスワードを再入力", text: $passwordConfirm)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .focused($focusedField, equals: .passwordConfirm)
                                    .onSubmit {
                                        focusedField = nil
                                    }
                            } else {
                                SecureField("パスワードを再入力", text: $passwordConfirm)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textContentType(.newPassword)
                                    .focused($focusedField, equals: .passwordConfirm)
                                    .onSubmit {
                                        focusedField = nil
                                    }
                            }
                        }

                        if showValidationErrors && password != passwordConfirm {
                            Text("パスワードが一致しません")
                                .font(.caption2)
                                .foregroundColor(.red)
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

                    if showValidationErrors && !agreeToTerms {
                        Text("利用規約とプライバシーポリシーに同意してください")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

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
                        updateValidationState()
                        if isFormValidState {
                            showValidationErrors = false
                            Task {
                                await handleSignUp()
                            }
                        } else {
                            showValidationErrors = true
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
                        .background(Color.primary)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(userAccountManager.isLoading)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 40)

                // ログインリンク
                HStack(spacing: 4) {
                    Text("すでにアカウントをお持ちですか？")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    Button(action: {
                        showLogin = true
                    }) {
                        Text("ログイン")
                            .font(.footnote)
                            .foregroundColor(Color.primary)
                    }
                }
                .padding(.top, 20)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
        .fullScreenCover(isPresented: $showSuccessView) {
            SignUpSuccessView(userEmail: email)
                .onDisappear {
                    dismiss()
                }
        }
        .onChange(of: userAccountManager.signUpSuccess) { oldValue, newValue in
            if newValue {
                userAccountManager.signUpSuccess = false
            }
        }
        .onChange(of: userAccountManager.isAuthenticated) { oldValue, newValue in
            if newValue {
                dismiss()
            }
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginView()
                .environmentObject(userAccountManager)
        }
    }

    // バリデーション状態を更新
    private func updateValidationState() {
        isFormValidState = !displayName.isEmpty &&
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
        return Self.emailPredicate.evaluate(with: email)
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