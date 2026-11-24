//
//  SpotDetailMoreCards.swift
//  ios_watchme_v9
//
//  Detail-screen cards for data the server already keeps but the screen only showed
//  as raw JSON (2026-11-14): countable events, the multimodal listener's description,
//  the rest of the conversation measurements, and recording information.
//  Layout is provisional; the user will reorganise later.
//

import SwiftUI

// MARK: - Shared card chrome

struct DetailCardHeader: View {
    let icon: String
    let title: String
    var badge: String? = nil
    /// How to read the card, behind an (i) at the right. Cards stay plain; whoever wants it asks.
    var info: String? = nil
    /// When set, the header folds the card: a chevron at the right, and a tap opens or closes it.
    var expanded: Binding<Bool>? = nil

    var body: some View {
        if let expanded {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.wrappedValue.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        titleRow
                        Spacer()
                        Image(systemName: expanded.wrappedValue ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(white: 0.5))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if let info {
                    InfoButton(text: info)
                }
            }
        } else {
            HStack(spacing: 8) {
                titleRow
                Spacer()
                if let info {
                    InfoButton(text: info)
                }
            }
        }
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.accentTeal)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(white: 0.45))
                .tracking(0.8)
            if let badge {
                Text(badge)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.accentTeal)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentTeal.opacity(0.15)))
            }
        }
    }
}

/// The button that closes a sheet: an ×, the same in every language (screen reader: 閉じる).
struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // .primary: white on the dark screens, dark on the few that are still light
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.primary.opacity(0.85))
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.primary.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("閉じる")
    }
}

/// An (i) that shows how to read a card or a chart in a small balloon.
struct InfoButton: View {
    let text: String
    @State private var shown = false

    var body: some View {
        Button {
            shown = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.5))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("見方")
        .popover(isPresented: $shown) {
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 260, alignment: .leading)
                .padding(14)
                .presentationCompactAdaptation(.popover)
                .presentationBackground(Color.darkElevated)
        }
    }
}

struct DetailCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.darkCard)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
            )
    }
}

extension View {
    func detailCard() -> some View { modifier(DetailCardStyle()) }
}

func detailRow(_ label: String, _ value: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
        Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Color(white: 0.45))
            .frame(width: 92, alignment: .leading)
        Text(value)
            .font(.system(size: 13))
            .foregroundColor(Color(white: 0.78))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private func smallValue(_ label: String, _ value: String?) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(label)
            .font(.system(size: 10))
            .foregroundColor(Color(white: 0.45))
        Text(value ?? "–")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(Color(white: 0.78))
    }
}

private func parseJSON(_ raw: String?) -> [String: Any]? {
    guard let raw, let data = raw.data(using: .utf8) else { return nil }
    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
}

private func seconds(_ value: Any?) -> String? {
    guard let v = value as? Double ?? (value as? Int).map(Double.init) else { return nil }
    if v >= 60 { return String(format: "%d分%02d秒", Int(v) / 60, Int(v) % 60) }
    return String(format: "%.1f秒", v)
}

// MARK: - Events (叱責・褒める・笑い …)

/// The counted events of one recording, read once and shown in two places of the detail
/// screen: the picture at the top and the list under 詳しく (platform docs/product/screens.md).
@MainActor
final class SpotEventsStore: ObservableObject {
    struct Run: Decodable {
        let activity: String?
        let audio_seconds: Double?
        let counts: [String: Int]?
        let extractor_version: String
        let llm_model: String?
    }

    struct Event: Decodable, Identifiable {
        let seq: Int
        let event_type: String
        let start_sec: Double
        let end_sec: Double
        let actor: String
        let target: String?
        let intensity: String?
        let evidence: String?
        let confidence: String
        var id: Int { seq }
    }

    @Published private(set) var run: Run?
    @Published private(set) var events: [Event] = []
    /// Why the events could not be read; shown with a retry instead of hiding the card.
    @Published private(set) var loadError: String?
    /// Loaded, and this recording has no events run (its listener stage failed or never ran).
    @Published private(set) var noRun = false
    private var loading = false

