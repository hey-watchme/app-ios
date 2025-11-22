//
//  AudioBarVisualizerView.swift
//  ios_watchme_v9
//
//  Simple equalizer-style audio visualizer
//  Clean and standard design with vertical bars
//

import SwiftUI

struct AudioBarVisualizerView: View {
    // MARK: - Properties
    let audioLevel: Float  // 0.0 ~ 1.0

    // Number of bars to display
    private let barCount: Int = 40

    // Bar appearance
    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 3
    private let maxBarHeight: CGFloat = 120
    private let minBarHeight: CGFloat = 4

    @State private var barHeights: [CGFloat] = []

    // MARK: - Body
    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: barWidth, height: barHeights.indices.contains(index) ? barHeights[index] : minBarHeight)
                    .animation(.easeOut(duration: 0.1), value: barHeights.indices.contains(index) ? barHeights[index] : minBarHeight)
            }
        }
        .frame(height: maxBarHeight)
        .onAppear {
            initializeBarHeights()
        }
        .onChange(of: audioLevel) { oldValue, newValue in
            updateBarHeights(for: newValue)
        }
    }

    // MARK: - Private Methods

    // Initialize bar heights with random values for aesthetic appearance
    private func initializeBarHeights() {
        barHeights = (0..<barCount).map { _ in
            minBarHeight
        }
    }

    // Update bar heights based on audio level
    private func updateBarHeights(for level: Float) {
        let normalizedLevel = CGFloat(max(0.0, min(1.0, level)))

        // Create a wave pattern across bars
        // Center bars respond more to audio, edge bars respond less
        barHeights = (0..<barCount).map { index in
            let centerIndex = CGFloat(barCount) / 2.0
            let distanceFromCenter = abs(CGFloat(index) - centerIndex)
            let normalizedDistance = distanceFromCenter / centerIndex  // 0.0 (center) ~ 1.0 (edge)

            // Center bars have higher amplitude, edge bars have lower amplitude
            let amplitudeFactor = 1.0 - (normalizedDistance * 0.7)  // 0.3 ~ 1.0

            // Add some randomness for natural look
            let randomFactor = CGFloat.random(in: 0.8...1.2)

            // Calculate final height
            let targetHeight = minBarHeight + (maxBarHeight - minBarHeight) * normalizedLevel * amplitudeFactor * randomFactor

            return max(minBarHeight, min(maxBarHeight, targetHeight))
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        AudioBarVisualizerView(audioLevel: 0.5)
    }
}
