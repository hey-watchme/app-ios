//
//  SpotTimelineChart.swift
//  ios_watchme_v9
//
//  The course of one recording, left to right: the counted events per stretch of time,
//  and under it the measured voice of every utterance (profile_result.metrics.voice,
//  platform backend/common/metrics/voice.py). A trial (2026-11-20): the three styles of
//  the event chart are there to compare, and the grouping of event types is provisional.
//

import SwiftUI
import Charts

// MARK: - What the charts draw

/// Event types drawn as one line. The colour belongs to the group, in every recording.
struct TimelineSeries: Identifiable {
    let id: String
    let name: String
    let types: [String]
    let color: Color

    static let all = [
        TimelineSeries(id: "trouble", name: "叱責・口論", types: ["reprimand", "conflict"], color: .accentCoral),
        TimelineSeries(id: "praise", name: "褒める", types: ["praise"], color: .accentTeal),
        TimelineSeries(id: "laughter", name: "笑い", types: ["laughter"],
                       color: Color(red: 0.95, green: 0.79, blue: 0.30)),
        TimelineSeries(id: "crying", name: "泣く", types: ["crying"],
                       color: Color(red: 0.35, green: 0.66, blue: 1.0)),
        TimelineSeries(id: "body", name: "咳など", types: ReportEvents.bodyTypes, color: Color(white: 0.6)),
    ]

    static func of(_ type: String) -> TimelineSeries? {
        all.first { $0.types.contains(type) }
    }
}

struct TimelineEvent: Identifiable {
    let id: Int
    let type: String
    let start: Double
    let end: Double
    let intensity: String?
}

/// One measured utterance, against the same speaker's typical voice in this recording.
struct VoicePoint: Identifiable {
    let id: Int
    let time: Double
    /// 1, 2 (raised) or 3 (shouting), as graded by the measure stage.
    let level: Int
    /// Loudness as a multiple of the speaker's typical loudness.
    let louder: Double?
    /// Semitones above the speaker's typical pitch.
    let pitchUp: Double?
    /// How much more strained than the speaker's typical voice (Hammarberg index, sign flipped).
    let strain: Double?

    static func parse(metricsRaw: String?) -> [VoicePoint] {
        guard let raw = metricsRaw, let data = raw.data(using: .utf8),
              let metrics = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let voice = metrics["voice"] as? [String: Any],
              let utterances = voice["utterances"] as? [[String: Any]] else { return [] }
        let typical = voice["typical"] as? [String: [String: Any]] ?? [:]
        func number(_ value: Any?) -> Double? { (value as? NSNumber)?.doubleValue }

        return utterances.enumerated().compactMap { index, u in
            guard let start = number(u["start"]), let end = number(u["end"]) else { return nil }
            let base = typical[u["speaker"] as? String ?? ""] ?? [:]
            var pitchUp: Double?
            if let own = number(u["pitch_st"]), let usual = number(base["pitch_st"]) { pitchUp = own - usual }
            var strain: Double?
            if let own = number(u["tension"]), let usual = number(base["tension"]) { strain = usual - own }
            return VoicePoint(id: index, time: (start + end) / 2, level: Int(number(u["level"]) ?? 1),
                              louder: number(u["louder"]), pitchUp: pitchUp, strain: strain)
        }
    }
}

/// The time axis both charts share: the recording cut into equal stretches.
struct TimelineScale {
    /// Seconds per stretch.
    let bin: Double
    let binCount: Int

    init(duration: Double) {
        bin = duration <= 180 ? 15 : (duration <= 600 ? 60 : (duration <= 1800 ? 120 : 300))
        binCount = max(Int((duration / bin).rounded(.up)), 1)
    }

    var domain: ClosedRange<Double> { 0...(Double(binCount) * bin) }

    func binIndex(of time: Double) -> Int {
        min(max(Int(time / bin), 0), binCount - 1)
    }

    func range(of index: Int) -> ClosedRange<Double> {
        (Double(index) * bin)...(Double(index + 1) * bin)
    }

    var ticks: [Double] {
        let step = [15.0, 30, 60, 120, 300, 600, 900, 1800].first { domain.upperBound / $0 <= 6 } ?? 3600
        return Array(stride(from: 0, through: domain.upperBound, by: step))
    }

