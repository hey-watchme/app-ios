//
//  AudioVisualizerView.swift
//  ios_watchme_v9
//
//  音声レベルに反応する円形ビジュアライザー
//  完全ネイティブ実装（SwiftUI + Core Animation）
//
//  ❌ 現在未使用（旧バージョン）
//  ✅ 代わりにBlobVisualizerView.swiftが使用されています
//

import SwiftUI

struct AudioVisualizerView: View {
    // MARK: - Properties
    let audioLevel: Float  // 0.0 〜 1.0
    @State private var animatedScale: CGFloat = 1.0
    @State private var pulseAnimation: Bool = false

    // MARK: - Body
    var body: some View {
        ZStack {
            // 外側の円（薄い）
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.3),
                            Color.blue.opacity(0.1)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .scaleEffect(animatedScale * 1.2)
                .opacity(Double(audioLevel) * 0.5 + 0.3)

            // 中間の円
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.5),
                            Color.cyan.opacity(0.3)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(animatedScale * 1.1)
                .opacity(Double(audioLevel) * 0.6 + 0.4)

            // メインの円
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.cyan,
                            Color.blue
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 75
                    )
                )
                .frame(width: 150, height: 150)
                .scaleEffect(animatedScale)
                .shadow(color: .cyan.opacity(0.5), radius: 20)

            // 中心のアイコン
            Image(systemName: "waveform")
                .font(.system(size: 50, weight: .light))
                .foregroundColor(.white)
                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
        }
        .onChange(of: audioLevel) { oldValue, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                // 音声レベルに応じてスケール変化（1.0 〜 1.5）
                animatedScale = 1.0 + CGFloat(newValue) * 0.5
            }

            // パルスアニメーション
            if newValue > 0.2 {
                withAnimation(.easeInOut(duration: 0.2)) {
                    pulseAnimation = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        pulseAnimation = false
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        AudioVisualizerView(audioLevel: 0.5)
    }
}
