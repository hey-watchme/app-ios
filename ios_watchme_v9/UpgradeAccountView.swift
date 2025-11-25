//
//  UpgradeAccountView.swift
//  ios_watchme_v9
//
//  Anonymous user upgrade screen
//  Allows guest users to link their account to Google or Email
//

import SwiftUI

struct UpgradeAccountView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var toastManager: ToastManager
    @Environment(\.dismiss) private var dismiss

    @State private var isProcessing = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(Color.safeColor("AppAccentColor"))

                    Text("アカウント登録")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("ゲストモードのデータを安全に保存しましょう。\nアカウント登録すると、データがクラウドに保存され、\n複数デバイスで同期できます。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                Spacer()

                // Buttons
                VStack(spacing: 16) {
                    // Google Sign In
                    Button(action: {
                        upgradeWithGoogle()
                    }) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Google でログイン")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    // Email Sign Up (Mock)
                    Button(action: {
                        toastManager.showInfo(
                            title: "メールアドレス登録",
                            subtitle: "現在準備中です"
                        )
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("メールアドレスでログイン")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.safeColor("AppAccentColor"))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    // Cancel
                    Button(action: {
                        dismiss()
                    }) {
                        Text("後で")
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                .disabled(isProcessing)
                .opacity(isProcessing ? 0.6 : 1.0)
            }
            .navigationTitle("アカウント登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .overlay(
                Group {
                    if isProcessing {
                        ZStack {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("アカウント登録中...")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                        }
                    }
                }
            )
        }
    }

    // MARK: - Actions

    private func upgradeWithGoogle() {
        isProcessing = true
        Task {
            // Call UserAccountManager's upgrade method
            let success = await userAccountManager.upgradeAnonymousToGoogle()

            await MainActor.run {
                isProcessing = false

                if success {
                    toastManager.showSuccess(
                        title: "アカウント登録完了",
                        subtitle: "ゲストデータをGoogleアカウントに移行しました"
                    )
                    dismiss()
                } else if let error = userAccountManager.authError {
                    toastManager.showError(
                        title: "登録エラー",
                        subtitle: error
                    )
                }
            }
        }
    }
}

#Preview {
    UpgradeAccountView()
        .environmentObject(UserAccountManager(deviceManager: DeviceManager()))
        .environmentObject(ToastManager.shared)
}
