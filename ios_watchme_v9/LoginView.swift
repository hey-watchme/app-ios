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
    @State private var isSignUpMode: Bool = false
    @State private var showPassword: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // アプリロゴ・タイトル
                VStack(spacing: 10) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("WatchMe")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(isSignUpMode ? "新規アカウント作成" : "ログイン")
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
                        
                        TextField("example@example.com", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
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
                    
                    // ログイン/サインアップボタン
                    Button(action: {
                        if isSignUpMode {
                            authManager.signUp(email: email, password: password)
                        } else {
                            authManager.signIn(email: email, password: password)
                        }
                    }) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isSignUpMode ? "アカウント作成" : "ログイン")
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
                
                // メール確認リマインダー（サインアップ時）
                if isSignUpMode {
                    VStack(spacing: 8) {
                        Text("📬 重要: サインアップ後の手順")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                        
                        Text("1. アカウント作成後、確認メールが送信されます\n2. メール内のリンクをクリックして確認完了\n3. その後ログインが可能になります")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // モード切り替えボタン
                Button(action: {
                    isSignUpMode.toggle()
                    authManager.authError = nil
                }) {
                    Text(isSignUpMode ? "既にアカウントをお持ちの方はこちら" : "新規アカウント作成はこちら")
                        .font(.footnote)
                        .foregroundColor(.blue)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // デバッグ情報（開発時のみ）
                #if DEBUG
                VStack(spacing: 4) {
                    Text("デバッグ情報")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Supabase URL: qvtlwotzuzbavrzqhyvt.supabase.co")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
                #endif
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
    LoginView()
        .environmentObject(SupabaseAuthManager())
}