//
//  NotificationView.swift
//  ios_watchme_v9
//
//  通知画面の実装
//

import SwiftUI

struct NotificationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    
    @State private var notifications: [Notification] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    // ローディング表示
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("通知を読み込み中...")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    // エラー表示
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color.safeColor("WarningColor"))
                        Text("通知の取得に失敗しました")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("再試行") {
                            Task {
                                await loadNotifications()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.safeColor("PrimaryActionColor"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if notifications.isEmpty {
                    // 通知がない場合
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(Color.safeColor("BorderLight"))
                        Text("通知はありません")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("新しい通知が届くとここに表示されます")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 通知リスト
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(notifications) { notification in
                                NotificationRow(
                                    notification: notification,
                                    onTap: {
                                        Task {
                                            await markAsRead(notification)
                                        }
                                    }
                                )
                                Divider()
                            }
                        }
                    }
                }
            }
            .navigationTitle("通知")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                if !notifications.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("すべて既読") {
                            Task {
                                await markAllAsRead()
                            }
                        }
                        .font(.footnote)
                    }
                }
            }
        }
        .task {
            await loadNotifications()
        }
    }
    
    // 通知を読み込む
    private func loadNotifications() async {
        isLoading = true
        errorMessage = nil

        // ✅ CLAUDE.md: public.usersのuser_idを使用
        guard let userId = userAccountManager.currentUser?.profile?.userId else {
            errorMessage = "ユーザー情報が取得できません"
            isLoading = false
            return
        }

        notifications = await dataManager.fetchNotifications(userId: userId)
        isLoading = false
    }
    
    // 通知を既読にする
    private func markAsRead(_ notification: Notification) async {
        // ✅ CLAUDE.md: public.usersのuser_idを使用
        guard let userId = userAccountManager.currentUser?.profile?.userId else { return }
        
        // UIを即座に更新
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
        }
        
        // バックエンドに既読を送信
        let isGlobal = notification.type == NotificationType.global.rawValue
        do {
            try await dataManager.markNotificationAsRead(
                notificationId: notification.id,
                userId: userId,
                isGlobal: isGlobal
            )
        } catch {
            print("❌ Failed to mark notification as read: \(error)")
        }
    }
    
    // すべての通知を既読にする
    private func markAllAsRead() async {
        // ✅ CLAUDE.md: public.usersのuser_idを使用
        guard let userId = userAccountManager.currentUser?.profile?.userId else { return }
        
        // UIを即座に更新
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        
        // バックエンドに既読を送信
        do {
            try await dataManager.markAllNotificationsAsRead(userId: userId)
        } catch {
            print("❌ Failed to mark all notifications as read: \(error)")
        }
    }
}

// 通知行のView
struct NotificationRow: View {
    let notification: Notification
    let onTap: () async -> Void
    
    var body: some View {
        Button(action: {
            Task {
                await onTap()
            }
        }) {
            HStack(alignment: .top, spacing: 12) {
                // 通知アイコン
                ZStack {
                    Circle()
                        .fill(notification.isRead ? Color.gray.opacity(0.1) : notificationColor.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: notification.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(notification.isRead ? .gray : notificationColor)
                }
                
                // 通知内容
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        // タイトルとタイプバッジ
                        Text(notification.title)
                            .font(.subheadline)
                            .fontWeight(notification.isRead ? .regular : .semibold)
                            .foregroundColor(notification.isRead ? .secondary : .primary)
                        
                        // 通知タイプバッジ
                        if notification.type == NotificationType.global.rawValue {
                            Text("全体")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        Text(notification.relativeTimeString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(notification.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // 未読インジケーター
                if !notification.isRead {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(notification.isRead ? Color(.systemBackground) : Color.safeColor("PrimaryActionColor").opacity(0.03))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var notificationColor: Color {
        switch notification.type {
        case NotificationType.global.rawValue:
            return Color.purple
        case NotificationType.event.rawValue:
            return Color.safeColor("PrimaryActionColor")
        case NotificationType.personal.rawValue:
            return Color.blue
        default:
            return Color.safeColor("PrimaryActionColor")
        }
    }
}