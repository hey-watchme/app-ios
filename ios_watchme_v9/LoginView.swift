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
                .padding(.top, 40)
                
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
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)  // これにより自動補完が有効になります
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .foregroundColor(.primary)
                                .accentColor(Color.safeColor("PrimaryActionColor"))
                                .font(.body)  // フォントサイズを少し大きく
                                .padding(.vertical, 4)  // 縦方向の余白を追加
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
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.body)
                                    .padding(.vertical, 4)
                            } else {
                                SecureField("パスワードを入力", text: $password)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textContentType(.password)
                                    .font(.body)
                                    .padding(.vertical, 4)
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
                                            .foregroundColor(Color.safeColor("PrimaryActionColor"))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.safeColor("PrimaryActionColor").opacity(0.1))
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
                        .padding()
                        .background(Color.safeColor("PrimaryActionColor"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(email.isEmpty || password.isEmpty || userAccountManager.isLoading)
                }
                .padding(.horizontal, 40)
                
                // 新規アカウント作成リンク
                Button(action: {
                    if let url = URL(string: "https://hey-watch.me/signup.html") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("新規アカウント作成はこちら")
                        .font(.footnote)
                        .foregroundColor(Color.safeColor("PrimaryActionColor"))
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .navigationBarHidden(true)
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