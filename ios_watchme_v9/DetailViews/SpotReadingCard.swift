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
        let kind: String        // "good", "concern" or "neutral" (reading-v2; not drawn)
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

    /// The pins the timeline draws: what went well and what did not. Ordinary exchanges (neutral) give the
    /// reading somewhere to put them, so that they are not forced into either side, and are not drawn.
    var shownPins: [Pin] { pins.filter { $0.kind == "good" || $0.kind == "concern" } }
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
    /// Inside another card (the home screen's recording card): no header and no card of its own.
    var embedded = false

    private enum Picked: Equatable {
        case pin(String)
        case topic(Double)
    }

    // Each layer on or off by itself; the voice is always there behind them
    @State private var showsPins = true
    @State private var showsTopics = false
    @State private var picked: Picked?
    @State private var openEpisode: SpotReading.Episode?

    private static let height: CGFloat = 340
    /// The middle of the drawing above the minute labels, which take the bottom 20pt.
    private static let middle: CGFloat = 160
    /// About how tall a pin's balloon is, to open it toward the side with room for it.
    private static let balloonHeight: CGFloat = 200
    private static let inset: CGFloat = 8
    /// How far from the middle line the voice reaches at most.
    private static let waveReach: CGFloat = 64
    /// Size of the faces that mark the exchanges: one size for all, as their distance from the line shows the weight.
    private static let faceSize: CGFloat = 18
    /// Emoji rows above and below the line, as distances from the middle. They may sit on pins.
    private static let topicRows: [CGFloat] = [14, 36, 58, 80, 102, 124]

    // Worked out once: the card is drawn again on every tap, and parsing the measurements
    // (about 50 KB of JSON) for every mark made it slow.
    private let duration: Double
    /// The voice in up to 120 steps, (time, 0...1 against this recording's more strained voices).
    private let wave: [(time: Double, value: CGFloat)]
    /// Above (negative) or below (positive) the line, and which row, for each topic's emoji.
    private let topicOffset: [Double: CGFloat]
    /// The pins in time order, for stepping from one to the next.
    private let pinsInOrder: [SpotReading.Pin]

    init(subjectId: String, recordedAt: String, reading: SpotReading, metricsRaw: String?, embedded: Bool = false) {
        self.subjectId = subjectId
        self.recordedAt = recordedAt
        self.reading = reading
        self.embedded = embedded
        let voice = VoicePoint.parse(metricsRaw: metricsRaw)
        let duration = max(reading.shownPins.map(\.sec).max() ?? 0, reading.topics.map(\.sec).max() ?? 0,
                           reading.episodes.map(\.toSec).max() ?? 0, voice.map(\.end).max() ?? 0, 60)
        self.duration = duration
        self.wave = Self.wave(voice, duration: duration)
        self.topicOffset = Self.scatter(reading, duration: duration)
        self.pinsInOrder = reading.shownPins.sorted { $0.sec < $1.sec }
    }

    /// The voice drawn the way the stamp chart draws it (SpotTimelineChart, its default measure):
    /// how much more strained than the speaker's usual, in up to 120 steps of at least 2 seconds,
    /// each taking its strongest voice, neighbours averaged once, joined by a smooth curve.
    private static func wave(_ voice: [VoicePoint], duration: Double) -> [(time: Double, value: CGFloat)] {
        let measure = VoiceMeasure.strain
        let values = voice.compactMap { measure.value($0) }.filter { $0 > 0 }.sorted()
        guard !voice.isEmpty, duration > 0 else { return [] }
        let reference = values.isEmpty ? 1 : max(values[Int(Double(values.count - 1) * 0.9)], 0.001)
        let count = max(min(Int(duration / 2), 120), 2)
        let width = duration / Double(count)
        var strongest = [Double](repeating: 0, count: count)
        for point in voice {
            let share = min(max((measure.value(point) ?? 0) / reference, 0), 1)
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
        return smoothed.enumerated().map { index, value in ((Double(index) + 0.5) * width, CGFloat(value)) }
    }

    /// A smooth curve through the points (Catmull-Rom, as the stamp chart's interpolation).
    private static func smoothLine(_ path: inout Path, through points: [CGPoint]) {
        guard points.count > 1 else { return }
        for index in 0..<(points.count - 1) {
            let p0 = points[max(index - 1, 0)], p1 = points[index], p2 = points[index + 1]
            let p3 = points[min(index + 2, points.count - 1)]
            path.addCurve(to: p2,
                          control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                          control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6))
        }
    }

    /// Emoji above the line near exchanges that went well, below near ones that did not, on a
    /// few rows so that neighbours do not sit on each other. Fixed for a recording, not random.
    private static func scatter(_ reading: SpotReading, duration: Double) -> [Double: CGFloat] {
        var lastAt = [CGFloat: Double]()   // row -> time of the last emoji put on it
        let gap = duration * 0.08          // about 8% of the width between emoji on one row
        var result = [Double: CGFloat]()
        for topic in reading.topics.sorted(by: { $0.sec < $1.sec }) {
            let near = reading.shownPins.filter { $0.sec >= topic.sec - 10 && $0.sec <= topic.sec + 40 }
            let good = near.filter(\.isGood).count, concern = near.count - good
            let seed = Int(topic.sec) &* 31 &+ 7
            let up = good == concern ? seed % 2 == 0 : good > concern
            let rows = topicRows.map { up ? -$0 : $0 }
            var row = rows[abs(seed / 2) % rows.count]
            if let last = lastAt[row], topic.sec - last < gap {
                row = rows.first { topic.sec - (lastAt[$0] ?? -.infinity) >= gap } ?? row
            }
            lastAt[row] = topic.sec
            result[topic.sec] = row
        }
        return result
    }

    private func radius(_ pin: SpotReading.Pin) -> CGFloat { Self.faceSize / 2 }

    /// A smiling face for what went well, an angry one for the rest; the same size for all.
    static func face(_ pin: SpotReading.Pin) -> String { pin.isGood ? "😊" : "😠" }

    /// The app's scheme: the accent for what went well, the body text grey for the rest.
    /// Above or below the line already says which is which, so the colours need not shout.
    static func color(_ pin: SpotReading.Pin) -> Color { pin.isGood ? .accentTeal : .brightText }

    /// Good pins above the line, the others below; the heavier, the further from the line.
    /// Each weight has a band, and a pin sits somewhere in its band by a value fixed by its
    /// time, so that pins of one weight do not stand in a row.
    private func pinY(_ pin: SpotReading.Pin) -> CGFloat {
        let bands: [ClosedRange<CGFloat>] = [24...54, 24...54, 54...96, 96...130]
        let band = bands[min(max(pin.weight, 0), 3)]
        var seed = UInt64(max(pin.sec, 0) * 10) &* 0x9E37_79B9_7F4A_7C15
        seed ^= seed >> 29
        seed = seed &* 0xBF58_476D_1CE4_E5B9
        seed ^= seed >> 32
        let share = CGFloat(seed % 1000) / 999
        let distance = band.lowerBound + (band.upperBound - band.lowerBound) * share
        return Self.middle + (pin.isGood ? -distance : distance)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !embedded {
                DetailCardHeader(icon: "mappin.and.ellipse", title: "TIMELINE", badge: "試作", info: Self.info)
            }

            // コミュニケーション: how the exchanges went (the faces); 出来事: what was going on (the emoji)
            HStack(spacing: 8) {
                layerToggle("コミュニケーション", isOn: $showsPins)
                layerToggle("出来事", isOn: $showsTopics)
            }

            GeometryReader { geometry in
                let width = geometry.size.width
                let x = { (sec: Double) -> CGFloat in Self.inset + CGFloat(sec / duration) * (width - Self.inset * 2) }
                ZStack(alignment: .topLeading) {
                    Canvas { context, _ in draw(&context, width: width, x: x) }

                    if showsTopics {
                        ForEach(reading.topics) { topic in
                            Text(topic.emoji)
                                .font(.system(size: 17))
                                .position(x: x(topic.sec), y: Self.middle + (topicOffset[topic.sec] ?? 0))
                        }
                    }

                    // Heavier pins first, so that a small one next to a large one stays visible
                    ForEach(showsPins ? reading.shownPins.sorted { $0.weight > $1.weight } : []) { pin in
                        Text(Self.face(pin))
                            .font(.system(size: Self.faceSize))
                            .frame(width: Self.faceSize + 4, height: Self.faceSize + 4)
                            .background(Circle().fill(Color.white.opacity(picked == .pin(pin.id) ? 0.25 : 0)))
                            .position(x: x(pin.sec), y: pinY(pin))
                    }

                }
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { pick(at: $0.location, x: x) })
                // Outside the tap area's shape, so that a balloon reaching past the drawing
                // still takes its own taps instead of passing them to what lies behind
                .overlay(alignment: .topLeading) { balloon(width: width, x: x) }
            }
            .frame(height: Self.height)
            .zIndex(1)
        }
        .modifier(CardUnlessEmbedded(embedded: embedded))
        .sheet(item: $openEpisode) { episode in
            SpotReadingEpisodeView(episode: episode, subjectId: subjectId, recordedAt: recordedAt)
                .preferredColorScheme(.dark)
        }
    }

    /// The pin or emoji nearest to a tap; a tap on nothing closes the balloon.
    private func pick(at location: CGPoint, x: (Double) -> CGFloat) {
        let reach: CGFloat = 22
        func pinDistance(_ pin: SpotReading.Pin) -> CGFloat { hypot(x(pin.sec) - location.x, pinY(pin) - location.y) }
        if showsPins, let pin = reading.shownPins.min(by: { pinDistance($0) < pinDistance($1) }), pinDistance(pin) < reach {
            picked = .pin(pin.id)
            return
        }
        if showsTopics {
            func distance(_ topic: SpotReading.Topic) -> CGFloat {
                hypot(x(topic.sec) - location.x, Self.middle + (topicOffset[topic.sec] ?? 0) - location.y)
            }
            if let topic = reading.topics.min(by: { distance($0) < distance($1) }), distance(topic) < reach {
                picked = .topic(topic.sec)
                return
            }
        }
        picked = nil
    }

    // MARK: Drawing (the minutes, the voice, the line)

    private func draw(_ context: inout GraphicsContext, width: CGFloat, x: (Double) -> CGFloat) {
        let step = duration > 2400 ? 10.0 : 5.0
        var minute = 0.0
        while minute * 60 <= duration {
            let px = x(minute * 60)
            var line = Path()
            line.move(to: CGPoint(x: px, y: 8))
            line.addLine(to: CGPoint(x: px, y: Self.height - 18))
            context.stroke(line, with: .color(.white.opacity(0.06)), lineWidth: 1)
            context.draw(Text("\(Int(minute))分").font(.system(size: 10)).foregroundColor(Color(white: 0.5)),
                         at: CGPoint(x: px + 3, y: Self.height - 8), anchor: .leading)
            minute += step
        }

        // The voice as one filled shape around the line: wide where people spoke loudly, flat in silence
        if wave.count > 1 {
            let tops = wave.map { CGPoint(x: x($0.time), y: Self.middle - Self.waveReach * $0.value) }
            let bottoms = tops.reversed().map { CGPoint(x: $0.x, y: 2 * Self.middle - $0.y) }
            var shape = Path()
            shape.move(to: tops[0])
            Self.smoothLine(&shape, through: tops)
            shape.addLine(to: bottoms[0])
            Self.smoothLine(&shape, through: bottoms)
            shape.closeSubpath()
            context.fill(shape, with: .color(.white.opacity(0.12)))
        }

        var middle = Path()
        middle.move(to: CGPoint(x: Self.inset, y: Self.middle))
        middle.addLine(to: CGPoint(x: width - Self.inset, y: Self.middle))
        context.stroke(middle, with: .color(.white.opacity(0.25)), lineWidth: 1)
    }

    /// A layer switched on or off by itself: filled while on, an outline while off.
    /// Turning one off closes its balloon.
    private func layerToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        let on = isOn.wrappedValue
        return Button {
            isOn.wrappedValue.toggle()
            if !isOn.wrappedValue { picked = nil }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(on ? .darkBase : Color(white: 0.5))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(on ? Color.accentTeal : Color.clear))
                .overlay(Capsule().stroke(on ? Color.clear : Color.white.opacity(0.25), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: on)
    }

    // MARK: The balloon, right next to what was picked (it may cover other marks)

    @ViewBuilder
    private func balloon(width: CGFloat, x: (Double) -> CGFloat) -> some View {
        switch picked {
        case .pin(let id):
            if let pin = reading.shownPins.first(where: { $0.id == id }) {
                // Good pins open upward and the others downward, unless that side has no room
                let above = pinY(pin) - radius(pin) - 8, below = pinY(pin) + radius(pin) + 8
                let upward = pin.isGood ? (above >= Self.balloonHeight || above > Self.height - below)
                                        : !(Self.height - below >= Self.balloonHeight || Self.height - below > above)
                placed(at: x(pin.sec), edge: upward ? above : below, upward: upward, width: width) {
                    pinBalloon(pin)
                }
            }
        case .topic(let sec):
            if let topic = reading.topics.first(where: { $0.sec == sec }) {
                let offset = topicOffset[sec] ?? 0
                // Toward the middle, where there is room
                placed(at: x(sec), edge: Self.middle + offset + (offset < 0 ? 14 : -14), upward: offset > 0, width: width) {
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

    /// A balloon whose near edge is at `edge`, growing up or down from there, kept inside the card sideways.
    private func placed<Content: View>(at px: CGFloat, edge: CGFloat, upward: Bool, width: CGFloat,
                                       @ViewBuilder content: () -> Content) -> some View {
        let balloonWidth = min(280, width - 8)
        let left = min(max(px - balloonWidth / 2, 4), max(width - balloonWidth - 4, 4))
        return content()
            .padding(12)
            .frame(width: balloonWidth, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.darkElevated))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
            .onTapGesture { }   // a tap on the balloon itself does not close it
            .frame(width: balloonWidth, height: upward ? edge : Self.height - edge, alignment: upward ? .bottom : .top)
            .offset(x: left, y: upward ? 0 : edge)
    }

    private func pinBalloon(_ pin: SpotReading.Pin) -> some View {
        let index = pinsInOrder.firstIndex { $0.id == pin.id } ?? 0
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text("\(Self.face(pin)) \(pin.isGood ? "うまくいった" : "気になる")")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Self.color(pin))
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
            HStack {
                if let episode = reading.episode(at: pin.sec) {
                    Button("この場面を詳しく") { openEpisode = episode }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.accentTeal)
                }
                Spacer()
                // Pins close in time overlap on the line; step through them in time order
                Button { picked = .pin(pinsInOrder[index - 1].id) } label: { Image(systemName: "chevron.left") }
                    .disabled(index == 0)
                Text("\(index + 1)/\(pinsInOrder.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(white: 0.55))
                Button { picked = .pin(pinsInOrder[index + 1].id) } label: { Image(systemName: "chevron.right") }
                    .disabled(index >= pinsInOrder.count - 1)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.accentTeal)
            .padding(.top, 2)
        }
    }

    static func clock(_ sec: Double) -> String {
        String(format: "%d:%02d", Int(sec) / 60, Int(sec) % 60)
    }

    static let info = """
        録音の中のやりとりを読んだ試作です。
        ・コミュニケーション（顔）: 😊 はやりとりがうまくいった場面で線より上、😠 は気になる場面で線より下。線から離れているほど重い場面です（同じ重さの中では重なりにくいよう少し散らしています）。
        ・出来事（絵文字）: そのころ何をしていたか、何の話をしていたかの挿し絵です。近くにうまくいった場面が多ければ上、気になる場面が多ければ下に置いています。
        ・後ろの波: 話していた声。その人のふだんより張り詰めているほど広がります。
        「コミュニケーション」「出来事」はそれぞれ表示を切り替えられます。
        顔を押すと理由が出て、その場面を再生できます。重なった顔は、吹き出しの ‹ › で順にたどれます。
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

/// The card's frame, left off when the timeline sits inside another card.
private struct CardUnlessEmbedded: ViewModifier {
    let embedded: Bool
    func body(content: Content) -> some View {
        if embedded { content } else { content.detailCard() }
    }
}
