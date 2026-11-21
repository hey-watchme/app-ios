//
//  SpotTimelineChart.swift
//  ios_watchme_v9
//
//  One recording as a picture, left to right: an emoji where each event happened, warm
//  ones above the middle line and hard ones below it, and behind them the measured voice
//  of every utterance (profile_result.metrics.voice, platform backend/common/metrics/voice.py)
//  as a band around the line. Tapping an emoji opens a balloon with what was said.
//  A trial (2026-11-20): which events go where, and the emoji, are provisional.
//

import SwiftUI
import Charts

// MARK: - What the picture draws

/// How far an emoji sits from the middle line: at least this, and up to this much more.
private let timelineMinReach = 0.7
private let timelineReachSpan = 2.5

/// Heights of the rows of small words along the bottom of the picture.
private let timelineWordRows = [-4.0, -4.45, -4.9]

struct TimelineEvent: Identifiable {
    let id: Int
    let type: String
    let start: Double
    let end: Double
    let intensity: String?

    /// The emoji of an event with feeling in it; nil for the ones written as a small word.
    var emoji: String? {
        ["reprimand": "😠", "conflict": "💢", "crying": "😢", "laughter": "😄", "praise": "👏"][type]
    }

    /// The word for an event without an emoji (body sounds, a mishap).
    var word: String {
        type == "mishap" ? "落とす" : (SpotEventsCard.typeNames[type] ?? type)
    }

    /// +1 for warm events (drawn above the middle line), -1 for hard ones, nil for the words.
    var direction: Double? {
        switch type {
        case "praise", "laughter": return 1
        case "reprimand", "conflict", "crying": return -1
        default: return nil
        }
    }

    /// How strong it was, 0...1, when no voice was measured: the graded strength of a
    /// reprimand or conflict, the middle for the rest.
    var gradedStrength: Double {
        switch intensity {
        case "severe": return 1
        case "strong": return 0.6
        case "mild": return 0.2
        default: return 0.5
        }
    }

    /// Height of an event with no voice to go by; the chart uses the measured voice when it has it.
    var height: Double {
        guard let direction else { return timelineWordRows[0] }
        return direction * (timelineMinReach + timelineReachSpan * gradedStrength)
    }
}

/// One measured utterance, against the same speaker's typical voice in this recording.
struct VoicePoint: Identifiable {
    let id: Int
    let start: Double
    let end: Double
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
            return VoicePoint(id: index, start: start, end: end, level: Int(number(u["level"]) ?? 1),
                              louder: number(u["louder"]), pitchUp: pitchUp, strain: strain)
        }
    }
}

/// Which measurement of the voice the band behind the events shows.
enum VoiceMeasure: String, CaseIterable, Identifiable {
    case strain = "張り"
    case loudness = "大きさ"
    case pitch = "高さ"
    var id: String { rawValue }

    func value(_ point: VoicePoint) -> Double? {
        switch self {
        case .strain: return point.strain
        case .loudness: return point.louder.map { $0 - 1 }  // above the typical loudness
        case .pitch: return point.pitchUp
        }
    }
}

// MARK: - The picture

struct SpotTimelineChart<Balloon: View>: View {
    /// Counted events only (low-confidence ones left out).
    let events: [TimelineEvent]
    let voice: [VoicePoint]
    let measure: VoiceMeasure
    /// Length of the recording in seconds.
    let duration: Double
    @Binding var selectedId: Int?
    /// What the balloon under the picture says about the selected event.
    @ViewBuilder let balloon: (TimelineEvent) -> Balloon

    /// Where the selected event is, across the picture (for the balloon's tail).
    @State private var selectedX: CGFloat?

    private static var yDomain: ClosedRange<Double> { -5.25...3.4 }
    /// How far from the middle line the voice band reaches at most.
    private static var bandReach: Double { 2.4 }

    private var xDomain: ClosedRange<Double> {
        // Room at both ends, so that an emoji at the very start or end is not cut off
        let margin = max(duration, 1) * 0.04
        return -margin...(max(duration, 1) + margin)
    }

