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
    @EnvironmentObject var dataManager: SupabaseDataManager
    @State private var showAccountSettings = false  // アカウント設定画面
    @State private var showUpgradeAccount = false  // 匿名アップグレード画面
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
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
                                    .background(Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [Color.black.opacity(0.10), Color.black.opacity(0.03)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
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
                                    
                                    // 名前（判定ロジックと表示を一致させる）
                                    if userAccountManager.isAnonymousUser {
                                        Text("ゲストユーザー")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    } else if let profile = userAccountManager.currentUser?.profile,
                                              let name = profile.name, !name.isEmpty {
                                        Text(name)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    } else {
                                        Text("ユーザー")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    }

                                    // ユーザーステータス
                                    Text(userAccountManager.userStatusLabel)
                                        .font(.caption)
                                        .foregroundColor(Color(white: 0.56))
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
                            // 全権限モード: タップでアバター編集可能（共通の編集部品）
                            EditableAvatarView(
                                type: .user,
                                entityId: userAccountManager.effectiveUserId,
                                avatarUrl: userAccountManager.currentUser?.profile?.avatarUrl,
                                size: 100
                            )
                            .environmentObject(userAccountManager)
                            .padding(.leading, 20)
                            .padding(.top, 130)  // バナーの下端付近に配置（180 - 50 = 130）
                        } else {
                            // 閲覧専用モード: アバター編集不可
                            ZStack(alignment: .bottomTrailing) {
                                AvatarView(userId: nil, size: 100, avatarUrl: nil)
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
                            let isAnonymous = userAccountManager.isAnonymousUser
                            let displayName: String = {
                                if isAnonymous { return "ゲストユーザー" }
                                if let name = user.profile?.name, !name.isEmpty { return name }
                                return "未設定"
                            }()
                            let displayNameColor: Color = (displayName == "未設定") ? Color(white: 0.56) : .primary

                            // 名前
                            InfoListRow(label: "名前", value: displayName, valueColor: displayNameColor)

                            // メールアドレス（匿名は常に未設定表示）
                            let displayEmail = (isAnonymous || user.email.isEmpty) ? "未設定" : user.email
                            let emailColor: Color = (displayEmail == "未設定") ? Color(white: 0.56) : .primary
                            InfoListRow(label: "メールアドレス", value: displayEmail, valueColor: emailColor)

                            // ニュースレター配信設定
                            if let profile = user.profile {
                                // ニュースレター設定切り替え（匿名ユーザーは無効化）
                                VStack(spacing: 0) {
                                    HStack {
                                        Text("ニュースレター配信")
                                            .font(.subheadline)
                                            .foregroundColor(Color(white: 0.56))

                                        Spacer()

                                        if let newsletter = profile.newsletter {
                                            Toggle("", isOn: Binding(
                                                get: { newsletter },
                                                set: { newValue in
                                                    userAccountManager.updateUserProfile(newsletterSubscription: newValue)
                                                }
                                            ))
                                            .labelsHidden()
                                            .disabled(userAccountManager.isAnonymousUser)
                                        } else {
                                            // 未設定の場合はデフォルトでfalse
                                            Toggle("", isOn: Binding(
                                                get: { false },
                                                set: { newValue in
                                                    userAccountManager.updateUserProfile(newsletterSubscription: newValue)
                                                }
                                            ))
                                            .labelsHidden()
                                            .disabled(userAccountManager.isAnonymousUser)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)

                                    Divider()
                                        .background(Color(.separator))
                                }

                                // 研究への協力（オプトイン。ゲストには出さない）
                                if !isAnonymous {
                                    ResearchConsentRow(store: ResearchConsentStore.shared)
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
                            InfoListRow(label: "名前", value: "未設定", valueColor: Color(white: 0.56))
                            InfoListRow(label: "メールアドレス", value: "未設定", valueColor: Color(white: 0.56))

                            // ニュースレター配信（無効化されたトグル）
                            VStack(spacing: 0) {
                                HStack {
                                    Text("ニュースレター配信")
                                        .font(.subheadline)
                                        .foregroundColor(Color(white: 0.56))

                                    Spacer()

                                    Toggle("", isOn: .constant(false))
                                        .labelsHidden()
                                        .disabled(true)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)

                                Divider()
                                    .background(Color(.separator))
                            }

                            InfoListRow(label: "会員登録日", value: "未設定", valueColor: Color(white: 0.56))
                            InfoListRow(label: "ユーザーID", value: "未設定", showDivider: false, valueColor: Color(white: 0.56))
                        }
                    }

                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // 匿名ユーザーの場合「アカウント登録」ボタンを表示
                if userAccountManager.isAnonymousUser {
                    Text("ゲストユーザーはログアウトすると、データが失われる可能性があります。")
                        .font(.caption)
                        .foregroundColor(Color.safeColor("WarningColor"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)

                    Button(action: {
                        showUpgradeAccount = true
                    }) {
                        Text("アカウント登録")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.accentTeal)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    .padding(.bottom, 20)
                }

                Spacer()

            }
        }
        }
        .edgesIgnoringSafeArea(.top)  // バナーを画面上部まで広げる
        .navigationBarHidden(true)  // ナビゲーションバーを完全に非表示
        .sheet(isPresented: $showAccountSettings) {
            AccountSettingsView()
                .environmentObject(userAccountManager)
                .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showUpgradeAccount) {
            UpgradeAccountView()
                .environmentObject(userAccountManager)
                .environmentObject(ToastManager.shared)
                .preferredColorScheme(.light)
        }
        .preferredColorScheme(.light)
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
    let isoWithFraction = ISO8601DateFormatter()
    isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]

    // ISO8601形式でパースを試行（小数秒あり/なし）
    if let date = isoWithFraction.date(from: dateString) ?? iso.date(from: dateString) {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    // フォールバック: 別の形式を試行
    let fallbackFormatter = DateFormatter()
    fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
    fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
    if let date = fallbackFormatter.date(from: dateString) {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    // タイムゾーンなしのISO（例: 2026-03-14T09:17:55）
    let noTzFormatter = DateFormatter()
    noTzFormatter.locale = Locale(identifier: "en_US_POSIX")
    noTzFormatter.timeZone = TimeZone.current
    noTzFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    if let date = noTzFormatter.date(from: dateString) {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    // 最終的にフォーマットできない場合は元の文字列を返す
    return dateString
}
