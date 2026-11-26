//
//  SpotReadingCard.swift
//  ios_watchme_v9
//
//  A trial (2026-11-26): the recording read for how the people got along, in three layers
//  on one timeline. Pins mark where an exchange went well (above the line) or did not
//  (below), an emoji on the line says what the talk was about, and the voice runs behind.
//  The data is profile_result.reading; a recording without it shows nothing here.
//  Direction and what is left open: platform docs/backlog.md, docs/research/moments-and-feelings-2026-11-25.md
//

import SwiftUI

// MARK: - The reading (profile_result.reading)

struct SpotReading: Decodable {
    struct Pin: Decodable, Identifiable {
        let sec: Double
        let kind: String        // "good" or "concern"
        let weight: Int         // 1 small, 2 clear, 3 for the family's record
        let who: String
        let label: String
        let why: String
        var id: String { "\(sec)-\(label)" }
        var isGood: Bool { kind == "good" }
    }

    struct Topic: Decodable, Identifiable {
        let sec: Double
        let emoji: String
        let what: String
        var id: Double { sec }
    }

    struct Episode: Decodable, Identifiable {
        let fromSec: Double
        let toSec: Double
        let title: String
        let course: String
        let quotes: String
        let reading: String
        let adults: String
        let children: String
        var id: Double { fromSec }
    }

    struct Person: Decodable, Identifiable {
        let who: String
        let today: String
        let toFollow: String
        var id: String { who }
    }

    struct Suggestion: Decodable, Identifiable {
        let `for`: String
        let suggestion: String
        var id: String { suggestion }
    }

    let pins: [Pin]
    let topics: [Topic]
    let episodes: [Episode]
    let summary: [String]
    let suggestions: [Suggestion]
    let record: [Person]

    static func parse(_ raw: String?) -> SpotReading? {
        guard let data = raw?.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(SpotReading.self, from: data)
    }

    func episode(at sec: Double) -> Episode? {
        episodes.first { $0.fromSec <= sec && sec <= $0.toSec + 5 }
    }
}

// MARK: - The timeline card

struct SpotReadingCard: View {
    let subjectId: String
    let recordedAt: String
    let reading: SpotReading
    let metricsRaw: String?

    private enum Layers: String, CaseIterable, Identifiable {
        case pins = "ピン"
        case topics = "＋話題"
        case all = "全部"
        var id: String { rawValue }
    }

    private enum Picked: Equatable {
        case pin(String)
        case topic(Double)
    }

    @State private var layers = Layers.all
    @State private var picked: Picked?
    @State private var openEpisode: SpotReading.Episode?

    private static let height: CGFloat = 230
    private static let middle: CGFloat = 115
    /// Width of one minute of the recording; the picture scrolls sideways.
    private static let minuteWidth: CGFloat = 38
    private static let inset: CGFloat = 16

    private var voice: [VoicePoint] { VoicePoint.parse(metricsRaw: metricsRaw) }

    private var duration: Double {
        max(reading.pins.map(\.sec).max() ?? 0, reading.topics.map(\.sec).max() ?? 0,
            reading.episodes.map(\.toSec).max() ?? 0, voice.map(\.end).max() ?? 0, 60)
    }

    private var width: CGFloat { max(320, CGFloat(duration / 60) * Self.minuteWidth + Self.inset * 2) }

    private func x(_ sec: Double) -> CGFloat {
        Self.inset + CGFloat(sec / duration) * (width - Self.inset * 2)
    }

    private func radius(_ pin: SpotReading.Pin) -> CGFloat { [5, 5, 8, 12][min(max(pin.weight, 0), 3)] }

