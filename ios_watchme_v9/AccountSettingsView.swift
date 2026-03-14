//
//  AccountSettingsView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/08/19.
//

import SwiftUI

struct AccountSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var showLogoutConfirmation = false
    @State private var isLoggingOut = false
    @State private var showAboutApp = false
    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var showDeleteAccountError = false
    @State private var showUpgradeAccount = false  // 匿名アップグレードシート
    
    var body: some View {
        NavigationView {
            List {
                #if DEBUG
                Section {
                    Button(action: {
                        UserDefaults.standard.removeObject(forKey: "has_seen_first_launch_guide")
                        UserDefaults.standard.removeObject(forKey: "has_seen_mic_tip")
                    }) {
                        HStack {
                            Label("チュートリアル表示をリセット", systemImage: "arrow.counterclockwise")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                } header: {
                    Text("デバッグ")
                } footer: {
                    Text("オンボーディング関連の表示を初回状態に戻します（端末単位）。")
                }
                .listRowBackground(Color(.systemBackground))
                #endif

                // 匿名ユーザー向けアップグレード導線（匿名認証済みユーザーのみ表示）
                if userAccountManager.isAnonymousUser {
                    Section {
                        Button(action: {
                            showUpgradeAccount = true
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("アカウント登録")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text("Googleアカウントで、現在のゲストデータをそのまま引き継げます")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundColor(Color.safeColor("AppAccentColor"))
                                    .font(.title2)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    } header: {
                        Text("ゲストモード")
                    } footer: {
                        Text("ゲストユーザーはログアウトすると、データが失われる可能性があります。通常アカウントへアップグレードして保護してください。")
                    }
                    .listRowBackground(Color(.systemBackground))
                }

                // このアプリについて
                Section {
                    HStack {
                        Label("このアプリについて", systemImage: "info.circle")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showAboutApp = true
                    }
                }
                .listRowBackground(Color(.systemBackground))
                
                // 利用規約・プライバシーポリシー
                Section {
                    HStack {
                        Label("利用規約", systemImage: "doc.text")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showTermsOfService = true
                    }

                    HStack {
                        Label("プライバシーポリシー", systemImage: "lock.shield")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showPrivacyPolicy = true
                    }
                }
                .listRowBackground(Color(.systemBackground))

                // サポート
                Section {
                    HStack {
                        Label("お問い合わせ", systemImage: "envelope")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let url = supportMailURL {
                            openURL(url)
                        }
                    }
                }
                .listRowBackground(Color(.systemBackground))
                
                // アカウント管理
                Section {
                    Button(action: {
                        showLogoutConfirmation = true
                    }) {
                        HStack {
                            Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.accentCoral)
                            Spacer()
                        }
                    }

                    // アカウント削除（プレースホルダー）
                    Button(action: {
                        showDeleteAccountConfirmation = true
                    }) {
                        HStack {
                            Label("アカウントを削除", systemImage: "trash")
                                .foregroundColor(.accentCoral)
                            Spacer()
                        }
                    }
                }
                .listRowBackground(Color(.systemBackground))
            }
            .scrollContentBackground(.automatic)
            .listStyle(.insetGrouped)
            .listRowSeparatorTint(Color(.separator))
            .navigationTitle("アカウント設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
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
                    .preferredColorScheme(.light)
            }
            .sheet(isPresented: $showTermsOfService) {
                TermsOfServiceView()
                    .preferredColorScheme(.light)
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
                    .preferredColorScheme(.light)
            }
            .sheet(isPresented: $showUpgradeAccount) {
                UpgradeAccountView()
                    .environmentObject(userAccountManager)
                    .environmentObject(ToastManager.shared)
                    .preferredColorScheme(.light)
            }
        }
        .preferredColorScheme(.light)
    }

    private var supportMailURL: URL? {
        let subject = "WatchMe お問い合わせ".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:support@hey-watch.me?subject=\(subject)")
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

        guard let userId = userAccountManager.effectiveUserId else {
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
