//
//  DailyReportView.swift
//  ios_watchme_v9
//
//  Daily分析の推移レポート
//
//  The chart shows one metric at a time, chosen from its heading: the day's Vibe or the
//  counted events (ReportMetric). The solid line is the selected period; the dashed line is
//  the period before it, moved forward by the period's length so the two overlap day by day.
//

import SwiftUI
import Charts
import Supabase

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
    @State private var selectedMetric: ReportMetric = .vibe
    @State private var dailySummaries: [DashboardSummary] = []      // the selected period
    @State private var previousSummaries: [DashboardSummary] = []   // the period before it
    @State private var eventDays: [String: ReportDayCounts] = [:]   // local_date -> counted events, both periods
    @State private var stripDays: [String: DayStripData] = [:]      // local_date -> the day's picture, selected period
    /// The counted events behind the balloon's number: the selected day and metric, in time order.
    @State private var balloonEvents: [BalloonEvent] = []
    @State private var balloonEventsKey = ""

    struct BalloonEvent: Identifiable {
        let id: String
        let recordedAt: String
        let start: Double      // seconds from the start of the recording
        let end: Double
        let clock: String      // local time of the event, HH:mm
        let type: String
        let intensity: String?
        let evidence: String?
    }
    @State private var isLoading = false

    /// The day pushed onto the app's navigation stack (ios_watchme_v9App mainTabView).
    private struct OpenDay: Identifiable, Hashable {
        let localDate: String
        var id: String { localDate }
    }
    @State private var openDay: OpenDay?
    @State private var showSaved = false

    // Day selected in the chart (local_date). Falls back to the latest day with data.
    @State private var selectedChartDate: String?
    @State private var sortNewestFirst = true

    /// One day of a line in the chart
    private struct ChartPoint: Identifiable {
        let id: String    // local_date the value belongs to
        let day: Date     // where it is drawn (the period before is moved forward)
        let value: Double

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
                // Period selector, and the saved recordings (not bound to the period)
                HStack(spacing: 10) {
                    periodSelector
                    if let deviceId = deviceManager.selectedDeviceID, SavedRecordings.canSave(deviceId: deviceId) {
                        savedButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Period display (e.g., "2025年11月24日 〜 11月30日")
                periodDisplayText
                    .padding(.horizontal, 20)

                if isLoading {
                    ProgressView()
                        .tint(Color.accentTeal)
                        .padding()
                } else if dailySummaries.isEmpty && stripDays.isEmpty {
                    Text("この期間のデータがありません")
                        .font(.subheadline)
                        .foregroundColor(Color(white: 0.56))
                        .padding()
                } else {
                    // Graph section
                    graphSection
                        .padding(.horizontal, 20)

                    // One panel per day
                    dayPanels
                        .padding(.horizontal, 20)
                }

                Spacer()
                    .frame(height: 40)
            }
        }
        .background(Color.darkBase)
        .navigationDestination(item: $openDay) { day in
            if let deviceId = deviceManager.selectedDeviceID {
                DayScreen(deviceId: deviceId, localDate: day.localDate)
                    .environmentObject(deviceManager)
                    .environmentObject(dataManager)
            }
        }
        .sheet(isPresented: $showSaved) {
            if let deviceId = deviceManager.selectedDeviceID {
                SavedRecordingsView(deviceId: deviceId)
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

    /// First day of the selected period and of the period before it
    private var periodStarts: (current: Date, previous: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let current = calendar.date(byAdding: .day, value: -(selectedPeriod.days - 1), to: today) ?? today
        let previous = calendar.date(byAdding: .day, value: -selectedPeriod.days, to: current) ?? current
        return (current, previous)
    }

    private func loadData() async {
        guard let deviceId = deviceManager.selectedDeviceID else {
            dailySummaries = []
            previousSummaries = []
            eventDays = [:]
            return
        }

        isLoading = true

        let today = Date()
        let starts = periodStarts
        let startString = Self.dayFormatter.string(from: starts.current)

        #if DEBUG
        print("📅 [DailyReport] Selected period: \(selectedPeriod.rawValue)")
        print("📅 [DailyReport] Days requested: \(selectedPeriod.days)")
        print("📅 [DailyReport] Start date: \(startString) (period before from \(Self.dayFormatter.string(from: starts.previous)))")
        print("📅 [DailyReport] End date: \(Self.dayFormatter.string(from: today))")
        #endif

        // The selected period and the one before it (the dashed line), in one read each
        async let summariesTask = dataManager.fetchDailyResultsRange(
            deviceId: deviceId,
            startDate: starts.previous,
            endDate: today
        )
        async let runsTask = fetchEventRuns(deviceId: deviceId, from: starts.previous, to: today)
        async let stripsTask = fetchStrips(deviceId: deviceId, from: starts.current, to: today)
        let fetched = await summariesTask
        let runs = await runsTask
        let strips = await stripsTask
        let results = fetched.filter { $0.date >= startString }

        #if DEBUG
        print("📊 [DailyReport] Fetched \(results.count) daily records, \(fetched.count - results.count) of the period before, \(runs.count) event runs")
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
        previousSummaries = fetched.filter { $0.date < startString }
        eventDays = ReportEvents.days(from: runs)
        stripDays = strips
        selectedChartDate = nil
        isLoading = false
    }

    /// The device's spot_event_runs between two local dates. Read in pages until the total
    /// the server reports is reached: one response holds a limited number of rows, and a
    /// short answer would silently lower the counts.
    private func fetchEventRuns(deviceId: String, from: Date, to: Date) async -> [ReportEventRun] {
        let client = SupabaseClientManager.shared.client
        let pageSize = 1000
        var rows: [ReportEventRun] = []
        do {
            while true {
                let response: PostgrestResponse<[ReportEventRun]> = try await client
                    .from("spot_event_runs")
                    .select("local_date, recorded_at, extractor_version, audio_seconds, counts", count: .exact)
                    .eq("device_id", value: deviceId)
                    .gte("local_date", value: Self.dayFormatter.string(from: from))
                    .lte("local_date", value: Self.dayFormatter.string(from: to))
                    .order("recorded_at", ascending: true)
                    .order("extractor_version", ascending: true)
                    .range(from: rows.count, to: rows.count + pageSize - 1)
                    .execute()
                rows += response.value
                if response.value.isEmpty { break }
                if let total = response.count, rows.count >= total { break }
            }
        } catch {
            // Part of the rows would show counts that are too low; show none instead
            print("❌ [DailyReport] Failed to fetch spot_event_runs: \(error)")
            return []
        }
        return rows
    }

    /// Each day's picture for the panels: the recordings whose events were looked for (newest
    /// extractor version of each), and their warm and hard events, low-confidence ones left out.
    /// Read in pages, like the runs, so a long period is not cut short.
    private func fetchStrips(deviceId: String, from: Date, to: Date) async -> [String: DayStripData] {
        struct Run: Decodable { let local_date: String; let recorded_at: String; let extractor_version: String; let audio_seconds: Double? }
        struct Spot: Decodable { let recorded_at: String; let local_time: String? }
        struct Row: Decodable {
            let recorded_at: String
            let extractor_version: String
            let seq: Int
            let event_type: String
            let start_sec: Double
            let intensity: String?
        }
        let client = SupabaseClientManager.shared.client
        let fromDate = Self.dayFormatter.string(from: from)
        let toDate = Self.dayFormatter.string(from: to)
        let pageSize = 1000

        func pages<T: Decodable>(_ table: String, _ columns: String, filter: (PostgrestFilterBuilder) -> PostgrestFilterBuilder) async throws -> [T] {
            var rows: [T] = []
            while true {
                let response: PostgrestResponse<[T]> = try await filter(client.from(table)
                    .select(columns, count: .exact)
                    .eq("device_id", value: deviceId)
                    .gte("local_date", value: fromDate)
                    .lte("local_date", value: toDate))
                    .order("recorded_at", ascending: true)
                    .range(from: rows.count, to: rows.count + pageSize - 1)
                    .execute()
                rows += response.value
                if response.value.isEmpty { break }
                if let total = response.count, rows.count >= total { break }
            }
            return rows
        }

        do {
            async let runsTask: [Run] = pages("spot_event_runs", "local_date, recorded_at, extractor_version, audio_seconds") { $0 }
            async let spotsTask: [Spot] = pages("spot_results", "recorded_at, local_time") { $0 }
            async let rowsTask: [Row] = pages("spot_events", "recorded_at, extractor_version, seq, event_type, start_sec, intensity") {
                $0.in("event_type", values: Array(DayStrip.emoji.keys)).neq("confidence", value: "low")
            }
            let (runs, spots, rows) = try await (runsTask, spotsTask, rowsTask)

            var newest: [String: Run] = [:]
            for run in runs where (newest[run.recorded_at]?.extractor_version ?? "") < run.extractor_version {
                newest[run.recorded_at] = run
            }
            let clocks = Dictionary(spots.compactMap { spot in
                spot.local_time.flatMap(Self.localStart).map { (spot.recorded_at, Self.clockFormatter.string(from: $0)) }
            }, uniquingKeysWith: { first, _ in first })

            var days: [String: DayStripData] = [:]
            for run in newest.values.sorted(by: { $0.recorded_at < $1.recorded_at }) {
                days[run.local_date, default: DayStripData()].recordings.append(
                    .init(recordedAt: run.recorded_at, clock: clocks[run.recorded_at], seconds: run.audio_seconds ?? 0))
            }
            for row in rows where newest[row.recorded_at]?.extractor_version == row.extractor_version {
                guard let date = newest[row.recorded_at]?.local_date else { continue }
                days[date]?.events.append(.init(id: "\(row.recorded_at)-\(row.seq)", recordedAt: row.recorded_at,
                                                start: row.start_sec, type: row.event_type, intensity: row.intensity))
            }
            // In time order, so a later event is drawn over an earlier one
            return days.mapValues { day in
                var day = day
                day.events.sort { ($0.recordedAt, $0.start) < ($1.recordedAt, $1.start) }
                return day
            }
        } catch {
            print("❌ [DailyReport] Failed to fetch the days' pictures: \(error)")
            return [:]
        }
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

    private var savedButton: some View {
        Button(action: {
            showSaved = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .font(.caption)
                Text("保存した録音")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.accentTeal)
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
        .fixedSize()
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

    /// local_date -> value of the selected metric, for both periods. A day without a value
    /// (no recording, or no recording that looked for the events) has no entry: it is
    /// missing, not zero.
    private var metricValues: [String: Double] {
        if selectedMetric.isVibe {
            let scored = (previousSummaries + dailySummaries).compactMap { summary in
                summary.averageVibe.map { (summary.date, Double($0)) }
            }
            return Dictionary(scored, uniquingKeysWith: { _, last in last })
        }
        return eventDays.compactMapValues { $0.value(of: selectedMetric).map(Double.init) }
    }

    /// The two lines of the chart: the selected period, and the period before it moved forward
    /// by the period's length.
    private var chartSeries: (current: [ChartPoint], previous: [ChartPoint]) {
        let calendar = Calendar.current
        let starts = periodStarts
        var current: [ChartPoint] = []
        var previous: [ChartPoint] = []
        for (date, value) in metricValues {
            guard let day = Self.dayFormatter.date(from: date) else { continue }
            if day >= starts.current {
                current.append(ChartPoint(id: date, day: day, value: value))
            } else if day >= starts.previous,
                      let moved = calendar.date(byAdding: .day, value: selectedPeriod.days, to: day) {
                previous.append(ChartPoint(id: date, day: moved, value: value))
            }
        }
        return (current.sorted { $0.day < $1.day }, previous.sorted { $0.day < $1.day })
    }

    private var graphSection: some View {
        let series = chartSeries
        let selected = series.current.first { $0.id == selectedChartDate } ?? series.current.last

        return VStack(alignment: .leading, spacing: 16) {
            metricMenu

            VStack(alignment: .leading, spacing: 0) {
                if series.current.isEmpty && series.previous.isEmpty {
                    Text(selectedMetric.isVibe
                         ? "この期間の気分の値はまだありません"
                         : "この期間の録音では、「\(selectedMetric.name)」を数えていません")
                        .font(.subheadline)
                        .foregroundColor(Color(white: 0.56))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                } else {
                    if let selected {
                        digestBalloon(selected)
                    }

                    trendChart(points: series.current, previous: series.previous, selected: selected)

                    chartLegend(showsPrevious: !series.previous.isEmpty)
                        .padding(.top, 10)

                    if !selectedMetric.isVibe {
                        Text("その日の録音で数えた回数です。録音の長さではならしていません。")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.4))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                    }
                }
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

    /// The chart's heading. Pressing it lists the metrics the chart can show.
    private var metricMenu: some View {
        Menu {
            metricButton(.vibe)
            Section("出来事のまとまり") {
                ForEach(ReportMetric.axes) { metric in
                    metricButton(metric)
                }
            }
            Section("出来事") {
                ForEach(ReportMetric.events) { metric in
                    metricButton(metric)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("\(selectedMetric.name)の推移")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(white: 0.56))
            }
        }
    }

    private func metricButton(_ metric: ReportMetric) -> some View {
        Button(action: {
            selectedMetric = metric
        }) {
            HStack {
                Text(metric.name)
                if selectedMetric == metric {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    /// Y axis: Vibe is centred on zero; counts start at zero and have four whole steps.
    private func yAxis(for values: [Double]) -> (domain: ClosedRange<Double>, ticks: [Double]) {
        if selectedMetric.isVibe {
            // Scores normally stay within -50...50; widen only if a day goes beyond
            let maxAbs = values.map { abs($0) }.max() ?? 0
            let bound = max(50.0, (maxAbs / 25).rounded(.up) * 25)
            return (-bound...bound, [-bound, -bound / 2, 0, bound / 2, bound])
        }
        let step = max(1.0, ((values.max() ?? 0) / 4).rounded(.up))
        // A little room above the top step, so a day at the maximum does not touch the balloon
        return (0...(step * 4.2), (0...4).map { Double($0) * step })
    }

    private func pointColor(_ point: ChartPoint) -> Color {
        selectedMetric.isVibe && point.value < 0 ? .accentCoral : .accentTeal
    }

    private func trendChart(points: [ChartPoint], previous: [ChartPoint], selected: ChartPoint?) -> some View {
        let start = periodStarts.current
        let end = Calendar.current.date(byAdding: .day, value: selectedPeriod.days, to: start) ?? start
        let axis = yAxis(for: (points + previous).map(\.value))
        let labelStride = selectedPeriod.days <= 7 ? 1 : (selectedPeriod.days <= 30 ? 7 : 14)
        // A date label starts at its tick, so one close to the right edge would be cut off
        let lastLabelDay = Calendar.current.date(byAdding: .day, value: -(selectedPeriod.days / 7), to: end) ?? end
        // Smaller dots when the days are close together
        let dotSize: CGFloat = selectedPeriod.days <= 7 ? 36 : (selectedPeriod.days <= 30 ? 18 : 6)
        let previousColor = Color.white.opacity(0.4)

        return Chart {
            if selectedMetric.isVibe {
                RuleMark(y: .value("基準", 0))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }

            if let selected {
                RuleMark(x: .value("選択", selected.midday))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }

            // The period before: dashed, under the selected period. The dots keep a lone day visible.
            ForEach(previous) { point in
                LineMark(
                    x: .value("日付", point.midday),
                    y: .value(selectedMetric.name, point.value),
                    series: .value("期間", "previous")
                )
                .foregroundStyle(previousColor)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
            ForEach(previous) { point in
                PointMark(
                    x: .value("日付", point.midday),
                    y: .value(selectedMetric.name, point.value)
                )
                .foregroundStyle(previousColor)
                .symbolSize(dotSize * 0.4)
            }

            ForEach(points) { point in
                LineMark(
                    x: .value("日付", point.midday),
                    y: .value(selectedMetric.name, point.value),
                    series: .value("期間", "current")
                )
                .foregroundStyle(Color.accentTeal)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            ForEach(points) { point in
                PointMark(
                    x: .value("日付", point.midday),
                    y: .value(selectedMetric.name, point.value)
                )
                .foregroundStyle(pointColor(point))
                .symbolSize(point.id == selected?.id ? 80 : dotSize)
            }
        }
        .chartXScale(domain: start...end)
        .chartYScale(domain: axis.domain)
        .chartYAxis {
            AxisMarks(position: .trailing, values: axis.ticks) { _ in
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.10))
                AxisValueLabel()
                    .foregroundStyle(Color(white: 0.56))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: labelStride)) { value in
                if labelStride == 1 || (value.as(Date.self).map { $0 <= lastLabelDay } ?? true) {
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), centered: labelStride == 1)
                        .foregroundStyle(Color(white: 0.56))
                }
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

                        // Tail of the balloon, pointing at the selected day
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

    private func chartLegend(showsPrevious: Bool) -> some View {
        HStack(spacing: 16) {
            legendItem(selectedPeriod.rawValue, color: .accentTeal, dash: [])
            if showsPrevious {
                legendItem("その前の\(selectedPeriod.days)日間", color: Color.white.opacity(0.4), dash: [4, 3])
            }
        }
    }

    private func legendItem(_ label: String, color: Color, dash: [CGFloat]) -> some View {
        HStack(spacing: 6) {
            LegendLine()
                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: dash))
                .frame(width: 20, height: 2)
            Text(label)
                .font(.caption2)
                .foregroundColor(Color(white: 0.56))
        }
    }

    private struct LegendLine: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }

    /// Digest of the selected day. Tapping it opens the detail view.
    private func digestBalloon(_ point: ChartPoint) -> some View {
        let insights = dailySummaries.first { $0.date == point.id }?.insights ?? ""

        // Not a Button: the event lines have their own play buttons, which a Button
        // around them would swallow. Tapping anywhere else opens the day.
        return VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(formatDate(point.id))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    if selectedMetric.isVibe {
                        Text(String(format: "%.1f", point.value))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(vibeScoreColor(point.value))
                    } else {
                        Text("\(selectedMetric.name) \(Int(point.value))回")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    HStack(spacing: 2) {
                        Text("詳細")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.accentTeal)
                }

                // A count only means something next to how much was recorded that day
                if !selectedMetric.isVibe, let day = eventDays[point.id] {
                    Text("録音 \(day.recordings)回・合計 \(ReportEvents.durationText(day.audioSeconds))")
                        .font(.caption2)
                        .foregroundColor(Color(white: 0.56))
                }

                if selectedMetric.isVibe {
                    Text(insights.isEmpty ? "この日の要約はまだありません" : insights)
                        .font(.caption)
                        .foregroundColor(Color(white: 0.70))
                        .lineLimit(3, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    eventLines(for: point)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.darkElevated)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                openDetail(point.id)
            }
            .accessibilityAddTraits(.isButton)
    }

    /// The events counted for the selected day and metric, with the words that were heard.
    private func eventLines(for point: ChartPoint) -> some View {
        let key = "\(deviceManager.selectedDeviceID ?? "")|\(point.id)|\(selectedMetric.id)"
        let shown = 4
        let loaded = balloonEventsKey == key

        return VStack(alignment: .leading, spacing: 4) {
            if !loaded {
                Text("読み込み中…")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.5))
            } else if balloonEvents.isEmpty {
                Text("この日は数えられていません")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.5))
            } else {
                ForEach(balloonEvents.prefix(shown)) { event in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(event.clock)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(white: 0.55))
                        if selectedMetric.eventTypes.count > 1 {
                            Text(SpotEventsCard.typeNames[event.type] ?? event.type)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        if let intensity = event.intensity, intensity != "mild" {
                            Text(intensity == "severe" ? "非常に強い" : "強め")
                                .font(.caption2)
                                .foregroundColor(.accentCoral)
                        }
                        Text(event.evidence.map { "「\($0)」" } ?? "（言葉の記録なし）")
                            .font(.caption)
                            .foregroundColor(Color(white: 0.78))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if let deviceId = deviceManager.selectedDeviceID, SavedRecordings.canSave(deviceId: deviceId) {
                            EventPlayButton(id: event.id, deviceId: deviceId, recordedAt: event.recordedAt,
                                            start: event.start, end: event.end)
                        }
                    }
                }
                if balloonEvents.count > shown {
                    Text("ほか \(balloonEvents.count - shown)件（詳細で全部見られます）")
                        .font(.caption2)
                        .foregroundColor(Color(white: 0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
        .task(id: key) { await loadBalloonEvents(key: key, localDate: point.id) }
    }

    /// Same rows the day's detail counts: the newest extractor version of each recording,
    /// low-confidence events left out.
    private func loadBalloonEvents(key: String, localDate: String) async {
        guard let deviceId = deviceManager.selectedDeviceID, !selectedMetric.isVibe else { return }
        struct Run: Decodable { let recorded_at: String; let extractor_version: String }
        struct Spot: Decodable { let recorded_at: String; let local_time: String? }
        struct Row: Decodable {
            let recorded_at: String
            let extractor_version: String
            let seq: Int
            let event_type: String
            let start_sec: Double
            let end_sec: Double
            let intensity: String?
            let evidence: String?
        }
        let client = SupabaseClientManager.shared.client
        do {
            async let runsTask: [Run] = client.from("spot_event_runs")
                .select("recorded_at, extractor_version")
                .eq("device_id", value: deviceId).eq("local_date", value: localDate)
                .execute().value
            async let spotsTask: [Spot] = client.from("spot_results")
                .select("recorded_at, local_time")
                .eq("device_id", value: deviceId).eq("local_date", value: localDate)
                .execute().value
            async let rowsTask: [Row] = client.from("spot_events")
                .select("recorded_at, extractor_version, seq, event_type, start_sec, end_sec, intensity, evidence")
                .eq("device_id", value: deviceId).eq("local_date", value: localDate)
                .in("event_type", values: selectedMetric.eventTypes)
                .neq("confidence", value: "low")
                .execute().value
            let (runs, spots, rows) = try await (runsTask, spotsTask, rowsTask)
            var newest: [String: String] = [:]
            for run in runs where (newest[run.recorded_at] ?? "") < run.extractor_version {
                newest[run.recorded_at] = run.extractor_version
            }
            let starts = Dictionary(spots.compactMap { spot in spot.local_time.flatMap(Self.localStart).map { (spot.recorded_at, $0) } },
                                    uniquingKeysWith: { first, _ in first })
            let events = rows
                .filter { newest[$0.recorded_at] == $0.extractor_version }
                .map { row -> (Date?, BalloonEvent) in
                    let at = starts[row.recorded_at].map { $0.addingTimeInterval(row.start_sec) }
                    return (at, BalloonEvent(id: "\(row.recorded_at)-\(row.seq)",
                                             recordedAt: row.recorded_at, start: row.start_sec, end: row.end_sec,
                                             clock: at.map { Self.clockFormatter.string(from: $0) } ?? "--:--",
                                             type: row.event_type, intensity: row.intensity, evidence: row.evidence))
                }
                .sorted { ($0.0 ?? .distantPast) < ($1.0 ?? .distantPast) }
                .map(\.1)
            balloonEvents = events
        } catch {
            print("❌ [DailyReport] Failed to fetch the day's events: \(error)")
            balloonEvents = []
        }
        balloonEventsKey = key
    }

    /// local_time is the wall-clock time of the recording, written without a zone; read it as UTC
    /// and print it as UTC so it comes back unchanged.
    private static func localStart(_ localTime: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        // Seconds are enough; the fraction has a varying number of digits
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: String(localTime.prefix(19)).replacingOccurrences(of: "T", with: " "))
    }

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

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

    private func openDetail(_ localDate: String) {
        openDay = OpenDay(localDate: localDate)
    }

    // MARK: - Day Panels

    /// Days of the selected period that have a summary or a picture, oldest first.
    private var panelDates: [String] {
        let start = Self.dayFormatter.string(from: periodStarts.current)
        return Set(dailySummaries.map(\.date) + stripDays.keys.filter { $0 >= start }).sorted()
    }

    /// One panel per day: the date and Vibe, and the day's picture as a thin strip.
    /// Pressing a panel opens the day, and from there its recordings.
    private var dayPanels: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("日ごと")
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
            .padding(.bottom, 6)

            ForEach(sortNewestFirst ? panelDates.reversed() : panelDates, id: \.self) { date in
                dayPanel(date)
            }
        }
    }

    private func dayPanel(_ date: String) -> some View {
        let vibe = dailySummaries.first { $0.date == date }?.averageVibe

        return Button(action: {
            openDetail(date)
        }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(formatDate(date))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Spacer()

                    if let vibe {
                        Text(String(format: "%.1f", Double(vibe)))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(vibeScoreColor(Double(vibe)))
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(Color(white: 0.4))
                }

                if let strip = stripDays[date], !strip.recordings.isEmpty {
                    DayStrip(data: strip)
                } else {
                    Text("出来事は数えていません")
                        .font(.caption2)
                        .foregroundColor(Color(white: 0.45))
                        .padding(.vertical, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.darkCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
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
