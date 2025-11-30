//
//  DailyReportView.swift
//  ios_watchme_v9
//
//  Daily分析の推移レポート（モックアップ）
//

import SwiftUI

struct DailyReportView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager

    // Period selection
    enum ReportPeriod: String, CaseIterable {
        case week = "過去7日間"
        case month = "過去30日間"
        case threeMonths = "過去90日間"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            }
        }
    }

    @State private var selectedPeriod: ReportPeriod = .week
    @State private var dailySummaries: [DashboardSummary] = []
    @State private var isLoading = false

    @State private var showDailyDetailSheet = false
    @State private var selectedDailyDate: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Period selector
                periodSelector
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                // Period display (e.g., "2025年11月24日 〜 11月30日")
                periodDisplayText
                    .padding(.horizontal, 20)

                if isLoading {
                    ProgressView()
                        .padding()
                } else if dailySummaries.isEmpty {
                    Text("この期間のデータがありません")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    // Graph section
                    graphSection
                        .padding(.horizontal, 20)

                    // Daily summary list
                    dailySummaryList
                        .padding(.horizontal, 20)
                }

                Spacer()
                    .frame(height: 40)
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showDailyDetailSheet) {
            if let deviceId = deviceManager.selectedDeviceID {
                DailyDetailView(deviceId: deviceId, localDate: selectedDailyDate)
            }
        }
        .task {
            await loadData()
        }
        .onChange(of: selectedPeriod) { _, _ in
            Task {
                await loadData()
            }
        }
        .onChange(of: deviceManager.selectedDeviceID) { _, _ in
            Task {
                await loadData()
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let deviceId = deviceManager.selectedDeviceID else {
            dailySummaries = []
            return
        }

        isLoading = true

        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .day, value: -(selectedPeriod.days - 1), to: today) ?? today

        let results = await dataManager.fetchDailyResultsRange(
            deviceId: deviceId,
            startDate: startDate,
            endDate: today
        )

        dailySummaries = results
        isLoading = false
    }

    // MARK: - Period Selector (Dropdown Menu Style)

    private var periodSelector: some View {
        Menu {
            ForEach(ReportPeriod.allCases, id: \.self) { period in
                Button(action: {
                    selectedPeriod = period
                }) {
                    HStack {
                        Text(period.rawValue)
                        if selectedPeriod == period {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text("期間：")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(selectedPeriod.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Period Display Text

    private var periodDisplayText: some View {
        Text(getPeriodDisplayText())
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func getPeriodDisplayText() -> String {
        let calendar = Calendar.current
        let today = Date()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        formatter.locale = Locale(identifier: "ja_JP")

        let endDateString = formatter.string(from: today)

        let startDate = calendar.date(byAdding: .day, value: -(selectedPeriod.days - 1), to: today) ?? today

        formatter.dateFormat = "M月d日"
        let startDateString = formatter.string(from: startDate)

        return "\(startDateString) 〜 \(endDateString)"
    }

    // MARK: - Graph Section

    private var graphSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("気分の推移")
                .font(.title3)
                .fontWeight(.semibold)

            vibeGraph
                .frame(height: 200)
        }
    }

    private var vibeGraph: some View {
        ZStack {
            // White background with border (same as ModernVibeCard)
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.safeColor("BorderLight").opacity(0.1), lineWidth: 1)

            GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(dailySummaries.indices, id: \.self) { index in
                        barView(for: dailySummaries[index], width: barWidth(count: dailySummaries.count, geometry: geometry))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }

    private func barView(for summary: DashboardSummary, width: CGFloat) -> some View {
        VStack(spacing: 4) {
            let score = Double(summary.averageVibe ?? 0)
            RoundedRectangle(cornerRadius: 4)
                .fill(vibeScoreGradient(score))
                .frame(width: width, height: max(CGFloat(score) * 1.5, 8))

            Text(formatDateLabel(summary.date))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func barWidth(count: Int, geometry: GeometryProxy) -> CGFloat {
        let totalSpacing = CGFloat(count - 1) * 8
        return (geometry.size.width - totalSpacing - 32) / CGFloat(count)
    }

    private func vibeScoreGradient(_ score: Double) -> LinearGradient {
        if score > 30 {
            return LinearGradient(
                colors: [
                    Color(red: 0, green: 1, blue: 0.53),
                    Color(red: 0, green: 0.85, blue: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 1, green: 0.42, blue: 0.42),
                    Color(red: 0.79, green: 0.16, blue: 0.16)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        }
    }

    // MARK: - Daily Summary List

    private var dailySummaryList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("日次サマリー")
                .font(.title3)
                .fontWeight(.semibold)

            ForEach(dailySummaries, id: \.date) { summary in
                dailySummaryRow(summary: summary)
            }
        }
    }

    private func dailySummaryRow(summary: DashboardSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatDate(summary.date))
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Text(String(format: "%.1f", Double(summary.averageVibe ?? 0)))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(vibeScoreColor(Double(summary.averageVibe ?? 0)))
            }

            if let insights = summary.insights, !insights.isEmpty {
                Text(insights)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Button(action: {
                selectedDailyDate = summary.date
                showDailyDetailSheet = true
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
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Helpers

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        formatter.dateFormat = "M/d (E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func formatDateLabel(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else {
            return String(dateString.suffix(2))
        }

        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        return String(day)
    }

    private func vibeScoreColor(_ score: Double) -> Color {
        if score >= 30 {
            return .green
        } else if score >= 0 {
            return .blue
        } else if score >= -30 {
            return .orange
        } else {
            return .red
        }
    }
}
