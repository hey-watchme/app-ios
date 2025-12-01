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

        #if DEBUG
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        print("📅 [DailyReport] Selected period: \(selectedPeriod.rawValue)")
        print("📅 [DailyReport] Days requested: \(selectedPeriod.days)")
        print("📅 [DailyReport] Start date: \(formatter.string(from: startDate))")
        print("📅 [DailyReport] End date: \(formatter.string(from: today))")
        #endif

        let results = await dataManager.fetchDailyResultsRange(
            deviceId: deviceId,
            startDate: startDate,
            endDate: today
        )

        #if DEBUG
        print("📊 [DailyReport] Fetched \(results.count) records")
        if !results.isEmpty {
            print("📊 [DailyReport] First date: \(results.first?.date ?? "unknown")")
            print("📊 [DailyReport] Last date: \(results.last?.date ?? "unknown")")

            // Calculate expected vs actual
            let expectedDays = selectedPeriod.days
            let actualDays = results.count
            print("⚠️ [DailyReport] Expected \(expectedDays) days, got \(actualDays) days")

            if actualDays < expectedDays {
                print("⚠️ [DailyReport] Missing \(expectedDays - actualDays) days of data")
                print("⚠️ [DailyReport] This may be normal if data doesn't exist for all days in the range")
            }
        }
        #endif

        // Fill missing days with nil data to show full time axis
        dailySummaries = fillMissingDays(results: results, startDate: startDate, endDate: today)
        isLoading = false
    }

    /// Fill missing days with placeholder data to show complete time axis
    private func fillMissingDays(results: [DashboardSummary], startDate: Date, endDate: Date) -> [DashboardSummary] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // Create a dictionary of existing data keyed by date
        var dataByDate: [String: DashboardSummary] = [:]
        for result in results {
            dataByDate[result.date] = result
        }

        // Generate all dates in the range
        var allSummaries: [DashboardSummary] = []
        var currentDate = startDate

        while currentDate <= endDate {
            let dateString = formatter.string(from: currentDate)

            if let existingData = dataByDate[dateString] {
                // Use existing data
                allSummaries.append(existingData)
            } else {
                // Create placeholder for missing data
                let placeholder = createPlaceholderSummary(for: dateString)
                allSummaries.append(placeholder)
            }

            // Move to next day
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return allSummaries
    }

    /// Create a placeholder summary for a missing day
    private func createPlaceholderSummary(for dateString: String) -> DashboardSummary {
        // Use a temporary UUID for missing data
        let placeholderDeviceId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()

        return DashboardSummary(
            deviceId: placeholderDeviceId,
            date: dateString,
            processedCount: nil,
            lastTimeBlock: nil,
            createdAt: nil,
            updatedAt: nil,
            averageVibe: nil, // nil indicates missing data
            vibeScores: nil,
            analysisResult: nil,
            insights: nil,
            burstEvents: nil
        )
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

        let startDate = calendar.date(byAdding: .day, value: -(selectedPeriod.days - 1), to: today) ?? today

        let startDateString = formatter.string(from: startDate)
        let endDateString = formatter.string(from: today)

        return "\(startDateString) 〜 \(endDateString)"
    }

    // MARK: - Graph Section

    private var graphSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("気分の推移")
                .font(.title3)
                .fontWeight(.semibold)

            vibeGraph
        }
    }

    private var vibeGraph: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width - 40 // Right side scale space
            let barWidth = totalWidth / CGFloat(dailySummaries.count)
            let barPaddingRatio: CGFloat = 0.15
            let barInnerWidth = barWidth * (1 - barPaddingRatio * 2)
            let chartHeight: CGFloat = 150
            let halfHeight = chartHeight / 2
            let maxValue: Double = 50.0

            HStack(spacing: 0) {
                // Graph area
                VStack(spacing: 4) {
                    // Chart area
                    ZStack(alignment: .top) {
                        // Background grid lines (from top to bottom: 50, 25, 0, -25, -50)
                        VStack(spacing: 0) {
                            // 50 line (top)
                            gridLine(value: 50, isZero: false)
                            Spacer().frame(height: chartHeight / 4)

                            // 25 line
                            gridLine(value: 25, isZero: false)
                            Spacer().frame(height: chartHeight / 4)

                            // 0 line (center)
                            gridLine(value: 0, isZero: true)
                            Spacer().frame(height: chartHeight / 4)

                            // -25 line
                            gridLine(value: -25, isZero: false)
                            Spacer().frame(height: chartHeight / 4)

                            // -50 line (bottom)
                            gridLine(value: -50, isZero: false)
                        }
                        .frame(height: chartHeight)

                        // Bar chart (centered at 0, extending up/down)
                        HStack(alignment: .center, spacing: 0) {
                            ForEach(dailySummaries.indices, id: \.self) { index in
                                let hasData = dailySummaries[index].averageVibe != nil
                                let vibeScore = Double(dailySummaries[index].averageVibe ?? 0)
                                let barHeight = abs(vibeScore) / maxValue * halfHeight
                                let isPositive = vibeScore >= 0
                                let barColor = isPositive ? Color.green : Color.red

                                ZStack {
                                    if !hasData {
                                        // No data: show gray placeholder at center
                                        VStack(spacing: 0) {
                                            Spacer()
                                                .frame(height: halfHeight - 2)
                                            Rectangle()
                                                .fill(Color(.systemGray4))
                                                .frame(width: barInnerWidth, height: 4)
                                            Spacer()
                                                .frame(height: halfHeight - 2)
                                        }
                                    } else if isPositive {
                                        // Positive: extends upward from center
                                        VStack(spacing: 0) {
                                            Spacer()
                                                .frame(height: halfHeight - barHeight)
                                            Rectangle()
                                                .fill(barColor)
                                                .frame(width: barInnerWidth, height: barHeight)
                                            Spacer()
                                                .frame(height: halfHeight)
                                        }
                                    } else {
                                        // Negative: extends downward from center
                                        VStack(spacing: 0) {
                                            Spacer()
                                                .frame(height: halfHeight)
                                            Rectangle()
                                                .fill(barColor)
                                                .frame(width: barInnerWidth, height: barHeight)
                                            Spacer()
                                                .frame(height: halfHeight - barHeight)
                                        }
                                    }
                                }
                                .frame(width: barWidth, height: chartHeight)
                            }
                        }
                    }
                    .frame(height: chartHeight)

                    // Label area (date)
                    HStack(spacing: 0) {
                        ForEach(dailySummaries.indices, id: \.self) { index in
                            Text(shouldShowLabel(index: index, total: dailySummaries.count) ? formatDateLabel(dailySummaries[index].date) : "")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: barWidth)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                    }
                }
                .frame(width: totalWidth)

                // Right side scale (perfectly aligned with grid lines)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("50")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer().frame(height: chartHeight / 4)

                    Text("25")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer().frame(height: chartHeight / 4)

                    Text("0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer().frame(height: chartHeight / 4)

                    Text("-25")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer().frame(height: chartHeight / 4)

                    Text("-50")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 30, height: chartHeight)
            }
        }
        .frame(height: 180)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    private func gridLine(value: Int, isZero: Bool) -> some View {
        HStack {
            Rectangle()
                .fill(isZero ? Color(.systemGray4) : Color(.systemGray5))
                .frame(height: isZero ? 1.0 : 0.5)
            Spacer()
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
        let hasData = summary.averageVibe != nil

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatDate(summary.date))
                    .font(.headline)
                    .foregroundColor(hasData ? .primary : .secondary)

                Spacer()

                if hasData {
                    Text(String(format: "%.1f", Double(summary.averageVibe ?? 0)))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(vibeScoreColor(Double(summary.averageVibe ?? 0)))
                } else {
                    Text("データなし")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if hasData {
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
            } else {
                Text("この日のデータは記録されていません")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(hasData ? Color(.systemGray6) : Color(.systemGray6).opacity(0.5))
        )
        .opacity(hasData ? 1.0 : 0.6)
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

    /// Determine if a label should be shown (only show first, middle, last to avoid crowding)
    private func shouldShowLabel(index: Int, total: Int) -> Bool {
        if total <= 7 {
            // 7 or fewer: show all
            return true
        } else if total <= 12 {
            // 8-12: show first, middle, last
            return index == 0 || index == total / 2 || index == total - 1
        } else {
            // 30 days or 90 days: show first, quarter points, last
            let quarter = total / 4
            return index == 0 || index == quarter || index == quarter * 2 || index == quarter * 3 || index == total - 1
        }
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
