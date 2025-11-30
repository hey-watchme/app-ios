//
//  MonthlyDetailView.swift
//  ios_watchme_v9
//
//  Monthly分析の詳細ページ（モックアップ）
//

import SwiftUI

struct MonthlyDetailView: View {
    let deviceId: String
    let monthStartDate: String

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Placeholder content
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 64))
                            .foregroundColor(.accentPurple)

                        Text("Monthly分析の詳細")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("ここにMonthly分析の詳細が入ります")
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
                                Text("Month Start Date:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(monthStartDate)
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
                                Label("月の期間（2025年11月）", systemImage: "calendar")
                                Label("月のサマリー（summary）", systemImage: "text.alignleft")
                                Label("印象的なイベント5件", systemImage: "star.fill")
                                Label("Daily vibe_scoreグラフ（30日分）", systemImage: "chart.bar.fill")
                                Label("各日のサマリー一覧（スクロール）", systemImage: "list.bullet")
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
            .navigationTitle("Monthly分析")
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