    private var ticks: [Double] {
        let step = [5.0, 15, 30, 60, 120, 300, 600, 900, 1800].first { duration / $0 <= 6 } ?? 3600
        return Array(stride(from: 0, through: duration, by: step))
    }

    /// Elapsed time from the start of the recording.
    private func tickLabel(_ seconds: Double) -> String {
        let total = Int(seconds)
        if total % 60 == 0 { return "\(total / 60)分" }
        return total < 60 ? "\(total)秒" : String(format: "%d:%02d", total / 60, total % 60)
    }

    /// The value a full-height bar of the band stands for: near the top of this recording's
    /// values, so that one extreme utterance does not flatten the rest.
    private var bandReference: Double {
        let values = voice.compactMap { measure.value($0) }.filter { $0 > 0 }.sorted()
        guard !values.isEmpty else { return 1 }
        return max(values[Int(Double(values.count - 1) * 0.9)], 0.001)
    }

    private struct WaveStep: Identifiable {
        let time: Double
        let reach: Double
        var id: Double { time }
    }

    /// The utterances gathered into about 120 steps along the recording: each step takes its
    /// strongest voice, then neighbours are averaged so the outline reads as one wave.
    private func wave(reference: Double) -> [WaveStep] {
        guard !voice.isEmpty, duration > 0 else { return [] }
        let count = max(min(Int(duration / 2), 120), 2)   // a step is at least 2 seconds
        let width = duration / Double(count)
        var strongest = [Double](repeating: 0, count: count)
        for point in voice {
            let share = min(max((measure.value(point) ?? 0) / reference, 0), 1)
            // An utterance counts in every step it spans
            let first = min(max(Int(point.start / width), 0), count - 1)
            let last = min(max(Int(point.end / width), first), count - 1)
            for index in first...last {
                // Speech that is not above the usual still shows a little, so talk is visible
                strongest[index] = max(strongest[index], 0.08 + 0.92 * share)
            }
        }
        let smoothed = strongest.indices.map { index -> Double in
            let before = strongest[max(index - 1, 0)], after = strongest[min(index + 1, count - 1)]
            return (before + 2 * strongest[index] + after) / 4
        }
        return smoothed.enumerated().map { index, value in
            WaveStep(time: (Double(index) + 0.5) * width, reach: Self.bandReach * value)
        }
    }

    /// How strong the voice was around an event, 0...1 against this recording's strongest voices.
    private func voiceStrength(_ event: TimelineEvent, reference: Double) -> Double? {
        let around = voice.filter { $0.end >= event.start - 1 && $0.start <= event.end + 1 }
            .compactMap { measure.value($0) }
        guard let strongest = around.max() else { return nil }
        return min(max(strongest / reference, 0), 1)
    }

    /// Where each event is drawn. An emoji sits above or below the middle line by its kind,
    /// and further out the stronger the voice around it was, so the picture spreads over the
    /// whole height. A word that would run into the word before it drops a row.
    private var heights: [Int: Double] {
        let reference = bandReference
        let span = xDomain.upperBound - xDomain.lowerBound
        var rowEnds = [Double](repeating: -.infinity, count: timelineWordRows.count)
        var heights: [Int: Double] = [:]
        for event in events.sorted(by: { $0.start < $1.start }) {
            if let direction = event.direction {
                let strength = voiceStrength(event, reference: reference) ?? event.gradedStrength
                heights[event.id] = direction * (timelineMinReach + timelineReachSpan * strength)
                continue
            }
            // About 3.5% of the width per character at this size, centred on the event
            let half = span * 0.035 * Double(event.word.count) / 2
            let row = rowEnds.firstIndex { $0 <= event.start - half } ?? rowEnds.indices.min { rowEnds[$0] < rowEnds[$1] } ?? 0
            rowEnds[row] = event.start + half
            heights[event.id] = timelineWordRows[row]
        }
        return heights
    }