    /// Good pins above the line, the others below; the heavier, the further out.
    private func y(_ pin: SpotReading.Pin) -> CGFloat {
        let step = CGFloat(3 - min(max(pin.weight, 1), 3)) * 12
        return pin.isGood ? 30 + step : Self.height - 44 - step
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailCardHeader(icon: "mappin.and.ellipse", title: "TIMELINE", badge: "試作", info: Self.info)

            Picker("表示", selection: $layers) {
                ForEach(Layers.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    Canvas { context, _ in draw(&context) }

                    if layers != .pins {
                        ForEach(reading.topics) { topic in
                            Text(topic.emoji)
                                .font(.system(size: 18))
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                                .onTapGesture { picked = .topic(topic.sec) }
                                .position(x: x(topic.sec), y: Self.middle)
                        }
                    }

                    ForEach(reading.pins) { pin in
                        let isPicked = picked == .pin(pin.id)
                        Circle()
                            .fill(pin.isGood ? Color.accentTeal : Color.accentCoral)
                            .frame(width: radius(pin) * 2, height: radius(pin) * 2)
                            .overlay(Circle().stroke(Color.white, lineWidth: isPicked ? 2 : 0))
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                            .onTapGesture { picked = .pin(pin.id) }
                            .position(x: x(pin.sec), y: y(pin))
                    }
                }
                .frame(width: width, height: Self.height)
            }

            HStack(spacing: 14) {
                legend(Color.accentTeal, "うまくいった")
                legend(Color.accentCoral, "気になる")
                Text("丸が大きいほど重い")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.45))
            }

            pickedPanel
        }
        .detailCard()
        .sheet(item: $openEpisode) { episode in
            SpotReadingEpisodeView(episode: episode, subjectId: subjectId, recordedAt: recordedAt)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: Drawing (the wave, the middle line, the stems, the minutes)

    private func draw(_ context: inout GraphicsContext) {
        // Minutes along the bottom, every five
        var minute = 0.0
        while minute * 60 <= duration {
            let px = x(minute * 60)
            var line = Path()
            line.move(to: CGPoint(x: px, y: 8))
            line.addLine(to: CGPoint(x: px, y: Self.height - 18))
            context.stroke(line, with: .color(.white.opacity(0.06)), lineWidth: 1)
            context.draw(Text("\(Int(minute))分").font(.system(size: 10)).foregroundColor(Color(white: 0.5)),
                         at: CGPoint(x: px + 3, y: Self.height - 8), anchor: .leading)
            minute += 5
        }

        // The voice of every utterance, taller where it was louder than the speaker's usual
        if layers == .all {
            for point in voice {
                let louder = min(max(point.louder ?? 1, 0.3), 3)
                let half = 4 + 22 * CGFloat((louder - 0.3) / 2.7)
                let rect = CGRect(x: x(point.start), y: Self.middle - half,
                                  width: max(x(point.end) - x(point.start), 1.5), height: half * 2)
                context.fill(Path(roundedRect: rect, cornerRadius: 1),
                             with: .color(point.level >= 2 ? Color.accentCoral.opacity(0.28) : Color.white.opacity(0.11)))
            }
        }

        var middle = Path()
        middle.move(to: CGPoint(x: Self.inset, y: Self.middle))
        middle.addLine(to: CGPoint(x: width - Self.inset, y: Self.middle))
        context.stroke(middle, with: .color(.white.opacity(0.25)), lineWidth: 1)

        for pin in reading.pins {
            var stem = Path()
            stem.move(to: CGPoint(x: x(pin.sec), y: y(pin)))
            stem.addLine(to: CGPoint(x: x(pin.sec), y: Self.middle + (pin.isGood ? -18 : 18)))
            context.stroke(stem, with: .color((pin.isGood ? Color.accentTeal : Color.accentCoral).opacity(0.35)), lineWidth: 1)
        }
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(Color(white: 0.6))
        }
    }

    // MARK: What was picked

    @ViewBuilder
    private var pickedPanel: some View {
        switch picked {
        case .pin(let id):
            if let pin = reading.pins.first(where: { $0.id == id }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(pin.isGood ? "うまくいった" : "気になる")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(pin.isGood ? .accentTeal : .accentCoral)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill((pin.isGood ? Color.accentTeal : Color.accentCoral).opacity(0.15)))
                        Text(Self.clock(pin.sec))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(white: 0.55))
                        Spacer()
                        if SavedRecordings.canSave(subjectId: subjectId) {
                            EventPlayButton(id: "\(recordedAt)-reading-\(pin.id)", subjectId: subjectId, recordedAt: recordedAt,
                                            start: pin.sec, end: pin.sec + 12)
                        }
                    }
                    Text(pin.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(pin.who)
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.6))
                    Text(pin.why)
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.82))
                        .fixedSize(horizontal: false, vertical: true)
                    if let episode = reading.episode(at: pin.sec) {
                        Button("この場面を詳しく") { openEpisode = episode }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.accentTeal)
                            .padding(.top, 2)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.darkElevated))
            }
        case .topic(let sec):
            if let topic = reading.topics.first(where: { $0.sec == sec }) {
                HStack(alignment: .top, spacing: 10) {
                    Text(topic.emoji).font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Self.clock(topic.sec))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(white: 0.55))
                        Text(topic.what)
                            .font(.system(size: 13))
                            .foregroundColor(Color(white: 0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.darkElevated))
            }
        case nil:
            Text("丸か絵文字を押すと、その場面が出ます")
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.5))
        }
    }

    static func clock(_ sec: Double) -> String {
        String(format: "%d:%02d", Int(sec) / 60, Int(sec) % 60)
    }

    static let info = """
        録音の中のやりとりを読んだ試作です。
        ・丸（ピン）: 線より上はやりとりがうまくいった場面、下は気になる場面。大きいほど重い場面です。
        ・絵文字: そのとき何の話をしていたか。
        ・後ろの波: 話していた声。その人のふだんより大きいほど高くなります。
        丸を押すと理由が出て、その場面を再生できます。
        """
}

