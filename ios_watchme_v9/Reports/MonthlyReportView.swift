//
//  MonthlyReportView.swift
//  ios_watchme_v9
//
//  Monthly analysis list view (mockup)
//

import SwiftUI

struct MonthlyReportView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager

    // Mock data
    let mockMonthlySummaries: [(month: String, summary: String, eventCount: Int)] = [
        ("2025-11", "今月は全体的に安定しており、家族との時間が多く観測された。", 12),
        ("2025-10", "月の前半は静かだったが、後半に活発な会話が増加した。", 15),
        ("2025-09", "感情の起伏が大きく、複数の重要なイベントが記録された。", 18),
        ("2025-08", "夏休み期間で環境音が多様化し、新しいパターンが見られた。", 20)
    ]

    @State private var showMonthlyDetailSheet = false
    @State private var selectedMonth: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Monthly summary list
                monthlySummaryList
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                Spacer()
                    .frame(height: 40)
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showMonthlyDetailSheet) {
            if let deviceId = deviceManager.selectedDeviceID {
                MonthlyDetailView(deviceId: deviceId, monthStartDate: selectedMonth)
            }
        }
    }

    // MARK: - Monthly Summary List

    private var monthlySummaryList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("月次分析")
                .font(.title3)
                .fontWeight(.semibold)

            ForEach(mockMonthlySummaries, id: \.month) { monthly in
                monthlySummaryRow(
                    month: monthly.month,
                    summary: monthly.summary,
                    eventCount: monthly.eventCount
                )
            }
        }
    }

    private func monthlySummaryRow(month: String, summary: String, eventCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formatMonth(month))
                .font(.headline)
                .foregroundColor(.primary)

            Text(summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Text("印象的イベント: \(eventCount)件")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    selectedMonth = month
                    showMonthlyDetailSheet = true
                }) {
                    HStack {
                        Text("詳細を見る")
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.accentPurple)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Helpers

    private func formatMonth(_ monthString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        guard let date = formatter.date(from: monthString) else {
            return monthString
        }

        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}
