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
            .scaleEffect(0.8 + audioLevel * 0.6)  // More responsive: 0.8x to 1.4x
            .frame(width: 200, height: 200)  // Larger size for better visibility
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: audioLevel)  // Smoother spring animation
            .opacity(0.7 + audioLevel * 0.3)  // Subtle opacity change for additional feedback
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
