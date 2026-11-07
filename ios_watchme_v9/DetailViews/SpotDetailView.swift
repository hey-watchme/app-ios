//
//  SpotDetailView.swift
//  ios_watchme_v9
//
//  Spot analysis detail page - Dark theme
//

import SwiftUI
#if DEBUG
import AVFoundation
#endif

struct SpotDetailView: View {
    let deviceId: String
    let spotData: DashboardTimeBlock

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: SupabaseDataManager
    @State private var rawSectionsLoadedFull: Set<String> = []
    #if DEBUG
    @StateObject private var previewPlayer = RecordingPreviewPlayer()
    #endif

    private let rawPreviewCharacterLimit = 4_000
    private let rawLargeContentThreshold = 12_000

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Vibe Score
                    if let vibeScore = spotData.vibeScore {
                        vibeScoreCard(vibeScore)
                    }

                    // Scene Mapping
                    if let sm = spotData.sceneMapping {
                        sceneMappingCard(sm)
                    }

                    // Summary
                    if let summary = spotData.summary {
                        contentCard(title: "Summary", content: summary, icon: "text.alignleft")
                    }

                    // Analysis
                    if let analysis = spotData.analysis, !analysis.isEmpty {
                        contentCard(title: "Analysis", content: analysis, icon: "brain.head.profile")
                    }

                    // Behavior
                    if let behavior = spotData.behavior {
                        contentCard(title: "Behavior", content: behavior, icon: "figure.walk")
                    }

                    // Emotion
                    if let emotion = spotData.emotion, !emotion.isEmpty {
                        contentCard(title: "Emotion", content: emotion, icon: "face.smiling")
                    }

                    // Sounds detected by the fixed classifier
                    if !soundSummaries.isEmpty {
                        soundsCard
                    }

