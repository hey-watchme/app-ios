//
//  DailyDetailView.swift
//  ios_watchme_v9
//
//  One day's analysis. Opened from anywhere with a device and a local date; it loads
//  everything itself. Tapping a recording opens its SpotDetailView.
//
//  Vibe of the day: the plain average of the day's recordings (daily_results.vibe_score,
//  platform backend/functions/day_so_far). Events: spot_event_runs / spot_events, newest
//  extractor version per recording, low-confidence events not counted (platform docs/events.md).
//

import SwiftUI
import Charts

struct DailyDetailView: View {
    let deviceId: String
    let localDate: String  // yyyy-MM-dd

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var deviceManager: DeviceManager

    @State private var summary: DashboardSummary?
    @State private var spots: [DashboardTimeBlock] = []
    @State private var runs: [String: EventRun] = [:]   // recorded_at -> newest run
    @State private var events: [DayEvent] = []
    @State private var isLoading = true
    @State private var selectedSpot: DashboardTimeBlock?

    struct EventRun: Decodable {
        let recorded_at: String
        let extractor_version: String
        let activity: String?
        let audio_seconds: Double?
    }

    struct DayEvent: Decodable, Identifiable {
        let recorded_at: String
        let extractor_version: String
        let seq: Int
        let event_type: String
        let start_sec: Double
        let actor: String
        let target: String?
        let intensity: String?
        let confidence: String
        var id: String { "\(recorded_at)-\(seq)" }
    }