    /// Elapsed time from the start of the recording.
    static func label(_ seconds: Double) -> String {
        let total = Int(seconds)
        if total % 60 == 0 { return "\(total / 60)分" }
        return total < 60 ? "\(total)秒" : String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Shared chart parts

private let timelineAxisLabelWidth: CGFloat = 52

private struct SelectedBinMark: ChartContent {
    let scale: TimelineScale
    let selectedBin: Int?

    var body: some ChartContent {
        if let selectedBin {
            let range = scale.range(of: selectedBin)
            RectangleMark(xStart: .value("開始", range.lowerBound), xEnd: .value("終了", range.upperBound))
                .foregroundStyle(Color.white.opacity(0.08))
        }
    }
}

private extension View {
    /// The shared time axis, and a tap that selects the stretch under the finger.
    func timelineAxis(_ scale: TimelineScale, selectedBin: Binding<Int?>) -> some View {
        self
            .chartXScale(domain: scale.domain)
            .chartXAxis {
                AxisMarks(values: scale.ticks) { value in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel {
                        if let seconds = value.as(Double.self) {
                            Text(TimelineScale.label(seconds))
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.56))
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            guard let anchor = proxy.plotFrame,
                                  let time: Double = proxy.value(atX: location.x - geometry[anchor].minX) else { return }
                            let bin = scale.binIndex(of: time)
                            selectedBin.wrappedValue = selectedBin.wrappedValue == bin ? nil : bin
                        }
                }
            }
    }
}

private func timelineAxisLabel(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 10))
        .foregroundColor(Color(white: 0.56))
        .frame(width: timelineAxisLabelWidth, alignment: .leading)
}

// MARK: - Events over the recording

struct SpotTimelineChart: View {
    enum Style: String, CaseIterable, Identifiable {
        case line = "折れ線"
        case bar = "棒"
        case lanes = "帯"
        var id: String { rawValue }
    }

    /// Counted events only (low-confidence ones left out).
    let events: [TimelineEvent]
    let scale: TimelineScale
    let style: Style
    @Binding var selectedBin: Int?

    private struct BinCount: Identifiable {
        let series: TimelineSeries
        let bin: Int
        let count: Int
        /// Counts of the groups drawn under this one in the same stretch (where its bar starts).
        let below: Int
        var id: String { "\(series.id)-\(bin)" }
    }

    /// The groups that occurred in this recording, in their fixed order.
    var series: [TimelineSeries] {
        TimelineSeries.all.filter { group in events.contains { group.types.contains($0.type) } }
    }

    private var counts: [BinCount] {
        var stacked = [Int](repeating: 0, count: scale.binCount)
        return series.flatMap { group in
            (0..<scale.binCount).map { bin in
                let count = events.filter {
                    group.types.contains($0.type) && scale.binIndex(of: $0.start) == bin
                }.count
                defer { stacked[bin] += count }
                return BinCount(series: group, bin: bin, count: count, below: stacked[bin])
            }
        }
    }

    var body: some View {
        let counts = counts
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if style == .lanes {
                    lanesChart
                } else {
                    countChart(counts)
                }
            }
            .timelineAxis(scale, selectedBin: $selectedBin)
            .frame(height: 150)

