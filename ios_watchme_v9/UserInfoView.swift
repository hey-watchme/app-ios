//
//  UserInfoView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/08/02.
//

import SwiftUI
import PhotosUI

// MARK: - ユーザー情報ビュー
struct UserInfoView: View {
    let authManager: SupabaseAuthManager
    @Binding var showLogoutConfirmation: Bool
    @State private var showAvatarPicker = false
    @State private var isUploadingAvatar = false
    @State private var avatarUploadError: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    // ViewModelを初期化
    @StateObject private var avatarViewModel = AvatarUploadViewModel(
        avatarType: .user,
        entityId: "",  // 実際のIDはonAppearで設定
        authToken: nil
    )
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 24) {
                // ユーザーアバター編集可能なセクション
                VStack(spacing: 12) {
                    AvatarView(userId: authManager.currentUser?.id)
                        .padding(.top, 20)
                    
                    Button(action: {
                        showAvatarPicker = true
                    }) {
                        Label("アバターを編集", systemImage: "pencil.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .disabled(isUploadingAvatar)
                    
                    if isUploadingAvatar {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    }
                    
                    if let error = avatarUploadError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                // ユーザー情報セクション
                VStack(spacing: 16) {
                    // ユーザーアカウント情報
                    InfoSection(title: "ユーザーアカウント情報") {
                        if let user = authManager.currentUser {
                            // 名前（profile.nameから取得）
                            if let profile = user.profile, let name = profile.name {
                                InfoRowTwoLine(label: "名前", value: name, icon: "person.fill")
                            }
                            
                            InfoRowTwoLine(label: "メールアドレス", value: user.email, icon: "envelope.fill")
                            
                            // ニュースレター配信設定（会員登録日より上に配置）
                            if let profile = user.profile {
                                
                                // ニュースレター設定切り替え
                                HStack {
                                    Image(systemName: "envelope.badge")
                                        .foregroundColor(.blue)
                                        .frame(width: 20)
                                    
                                    Text("ニュースレター配信")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    if let newsletter = profile.newsletter {
                                        Toggle("", isOn: Binding(
                                            get: { newsletter },
                                            set: { newValue in
                                                authManager.updateUserProfile(newsletterSubscription: newValue)
                                            }
                                        ))
                                        .labelsHidden()
                                    } else {
                                        // 未設定の場合はデフォルトでfalse
                                        Toggle("", isOn: Binding(
                                            get: { false },
                                            set: { newValue in
                                                authManager.updateUserProfile(newsletterSubscription: newValue)
                                            }
                                        ))
                                        .labelsHidden()
                                    }
                                }
                                
                                // 会員登録日
                                if let createdAt = profile.createdAt {
                                    let formattedDate = formatDate(createdAt)
                                    InfoRow(label: "会員登録日", value: formattedDate, icon: "calendar.badge.plus")
                                }
                            }
                            
                            InfoRowTwoLine(label: "ユーザーID", value: user.id, icon: "person.text.rectangle.fill")
                        } else {
                            InfoRow(label: "状態", value: "ログインしていません", icon: "exclamationmark.triangle.fill", valueColor: .red)
                        }
                    }
                    
                }
                
                Spacer()
                
                // ログアウトボタン
                if authManager.isAuthenticated {
                    Button(action: {
                        dismiss()
                        // シートが完全に閉じてからダイアログを表示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showLogoutConfirmation = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                            Text("ログアウト")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("マイページ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showAvatarPicker) {
            NavigationView {
                AvatarPickerView(
                    viewModel: avatarViewModel,
                    currentAvatarURL: getAvatarURL()
                )
                .navigationTitle("アバターを選択")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            showAvatarPicker = false
                            avatarViewModel.reset()
                        }
                    }
                }
            }
        }
        .onAppear {
            // ViewModelの初期化
            if avatarViewModel.entityId?.isEmpty ?? true {
                avatarViewModel.entityId = authManager.currentUser?.id
                avatarViewModel.authToken = authManager.getAccessToken()
            }
        }
    }
    
    // MARK: - Avatar Helper Methods
    
    private func getAvatarURL() -> URL? {
        guard let userId = authManager.currentUser?.id else { return nil }
        return AWSManager.shared.getAvatarURL(type: "users", id: userId)
    }
    
    // uploadAvatar関数は削除（ViewModelが処理を担当）
}


// MARK: - アバタービュー

// MARK: - ヘルパー関数
private func getNewsletterStatus(_ newsletter: Bool?) -> String {
    if let newsletter = newsletter {
        return newsletter ? "ON" : "OFF"
    } else {
        return "未設定"
    }
}

private func getNewsletterStatusColor(_ newsletter: Bool?) -> Color {
    if let newsletter = newsletter {
        return newsletter ? .green : .secondary
    } else {
        return .orange
    }
}

private func formatDate(_ dateString: String) -> String {
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    // ISO8601形式でパースを試行
    if let date = isoFormatter.date(from: dateString) {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    // フォールバック: 別の形式を試行
    let fallbackFormatter = DateFormatter()
    fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
    if let date = fallbackFormatter.date(from: dateString) {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    // 最終的にフォーマットできない場合は元の文字列を返す
    return dateString
}