    // Same rule as platform backend/common/record.py: direction x strength, added up.
    private static let direction: [String: Int] = [
        "reprimand": -1, "conflict": -1, "crying": -1, "praise": 1, "laughter": 1,
        "mishap": 0, "cough": 0, "sneeze": 0, "throat_clearing": 0,
    ]
    private static let levels = ["mild": 1, "strong": 2, "severe": 3]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView()
                            .tint(.accentTeal)
                            .padding(.top, 60)
                    } else if spots.isEmpty && summary == nil {
                        Text("この日の録音はありません")
                            .font(.subheadline)
                            .foregroundColor(Color(white: 0.56))
                            .padding(.top, 60)
                    } else {
                        vibeHeader
                        if let insights = summary?.insights, !insights.isEmpty {
                            summaryCard(insights)
                        }
                        eventsCard
                        if !spots.isEmpty {
                            timelineCard
                            recordingsCard
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.darkBase)
            .navigationTitle(dateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.darkBase, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .sheet(item: $selectedSpot) { spot in
            SpotDetailView(deviceId: deviceId, spotData: spot)
                .environmentObject(dataManager)
        }
        .task(id: "\(deviceId)-\(localDate)") { await load() }
    }

    // MARK: - Vibe

    private var vibeHeader: some View {
        VStack(spacing: 6) {
            if let vibe = summary?.averageVibe {
                Text(String(format: "%.0f", vibe))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(Color.vibeScoreColor(for: Double(vibe)))
            } else {
                Text("–")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(Color(white: 0.4))
            }
            Text("Vibe（その日の録音の平均）")
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.5))
            Text(recordingLine)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(white: 0.75))
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var recordingLine: String {
        let total = spots.compactMap { duration(of: $0) }.reduce(0, +)
        let count = "録音 \(spots.count)回"
        return total > 0 ? "\(count)・合計 \(durationText(total))" : count
    }

    // MARK: - Summary

    private func summaryCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DetailCardHeader(icon: "text.alignleft", title: "SUMMARY", badge: "その日のまとめ")
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(Color(white: 0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .detailCard()
    }

    // MARK: - Events

    private var counted: [DayEvent] { events.filter { $0.confidence != "low" } }

    private func points(_ event: DayEvent) -> Int {
        let level = ["reprimand", "conflict"].contains(event.event_type) ? (Self.levels[event.intensity ?? ""] ?? 1) : 1
        return (Self.direction[event.event_type] ?? 0) * level
    }

    private var eventsCard: some View {
        let counts = Dictionary(grouping: counted, by: \.event_type).mapValues(\.count)
        let plus = counted.map(points).filter { $0 > 0 }.reduce(0, +)
        let minus = -counted.map(points).filter { $0 < 0 }.reduce(0, +)
        let hours = runs.values.compactMap(\.audio_seconds).reduce(0, +) / 3600
        let strong = counted.filter { ["reprimand", "conflict"].contains($0.event_type) && ($0.intensity == "strong" || $0.intensity == "severe") }.count

        return VStack(alignment: .leading, spacing: 14) {
            DetailCardHeader(icon: "list.number", title: "EVENTS", badge: "出来事")

            if runs.isEmpty {
                Text("この日の録音では、出来事を数えていません")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.5))
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 18) {
                    scoreFigure("マイナス", minus, .accentCoral)
                    scoreFigure("プラス", plus, .accentTeal)
                    Spacer()
                    if hours > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%+.1f", Double(plus - minus) / hours))
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            Text("1時間あたりの差し引き")
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.5))
                        }
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), spacing: 8) {
                    ForEach(SpotEventsCard.typeOrder, id: \.self) { type in
                        HStack(spacing: 6) {
                            Text(SpotEventsCard.typeNames[type] ?? type)
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.6))
                            Text("\(counts[type] ?? 0)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor((counts[type] ?? 0) > 0 ? .white : Color(white: 0.35))
                        }
                    }
                }
                if strong > 0 {
                    Text("叱責・口論のうち、声が強め以上: \(strong)回")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.6))
                }

                let pairs = whoToWhom
                if !pairs.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("誰から誰へ（叱責・口論・褒める）")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.45))
                        ForEach(pairs, id: \.0) { pair in
                            HStack {
                                Text(pair.0)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(white: 0.8))
                                Spacer()
                                Text("\(pair.1)回")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }

                Text("決まった種類だけを数えています。点数は、マイナス（叱責・口論・泣く）とプラス（褒める・笑い）に、叱責と口論は声の強さ（1〜3）を掛けて足したものです。根拠の弱いものは入れていません。")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .detailCard()
    }

    private func scoreFigure(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(value > 0 ? color : Color(white: 0.4))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.5))
        }
    }

    private var whoToWhom: [(String, Int)] {
        let directed = counted.filter { ["reprimand", "conflict", "praise"].contains($0.event_type) && $0.target != nil }
        let grouped = Dictionary(grouping: directed) { event in
            let actor = SpotEventsCard.roleNames[event.actor] ?? event.actor
            let target = SpotEventsCard.roleNames[event.target ?? ""] ?? (event.target ?? "")
            return "\(actor) → \(target)・\(SpotEventsCard.typeNames[event.event_type] ?? event.event_type)"
        }
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    }

    // MARK: - Timeline

    private struct Band: Identifiable {
        let id: String
        let start: Double  // minutes from midnight
        let end: Double
    }

    private struct Dot: Identifiable {
        let id: String
        let minute: Double
        let kind: String  // マイナス / プラス / その他
    }

    private var bands: [Band] {
        spots.compactMap { spot in
            guard let start = startMinute(of: spot) else { return nil }
            let length = max((duration(of: spot) ?? 60) / 60, 4)  // short ones stay visible
            return Band(id: spot.id, start: start, end: min(start + length, 1440))
        }
    }

    private var dots: [Dot] {
        let startByRecording = Dictionary(spots.compactMap { spot in
            spot.recordedAt.flatMap { key in startMinute(of: spot).map { (key, $0) } }
        }, uniquingKeysWith: { first, _ in first })
        return counted.compactMap { event in
            guard let start = startByRecording[event.recorded_at] else { return nil }
            let direction = Self.direction[event.event_type] ?? 0
            return Dot(id: event.id, minute: start + event.start_sec / 60,
                       kind: direction < 0 ? "マイナス" : (direction > 0 ? "プラス" : "その他"))
        }
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailCardHeader(icon: "clock", title: "TIMELINE", badge: "1日の流れ")

            Chart {
                ForEach(bands) { band in
                    RectangleMark(
                        xStart: .value("開始", band.start),
                        xEnd: .value("終了", band.end),
                        y: .value("行", "録音")
                    )
                    .foregroundStyle(Color.accentTeal.opacity(0.35))
                    .cornerRadius(3)
                }
                ForEach(dots) { dot in
                    PointMark(
                        x: .value("時刻", dot.minute),
                        y: .value("行", "出来事")
                    )
                    .foregroundStyle(by: .value("向き", dot.kind))
                    .symbolSize(40)
                }
            }
            .chartForegroundStyleScale([
                "マイナス": Color.accentCoral, "プラス": Color.accentTeal, "その他": Color(white: 0.6),
            ])
            .chartXScale(domain: 0...1440)
            .chartXAxis {
                AxisMarks(values: Array(stride(from: 0, through: 1440, by: 180))) { value in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel {
                        if let minute = value.as(Double.self) {
                            Text("\(Int(minute) / 60)時")
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.5))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(.system(size: 10)).foregroundStyle(Color(white: 0.5))
                }
            }
            .chartLegend(position: .bottom, spacing: 8)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(Color.clear).contentShape(Rectangle())
                        .onTapGesture { location in
                            guard let plot = proxy.plotFrame else { return }
                            let x = location.x - geometry[plot].origin.x
                            guard let minute: Double = proxy.value(atX: x) else { return }
                            if let band = bands.min(by: { distance(minute, $0) < distance(minute, $1) }),
                               distance(minute, band) <= 20 {
                                selectedSpot = spots.first { $0.id == band.id }
                            }
                        }
                }
            }
            .frame(height: 120)

            Text("帯を押すと、その録音の詳細が開きます")
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.4))
        }
        .detailCard()
    }

    private func distance(_ minute: Double, _ band: Band) -> Double {
        minute < band.start ? band.start - minute : (minute > band.end ? minute - band.end : 0)
    }

    // MARK: - Recordings

    private var recordingsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            DetailCardHeader(icon: "waveform", title: "RECORDINGS", badge: "録音ごと")
                .padding(.bottom, 6)
            ForEach(spots) { spot in
                Button {
                    selectedSpot = spot
                } label: {
                    recordingRow(spot)
                }
                .buttonStyle(.plain)
                if spot.id != spots.last?.id {
                    Divider().background(Color.white.opacity(0.08))
                }
            }
        }
        .detailCard()
    }

    private func recordingRow(_ spot: DashboardTimeBlock) -> some View {
        let run = spot.recordedAt.flatMap { runs[$0] }
        let mine = counted.filter { $0.recorded_at == spot.recordedAt }
        let countText = SpotEventsCard.typeOrder.compactMap { type -> String? in
            let n = mine.filter { $0.event_type == type }.count
            return n > 0 ? "\(SpotEventsCard.typeNames[type] ?? type) \(n)" : nil
        }.joined(separator: "・")

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(spot.displayTime)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    if let length = duration(of: spot) {
                        Text(durationText(length))
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.55))
                    }
                    if let activity = run?.activity, activity != "unknown" {
                        Text(SpotEventsCard.activityNames[activity] ?? activity)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.accentTeal)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentTeal.opacity(0.15)))
                    }
                }
                if !countText.isEmpty {
                    Text(countText)
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.7))
                }
                if let summary = spot.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.6))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if let vibe = spot.vibeScore {
                    Text(String(format: "%.0f", vibe))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Color.vibeScoreColor(for: vibe))
                    Text("Vibe")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.45))
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.35))
                .padding(.top, 4)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private var dateTitle: String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: localDate) else { return localDate }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日（E）"
        return formatter.string(from: date)
    }

    /// Minutes from midnight of the recording's local start (local_time).
    private func startMinute(of spot: DashboardTimeBlock) -> Double? {
        guard let localTime = spot.localTime else { return nil }
        let time = localTime.split(whereSeparator: { $0 == "T" || $0 == " " }).dropFirst().first ?? ""
        let parts = time.split(separator: ":").compactMap { Double($0.prefix(2)) }
        guard parts.count >= 2 else { return nil }
        return parts[0] * 60 + parts[1] + (parts.count > 2 ? parts[2] / 60 : 0)
    }

    /// Length in seconds: the events run's audio length, else profile_result.recording.duration_seconds.
    private func duration(of spot: DashboardTimeBlock) -> Double? {
        if let key = spot.recordedAt, let seconds = runs[key]?.audio_seconds { return seconds }
        guard let raw = spot.recordingRaw, let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (object["duration_seconds"] as? NSNumber)?.doubleValue
    }

    private func durationText(_ seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes >= 60 { return "\(minutes / 60)時間\(minutes % 60)分" }
        return minutes > 0 ? "\(minutes)分" : "\(Int(seconds))秒"
    }

    // MARK: - Loading

    private func load() async {
        isLoading = true
        let timezone = deviceManager.getTimezone(for: deviceId)
        async let summaryTask = dataManager.fetchDailyResults(deviceId: deviceId, localDate: localDate, timezone: timezone)
        async let spotsTask = dataManager.fetchDashboardTimeBlocks(deviceId: deviceId, localDate: localDate, timezone: timezone)
        async let eventsTask = loadEvents()
        summary = await summaryTask
        spots = await spotsTask
        await eventsTask
        isLoading = false
    }

    private func loadEvents() async {
        let client = SupabaseClientManager.shared.client
        let allRuns: [EventRun] = (try? await client
            .from("spot_event_runs")
            .select("recorded_at, extractor_version, activity, audio_seconds")
            .eq("device_id", value: deviceId)
            .eq("local_date", value: localDate)
            .execute()
            .value) ?? []
        var newest: [String: EventRun] = [:]
        for run in allRuns where (newest[run.recorded_at]?.extractor_version ?? "") < run.extractor_version {
            newest[run.recorded_at] = run
        }
        let rows: [DayEvent] = (try? await client
            .from("spot_events")
            .select("recorded_at, extractor_version, seq, event_type, start_sec, actor, target, intensity, confidence")
            .eq("device_id", value: deviceId)
            .eq("local_date", value: localDate)
            .order("recorded_at", ascending: true)
            .order("seq", ascending: true)
            .execute()
            .value) ?? []
        runs = newest
        events = rows.filter { newest[$0.recorded_at]?.extractor_version == $0.extractor_version }
    }
}
