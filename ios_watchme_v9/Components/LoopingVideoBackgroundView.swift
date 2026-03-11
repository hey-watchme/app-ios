//
//  LoopingVideoBackgroundView.swift
//  ios_watchme_v9
//
//  Reusable muted looping background video for splash/auth surfaces.
//

import SwiftUI
import AVFoundation

struct LoopingVideoBackgroundView: View {
    let resourceName: String
    let resourceExtension: String
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill
    var fallbackColor: Color = .black

    init(
        resourceName: String,
        resourceExtension: String = "mp4",
        videoGravity: AVLayerVideoGravity = .resizeAspectFill,
        fallbackColor: Color = .black
    ) {
        self.resourceName = resourceName
        self.resourceExtension = resourceExtension
        self.videoGravity = videoGravity
        self.fallbackColor = fallbackColor
    }

    var body: some View {
        Group {
            if let url = resolvedVideoURL() {
                LoopingVideoPlayerContainer(url: url, videoGravity: videoGravity)
                    .onAppear {
                        print("✅ [LoopingVideoBackgroundView] Loaded video: \(url.lastPathComponent)")
                    }
            } else {
                fallbackColor
                    .onAppear {
                        print("⚠️ [LoopingVideoBackgroundView] Video not found: \(resourceName).\(resourceExtension)")
                    }
            }
        }
        .ignoresSafeArea()
    }

    // Xcode's synchronized folders may preserve or flatten folder paths depending on build settings.
    // Resolve across common locations so the background keeps working after file moves.
    private func resolvedVideoURL() -> URL? {
        let bundle = Bundle.main
        let root = bundle.url(forResource: resourceName, withExtension: resourceExtension)
        let inVideos = bundle.url(forResource: resourceName, withExtension: resourceExtension, subdirectory: "Videos")
        let inResourcesVideos = bundle.url(forResource: resourceName, withExtension: resourceExtension, subdirectory: "Resources/Videos")
        return root ?? inVideos ?? inResourcesVideos
    }
}

private struct LoopingVideoPlayerContainer: UIViewRepresentable {
    let url: URL
    let videoGravity: AVLayerVideoGravity

    func makeUIView(context: Context) -> LoopingVideoPlayerView {
        let view = LoopingVideoPlayerView()
        view.configure(url: url, videoGravity: videoGravity)
        return view
    }

    func updateUIView(_ uiView: LoopingVideoPlayerView, context: Context) {
        uiView.configure(url: url, videoGravity: videoGravity)
        uiView.resumePlaybackIfNeeded()
    }

    static func dismantleUIView(_ uiView: LoopingVideoPlayerView, coordinator: ()) {
        uiView.teardown()
    }
}

private final class LoopingVideoPlayerView: UIView {
    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var configuredURL: URL?

    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        guard let layer = self.layer as? AVPlayerLayer else {
            fatalError("Expected AVPlayerLayer")
        }
        return layer
    }

    func configure(url: URL, videoGravity: AVLayerVideoGravity) {
        playerLayer.videoGravity = videoGravity

        if queuePlayer == nil || configuredURL != url || queuePlayer?.currentItem == nil {
            setupPlayer(url: url)
        }

        resumePlaybackIfNeeded()
    }

    func resumePlaybackIfNeeded() {
        if queuePlayer?.rate == 0 {
            queuePlayer?.play()
            print("▶️ [LoopingVideoBackgroundView] Playback resumed")
        }
    }

    func teardown() {
        queuePlayer?.pause()
        playerLayer.player = nil
        looper = nil
        queuePlayer = nil
        configuredURL = nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            queuePlayer?.pause()
        } else {
            resumePlaybackIfNeeded()
        }
    }

    private func setupPlayer(url: URL) {
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 0

        let player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .none
        player.automaticallyWaitsToMinimizeStalling = false

        looper = AVPlayerLooper(player: player, templateItem: item)
        queuePlayer = player
        configuredURL = url
        playerLayer.player = player

        print("▶️ [LoopingVideoBackgroundView] Player initialized")
    }
}
