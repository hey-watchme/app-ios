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
                            .foregroundColor(.accentTeal)

                        Text("Weekly分析の詳細")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("ここにWeekly分析の詳細が入ります")
                            .font(.body)
                            .foregroundColor(Color(white: 0.56))
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
                                    .foregroundColor(Color(white: 0.56))
                            }

                            HStack {
                                Text("Week Start Date:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(weekStartDate)
                                    .font(.caption)
                                    .foregroundColor(Color(white: 0.56))
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.darkCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
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
                            .foregroundColor(Color(white: 0.56))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.darkCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )

                        Text("📝 次フェーズでデータ取得を実装")
                            .font(.caption)
                            .foregroundColor(.accentAmber)
                            .padding(.top)
                    }
                    .padding()
                }
            }
            .background(Color.darkBase)
            .navigationTitle("Weekly分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.darkBase, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