                    // Raw data
                    rawAnalysisSection

                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color.darkBase)
            .navigationTitle(formatNavigationTitle())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.accentTeal)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - View Components

    private func vibeScoreCard(_ score: Double) -> some View {
        HStack(spacing: 20) {
            // Ring gauge
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 4)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: min(max((score + 100) / 200, 0), 1))
                    .stroke(vibeScoreColor(score), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 72, height: 72)

                Text(String(format: "%.0f", score))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("VIBE SCORE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(white: 0.45))
                    .tracking(1.0)

                Text(vibeStatusLabel(score))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(vibeScoreColor(score))

                // Score bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(vibeScoreColor(score))
                            .frame(width: geo.size.width * min(max((score + 100) / 200, 0), 1), height: 6)
                    }
                }
                .frame(height: 6)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func contentCard(title: String, content: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.accentTeal)
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(white: 0.45))
                    .tracking(0.8)
                Spacer()
            }

            Text(content)
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.78))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func sceneMappingCard(_ sm: SceneMapping) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "map")
                    .font(.system(size: 14))
                    .foregroundColor(.accentTeal)
                Text("SCENE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(white: 0.45))
                    .tracking(0.8)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                if let participants = sm.participants, !participants.isEmpty {
                    sceneMappingRow(label: "Participants", value: participants)
                }
                if let activity = sm.core_activity, !activity.isEmpty {
                    sceneMappingRow(label: "Activity", value: activity)
                }
                if let detail = sm.behavior_detail, !detail.isEmpty {
                    sceneMappingRow(label: "Interaction", value: detail)
                }
                if let atmosphere = sm.atmosphere, !atmosphere.isEmpty {
                    sceneMappingRow(label: "Atmosphere", value: atmosphere)
                }
                if let uncertainty = sm.uncertainty, !uncertainty.isEmpty {
                    sceneMappingRow(label: "Uncertainty", value: uncertainty)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func sceneMappingRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(white: 0.45))
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Sounds (sound event detection)

    private struct SoundSummary: Identifiable {
        let id: String
        let label: String
        let peak: Double
        let ranges: String
    }

    /// Same threshold the analysis prompt uses for this classifier.
    private let soundScoreThreshold = 0.10

    /// Each detected sound (except generic speech) with its peak score and the seconds it was present.
    private var soundSummaries: [SoundSummary] {
        var peaks: [String: Double] = [:]
        var spans: [String: [(Double, Double)]] = [:]
        var japanese: [String: String] = [:]
        for point in spotData.behaviorTimePoints {
            for event in point.events where event.score >= soundScoreThreshold {
                let english = event.label.split(separator: "/").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? event.label
                if english == "Speech" { continue }
                peaks[event.label] = max(peaks[event.label] ?? 0, event.score)
                japanese[event.label] = event.japaneseLabel
                var ranges = spans[event.label] ?? []
                if let last = ranges.last, point.time - last.1 <= 1.0 {
                    ranges[ranges.count - 1].1 = point.time
                } else {
                    ranges.append((point.time, point.time))
                }
                spans[event.label] = ranges
            }
        }
        return peaks.sorted { $0.value > $1.value }.prefix(10).map { label, peak in
            let ranges = (spans[label] ?? []).map { start, end in
                Int(start.rounded()) == Int(end.rounded())
                    ? "\(Int(start.rounded()))秒"
                    : "\(Int(start.rounded()))–\(Int(end.rounded()))秒"
            }.joined(separator: ", ")
            return SoundSummary(id: label, label: japanese[label] ?? label, peak: peak, ranges: ranges)
        }
    }

    private var soundsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 14))
                    .foregroundColor(.accentTeal)
                Text("SOUNDS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(white: 0.45))
                    .tracking(0.8)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(soundSummaries) { sound in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(sound.label)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(white: 0.85))
                            Spacer()
                            Text(String(format: "%.2f", sound.peak))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(white: 0.6))
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.08))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.accentTeal.opacity(0.8))
                                    .frame(width: geo.size.width * min(sound.peak, 1))
                            }
                        }
                        .frame(height: 4)
                        Text(sound.ranges)
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.45))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Text("音の分類器による検出（最大スコア・時間帯）。似た音を取り違えることがあります")
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Raw Analysis Section

    private var rawAnalysisSection: some View {
        Group {
            if hasAnyRawData {
                VStack(alignment: .leading, spacing: 12) {
                    Text("DATA")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(white: 0.36))
                        .tracking(1.0)

                    #if DEBUG
                    if let audioKey = spotData.audioKey {
                        audioPreviewRow(audioKey: audioKey)
                    }
                    #endif

                    if !conversationTurns.isEmpty {
                        conversationDisclosure
                    }

                    if let transcription = spotData.vibeTranscriberResult {
                        rawDataDisclosure(id: "stt", title: "STT", content: transcription)
                    }

                    if let scene = spotData.sceneDescriptionRaw {
                        rawDataDisclosure(id: "scene", title: "Scene (Gemini)", content: scene)
                    }

                    if !spotData.behaviorTimePoints.isEmpty {
                        rawDataDisclosure(id: "sed", title: "SED", content: behaviorExtractorJSONString)
                    }

                    if let humeRaw = spotData.emotionFeaturesResultHumeRaw, !humeRaw.isEmpty {
                        rawDataDisclosure(id: "ser", title: "SER", content: humeRaw)
                    }
                }
            }
        }
    }

    #if DEBUG
    // MARK: - Audio preview (development builds only)

    private func audioPreviewRow(audioKey: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button {
                    Task { await previewPlayer.toggle(audioKey: audioKey) }
                } label: {
                    HStack(spacing: 8) {
                        if previewPlayer.isLoading {
                            ProgressView().tint(.accentTeal)
                        } else {
                            Image(systemName: previewPlayer.isPlaying ? "stop.fill" : "play.fill")
                        }
                        Text(previewPlayer.isPlaying ? "停止" : "録音を再生")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.accentTeal)
                }
                .disabled(previewPlayer.isLoading)
                Spacer()
                Text("開発用")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.45))
            }
            if let message = previewPlayer.errorMessage {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(.accentCoral)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onDisappear { previewPlayer.stop() }
    }
    #endif

    // MARK: - Conversation (speaker-labelled transcript)

    private struct ConversationTurn: Identifiable {
        let id: Int
        let speaker: String?
        let text: String
    }

    private var transcriptObject: [String: Any]? {
        guard let raw = spotData.vibeTranscriberResult, let data = raw.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// Splits the stored transcription ("SPEAKER S1: ...\nSPEAKER S2: ...") into turns.
    private var conversationTurns: [ConversationTurn] {
        guard let text = transcriptObject?["transcription"] as? String else { return [] }
        let prefix = "SPEAKER "
        return text.split(separator: "\n").enumerated().compactMap { index, rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return nil }
            if line.hasPrefix(prefix), let colon = line.firstIndex(of: ":") {
                let speaker = String(line[line.index(line.startIndex, offsetBy: prefix.count)..<colon])
                let body = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                return ConversationTurn(id: index, speaker: speaker, text: body)
            }
            return ConversationTurn(id: index, speaker: nil, text: line)
        }
    }

    /// Who each speaker label sounds like, estimated from the voice by the scene stage (e.g. "S1" -> "子ども").
    private var speakerRoles: [String: String] {
        guard let raw = spotData.sceneDescriptionRaw,
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scene = object["scene"] as? [String: Any],
              let roles = scene["speaker_roles"] as? [[String: Any]] else { return [:] }
        var result: [String: String] = [:]
        for entry in roles {
            if let label = entry["label"] as? String, let role = entry["role"] as? String {
                result[label] = role
            }
        }
        return result
    }

    private var conversationDisclosure: some View {
        let engine = transcriptObject?["asr_model"] as? String
        let speakerOrder = conversationTurns.compactMap(\.speaker).reduce(into: [String]()) { order, speaker in
            if !order.contains(speaker) { order.append(speaker) }
        }
        let roles = speakerRoles

        return DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                if !roles.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(speakerOrder, id: \.self) { speaker in
                            if let role = roles[speaker] {
                                HStack(spacing: 10) {
                                    Text(speaker)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(speakerColor(speaker, order: speakerOrder))
                                        .frame(width: 28, alignment: .leading)
                                    Text(role)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color(white: 0.78))
                                }
                            }
                        }
                        Text("声からの推定")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.45))
                    }
                    .padding(.bottom, 6)
                }

                ForEach(conversationTurns) { turn in
                    HStack(alignment: .top, spacing: 10) {
                        Text(turn.speaker ?? "–")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(speakerColor(turn.speaker, order: speakerOrder))
                            .frame(width: 28, alignment: .leading)
                            .padding(.top, 2)
                        Text(turn.text)
                            .font(.system(size: 14))
                            .foregroundColor(Color(white: 0.78))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                            .textSelection(.enabled)
                    }
                }

                if let engine {
                    Text(engine)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(white: 0.45))
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 8)
        } label: {
            HStack {
                Text("Conversation")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Text(speakerOrder.isEmpty ? "" : "\(speakerOrder.count) speakers")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(white: 0.45))
            }
        }
        .tint(Color(white: 0.36))
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func speakerColor(_ speaker: String?, order: [String]) -> Color {
        let palette: [Color] = [.accentTeal, .accentCoral, .brightText, .accentTealMuted]
        guard let speaker, let index = order.firstIndex(of: speaker) else { return Color(white: 0.45) }
        return palette[index % palette.count]
    }

    private var hasAnyRawData: Bool {
        spotData.vibeTranscriberResult != nil
            || spotData.sceneDescriptionRaw != nil
            || !spotData.behaviorTimePoints.isEmpty
            || (spotData.emotionFeaturesResultHumeRaw.map { !$0.isEmpty } ?? false)
    }

    private var behaviorExtractorJSONString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(spotData.behaviorTimePoints),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }

    private func rawDataDisclosure(id: String, title: String, content: String) -> some View {
        let byteCount = content.lengthOfBytes(using: .utf8)
        let isLargeContent = byteCount >= rawLargeContentThreshold
        let isFullLoaded = rawSectionsLoadedFull.contains(id)
        let shouldShowFullContent = !isLargeContent || isFullLoaded
        let previewText: String = {
            let preview = String(content.prefix(rawPreviewCharacterLimit))
            if content.count > rawPreviewCharacterLimit {
                return preview + "\n\n… truncated (preview only)"
            }
            return preview
        }()

        return DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                if isLargeContent, !isFullLoaded {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Large raw data", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentTealMuted)

                        Text("Size: \(formattedByteCount(byteCount)). \(expectedLoadHint(for: byteCount))")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.62))

                        Button("全文を読み込む（重くなる可能性あり）") {
                            rawSectionsLoadedFull.insert(id)
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.accentTealMuted.opacity(0.35))
                        )
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                }

                ScrollView(.horizontal, showsIndicators: true) {
                    if shouldShowFullContent {
                        Text(content)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color(white: 0.45))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    } else {
                        Text(previewText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color(white: 0.45))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.disabled)
                    }
                }
                .padding(.vertical, 8)

                if isLargeContent, isFullLoaded {
                    Button("プレビュー表示に戻す") {
                        rawSectionsLoadedFull.remove(id)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(white: 0.62))
                }
            }
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Text(formattedByteCount(byteCount))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(white: 0.45))
            }
        }
        .tint(Color(white: 0.36))
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func formattedByteCount(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func expectedLoadHint(for bytes: Int) -> String {
        if bytes >= 180_000 {
            return "端末によっては展開に数十秒〜2分かかる場合があります。"
        }
        if bytes >= 80_000 {
            return "端末によっては展開に数秒〜30秒かかる場合があります。"
        }
        return "重い場合はプレビュー表示で確認してください。"
    }

    // MARK: - Helpers

    private func formatNavigationTitle() -> String {
        guard let localDate = spotData.date, let localTime = spotData.localTime else {
            return "Spot Analysis"
        }

        let dateString = formatDateShort(localDate)
        let timeString = formatTime(localTime)
        return "\(dateString) \(timeString)"
    }

    private func formatDateShort(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        formatter.dateFormat = "M/d (E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        formatter.dateFormat = "yyyy/M/d (E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func formatTime(_ timeString: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"

        if let time = formatter.date(from: timeString) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: time)
        }

        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let time = formatter.date(from: timeString) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: time)
        }

        return timeString
    }

    private func vibeScoreColor(_ score: Double) -> Color {
        Color.vibeScoreColor(for: score)
    }

    private func vibeStatusLabel(_ score: Double) -> String {
        if score >= 30 { return "Positive" }
        else if score >= 0 { return "Good" }
        else if score >= -30 { return "Neutral" }
        else { return "Low" }
    }
}

#if DEBUG
/// Plays a recording through a short-lived URL from GET /audio (development builds only).
/// The API checks the signed-in user's token and their access to the device.
@MainActor
private final class RecordingPreviewPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let serverURL = "https://api.hey-watch.me"
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?

    func toggle(audioKey: String) async {
        if isPlaying {
            stop()
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let token = try await SupabaseClientManager.shared.client.auth.session.accessToken
            var components = URLComponents(string: "\(serverURL)/audio")!
            components.queryItems = [URLQueryItem(name: "audio_key", value: audioKey)]
            var request = URLRequest(url: components.url!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200,
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let urlString = object["url"] as? String,
                  let url = URL(string: urlString) else {
                errorMessage = "再生用のURLを取得できませんでした（HTTP \(status)）"
                return
            }

            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            let item = AVPlayerItem(url: url)
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.stop() }
            }
            player = AVPlayer(playerItem: item)
            player?.play()
            isPlaying = true
        } catch {
            errorMessage = "再生できませんでした: \(error.localizedDescription)"
        }
    }

    func stop() {
        player?.pause()
        player = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        isPlaying = false
    }
}
#endif
