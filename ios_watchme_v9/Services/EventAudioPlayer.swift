//
//  EventAudioPlayer.swift
//  ios_watchme_v9
//
//  Plays the moment of a counted event: from a few seconds before it starts to a little
//  after it ends. The URL comes from GET /audio?device_id&recorded_at&at (platform
//  backend/functions/audio), which finds the kept copy or, within 3 days, the audio that
//  is still there; 410 means the audio was deleted. Event times come from the listener
//  and can be a few seconds off, hence the lead-in.
//

import AVFoundation
import SwiftUI

@MainActor
final class EventAudioPlayer: ObservableObject {
    static let shared = EventAudioPlayer()

    /// The event being loaded or played (its id), nil when idle.
    @Published private(set) var activeId: String?
    @Published private(set) var isLoading = false

    private static let leadIn: Double = 3
    private static let tail: Double = 2
    private static let minimumLength: Double = 6

    private let serverURL = "https://api.hey-watch.me"
    private var player: AVPlayer?
    private var stopObserver: Any?
    private var endObserver: NSObjectProtocol?

    func isActive(_ id: String) -> Bool { activeId == id }

    /// Toggle playback of one event. start/end are seconds from the start of the recording.
    func toggle(id: String, deviceId: String, recordedAt: String, start: Double, end: Double) async {
        if activeId == id {
            stop()
            return
        }
        stop()
        activeId = id
        isLoading = true
        defer { isLoading = false }

        let from = max(start - Self.leadIn, 0)
        let until = max(end + Self.tail, from + Self.minimumLength)
        do {
            let (url, partStart) = try await playbackURL(deviceId: deviceId, recordedAt: recordedAt, at: from)
            guard activeId == id else { return }  // another event was pressed meanwhile
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)

            let item = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: item)
            self.player = player
            await player.seek(to: CMTime(seconds: from - partStart, preferredTimescale: 600),
                              toleranceBefore: .zero, toleranceAfter: .zero)
            stopObserver = player.addBoundaryTimeObserver(
                forTimes: [NSValue(time: CMTime(seconds: until - partStart, preferredTimescale: 600))],
                queue: .main
            ) { [weak self] in
                Task { @MainActor in self?.stop() }
            }
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.stop() }
            }
            player.play()
        } catch PlaybackError.deleted {
            activeId = nil
            ToastManager.shared.showInfo(title: "音声は削除されました", subtitle: "この録音の音声は保存期間（3日）を過ぎたため、残っていません")
        } catch {
            activeId = nil
            print("❌ [EventAudioPlayer] \(error)")
            ToastManager.shared.showError(title: "再生できませんでした", subtitle: error.localizedDescription)
        }
    }

    func stop() {
        if let stopObserver, let player { player.removeTimeObserver(stopObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        stopObserver = nil
        endObserver = nil
        player?.pause()
        player = nil
        activeId = nil
    }

    enum PlaybackError: LocalizedError {
        case deleted
        case failed(Int)

        var errorDescription: String? {
            switch self {
            case .deleted: return "音声は削除されました"
            case .failed(let status): return "再生用のURLを取得できませんでした（HTTP \(status)）"
            }
        }
    }

    private func playbackURL(deviceId: String, recordedAt: String, at: Double) async throws -> (URL, Double) {
        guard let bearer = await SupabaseClientManager.shared.bearerToken() else { throw PlaybackError.failed(401) }
        var components = URLComponents(string: "\(serverURL)/audio")!
        components.queryItems = [
            URLQueryItem(name: "device_id", value: deviceId),
            URLQueryItem(name: "recorded_at", value: recordedAt),
            URLQueryItem(name: "at", value: String(format: "%.1f", at)),
        ]
        // "+" in the time zone must not be read as a space
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        var request = URLRequest(url: components.url!)
        request.setValue(bearer, forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 410 || status == 404 { throw PlaybackError.deleted }
        guard status == 200,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urlString = object["url"] as? String,
              let url = URL(string: urlString) else { throw PlaybackError.failed(status) }
        return (url, (object["part_start"] as? NSNumber)?.doubleValue ?? 0)
    }
}

/// The play / stop button of one event.
struct EventPlayButton: View {
    let id: String
    let deviceId: String
    let recordedAt: String
    let start: Double
    let end: Double
    @ObservedObject private var player = EventAudioPlayer.shared

    var body: some View {
        Button {
            Task { await player.toggle(id: id, deviceId: deviceId, recordedAt: recordedAt, start: start, end: end) }
        } label: {
            Group {
                if player.isActive(id) && player.isLoading {
                    ProgressView().scaleEffect(0.6)
                } else {
                    Image(systemName: player.isActive(id) ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accentTeal)
                }
            }
            .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isActive(id) ? "停止" : "この場面を再生")
    }
}
