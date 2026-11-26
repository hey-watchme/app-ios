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

    private static let height: CGFloat = 320
    private static let middle: CGFloat = 160
    /// Width of one minute of the recording; the picture scrolls sideways.
    private static let minuteWidth: CGFloat = 54
    private static let inset: CGFloat = 20
    private static let balloonWidth: CGFloat = 270
    /// How far from the middle line the voice reaches at most.
    private static let waveReach: CGFloat = 128
    private static let waveStep = 3.0

    // Worked out once: the card is drawn again on every tap, and parsing the measurements
    // (about 50 KB of JSON) for every mark made it slow.
    private let duration: Double
    private let width: CGFloat
    /// The voice per step of waveStep seconds, 0...1 against this recording's louder voices.
    private let wave: [CGFloat]
    /// Where each topic's emoji sits (it illustrates the talk; it is not on the line).
    private let topicY: [Double: CGFloat]

    init(subjectId: String, recordedAt: String, reading: SpotReading, metricsRaw: String?) {
        self.subjectId = subjectId
        self.recordedAt = recordedAt
        self.reading = reading
        let voice = VoicePoint.parse(metricsRaw: metricsRaw)
        let duration = max(reading.pins.map(\.sec).max() ?? 0, reading.topics.map(\.sec).max() ?? 0,
                           reading.episodes.map(\.toSec).max() ?? 0, voice.map(\.end).max() ?? 0, 60)
        self.duration = duration
        let width = max(320, CGFloat(duration / 60) * Self.minuteWidth + Self.inset * 2)
        self.width = width
        self.wave = Self.wave(voice, duration: duration)
        self.topicY = Self.scatter(reading, duration: duration, width: width)
    }

    /// The utterances as one outline: each step takes its loudest voice against the speaker's
    /// usual, scaled to this recording's louder voices so the picture fills, then smoothed.
    private static func wave(_ voice: [VoicePoint], duration: Double) -> [CGFloat] {
        let count = max(Int(duration / waveStep) + 1, 2)
        let values = voice.compactMap(\.louder).filter { $0 > 0 }.sorted()
        guard !values.isEmpty else { return [] }
        let reference = max(values[Int(Double(values.count - 1) * 0.9)], 0.001)
        var strongest = [Double](repeating: 0, count: count)
        for point in voice {
            let share = min(max((point.louder ?? 0) / reference, 0), 1)
            let first = min(max(Int(point.start / waveStep), 0), count - 1)
            let last = min(max(Int(point.end / waveStep), first), count - 1)
            for index in first...last {
                strongest[index] = max(strongest[index], 0.18 + 0.82 * share)
            }
        }
        for _ in 0..<2 {
            strongest = strongest.indices.map { index in
                let before = strongest[max(index - 1, 0)], after = strongest[min(index + 1, count - 1)]
                return (before + 2 * strongest[index] + after) / 4
            }
        }
        return strongest.map { CGFloat($0) }
    }

    /// Emoji above the line near exchanges that went well, below near ones that did not, on a
    /// few rows so that neighbours do not sit on each other. Fixed for a recording, not random.
    private static func scatter(_ reading: SpotReading, duration: Double, width: CGFloat) -> [Double: CGFloat] {
        let above: [CGFloat] = [44, 74, 104], below: [CGFloat] = [216, 246, 276]
        var lastX = [CGFloat: CGFloat]()
        var result = [Double: CGFloat]()
        for topic in reading.topics.sorted(by: { $0.sec < $1.sec }) {
            let near = reading.pins.filter { $0.sec >= topic.sec - 10 && $0.sec <= topic.sec + 40 }
            let good = near.filter(\.isGood).count, concern = near.count - good
            let seed = Int(topic.sec) &* 31 &+ 7
            let up = good == concern ? seed % 2 == 0 : good > concern
            let rows = up ? above : below
            let px = inset + CGFloat(topic.sec / duration) * (width - inset * 2)
            var row = rows[abs(seed / 2) % rows.count]
            if let taken = lastX[row], px - taken < 30 {
                row = rows.first { px - (lastX[$0] ?? -100) >= 30 } ?? row
            }
            lastX[row] = px
            result[topic.sec] = row
        }
        return result
    }

    private func x(_ sec: Double) -> CGFloat {
        Self.inset + CGFloat(sec / duration) * (width - Self.inset * 2)
    }

    private func radius(_ pin: SpotReading.Pin) -> CGFloat { [5, 5, 8, 12][min(max(pin.weight, 0), 3)] }

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
                                .font(.system(size: 22))
                                .position(x: x(topic.sec), y: topicY[topic.sec] ?? Self.middle)
                        }
                    }

                    // Heavier pins first, so that a small one next to a large one stays visible
                    ForEach(reading.pins.sorted { $0.weight > $1.weight }) { pin in
                        Circle()
                            .fill(pin.isGood ? Color.accentTeal : Color.accentCoral)
                            .frame(width: radius(pin) * 2, height: radius(pin) * 2)
                            .overlay(Circle().stroke(Color.white, lineWidth: picked == .pin(pin.id) ? 2 : 0))
                            .position(x: x(pin.sec), y: Self.middle)
                    }

                    balloon
                }
                .frame(width: width, height: Self.height)
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { pick(at: $0.location) })
            }

            HStack(spacing: 14) {
                legend(Color.accentTeal, "うまくいった")
                legend(Color.accentCoral, "気になる")
                Text("丸が大きいほど重い")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.45))
            }
        }
        .detailCard()
        .sheet(item: $openEpisode) { episode in
            SpotReadingEpisodeView(episode: episode, subjectId: subjectId, recordedAt: recordedAt)
                .preferredColorScheme(.dark)
        }
    }

    /// The pin or emoji nearest to a tap; a tap on nothing closes the balloon.
    private func pick(at location: CGPoint) {
        let reach: CGFloat = 26
        if abs(location.y - Self.middle) < reach,
           let pin = reading.pins.min(by: { abs(x($0.sec) - location.x) < abs(x($1.sec) - location.x) }),
           abs(x(pin.sec) - location.x) < reach {
            picked = .pin(pin.id)
            return
        }
        if layers != .pins {
            func distance(_ topic: SpotReading.Topic) -> CGFloat {
                hypot(x(topic.sec) - location.x, (topicY[topic.sec] ?? Self.middle) - location.y)
            }
            if let topic = reading.topics.min(by: { distance($0) < distance($1) }), distance(topic) < reach {
                picked = .topic(topic.sec)
                return
            }
        }
        picked = nil
    }

    // MARK: Drawing (the minutes, the voice, the line)

    private func draw(_ context: inout GraphicsContext) {
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

        // The voice as one filled shape around the line: wide where people spoke loudly, flat in silence
        if layers == .all, wave.count > 1 {
            let tops = wave.enumerated().map { index, value in
                CGPoint(x: x(min((Double(index) + 0.5) * Self.waveStep, duration)), y: Self.middle - Self.waveReach * value)
            }
            var shape = Path()
            shape.move(to: CGPoint(x: tops[0].x, y: Self.middle))
            shape.addLine(to: tops[0])
            for index in 1..<tops.count {
                let previous = tops[index - 1], current = tops[index]
                shape.addQuadCurve(to: CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2), control: previous)
            }
            shape.addLine(to: tops[tops.count - 1])
            shape.addLine(to: CGPoint(x: tops[tops.count - 1].x, y: 2 * Self.middle - tops[tops.count - 1].y))
            for index in stride(from: tops.count - 1, to: 0, by: -1) {
                let previous = tops[index], current = tops[index - 1]
                let mirrored = CGPoint(x: previous.x, y: 2 * Self.middle - previous.y)
                shape.addQuadCurve(to: CGPoint(x: (previous.x + current.x) / 2, y: 2 * Self.middle - (previous.y + current.y) / 2),
                                   control: mirrored)
            }
            shape.addLine(to: CGPoint(x: tops[0].x, y: 2 * Self.middle - tops[0].y))
            shape.closeSubpath()
            context.fill(shape, with: .color(.white.opacity(0.10)))
        }

        var middle = Path()
        middle.move(to: CGPoint(x: Self.inset, y: Self.middle))
        middle.addLine(to: CGPoint(x: width - Self.inset, y: Self.middle))
        context.stroke(middle, with: .color(.white.opacity(0.25)), lineWidth: 1)
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(Color(white: 0.6))
        }
    }

    // MARK: The balloon, right next to what was picked (it may cover other marks)

    @ViewBuilder
    private var balloon: some View {
        switch picked {
        case .pin(let id):
            if let pin = reading.pins.first(where: { $0.id == id }) {
                // Good pins open upward, the others downward, so the two sides stay apart
                placed(at: x(pin.sec), edge: Self.middle + (pin.isGood ? -(radius(pin) + 8) : radius(pin) + 8), upward: pin.isGood) {
                    pinBalloon(pin)
                }
            }
        case .topic(let sec):
            if let topic = reading.topics.first(where: { $0.sec == sec }) {
                let y = topicY[sec] ?? Self.middle
                // Toward the middle, where there is room
                placed(at: x(sec), edge: y + (y < Self.middle ? 18 : -18), upward: y > Self.middle) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(topic.emoji).font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Self.clock(topic.sec))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(white: 0.55))
                            Text(topic.what)
                                .font(.system(size: 13))
                                .foregroundColor(Color(white: 0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        case nil:
            EmptyView()
        }
    }

    /// A balloon whose near edge is at `edge`, growing up or down from there, kept inside the picture sideways.
    private func placed<Content: View>(at px: CGFloat, edge: CGFloat, upward: Bool,
                                       @ViewBuilder content: () -> Content) -> some View {
        let left = min(max(px - Self.balloonWidth / 2, 6), max(width - Self.balloonWidth - 6, 6))
        return content()
            .padding(12)
            .frame(width: Self.balloonWidth, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.darkElevated))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
            .onTapGesture { }   // a tap on the balloon itself does not close it
            .frame(width: Self.balloonWidth, height: upward ? edge : Self.height - edge, alignment: upward ? .bottom : .top)
            .offset(x: left, y: upward ? 0 : edge)
    }

    private func pinBalloon(_ pin: SpotReading.Pin) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(pin.isGood ? "うまくいった" : "気になる")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(pin.isGood ? .accentTeal : .accentCoral)
                Text(Self.clock(pin.sec))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
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
                .lineLimit(2)
            Text(pin.who)
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.6))
                .lineLimit(1)
            Text(pin.why)
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.85))
                .lineLimit(3)
            if let episode = reading.episode(at: pin.sec) {
                Button("この場面を詳しく") { openEpisode = episode }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.accentTeal)
            }
        }
    }

    static func clock(_ sec: Double) -> String {
        String(format: "%d:%02d", Int(sec) / 60, Int(sec) % 60)
    }

    static let info = """
        録音の中のやりとりを読んだ試作です。
        ・丸（ピン）: やりとりがうまくいった場面と、気になる場面。大きいほど重い場面です。
        ・絵文字: そのころ何の話をしていたかの挿し絵です。位置に細かい意味はありません。
        ・後ろの波: 話していた声。その人のふだんより大きいほど広がります。
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