            HStack(spacing: 12) {
                ForEach(series) { group in
                    HStack(spacing: 5) {
                        Circle().fill(group.color).frame(width: 8, height: 8)
                        Text(group.name)
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.7))
                    }
                }
            }
        }
    }

    private func countChart(_ counts: [BinCount]) -> some View {
        // The tallest point: a single line's stretch, or a whole stack of bars
        let tallest: Int = style == .line
            ? (counts.map(\.count).max() ?? 0)
            : (counts.map { $0.below + $0.count }.max() ?? 0)
        let top = max(tallest, 2)
        let step = max(1, Int((Double(top) / 3).rounded(.up)))
        let gap = scale.bin * 0.12

        return Chart {
            SelectedBinMark(scale: scale, selectedBin: selectedBin)

            if style == .line {
                ForEach(counts) { item in
                    LineMark(
                        x: .value("時間", scale.range(of: item.bin).lowerBound + scale.bin / 2),
                        y: .value("回数", item.count),
                        series: .value("種類", item.series.name)
                    )
                    .foregroundStyle(item.series.color)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))
                }
                ForEach(counts.filter { $0.count > 0 }) { item in
                    PointMark(
                        x: .value("時間", scale.range(of: item.bin).lowerBound + scale.bin / 2),
                        y: .value("回数", item.count)
                    )
                    .foregroundStyle(item.series.color)
                    .symbolSize(36)
                }
            } else {
                ForEach(counts.filter { $0.count > 0 }) { item in
                    RectangleMark(
                        xStart: .value("開始", scale.range(of: item.bin).lowerBound + gap),
                        xEnd: .value("終了", scale.range(of: item.bin).upperBound - gap),
                        yStart: .value("下", item.below),
                        yEnd: .value("回数", item.below + item.count)
                    )
                    .foregroundStyle(item.series.color)
                    .cornerRadius(2)
                }
            }
        }
        .chartYScale(domain: 0...top)
        .chartYAxis {
            AxisMarks(position: .trailing, values: Array(stride(from: 0, through: top, by: step))) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.10))
                AxisValueLabel {
                    timelineAxisLabel(value.as(Int.self).map { "\($0)回" } ?? "")
                }
            }
        }
    }

    /// Each event where it happened and for how long, one row per group.
    private var lanesChart: some View {
        // A one-second event would be too thin to see
        let minimumWidth = scale.domain.upperBound / 100
        // Rows by number, top to bottom, so that the axis takes the same width as in the other charts
        let names = series.map(\.name)
        let rows = Dictionary(uniqueKeysWithValues: series.enumerated().map { ($1.id, Double(names.count - 1 - $0)) })

        return Chart {
            SelectedBinMark(scale: scale, selectedBin: selectedBin)

            ForEach(events) { event in
                if let group = TimelineSeries.of(event.type), let row = rows[group.id] {
                    RectangleMark(
                        xStart: .value("開始", event.start),
                        xEnd: .value("終了", max(event.end, event.start + minimumWidth)),
                        yStart: .value("下", row - 0.22),
                        yEnd: .value("上", row + 0.22)
                    )
                    .foregroundStyle(group.color.opacity(event.intensity == "mild" ? 0.55 : 1))
                    .cornerRadius(2)
                }
            }
        }
        .chartYScale(domain: -0.5...(Double(names.count) - 0.5))
        .chartYAxis {
            AxisMarks(position: .trailing, values: names.indices.map(Double.init)) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.10))
                AxisValueLabel {
                    timelineAxisLabel(value.as(Double.self).map { names[names.count - 1 - Int($0)] } ?? "")
                }
            }
        }
    }
}

// MARK: - The voice over the recording

struct SpotVoiceChart: View {
    enum Measure: String, CaseIterable, Identifiable {
        case loudness = "大きさ"
        case pitch = "高さ"
        case strain = "張り"
        var id: String { rawValue }

        var caption: String {
            switch self {
            case .loudness: return "発話ごとの声の大きさ。その人の、この録音でのふだんの何倍か。"
            case .pitch: return "発話ごとの声の高さ。その人の、この録音でのふだんより何半音高いか。"
            case .strain: return "発話ごとの声の張り。その人の、この録音でのふだんより張っているほど上。"
            }
        }
    }

    let points: [VoicePoint]
    let scale: TimelineScale
    let measure: Measure
    @Binding var selectedBin: Int?

    private func value(_ point: VoicePoint) -> Double? {
        switch measure {
        case .loudness: return point.louder
        case .pitch: return point.pitchUp
        case .strain: return point.strain
        }
    }

    private func axisText(_ value: Double) -> String {
        measure == .loudness ? String(format: "%g倍", value) : String(format: "%+g", value)
    }

    var body: some View {
        // Raised voices are drawn last, on top of the rest
        let ordered = points.sorted { $0.level < $1.level }

        VStack(alignment: .leading, spacing: 8) {
            Chart {
                SelectedBinMark(scale: scale, selectedBin: selectedBin)

                RuleMark(y: .value("ふだん", measure == .loudness ? 1.0 : 0.0))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1))

                ForEach(ordered) { point in
                    if let value = value(point) {
                        PointMark(x: .value("時間", point.time), y: .value(measure.rawValue, value))
                            .foregroundStyle(point.level >= 2 ? Color.accentCoral : Color.white.opacity(0.3))
                            .symbolSize(point.level >= 3 ? 60 : (point.level == 2 ? 30 : 10))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.10))
                    AxisValueLabel {
                        timelineAxisLabel(value.as(Double.self).map(axisText) ?? "")
                    }
                }
            }
            .timelineAxis(scale, selectedBin: $selectedBin)
            .frame(height: 110)

            Text(measure.caption + "赤い点は、声が強まったと測定された発話（大きいほど強い）。マイクとの距離でも変わります。")
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.4))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
