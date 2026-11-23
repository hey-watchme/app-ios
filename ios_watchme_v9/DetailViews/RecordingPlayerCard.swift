//
//  RecordingPlayerCard.swift
//  ios_watchme_v9
//
//  The whole recording, played back with the transcript beside it: a seek bar, ±10 s, speed,
//  and the utterance being spoken highlighted (tap one to play from there). The audio comes
//  from GET /audio?subject_id&recorded_at&at, the same as an event's play button
//  (EventAudioPlayer): it answers with the part that holds `at` and where that part starts,
//  so a seek outside the loaded part asks for the next one. 410 = the audio was deleted.
//

import AVFoundation
import SwiftUI

/// One speaker turn of the transcript, with its time in the recording.
struct TimedUtterance: Identifiable {
    let id: Int
    let speaker: String?
    let start: Double
    let end: Double
    let text: String

    /// Words of the same speaker closer than `gap` seconds are one utterance (platform
    /// common/metrics/voice.py groups them the same way). Sound tags are left out.
    static func from(transcript: [String: Any]?, gap: Double = 0.7) -> [TimedUtterance] {
        guard let words = transcript?["words"] as? [[String: Any]] else { return [] }
        var result: [TimedUtterance] = []
        var speaker: String?
        var start = 0.0, end = 0.0, text = ""
        func flush() {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                result.append(TimedUtterance(id: result.count, speaker: speaker, start: start, end: end, text: trimmed))
            }
            text = ""
        }
        for word in words {
            guard let s = (word["start_time"] as? NSNumber)?.doubleValue,
                  let e = (word["end_time"] as? NSNumber)?.doubleValue,
                  let content = word["content"] as? String else { continue }
            let type = word["type"] as? String ?? "word"
            if type == "audio_event" { continue }
            if type != "word" {
                text += content
                continue
            }
            let who = word["speaker"] as? String
            if !text.isEmpty && who == speaker && s - end <= gap {
                end = max(end, e)
                text += content
            } else {
                flush()
                speaker = who
                start = s
                end = e
                text = content
            }
        }
        flush()
        return result
    }
}

