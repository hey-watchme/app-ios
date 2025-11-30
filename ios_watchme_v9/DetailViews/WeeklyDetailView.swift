//
//  WeeklyDetailView.swift
//  ios_watchme_v9
//
//  Weekly分析の詳細ページ（モックアップ）
//

import SwiftUI

struct WeeklyDetailView: View {
    let deviceId: String
    let weekStartDate: String

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Placeholder content
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 64))
                            .foregroundColor(.accentPurple)

                        Text("Weekly分析の詳細")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("ここにWeekly分析の詳細が入ります")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Divider()
                            .padding(.vertical)

                        // Debug info
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Device ID:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(deviceId)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Text("Week Start Date:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(weekStartDate)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )

                        // Future implementation preview
                        VStack(alignment: .leading, spacing: 12) {
                            Text("実装予定の内容:")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            VStack(alignment: .leading, spacing: 6) {
                                Label("週の期間（月曜〜日曜）", systemImage: "calendar")
                                Label("週のサマリー（summary）", systemImage: "text.alignleft")
                                Label("印象的なイベント5件", systemImage: "star.fill")
                                Label("Daily vibe_scoreグラフ（7日分）", systemImage: "chart.bar.fill")
                                Label("各日のサマリー一覧", systemImage: "list.bullet")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )

                        Text("📝 次フェーズでデータ取得を実装")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top)
                    }
                    .padding()
                }
            }
            .navigationTitle("Weekly分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}
