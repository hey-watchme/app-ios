//
//  UpgradeAccountView.swift
//  ios_watchme_v9
//
//  Anonymous user upgrade screen
//  Allows guest users to upgrade to a regular account via Google
//

import SwiftUI

struct UpgradeAccountView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var toastManager: ToastManager
    @Environment(\.dismiss) private var dismiss

    @State private var isProcessing = false
    @State private var showSignUp = false
    @State private var errorAnnouncement: ErrorAnnouncement?

    private struct ErrorAnnouncement: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.darkBase.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(Color.safeColor("AppAccentColor"))

                        Text("通常アカウントへのアップグレード")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("現在のゲストデータを引き継いだまま、通常アカウントへ移行します。")
                            .font(.subheadline)
                            .foregroundColor(Color(white: 0.56))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color.safeColor("WarningColor"))
                            Text("注意")
                                .font(.headline)
                                .foregroundColor(Color.safeColor("WarningColor"))
                        }

                        Text("アカウントの移行はGoogle認証でのみ行うことができます。Googleアカウントを使った認証ができない場合は、新規アカウント登録をご利用ください。その際データの引き継ぎはできませんのでご注意ください。")
                            .font(.footnote)
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.safeColor("WarningColor").opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.safeColor("WarningColor").opacity(0.45), lineWidth: 1)
                    )
                    .cornerRadius(12)
                    .padding(.horizontal, 24)

                    Spacer()

                    // Buttons
                    VStack(spacing: 16) {
                        // Google Sign In
                        Button(action: {
                            upgradeWithGoogle()
                        }) {
                            HStack {
                                Image(systemName: "globe")
                                Text("Google認証を使ってアップデート")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.darkElevated)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        Button(action: {
                            showSignUp = true
                        }) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                Text("新規アカウント登録")
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
                                .foregroundColor(Color(white: 0.56))
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                    .disabled(isProcessing)
                    .opacity(isProcessing ? 0.6 : 1.0)
                }
            }
            .navigationTitle("アップグレード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.darkBase, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(.white)
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
                                Text("アップグレード中...")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                        }
                    }
                }
            )
            .sheet(isPresented: $showSignUp) {
                SignUpView()
                    .environmentObject(userAccountManager)
            }
        }
        .preferredColorScheme(.dark)
        .overlay {
            ToastOverlay(toastManager: toastManager)
        }
        .alert(item: $errorAnnouncement) { item in
            Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Actions

    private func upgradeWithGoogle() {
        isProcessing = true
        Task {
            // Call UserAccountManager's upgrade method
            let result = await userAccountManager.upgradeAnonymousToGoogle()

            await MainActor.run {
                isProcessing = false

                switch result {
                case .upgraded:
                    toastManager.showSuccess(
                        title: "アップグレード完了",
                        subtitle: "ゲストデータを引き継いで通常アカウントへ移行しました"
                    )
                    dismiss()
                case .cancelled:
                    toastManager.showInfo(
                        title: "処理を中止しました",
                        subtitle: "Google認証をキャンセルしました"
                    )
                case .notAnonymousUser:
                    showUpgradeError("現在のユーザーは匿名ユーザーではありません")
                case .switchedToExistingGoogleAccount:
                    showUpgradeError("既存のGoogleアカウントがあるためアップグレードに失敗しました。ログインから入り直してください。")
                case .oauthFailed(let message):
                    showUpgradeError("Google連携に失敗しました: \(message)")
                case .unknownFailure:
                    showUpgradeError("アップグレードに失敗しました。ログインから入り直してください。")
                }
            }
        }
    }

    private func showUpgradeError(_ message: String) {
        toastManager.showError(
            title: "アップグレードエラー",
            subtitle: message
        )
        errorAnnouncement = ErrorAnnouncement(
            title: "アップグレードできませんでした",
            message: message
        )
    }
}

#Preview {
    UpgradeAccountView()
        .environmentObject(UserAccountManager(deviceManager: DeviceManager()))
        .environmentObject(ToastManager.shared)
}