// MARK: - The day in a few sentences, and what is folded away

struct SpotReadingSummaryCard: View {
    let reading: SpotReading
    @State private var showsPeople = false
    @State private var showsSuggestions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailCardHeader(icon: "list.bullet", title: "この録音のまとめ", badge: "試作")
            VStack(alignment: .leading, spacing: 8) {
                ForEach(reading.summary, id: \.self) { sentence in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(Color(white: 0.45)).frame(width: 4, height: 4).padding(.top, 8)
                        Text(sentence)
                            .font(.system(size: 14))
                            .foregroundColor(Color(white: 0.88))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if !reading.record.isEmpty {
                DetailCardHeader(icon: "person.2", title: "人ごとの記録", expanded: $showsPeople)
                if showsPeople {
                    ForEach(reading.record) { person in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(person.who)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Text(person.today)
                                .font(.system(size: 13))
                                .foregroundColor(Color(white: 0.82))
                                .fixedSize(horizontal: false, vertical: true)
                            Text("他の日と比べること: \(person.toFollow)")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.55))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if !reading.suggestions.isEmpty {
                DetailCardHeader(icon: "lightbulb", title: "提案", expanded: $showsSuggestions)
                if showsSuggestions {
                    ForEach(reading.suggestions) { item in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.for)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(white: 0.6))
                            Text(item.suggestion)
                                .font(.system(size: 13))
                                .foregroundColor(Color(white: 0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .detailCard()
    }
}

// MARK: - One episode in full

struct SpotReadingEpisodeView: View {
    let episode: SpotReading.Episode
    let subjectId: String
    let recordedAt: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("\(SpotReadingCard.clock(episode.fromSec)) – \(SpotReadingCard.clock(episode.toSec))")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(white: 0.55))
                        Spacer()
                        if SavedRecordings.canSave(subjectId: subjectId) {
                            EventPlayButton(id: "\(recordedAt)-episode-\(episode.id)", subjectId: subjectId, recordedAt: recordedAt,
                                            start: episode.fromSec, end: episode.toSec)
                        }
                    }
                    section("流れ", episode.course)
                    section("発言", episode.quotes)
                    section("読み", episode.reading)
                    section("大人", episode.adults)
                    section("子ども", episode.children)
                }
                .padding(20)
            }
            .background(Color.darkBase)
            .navigationTitle(episode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    CloseButton { dismiss() }
                        .foregroundColor(.accentTeal)
                }
            }
        }
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(white: 0.5))
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
