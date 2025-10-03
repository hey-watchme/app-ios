//
//  LoginView.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/07/04.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var showSignUp: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
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
                        .foregroundColor(.secondary)
                }
                .padding(.top, 80)
                
                Spacer()
                
                // ログインフォーム
                VStack(spacing: 16) {
                    // メールアドレス入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text("メールアドレス")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ZStack(alignment: .leading) {
                            if email.isEmpty {
                                Text("example@example.com")
                                    .foregroundColor(Color.safeColor("BorderLight").opacity(0.6))
                                    .padding(.leading, 8)
                                    .allowsHitTesting(false)
                            }
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
                                        .stroke(Color.safeColor("BorderLight"), lineWidth: 1)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color(.systemBackground))
                                        )
                                )
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
                                    .foregroundColor(Color.safeColor("PrimaryActionColor"))
                            }
                        }
                        
                        HStack {
                            if showPassword {
                                TextField("パスワードを入力", text: $password)
                                    .font(.body)
                                    .padding()
                                    .frame(height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.safeColor("BorderLight"), lineWidth: 1)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color(.systemBackground))
                                            )
                                    )
                            } else {
                                SecureField("パスワードを入力", text: $password)
                                    .textContentType(.password)
                                    .font(.body)
                                    .padding()
                                    .frame(height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.safeColor("BorderLight"), lineWidth: 1)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color(.systemBackground))
                                            )
                                    )
                            }
                        }
                    }
                    
                    // エラーメッセージ
                    if let errorMessage = userAccountManager.authError {
                        VStack(spacing: 8) {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(Color.safeColor("ErrorColor"))
                                .multilineTextAlignment(.center)
                            
                            // メール確認エラーの場合の説明
                            if errorMessage.contains("Email not confirmed") || errorMessage.contains("email_not_confirmed") {
                                VStack(spacing: 8) {
                                    Text("📧 メール確認が必要です")
                                        .font(.caption)
                                        .foregroundColor(Color.safeColor("WarningColor"))
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
                                            .foregroundColor(Color.safeColor("AppAccentColor"))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.safeColor("AppAccentColor").opacity(0.1))
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
                        userAccountManager.signIn(email: email, password: password)
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
                        .background(Color.safeColor("AppAccentColor"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(email.isEmpty || password.isEmpty || userAccountManager.isLoading)
                }
                .padding(.horizontal, 40)
                
                // 新規登録リンク
                Button(action: {
                    showSignUp = true
                }) {
                    Text("新規ではじめる")
                        .font(.footnote)
                        .foregroundColor(Color.safeColor("AppAccentColor"))
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
                .environmentObject(userAccountManager)
        }
        .onChange(of: userAccountManager.isAuthenticated) { oldValue, newValue in
            if newValue {
                print("🔄 ログイン成功 - LoginViewからdismiss実行")
                dismiss()
            }
        }
    }
}


#Preview {
    let deviceManager = DeviceManager()
    let userAccountManager = UserAccountManager(deviceManager: deviceManager)
    return LoginView()
        .environmentObject(userAccountManager)
}