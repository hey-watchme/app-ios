//
//  SpotDetailView.swift
//  ios_watchme_v9
//
//  Spot分析の詳細ページ（モックアップ）
//

import SwiftUI

struct SpotDetailView: View {
    let deviceId: String
    let recordedAt: String

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Placeholder content
                    VStack(spacing: 16) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.accentPurple)

                        Text("Spot分析の詳細")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("ここにSpot分析の詳細が入ります")
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
                                Text("Recorded At:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(recordedAt)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
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
            .navigationTitle("Spot分析")
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