    func load(subjectId: String, recordedAt: String) async {
        guard run == nil, !loading else { return }
        loading = true
        defer { loading = false }
        let client = SupabaseClientManager.shared.client
        do {
            let runs: [Run] = try await client
                .from("spot_event_runs")
                .select("activity, audio_seconds, counts, extractor_version, llm_model")
                .eq("subject_id", value: subjectId)
                .eq("recorded_at", value: recordedAt)
                .order("extractor_version", ascending: false)
                .limit(1)
                .execute()
                .value
            guard let latest = runs.first else {
                print("ℹ️ [Events] no events run for \(recordedAt)")
                noRun = true
                return
            }
            let rows: [Event] = try await client
                .from("spot_events")
                .select("seq, event_type, start_sec, end_sec, actor, target, intensity, evidence, confidence")
                .eq("subject_id", value: subjectId)
                .eq("recorded_at", value: recordedAt)
                .eq("extractor_version", value: latest.extractor_version)
                .order("seq", ascending: true)
                .execute()
                .value
            run = latest
            events = rows
            loadError = nil
            print("✅ [Events] \(recordedAt): \(rows.count) events")
        } catch {
            // Leaving the screen cancels the request: not an error, it loads again next time
            guard !Task.isCancelled else { return }
            print("❌ [Events] could not load \(recordedAt): \(error)")
            loadError = error.localizedDescription
        }
    }
}

/// One part of the events of a recording: the picture (emoji along the time, over the voice)
/// or the list (counts and every event with its play button).
struct SpotEventsCard: View {
    enum Part {
        case picture
        case list
    }

    let subjectId: String
    let recordedAt: String
    let localTime: String?
    /// profile_result.metrics as JSON; the voice chart reads its per-utterance measurements.
    var metricsRaw: String? = nil
    @ObservedObject var store: SpotEventsStore
    let part: Part
    /// Inside another card (the home screen): no header, no card of its own, no switch for the wave.
    var embedded = false

    private typealias Run = SpotEventsStore.Run
    private typealias Event = SpotEventsStore.Event

    private var run: Run? { store.run }
    private var events: [Event] { store.events }

    @State private var voiceMeasure = VoiceMeasure.strain
    /// The event picked on the timeline (its seq); the balloon under the picture shows it.
    @State private var selectedSeq: Int?

    static let typeOrder = ["reprimand", "joy", "praise", "laughter", "crying", "conflict", "mishap",
                            "cough", "sneeze", "throat_clearing"]
    static let typeNames = [
        "reprimand": "叱責", "joy": "楽しい場面", "praise": "褒める", "laughter": "笑い",
        "crying": "泣く", "conflict": "口論", "mishap": "落とす・こぼす",
        "cough": "咳", "sneeze": "くしゃみ", "throat_clearing": "咳払い",
    ]
    // The strength of a reprimand or conflict; from events-v3 it comes from the measured voice.
    static let intensityNames = ["mild": "（穏やか）", "strong": "（強め）", "severe": "（非常に強い）"]
    // Joy's level comes from how far the voice went up (events-v4).
    static let joyIntensityNames = ["strong": "（弾んだ声）", "severe": "（とても弾んだ声）"]
    static let roleNames = ["subject": "本人", "adult": "大人", "other_child": "ほかの子ども", "unknown": "不明"]
    static let activityNames = [
        "meal": "食事", "homework_study": "宿題・勉強", "play": "遊び", "getting_ready": "身支度",
        "bath_bedtime": "お風呂・寝る前", "outing_travel": "外出・移動", "media": "テレビ・動画",
        "conversation": "会話", "other": "その他", "unknown": "不明",
    ]

