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
    @State private var showLogoutConfirmation = false
    @State private var isLoggingOut = false
    @State private var showAboutApp = false
    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false
    
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
                
                // ログアウト
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
            .overlay {
                if isLoggingOut {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .overlay {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                                Text("ログアウト中...")
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
        }
    }
    
    private func performLogout() async {
        isLoggingOut = true
        
        // Supabaseからサインアウト
        await userAccountManager.signOut()
        
        // 少し待機（UX向上のため）
        do {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        } catch {
            print("待機エラー: \(error)")
        }
        
        isLoggingOut = false
        dismiss()
    }
}

#Preview {
    let deviceManager = DeviceManager()
    let userAccountManager = UserAccountManager(deviceManager: deviceManager)
    
    return AccountSettingsView()
        .environmentObject(userAccountManager)
}