@MainActor
final class RecordingPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    /// Seconds from the start of the recording.
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var errorMessage: String?
    @Published var rate: Float = 1.0

    let subjectId: String
    let recordedAt: String
    let duration: Double

    private let serverURL = "https://api.hey-watch.me"
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    /// Where the loaded part starts in the recording, and how long it is.
    private var partStart: Double = 0
    private var partLength: Double = 0

    init(subjectId: String, recordedAt: String, duration: Double) {
        self.subjectId = subjectId
        self.recordedAt = recordedAt
        self.duration = max(duration, 1)
    }

    func togglePlay() async {
        if isPlaying {
            pause()
        } else {
            await play(from: currentTime >= duration - 0.5 ? 0 : currentTime)
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    /// Play from `time` (seconds from the start of the recording).
    func play(from time: Double) async {
        let target = min(max(time, 0), duration)
        EventAudioPlayer.shared.stop()
        if player == nil || target < partStart || target >= partStart + partLength - 0.5 {
            guard await load(at: target) else { return }
        }
        guard let player else { return }
        await player.seek(to: CMTime(seconds: target - partStart, preferredTimescale: 600),
                          toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = target
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.playImmediately(atRate: rate)
        isPlaying = true
    }

    /// Move without starting playback (while paused), or keep playing from there.
    func seek(to time: Double) async {
        if isPlaying {
            await play(from: time)
        } else {
            currentTime = min(max(time, 0), duration)
            if let player, currentTime >= partStart, currentTime < partStart + partLength {
                await player.seek(to: CMTime(seconds: currentTime - partStart, preferredTimescale: 600),
                                  toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
    }

    func skip(_ seconds: Double) async {
        await seek(to: currentTime + seconds)
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        if isPlaying { player?.rate = newRate }
    }

    func stop() {
        player?.pause()
        if let timeObserver, let player { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
        player = nil
        isPlaying = false
    }

    private func load(at time: Double) async -> Bool {
        stop()
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let (url, start) = try await playbackURL(at: time)
            let item = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: item)
            self.player = player
            partStart = start
            let length = try? await item.asset.load(.duration).seconds
            partLength = (length.map { $0.isFinite && $0 > 0 ? $0 : nil } ?? nil) ?? (duration - start)
            timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
                                                          queue: .main) { [weak self] t in
                Task { @MainActor in
                    guard let self, self.isPlaying else { return }
                    self.currentTime = min(self.partStart + t.seconds, self.duration)
                }
            }
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in await self?.partEnded() }
            }
            return true
        } catch EventAudioPlayer.PlaybackError.deleted {
            errorMessage = "この録音の音声は保存期間（3日）を過ぎたため、残っていません"
        } catch {
            errorMessage = "再生できませんでした: \(error.localizedDescription)"
        }
        return false
    }

    /// The loaded part ran out: go on with the next one, or stop at the end of the recording.
    private func partEnded() async {
        let next = partStart + partLength
        if next < duration - 0.5 {
            await play(from: next)
        } else {
            isPlaying = false
            currentTime = duration
        }
    }

    private func playbackURL(at: Double) async throws -> (URL, Double) {
        guard let bearer = await SupabaseClientManager.shared.bearerToken() else {
            throw EventAudioPlayer.PlaybackError.failed(401)
        }
        var components = URLComponents(string: "\(serverURL)/audio")!
        components.queryItems = [
            URLQueryItem(name: "subject_id", value: subjectId),
            URLQueryItem(name: "recorded_at", value: recordedAt),
            URLQueryItem(name: "at", value: String(format: "%.1f", at)),
        ]
        // "+" in the time zone must not be read as a space
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        var request = URLRequest(url: components.url!)
        request.setValue(bearer, forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 410 || status == 404 { throw EventAudioPlayer.PlaybackError.deleted }
        guard status == 200,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urlString = object["url"] as? String,
              let url = URL(string: urlString) else { throw EventAudioPlayer.PlaybackError.failed(status) }
        return (url, (object["part_start"] as? NSNumber)?.doubleValue ?? 0)
    }
}

/// The card at the top of the data section.
struct RecordingPlayerCard: View {
    @StateObject private var player: RecordingPlayer
    private let utterances: [TimedUtterance]
    private let speakerColor: (String?) -> Color
    private let roles: [String: String]
    private let engine: String?          // the speech-to-text model (transcript.json asr_model)
    private let fallbackFrom: String?    // the engine that could not be used, when it fell back
    /// While the thumb is dragged, the bar shows the drag, not the playback.
    @State private var dragTime: Double?
    @State private var followsPlayback = true

    init(subjectId: String, recordedAt: String, transcript: [String: Any]?, duration: Double?,
         roles: [String: String], speakerColor: @escaping (String?) -> Color) {
        let utterances = TimedUtterance.from(transcript: transcript)
        let length = duration ?? utterances.last?.end ?? 0
        _player = StateObject(wrappedValue: RecordingPlayer(subjectId: subjectId, recordedAt: recordedAt, duration: length))
        self.utterances = utterances
        self.roles = roles
        self.engine = transcript?["asr_model"] as? String
        self.fallbackFrom = (transcript?["asr_fallback"] as? [String: Any])?["from"] as? String
        self.speakerColor = speakerColor
    }

    private var shownTime: Double { dragTime ?? player.currentTime }

    /// The utterance being spoken now, or the last one before it.
    private var currentIndex: Int? {
        let t = player.currentTime
        return utterances.lastIndex { $0.start <= t + 0.1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailCardHeader(icon: "waveform", title: "PLAYBACK", badge: "録音を聞く",
                             info: "録音を最初から聞けます。下の発言を押すと、そこから再生します。音声は録音から3日で消えます（録音の音声を残す設定にしている場合を除く）。")

            // Seek bar and times
            VStack(spacing: 4) {
                Slider(value: Binding(get: { shownTime }, set: { dragTime = $0 }),
                       in: 0...player.duration) { editing in
                    if !editing, let target = dragTime {
                        Task {
                            await player.seek(to: target)
                            dragTime = nil
                        }
                    }
                }
                .tint(.accentTeal)
                HStack {
                    Text(clock(shownTime))
                    Spacer()
                    if let index = currentIndex, utterances.indices.contains(index) {
                        Text(speakerName(utterances[index].speaker))
                            .foregroundColor(speakerColor(utterances[index].speaker))
                    }
                    Spacer()
                    Text(clock(player.duration))
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(white: 0.55))
            }

            // Controls
            HStack(spacing: 28) {
                Spacer()
                Button { Task { await player.skip(-10) } } label: {
                    Image(systemName: "gobackward.10").font(.system(size: 22))
                }
                Button { Task { await player.togglePlay() } } label: {
                    Group {
                        if player.isLoading {
                            ProgressView().tint(.accentTeal)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 44))
                        }
                    }
                    .frame(width: 48, height: 48)
                }
                .accessibilityLabel(player.isPlaying ? "一時停止" : "再生")
                Button { Task { await player.skip(10) } } label: {
                    Image(systemName: "goforward.10").font(.system(size: 22))
                }
                Spacer()
            }
            .foregroundColor(.accentTeal)
            .buttonStyle(.plain)
            .overlay(alignment: .trailing) {
                Menu {
                    ForEach([Float(1.0), 1.25, 1.5, 2.0], id: \.self) { r in
                        Button(rateLabel(r)) { player.setRate(r) }
                    }
                } label: {
                    Text(rateLabel(player.rate))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.accentTeal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().stroke(Color.accentTeal.opacity(0.5), lineWidth: 1))
                }
            }

            if let message = player.errorMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.accentCoral)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Who speaks (labels from the transcription, people from the listener) and the model
            if !utterances.isEmpty {
                speakersAndModel
            }

            // The transcript, following the playback
            if !utterances.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(utterances) { u in
                                utteranceRow(u, isCurrent: u.id == currentIndex)
                                    .id(u.id)
                            }
                        }
                    }
                    .frame(height: 280)
                    .simultaneousGesture(DragGesture().onChanged { _ in followsPlayback = false })
                    .onChange(of: currentIndex) { _, index in
                        guard followsPlayback, player.isPlaying, let index else { return }
                        withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(index, anchor: .center) }
                    }
                }
                if !followsPlayback {
                    Button("再生位置に戻る") { followsPlayback = true }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.accentTeal)
                }
            }
        }
        .detailCard()
        .onDisappear { player.stop() }
    }

    /// Labels in the order they first speak.
    private var speakerOrder: [String] {
        utterances.compactMap(\.speaker).reduce(into: [String]()) { order, s in
            if !order.contains(s) { order.append(s) }
        }
    }

    private var speakersAndModel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("文字起こし")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.45))
                if let engine {
                    Text(engine)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.7))
                        .lineLimit(1)
                }
                Spacer()
                Text("話者 \(speakerOrder.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(white: 0.55))
            }
            if let fallbackFrom {
                Text("\(fallbackFrom) が使えなかったため切り替え")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }
            if !roles.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                          alignment: .leading, spacing: 4) {
                    ForEach(speakerOrder, id: \.self) { speaker in
                        HStack(spacing: 6) {
                            Text(speaker)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(speakerColor(speaker))
                            Text(roles[speaker] ?? "不明")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.75))
                                .lineLimit(1)
                        }
                    }
                }
                Text("誰の声かは、録音を聞いた分析の推定です")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.4))
            }
        }
    }

    private func utteranceRow(_ u: TimedUtterance, isCurrent: Bool) -> some View {
        Button {
            followsPlayback = true
            Task { await player.play(from: u.start) }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Text(clock(u.start))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(white: 0.45))
                    .frame(width: 40, alignment: .leading)
                    .padding(.top, 2)
                Text(u.speaker ?? "–")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(speakerColor(u.speaker))
                    .frame(width: 28, alignment: .leading)
                    .padding(.top, 2)
                Text(u.text)
                    .font(.system(size: 13))
                    .foregroundColor(isCurrent ? .white : Color(white: 0.7))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(isCurrent ? Color.accentTeal.opacity(0.18) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func speakerName(_ speaker: String?) -> String {
        guard let speaker else { return "" }
        if let role = roles[speaker], !role.isEmpty { return "\(speaker) \(role)" }
        return speaker
    }

    private func rateLabel(_ r: Float) -> String {
        r == 1 ? "1x" : (r == 2 ? "2x" : String(format: "%.2gx", r))
    }

    private func clock(_ t: Double) -> String {
        let s = Int(max(t, 0).rounded(.down))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
                         : String(format: "%d:%02d", s / 60, s % 60)
    }
}