    var body: some View {
        // A VStack, not a Group: an empty Group is not placed at all, so its .task never
        // ran and the card stayed empty for good (found 2026-11-21).
        VStack(spacing: 0) {
            if let run {
                switch part {
                case .picture:
                    pictureCard(run)
                case .list:
                    listCard(run)
                }
            } else if embedded && part == .picture && store.loadError == nil && !store.noRun {
                // Loading: the empty picture, so the card does not jump when it arrives
                PendingPicture()
            } else if let loadError = store.loadError, part == .picture {
                VStack(alignment: .leading, spacing: 10) {
                    DetailCardHeader(icon: "list.number", title: "EVENTS", badge: "出来事")
                    Text("出来事を読み込めませんでした（\(loadError)）")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.6))
                        .fixedSize(horizontal: false, vertical: true)
                    Button("もう一度読み込む") {
                        Task { await store.load(subjectId: subjectId, recordedAt: recordedAt) }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.accentTeal)
                }
                .detailCard()
            }
        }
        .task(id: recordedAt) { await store.load(subjectId: subjectId, recordedAt: recordedAt) }
    }

    @ViewBuilder
    private func pictureCard(_ run: Run) -> some View {
        if embedded {
            VStack(alignment: .leading, spacing: 12) {
                timeline(run)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                DetailCardHeader(icon: "waveform.path.ecg", title: "TIMELINE", badge: "タイムライン",
                             info: Self.timelineInfo)
                timeline(run)
            }
            .detailCard()
        }
    }

    private func listCard(_ run: Run) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailCardHeader(icon: "list.number", title: "EVENTS", badge: "出来事", info: Self.eventsInfo)

            // Counts (low-confidence events are not counted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), spacing: 8) {
                ForEach(Self.typeOrder, id: \.self) { type in
                    HStack(spacing: 6) {
                        Text(Self.typeNames[type] ?? type)
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.6))
                        Text("\(run.counts?[type] ?? 0)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor((run.counts?[type] ?? 0) > 0 ? .white : Color(white: 0.35))
                    }
                }
            }

            if let activity = run.activity {
                detailRow("推定した活動", Self.activityNames[activity] ?? activity)
            }

            if events.isEmpty {
                Text("この録音では、数える対象の出来事はありませんでした")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.5))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(events) { event in
                        eventRow(event)
                    }
                }
            }
        }
        .detailCard()
    }

    // MARK: Timeline (trial, 2026-11-20)

    /// The recording as a picture: the events as emoji along the time, the voice behind them.
    @ViewBuilder
    private func timeline(_ run: Run) -> some View {
        let counted = events.filter { $0.confidence != "low" }.map {
            TimelineEvent(id: $0.seq, type: $0.event_type, start: $0.start_sec, end: $0.end_sec, intensity: $0.intensity)
        }
        let voice = VoicePoint.parse(metricsRaw: metricsRaw)
        let duration = run.audio_seconds ?? max(events.map(\.end_sec).max() ?? 0, voice.map(\.end).max() ?? 0)

        if !counted.isEmpty || !voice.isEmpty {
            SpotTimelineChart(events: counted, voice: voice, measure: voiceMeasure, duration: duration,
                              selectedId: $selectedSeq) { picked in
                if let event = events.first(where: { $0.seq == picked.id }) {
                    eventRow(event)
                }
            }

            if !voice.isEmpty && !embedded {
                // Which voice measure draws the wave behind (explained behind the card's (i))
                Picker("声の測定", selection: $voiceMeasure) {
                    ForEach(VoiceMeasure.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }

        }
    }

    /// How to read the picture (behind the (i) of the card).
    static let timelineInfo = """
        横は録音の時間です。中央の線より上はあたたかい出来事（楽しい場面・笑う・褒める）、下はきつい出来事（叱責・口論・泣く）。        叱責と口論は、強いものほど線から離れます。絵文字の位置は下のボタンでは変わりません。
        後ろの波は話していた声で、絵文字とは別の測定です。下のボタンで次の 3 つを切り替えます。どれも、その人のこの録音でのふだんの値からどれだけ離れたかで膨らみます。誰も話していないところは平らです。
        ・Hammarberg 指数（声の緊張）: 0〜2 kHz と 2〜5 kHz の一番強い成分の差（dB、eGeMAPS）。低いほど高い周波数が強い、張り詰めた声
        ・ラウドネス（声の大きさ）: 聞こえの大きさ。マイクとの距離でも変わる
        ・F0（声の高さ）: 基本周波数（半音）
        絵文字を押すと、そのときの言葉と再生ボタンが出ます。
        """

    static let eventsInfo = "決まった種類だけを数えています。30秒以内に続いた同じ種類は1回です。根拠の弱いもの（薄い表示）は回数に入れていません。"

    private func eventRow(_ event: Event) -> some View {
        let weak = event.confidence == "low"
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(clockTime(event.start_sec))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(white: 0.55))
                Text((Self.typeNames[event.event_type] ?? event.event_type)
                     + ((event.event_type == "joy" ? Self.joyIntensityNames : Self.intensityNames)[event.intensity ?? ""] ?? ""))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(whoText(event))
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.6))
                Spacer()
                if weak {
                    Text("根拠が弱い")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.5))
                }
                if SavedRecordings.canSave(subjectId: subjectId) {
                    EventPlayButton(id: "\(recordedAt)-\(event.seq)", subjectId: subjectId, recordedAt: recordedAt,
                                    start: event.start_sec, end: event.end_sec)
                }
            }
            if let evidence = event.evidence {
                Text("「\(evidence)」")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(weak ? 0.5 : 1)
    }

    private func whoText(_ event: Event) -> String {
        let actor = Self.roleNames[event.actor] ?? event.actor
        guard let target = event.target else { return actor }
        return "\(actor) → \(Self.roleNames[target] ?? target)"
    }

    /// Local clock time of an event: the recording's local start plus the event's offset.
    private func clockTime(_ offset: Double) -> String {
        guard let localTime else { return String(format: "%.0f秒", offset) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss.SSS", "yyyy-MM-dd HH:mm:ss"] {
            formatter.dateFormat = format
            if let start = formatter.date(from: localTime) {
                formatter.dateFormat = "HH:mm:ss"
                return formatter.string(from: start.addingTimeInterval(offset))
            }
        }
        return String(format: "%.0f秒", offset)
    }
}

