//
//  SignUpSuccessView.swift
//  ios_watchme_v9
//
//  会員登録成功後の案内画面
//

import SwiftUI

struct SignUpSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    let userEmail: String

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Spacer()

                // 成功アイコン
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color.safeColor("SuccessColor"))
                    .padding(.bottom, 30)

                // タイトル
                Text("認証メールを送信しました")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.bottom, 20)

                // 説明文
                VStack(spacing: 12) {
                    Text("以下のメールアドレスに認証メールを送信しました。")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Text(userEmail)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                        )

                    Text("メールに記載された認証ボタンをクリックしてから、\nログインしてください。")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 40)

                Spacer()

                // ログインボタン
                Button(action: {
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                        Text("ログイン画面へ")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.safeColor("AppAccentColor"))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    SignUpSuccessView(userEmail: "example@example.com")
}
