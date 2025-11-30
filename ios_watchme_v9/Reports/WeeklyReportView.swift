//
//  WeeklyReportView.swift
//  ios_watchme_v9
//
//  Weekly analysis list view (mockup)
//

import SwiftUI

struct WeeklyReportView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager

    // Mock data
    let mockWeeklySummaries: [(weekStart: String, weekEnd: String, summary: String, eventCount: Int)] = [
        ("2025-11-24", "2025-11-30", "今週は家族との会話が活発で、ポジティブな感情が多く観測された。", 5),
        ("2025-11-17", "2025-11-23", "週の前半は静かだったが、後半に感情変化が活発化した。", 5),
        ("2025-11-10", "2025-11-16", "全体的に穏やかな週で、大きな変動は見られなかった。", 3),
        ("2025-11-03", "2025-11-09", "感情の起伏が大きく、複数のバースト イベントが記録された。", 7)
    ]

    @State private var showWeeklyDetailSheet = false
    @State private var selectedWeekStart: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Weekly summary list
                weeklySummaryList
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                Spacer()
                    .frame(height: 40)
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showWeeklyDetailSheet) {
            if let deviceId = deviceManager.selectedDeviceID {
                WeeklyDetailView(deviceId: deviceId, weekStartDate: selectedWeekStart)
            }
        }
    }

    // MARK: - Weekly Summary List

    private var weeklySummaryList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("週次分析")
                .font(.title3)
                .fontWeight(.semibold)

            ForEach(mockWeeklySummaries, id: \.weekStart) { weekly in
                weeklySummaryRow(
                    weekStart: weekly.weekStart,
                    weekEnd: weekly.weekEnd,
                    summary: weekly.summary,
                    eventCount: weekly.eventCount
                )
            }
        }
    }

    private func weeklySummaryRow(weekStart: String, weekEnd: String, summary: String, eventCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formatWeekPeriod(start: weekStart, end: weekEnd))
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
                    selectedWeekStart = weekStart
                    showWeeklyDetailSheet = true
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

    private func formatWeekPeriod(start: String, end: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let startDate = formatter.date(from: start),
              let endDate = formatter.date(from: end) else {
            return "\(start) 〜 \(end)"
        }

        let calendar = Calendar.current
        let month = calendar.component(.month, from: startDate)
        let weekOfMonth = calendar.component(.weekOfMonth, from: startDate)

        formatter.dateFormat = "M/d"
        formatter.locale = Locale(identifier: "ja_JP")
        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: endDate)

        return "\(month)月第\(weekOfMonth)週（\(startStr)〜\(endStr)）"
    }
}
