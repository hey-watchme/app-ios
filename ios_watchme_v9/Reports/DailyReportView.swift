//
//  DailyReportView.swift
//  ios_watchme_v9
//
//  Daily分析の推移レポート
//

import SwiftUI
import Charts

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

    // Bar selected in the chart (local_date). Falls back to the latest day with data.
    @State private var selectedChartDate: String?
    @State private var sortNewestFirst = true

    /// One bar of the chart
    private struct ChartPoint: Identifiable {
        let id: String
        let day: Date
        let score: Double
        let summary: DashboardSummary

        var midday: Date { day.addingTimeInterval(12 * 60 * 60) }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

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
                        .tint(Color.accentTeal)
                        .padding()
                } else if dailySummaries.isEmpty {
                    Text("この期間のデータがありません")
                        .font(.subheadline)
                        .foregroundColor(Color(white: 0.56))
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
        .background(Color.darkBase)
        .sheet(isPresented: $showDailyDetailSheet) {
            if let deviceId = deviceManager.selectedDeviceID {
                DailyDetailView(deviceId: deviceId, localDate: selectedDailyDate)
                    .environmentObject(deviceManager)
                    .environmentObject(dataManager)
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

        // Fetch daily summaries
        let results = await dataManager.fetchDailyResultsRange(
            deviceId: deviceId,
            startDate: startDate,
            endDate: today
        )

        #if DEBUG
        print("📊 [DailyReport] Fetched \(results.count) daily records")
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

        // Days without a record are not listed; the chart keeps the full time axis by its domain
        dailySummaries = results
        selectedChartDate = nil
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
                    .foregroundColor(Color(white: 0.56))
                Text(selectedPeriod.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.56))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.darkCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Period Display Text

    private var periodDisplayText: some View {
        Text(getPeriodDisplayText())
            .font(.subheadline)
            .foregroundColor(Color(white: 0.56))
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

    private var chartPoints: [ChartPoint] {
        dailySummaries.compactMap { summary in
            guard let vibe = summary.averageVibe,
                  let day = Self.dayFormatter.date(from: summary.date) else { return nil }
            return ChartPoint(id: summary.date, day: day, score: Double(vibe), summary: summary)
        }
    }

    private var graphSection: some View {
        let points = chartPoints
        let selected = points.first { $0.id == selectedChartDate } ?? points.last

        return VStack(alignment: .leading, spacing: 16) {
            Text("気分の推移")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            VStack(spacing: 0) {
                if let selected {
                    digestBalloon(selected)
                }

                vibeChart(points: points, selected: selected)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.darkCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    private func vibeChart(points: [ChartPoint], selected: ChartPoint?) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(selectedPeriod.days - 1), to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        // Scores normally stay within -50...50; widen only if a day goes beyond
        let maxAbs = points.map { abs($0.score) }.max() ?? 0
        let bound = max(50.0, (maxAbs / 25).rounded(.up) * 25)
        let labelStride = selectedPeriod.days <= 7 ? 1 : (selectedPeriod.days <= 30 ? 7 : 14)

        return Chart {
            RuleMark(y: .value("基準", 0))
                .foregroundStyle(Color.white.opacity(0.25))
                .lineStyle(StrokeStyle(lineWidth: 1))

            if let selected {
                RuleMark(x: .value("選択", selected.midday))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }

            ForEach(points) { point in
                BarMark(
                    x: .value("日付", point.day, unit: .day),
                    y: .value("気分", point.score)
                )
                .foregroundStyle(point.score >= 0 ? Color.accentTeal : Color.accentCoral)
                .opacity(point.id == selected?.id ? 1.0 : 0.45)
            }
        }
        .chartXScale(domain: start...end)
        .chartYScale(domain: -bound...bound)
        .chartYAxis {
            AxisMarks(position: .trailing, values: [-bound, -bound / 2, 0, bound / 2, bound]) { _ in
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.10))
                AxisValueLabel()
                    .foregroundStyle(Color(white: 0.56))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: labelStride)) { _ in
                AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), centered: labelStride == 1)
                    .foregroundStyle(Color(white: 0.56))
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let anchor = proxy.plotFrame {
                    let plot = geometry[anchor]

                    ZStack(alignment: .topLeading) {
                        // Tap anywhere in the chart to select the nearest day with data
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                guard let tapped: Date = proxy.value(atX: location.x - plot.minX) else { return }
                                let nearest = points.min {
                                    abs($0.midday.timeIntervalSince(tapped)) < abs($1.midday.timeIntervalSince(tapped))
                                }
                                selectedChartDate = nearest?.id
                            }

                        // Tail of the balloon, pointing at the selected bar
                        if let selected, let x = proxy.position(forX: selected.midday) {
                            BalloonTail()
                                .fill(Color.darkElevated)
                                .frame(width: 14, height: 8)
                                .position(x: plot.minX + x, y: 4)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
        }
        .frame(height: 190)
    }

    /// Digest of the selected day. Tapping it opens the detail view.
    private func digestBalloon(_ point: ChartPoint) -> some View {
        Button(action: {
            openDetail(point.summary)
        }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(formatDate(point.id))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Text(String(format: "%.1f", point.score))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(vibeScoreColor(point.score))

                    Spacer()

                    HStack(spacing: 2) {
                        Text("詳細")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.accentTeal)
                }

                Text(point.summary.insights?.isEmpty == false ? point.summary.insights ?? "" : "この日の要約はまだありません")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.70))
                    .lineLimit(3, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.darkElevated)
            )
        }
        .buttonStyle(.plain)
    }

    private struct BalloonTail: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }

    private func openDetail(_ summary: DashboardSummary) {
        selectedDailyDate = summary.date
        showDailyDetailSheet = true
    }

    // MARK: - Daily Summary List

    private var dailySummaryList: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("日次サマリー")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                Button(action: {
                    sortNewestFirst.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortNewestFirst ? "新しい順" : "古い順")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.accentTeal)
                }
            }

            // dailySummaries is ascending by date (as fetched)
            ForEach(sortNewestFirst ? dailySummaries.reversed() : dailySummaries, id: \.date) { summary in
                dailySummaryRow(summary: summary)
            }
        }
    }

    private func dailySummaryRow(summary: DashboardSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatDate(summary.date))
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                if let vibe = summary.averageVibe {
                    Text(String(format: "%.1f", Double(vibe)))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(vibeScoreColor(Double(vibe)))
                }
            }

            if let insights = summary.insights, !insights.isEmpty {
                Text(insights)
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.56))
                    .lineLimit(2)
            }

            Button(action: {
                openDetail(summary)
            }) {
                HStack {
                    Text("詳細を見る")
                        .font(.caption)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(.accentTeal)
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

    private func vibeScoreColor(_ score: Double) -> Color {
        Color.vibeScoreColor(for: score)
    }
}