    var body: some View {
        let reference = bandReference
        let heights = heights
        let minimumWidth = (xDomain.upperBound - xDomain.lowerBound) / 160
        let selected = events.first { $0.id == selectedId }

        VStack(alignment: .leading, spacing: 0) {
            Chart {
                // The voice as one smooth wave around the middle line, wider where voices were
                // further above the speaker's typical voice. Flat where nobody spoke.
                ForEach(wave(reference: reference)) { step in
                    AreaMark(
                        x: .value("時間", step.time),
                        yStart: .value("下", -step.reach),
                        yEnd: .value("上", step.reach)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.white.opacity(0.12))
                }

                RuleMark(y: .value("中央", 0.0))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1))

                ForEach(events) { event in
                    // How long it went on
                    if let direction = event.direction, event.end - event.start > minimumWidth {
                        RuleMark(
                            xStart: .value("開始", event.start),
                            xEnd: .value("終了", event.end),
                            y: .value("位置", (heights[event.id] ?? event.height) - 0.5)
                        )
                        .foregroundStyle((direction > 0 ? Color.accentTeal : Color.accentCoral).opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    }
                }
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: Self.yDomain)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: ticks) { value in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel {
                        if let seconds = value.as(Double.self) {
                            Text(tickLabel(seconds))
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.56))
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                guard let anchor = proxy.plotFrame else { return }
                                select(at: location, plot: geometry[anchor], proxy: proxy)
                            }

                        // The stamps are drawn over the chart, not as chart symbols: a symbol
                        // is cut to its small frame, which showed half of each emoji on a phone.
                        // In time order, so a later event lies on top of an earlier one.
                        if let anchor = proxy.plotFrame {
                            let plot = geometry[anchor]
                            ForEach(events.sorted { $0.start < $1.start }) { event in
                                if let x = proxy.position(forX: event.start),
                                   let y = proxy.position(forY: heights[event.id] ?? event.height) {
                                    stamp(event, isSelected: event.id == selectedId)
                                        .fixedSize()
                                        .position(x: plot.minX + x, y: plot.minY + y)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: 250)
            // The balloon opens above the picture, where it is quiet, and over what is above
            // it, so the picture does not move under the finger
            .overlay(alignment: .top) {
                if let selected {
                    VStack(alignment: .leading, spacing: 0) {
                        balloon(selected)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.darkElevated))
                            .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
                        BalloonTailDown()
                            .fill(Color.darkElevated)
                            .frame(width: 14, height: 8)
                            .offset(x: (selectedX ?? 20) - 7)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    // A frame with no height at the top edge: the balloon grows upward out of
                    // it, so it sits above the picture and its tail ends at the picture's top
                    .frame(maxWidth: .infinity, maxHeight: 0, alignment: .bottom)
                }
            }
            .zIndex(1)
        }
    }

    @ViewBuilder
    private func stamp(_ event: TimelineEvent, isSelected: Bool) -> some View {
        if let emoji = event.emoji {
            Text(emoji)
                .font(.system(size: 22))
                .background(Circle().fill(Color.white.opacity(isSelected ? 0.25 : 0)).padding(-5))
        } else {
            Text(event.word)
                .font(.system(size: 9, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .white : Color(white: 0.6))
        }
    }

    /// Select the event drawn nearest to the tap; a tap away from every event closes the balloon.
    private func select(at location: CGPoint, plot: CGRect, proxy: ChartProxy) {
        let heights = heights
        var nearest: (event: TimelineEvent, distance: CGFloat, x: CGFloat)?
        for event in events {
            guard let x = proxy.position(forX: event.start), let y = proxy.position(forY: heights[event.id] ?? event.height) else { continue }
            let distance = hypot(plot.minX + x - location.x, plot.minY + y - location.y)
            if distance < (nearest?.distance ?? 32) {
                nearest = (event, distance, plot.minX + x)
            }
        }
        // Tapping the open one again closes it
        if let nearest, nearest.event.id != selectedId {
            selectedId = nearest.event.id
            selectedX = nearest.x
        } else {
            selectedId = nil
        }
    }
}

private struct BalloonTailDown: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