// MARK: - Listener (Gemini's description of the audio)

/// What the multimodal model heard (profile_result.scene). Context only: it can report
/// sounds that are not there, which is why it is not used for counting.
struct SpotListenerCard: View {
    let sceneRaw: String?
    @State private var expanded = false

    var body: some View {
        if let object = parseJSON(sceneRaw), let scene = object["scene"] as? [String: Any] {
            VStack(alignment: .leading, spacing: 12) {
                DetailCardHeader(icon: "ear", title: "LISTENER", badge: (object["run"] as? [String: Any])?["model"] as? String,
                                 info: "音声を直接聞いた AI の説明です。聞こえていない音を挙げることがあるため、出来事の回数には使っていません。",
                                 expanded: $expanded)
              if expanded {

                VStack(alignment: .leading, spacing: 8) {
                    if let setting = scene["setting"] as? String, !setting.isEmpty {
                        detailRow("場所", setting)
                    }
                    if let speakers = scene["speakers"] as? [String: Any] {
                        let count = speakers["estimated_count"] as? Int
                        let description = speakers["description"] as? String ?? ""
                        detailRow("人数", [count.map { "\($0)人" }, description].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "・"))
                    }
                    if let summary = scene["summary"] as? String, !summary.isEmpty {
                        detailRow("様子", summary)
                    }
                    if let background = scene["background"] as? String, !background.isEmpty {
                        detailRow("背景の音", background)
                    }
                    if let uncertainty = scene["uncertainty"] as? String, !uncertainty.isEmpty {
                        detailRow("不確かな点", uncertainty)
                    }
                }

                let sounds = scene["sound_events"] as? [[String: Any]] ?? []
                if !sounds.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("聞こえた音")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(white: 0.45))
                        ForEach(Array(sounds.enumerated()), id: \.offset) { _, sound in
                            HStack(alignment: .top, spacing: 8) {
                                Text(String(format: "%.0f–%.0f秒", sound["start_sec"] as? Double ?? 0, sound["end_sec"] as? Double ?? 0))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color(white: 0.5))
                                    .frame(width: 76, alignment: .leading)
                                Text(sound["label"] as? String ?? "")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(white: 0.8))
                                Spacer()
                                Text(confidenceName(sound["confidence"] as? String))
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(white: 0.5))
                            }
                        }
                    }
                }
              }
            }
            .detailCard()
        }
    }

    private func confidenceName(_ value: String?) -> String {
        switch value {
        case "high": return "確か"
        case "medium": return "たぶん"
        case "low": return "不確か"
        default: return ""
        }
    }
}

// MARK: - Measurement details (the rest of profile_result.metrics)

struct SpotMeasurementDetailsCard: View {
    let metricsRaw: String?
    let speakerRoles: [String: String]
    @State private var expanded = false

