//
//  AccountSettingsView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/08/19.
//

import SwiftUI

struct AccountSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var showLogoutConfirmation = false
    @State private var isLoggingOut = false
    @State private var showAboutApp = false
    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showFeedbackForm = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var showDeleteAccountError = false
    
    var body: some View {
        NavigationView {
            List {
                // このアプリについて
                Section {
                    HStack {
                        Label("このアプリについて", systemImage: "info.circle")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showAboutApp = true
                    }
                }
                
                // 利用規約・プライバシーポリシー
                Section {
                    HStack {
                        Label("利用規約", systemImage: "doc.text")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showTermsOfService = true
                    }

                    HStack {
                        Label("プライバシーポリシー", systemImage: "lock.shield")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showPrivacyPolicy = true
                    }
                }

                // サポート
                Section {
                    HStack {
                        Label("お問い合わせ", systemImage: "envelope")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showFeedbackForm = true
                    }
                }
                
                // アカウント管理
                Section {
                    Button(action: {
                        showLogoutConfirmation = true
                    }) {
                        HStack {
                            Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }

                    // アカウント削除（プレースホルダー）
                    Button(action: {
                        showDeleteAccountConfirmation = true
                    }) {
                        HStack {
                            Label("アカウントを削除", systemImage: "trash")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("アカウント設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .alert("ログアウトしますか？", isPresented: $showLogoutConfirmation) {
                Button("キャンセル", role: .cancel) { }
                Button("ログアウト", role: .destructive) {
                    Task {
                        await performLogout()
                    }
                }
            } message: {
                Text("ログアウトすると、再度ログインが必要になります。")
            }
            .alert("アカウントを削除しますか？", isPresented: $showDeleteAccountConfirmation) {
                Button("キャンセル", role: .cancel) { }
                Button("削除", role: .destructive) {
                    Task {
                        await performDeleteAccount()
                    }
                }
            } message: {
                Text("アカウントを削除すると、すべてのデータが完全に削除されます。この操作は取り消せません。")
            }
            .alert("削除エラー", isPresented: $showDeleteAccountError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteAccountError ?? "アカウント削除に失敗しました")
            }
            .overlay {
                if isLoggingOut || isDeletingAccount {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .overlay {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                                Text(isDeletingAccount ? "アカウント削除中..." : "ログアウト中...")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16))
                            }
                            .padding(40)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(12)
                        }
                }
            }
            .sheet(isPresented: $showAboutApp) {
                AboutAppView()
            }
            .sheet(isPresented: $showTermsOfService) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showFeedbackForm) {
                FeedbackFormView(context: .general)
                    .environmentObject(userAccountManager)
            }
        }
    }
    
    private func performLogout() async {
        isLoggingOut = true

        // Supabaseからサインアウト
        await userAccountManager.signOut()

        // authStateが.guestになるまで待機
        // MainAppViewで自動的に初期画面に遷移する
        do {
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
        } catch {
            print("待機エラー: \(error)")
        }

        isLoggingOut = false
        dismiss()
    }

    private func performDeleteAccount() async {
        isDeletingAccount = true

        guard let userId = userAccountManager.currentUser?.profile?.userId else {
            print("❌ ユーザーIDが取得できません")
            deleteAccountError = "ユーザー情報が見つかりません"
            isDeletingAccount = false
            showDeleteAccountError = true
            return
        }

        do {
            // NetworkManagerを必要な時にだけ作成（軽量化）
            let networkManager = NetworkManager(userAccountManager: userAccountManager, deviceManager: deviceManager)

            // 管理画面APIでアカウント削除
            try await networkManager.deleteAccount(userId: userId)

            print("✅ アカウント削除完了 - ログアウト処理を開始")

            // Supabaseからサインアウト
            await userAccountManager.signOut()

            // 画面を閉じる
            isDeletingAccount = false
            dismiss()

        } catch {
            print("❌ アカウント削除エラー: \(error)")
            deleteAccountError = error.localizedDescription
            isDeletingAccount = false
            showDeleteAccountError = true
        }
    }
}

#Preview {
    let deviceManager = DeviceManager()
    let userAccountManager = UserAccountManager(deviceManager: deviceManager)

    return AccountSettingsView()
        .environmentObject(userAccountManager)
        .environmentObject(deviceManager)
}