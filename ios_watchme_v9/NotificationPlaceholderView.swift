//
//  NotificationPlaceholderView.swift
//  ios_watchme_v9
//
//  通知画面のプレースホルダー実装
//  TODO: バックエンドの通知システムが完成したら、実際の通知取得・表示機能を実装
//

import SwiftUI

struct NotificationPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    
    // TODO: 実際の通知データモデルに置き換える
    // 現在はデモ用のダミーデータ
    @State private var demoNotifications = [
        DemoNotification(id: "1", title: "分析完了", message: "本日の感情分析が完了しました", time: "5分前", isRead: false),
        DemoNotification(id: "2", title: "録音リマインダー", message: "30分間の自動録音が開始されました", time: "1時間前", isRead: false),
        DemoNotification(id: "3", title: "週次レポート", message: "今週の活動サマリーが利用可能です", time: "昨日", isRead: true),
        DemoNotification(id: "4", title: "デバイス接続", message: "新しいデバイスが正常に接続されました", time: "2日前", isRead: true)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 開発中メッセージ
                VStack(spacing: 8) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.safeColor("WarningColor"))
                    
                    Text("通知機能は現在開発中です")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.safeColor("WarningColor").opacity(0.1))
                
                // デモ通知リスト
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(demoNotifications) { notification in
                            NotificationRow(notification: notification)
                            Divider()
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
                
                // TODO: 実装時には「すべて既読にする」機能を追加
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("すべて既読") {
                        // TODO: バックエンドAPIと連携して既読状態を更新
                        markAllAsRead()
                    }
                    .font(.footnote)
                }
            }
        }
    }
    
    private func markAllAsRead() {
        // TODO: 実際のAPI呼び出しに置き換える
        for index in demoNotifications.indices {
            demoNotifications[index].isRead = true
        }
    }
}

// デモ用の通知データモデル
// TODO: 実際のデータモデルに置き換える
struct DemoNotification: Identifiable {
    let id: String
    let title: String
    let message: String
    let time: String
    var isRead: Bool
}

// 通知行のView
struct NotificationRow: View {
    let notification: DemoNotification
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 通知アイコン
            ZStack {
                Circle()
                    .fill(notification.isRead ? Color.gray.opacity(0.1) : Color.safeColor("PrimaryActionColor").opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconName(for: notification.title))
                    .font(.system(size: 18))
                    .foregroundColor(notification.isRead ? .gray : Color.safeColor("PrimaryActionColor"))
            }
            
            // 通知内容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.subheadline)
                        .fontWeight(notification.isRead ? .regular : .semibold)
                        .foregroundColor(notification.isRead ? .secondary : .primary)
                    
                    Spacer()
                    
                    Text(notification.time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(notification.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
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
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            // TODO: 通知タップ時の詳細画面遷移を実装
            print("通知タップ: \(notification.title)")
        }
    }
    
    private func iconName(for title: String) -> String {
        // タイトルに基づいてアイコンを選択
        if title.contains("分析") {
            return "chart.line.uptrend.xyaxis"
        } else if title.contains("録音") {
            return "mic.fill"
        } else if title.contains("レポート") {
            return "doc.text.fill"
        } else if title.contains("デバイス") {
            return "iphone"
        } else {
            return "bell.fill"
        }
    }
}

// Color.safeColorは既にColor+AppColors.swiftで定義されているため、ここでは定義しない