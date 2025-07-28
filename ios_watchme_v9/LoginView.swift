//
//  LoginView.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/07/04.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
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
                                    .foregroundColor(.gray.opacity(0.6))
                                    .padding(.leading, 8)
                                    .allowsHitTesting(false)
                            }
                            TextField("", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .foregroundColor(.primary)
                                .accentColor(.blue)
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
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        HStack {
                            if showPassword {
                                TextField("パスワードを入力", text: $password)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            } else {
                                SecureField("パスワードを入力", text: $password)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                    }
                    
                    // エラーメッセージ
                    if let errorMessage = authManager.authError {
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
                                        authManager.resendConfirmationEmail(email: email)
                                    }) {
                                        Text("📬 確認メールを再送")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(6)
                                    }
                                    .disabled(email.isEmpty || authManager.isLoading)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    
                    // ログインボタン
                    Button(action: {
                        authManager.signIn(email: email, password: password)
                    }) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text("ログイン")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
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
                        .foregroundColor(.blue)
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
        .onChange(of: authManager.isAuthenticated) { oldValue, newValue in
            if newValue {
                print("🔄 ログイン成功 - LoginViewからdismiss実行")
                dismiss()
            }
        }
    }
}


#Preview {
    let deviceManager = DeviceManager()
    let authManager = SupabaseAuthManager(deviceManager: deviceManager)
    return LoginView()
        .environmentObject(authManager)
}