    var body: some View {
        if let metrics = parseJSON(metricsRaw),
           let conversation = metrics["conversation"] as? [String: Any],
           conversation["available"] as? Bool == true {
            let whole = conversation["conversation"] as? [String: Any] ?? [:]
            let speakers = conversation["speakers"] as? [String: [String: Any]] ?? [:]
            let acoustic = (metrics["acoustic"] as? [String: Any])?["speakers"] as? [String: [String: Any]] ?? [:]

            VStack(alignment: .leading, spacing: 12) {
                DetailCardHeader(icon: "ruler", title: "MEASUREMENTS", badge: conversation["metric_version"] as? String,
                                 info: "CONVERSATION に出していない残りの測定値です。割り込みは、相手が話している途中で話し始めた回数。",
                                 expanded: $expanded)
              if expanded {

                HStack(spacing: 14) {
                    smallValue("長さ", seconds(whole["duration_seconds"]))
                    smallValue("発話", (whole["speech_ratio"] as? Double).map { String(format: "%.0f%%", $0 * 100) })
                    smallValue("ターン", (whole["turns"] as? Int).map(String.init))
                    smallValue("交代", (whole["speaker_changes"] as? Int).map(String.init))
                    smallValue("重なり", seconds(whole["overlap_seconds"]))
                }

                ForEach(speakers.keys.sorted(), id: \.self) { label in
                    let m = speakers[label] ?? [:]
                    let voice = acoustic[label] ?? [:]
                    let summary = voice["summary"] as? [String: Any] ?? [:]
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(label)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.accentTeal)
                            Text(speakerRoles[label] ?? "")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(white: 0.85))
                        }
                        HStack(spacing: 14) {
                            smallValue("ターン", (m["turns"] as? Int).map(String.init))
                            smallValue("1回の長さ", seconds(m["median_turn_seconds"]))
                            smallValue("間の回数", (m["pause_count"] as? Int).map(String.init))
                            smallValue("最長の間", seconds(m["longest_pause_seconds"]))
                        }
                        HStack(spacing: 14) {
                            smallValue("応答の回数", (m["response_count"] as? Int).map(String.init))
                            smallValue("割り込み", (m["overlap_starts"] as? Int).map(String.init))
                            smallValue("単独の発話", seconds(voice["solo_seconds"]))
                        }
                        if voice["available"] as? Bool == true {
                            HStack(spacing: 14) {
                                smallValue("大きさの幅", (summary["loudness_range"] as? Double).map { String(format: "%.2f", $0) })
                                smallValue("有声区間/秒", (summary["voiced_segments_per_sec"] as? Double).map { String(format: "%.2f", $0) })
                                smallValue("有声区間の長さ", seconds(summary["mean_voiced_segment_sec"]))
                            }
                        } else if let reason = voice["reason"] as? String {
                            Text("声の特徴: 測れませんでした（\(reason)）")
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.45))
                        }
                    }
                }
              }
            }
            .detailCard()
        }
    }
}

// MARK: - Recording information

struct SpotRecordingInfoCard: View {
    let recordingRaw: String?
    let transcript: [String: Any]?
    let sceneRaw: String?
    let llmModel: String?
    let recordedAt: String?

    var body: some View {
        let recording = parseJSON(recordingRaw)
        let sceneModel = (parseJSON(sceneRaw)?["run"] as? [String: Any])?["model"] as? String
        let asrModel = transcript?["asr_model"] as? String ?? transcript?["asr_provider"] as? String

        VStack(alignment: .leading, spacing: 12) {
            DetailCardHeader(icon: "info.circle", title: "RECORDING")
            VStack(alignment: .leading, spacing: 8) {
                if let duration = seconds(recording?["duration_seconds"]) {
                    detailRow("長さ", duration)
                }
                if let sequence = recording?["sequence"] as? Int {
                    detailRow("長時間録音", "\(sequence + 1)番目の区切り（5分ごと）")
                }
                if let recordedAt {
                    detailRow("録音開始（UTC）", recordedAt)
                }
                if let asrModel { detailRow("文字起こし", asrModel) }
                if let sceneModel { detailRow("場面・聞き取り", sceneModel) }
                if let llmModel { detailRow("分析・出来事", llmModel) }
            }
        }
        .detailCard()
    }
}
