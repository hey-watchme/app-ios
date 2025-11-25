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
    let userAccountManager: UserAccountManager
    @State private var showAccountSettings = false  // アカウント設定画面
    @State private var showingAvatarPicker = false  // アバター選択画面
    @State private var showSignUp = false  // 新規ユーザー登録画面
    @Environment(\.dismiss) private var dismiss
    
    // Avatar ViewModel
    @StateObject private var avatarViewModel = AvatarUploadViewModel(
        avatarType: .user,
        entityId: "",  // 実際のIDはonAppearで設定
        authToken: nil
    )
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // ヘッダー部分（バナーとプロフィール情報）
                ZStack(alignment: .topLeading) {
                    // 背景のコンテナ
                    VStack(spacing: 0) {
                        // バナー画像とアカウント設定ボタン
                        ZStack(alignment: .topTrailing) {
                            Image("DefaultBanner")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .clipped()
                            
                            // アカウント設定ボタンをキービジュアル内の右上に配置
                            Button(action: {
                                showAccountSettings = true
                            }) {
                                Text("アカウント設定")
                                    .font(.system(size: 14))
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.95))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .cornerRadius(20)
                                    .foregroundColor(.primary)
                            }
                            .padding(.top, 50)  // ステータスバーを考慮
                            .padding(.trailing, 20)
                        }
                        
                        // プロフィール情報エリア（白い背景）
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .top) {
                                // 左側：アバターのスペース + 名前とID
                                VStack(alignment: .leading, spacing: 4) {
                                    // アバター分のスペース
                                    Spacer()
                                        .frame(height: 60)
                                    
                                    // 名前
                                    if let profile = userAccountManager.currentUser?.profile,
                                       let name = profile.name, !name.isEmpty {
                                        Text(name)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    } else {
                                        Text("ゲストユーザー")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    }

                                    // ユーザーステータス
                                    Text(userAccountManager.userStatusLabel)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                }
                                .padding(.leading, 20)
                                
                                Spacer()
                            }
                            .padding(.bottom, 20)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                    }
                    
                    // アバターを最前面に配置（権限に応じて編集可否が変わる）
                    Group {
                        if userAccountManager.authState.canEditAvatar {
                            // 全権限モード: タップでアバター編集可能
                            Button(action: {
                                showingAvatarPicker = true
                            }) {
                                ZStack(alignment: .bottomTrailing) {
                                    // ✅ CLAUDE.md: public.usersのuser_idを使用
                                    AvatarView(userId: userAccountManager.currentUser?.profile?.userId, size: 100)
                                        .overlay(
                                            Circle()
                                                .stroke(Color(.systemBackground), lineWidth: 4)
                                        )

                                    // カメラアイコンを追加
                                    Circle()
                                        .fill(Color.black)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(.white)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color(.systemBackground), lineWidth: 2)
                                        )
                                }
                            }
                            .padding(.leading, 20)
                            .padding(.top, 130)  // バナーの下端付近に配置（180 - 50 = 130）
                        } else {
                            // 閲覧専用モード: アバター編集不可
                            ZStack(alignment: .bottomTrailing) {
                                AvatarView(userId: nil, size: 100)
                                    .overlay(
                                        Circle()
                                            .stroke(Color(.systemBackground), lineWidth: 4)
                                    )
                                // カメラアイコンは表示しない
                            }
                            .padding(.leading, 20)
                            .padding(.top, 130)
                        }
                    }
                }
                
                // ユーザー情報セクション
                VStack(spacing: 20) {
                    // ユーザーアカウント情報（リストスタイル）
                    InfoListSection(title: "ユーザーアカウント情報") {
                        if let user = userAccountManager.currentUser {
                            // ログインユーザー
                            // 名前
                            if let profile = user.profile, let name = profile.name {
                                InfoListRow(label: "名前", value: name)
                            }

                            // メールアドレス
                            InfoListRow(label: "メールアドレス", value: user.email)

                            // ニュースレター配信設定
                            if let profile = user.profile {
                                // ニュースレター設定切り替え
                                VStack(spacing: 0) {
                                    HStack {
                                        Text("ニュースレター配信")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)

                                        Spacer()

                                        if let newsletter = profile.newsletter {
                                            Toggle("", isOn: Binding(
                                                get: { newsletter },
                                                set: { newValue in
                                                    userAccountManager.updateUserProfile(newsletterSubscription: newValue)
                                                }
                                            ))
                                            .labelsHidden()
                                        } else {
                                            // 未設定の場合はデフォルトでfalse
                                            Toggle("", isOn: Binding(
                                                get: { false },
                                                set: { newValue in
                                                    userAccountManager.updateUserProfile(newsletterSubscription: newValue)
                                                }
                                            ))
                                            .labelsHidden()
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)

                                    Divider()
                                        .background(Color(.systemGray4))
                                }

                                // 会員登録日
                                if let createdAt = profile.createdAt {
                                    let formattedDate = formatDate(createdAt)
                                    InfoListRow(label: "会員登録日", value: formattedDate)
                                }
                            }

                            // ユーザーID（最後なので罫線なし）
                            InfoListRow(label: "ユーザーID", value: user.id, showDivider: false)
                        } else {
                            // ゲストユーザー: ログインユーザーと同じ項目を表示（すべて「未設定」）
                            InfoListRow(label: "名前", value: "未設定", valueColor: .secondary)
                            InfoListRow(label: "メールアドレス", value: "未設定", valueColor: .secondary)

                            // ニュースレター配信（無効化されたトグル）
                            VStack(spacing: 0) {
                                HStack {
                                    Text("ニュースレター配信")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Toggle("", isOn: .constant(false))
                                        .labelsHidden()
                                        .disabled(true)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)

                                Divider()
                                    .background(Color(.systemGray4))
                            }

                            InfoListRow(label: "会員登録日", value: "未設定", valueColor: .secondary)
                            InfoListRow(label: "ユーザーID", value: "未設定", showDivider: false, valueColor: .secondary)
                        }
                    }

                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // 匿名ユーザーの場合「アカウント登録」ボタンを表示
                if userAccountManager.isAnonymousUser {
                    Button(action: {
                        showSignUp = true
                    }) {
                        Text("アカウント登録")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    .padding(.bottom, 20)
                }

                Spacer()

            }
        }
        .edgesIgnoringSafeArea(.top)  // バナーを画面上部まで広げる
        .navigationBarHidden(true)  // ナビゲーションバーを完全に非表示
        .sheet(isPresented: $showAccountSettings) {
            AccountSettingsView()
                .environmentObject(userAccountManager)
        }
        .sheet(isPresented: $showingAvatarPicker) {
            NavigationStack {
                AvatarPickerView(
                    viewModel: avatarViewModel,
                    // ✅ CLAUDE.md: public.usersのuser_idを使用
                    currentAvatarURL: userAccountManager.currentUser?.profile?.userId != nil ? AWSManager.shared.getAvatarURL(type: "users", id: userAccountManager.currentUser!.profile!.userId) : nil
                )
                .navigationTitle("アバターを選択")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            showingAvatarPicker = false
                            avatarViewModel.reset()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
                .environmentObject(userAccountManager)
        }
        .onAppear {
            // ViewModelの初期化
            // ✅ CLAUDE.md: public.usersのuser_idを使用
            if let userId = userAccountManager.currentUser?.profile?.userId {
                avatarViewModel.entityId = userId
                avatarViewModel.authToken = userAccountManager.getAccessToken()
            } else {
                print("❌ ユーザープロファイルが読み込まれていません")
            }
        }
    }
    
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
        return newsletter ? Color.safeColor("SuccessColor") : .secondary
    } else {
        return Color.safeColor("WarningColor")
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