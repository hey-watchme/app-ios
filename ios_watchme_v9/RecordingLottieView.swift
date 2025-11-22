//
//  RecordingLottieView.swift
//  ios_watchme_v9
//
//  Lottie animation wrapper for recording visualization
//  音声レベルに応じてスケールが変化するLottieアニメーション
//

import SwiftUI
import Lottie

struct RecordingLottieView: View {
    var audioLevel: CGFloat  // 0.0 ~ 1.0 normalized audio level

    var body: some View {
        LottieView(animation: .named("recording_blob"))
            .playing(loopMode: .loop)
            .animationSpeed(1.0)
            .scaleEffect(0.9 + audioLevel * 0.3)
            .frame(width: 160, height: 160)
            .animation(.easeInOut(duration: 0.1), value: audioLevel)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        RecordingLottieView(audioLevel: 0.5)
    }
}
