//
//  BlobVisualizerView.swift
//  ios_watchme_v9
//
//  音声に反応する有機的なBlob形状ビジュアライザー
//  ChatGPT風のランダムで抽象的な表現
//
//  ✅ 現在使用中（FullScreenRecordingViewで使用）
//  ※ AudioVisualizerView.swiftは旧バージョン（現在未使用）
//

import SwiftUI

struct BlobVisualizerView: View {
    // MARK: - Properties
    let audioLevel: Float  // 0.0 〜 1.0

    @State private var phase: CGFloat = 0.0

    // タイマーを使って phase を無限に増やし続ける（ワープなし）
    private let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    // MARK: - Body
    var body: some View {
        ZStack {
            // メインのBlob（1つのみ、2倍サイズ）
            BlobShape(
                audioLevel: CGFloat(audioLevel),
                phase: phase * 1.7,
                complexity: 8,
                phaseOffset: 4.1
            )
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.cyan,
                        Color.blue
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 100
                )
            )
            .frame(width: 160, height: 160)  // 200の80%
            .shadow(color: .cyan.opacity(0.5), radius: 20)

            // 中心のアイコン
            Image(systemName: "waveform")
                .font(.system(size: 50, weight: .light))
                .foregroundColor(.white)
        }
        .onReceive(timer) { _ in
            // phase を無限に増やし続ける（ワープなし）
            // sin関数は周期的なので、phase が増え続けても自然にループする
            phase += 0.025  // 適度な回転速度
        }
    }
}

// MARK: - BlobShape

struct BlobShape: Shape {
    var audioLevel: CGFloat
    var phase: CGFloat
    var complexity: Int
    var phaseOffset: CGFloat  // 位相オフセット（各円をずらす）

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(audioLevel, phase) }
        set {
            audioLevel = newValue.first
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) / 2

        // 音声レベルに応じて変形の振幅を調整（適度に）
        // 待機中（audioLevel=0）: 0.01（ほぼ円形）
        // 音声検知時（audioLevel>0）: 0.01 + audioLevel * 0.35（最大0.36、適度に変化）
        let amplitude = 0.01 + audioLevel * 0.35

        // 音声レベルに応じて半径も変化（1.0 〜 1.22倍、適度に）
        let radiusMultiplier = 1.0 + audioLevel * 0.22

        let points = complexity * 20  // 滑らかさ（頂点数を大幅に増やして円に近づける）

        for i in 0..<points {
            let angle = (CGFloat(i) / CGFloat(points)) * 2 * .pi

            // スパイクのインデックスを計算（どのスパイクに属するか）
            let spikeIndex = floor(angle / (2 * .pi / CGFloat(complexity)))

            // 各スパイクに異なる振幅を与える（擬似ランダム）
            // sin関数で擬似ランダムな値を生成（0.6〜1.4の範囲）
            let spikeRandomFactor = 0.6 + sin(spikeIndex * 2.718 + phase * 0.05) * 0.4 + 0.4

            // メインのsin波 + スパイクのランダム性
            let mainNoise = sin(angle * CGFloat(complexity) + phase + phaseOffset) * amplitude * spikeRandomFactor
            let totalNoise = mainNoise

            let radius = baseRadius * (1.0 + totalNoise) * radiusMultiplier

            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        BlobVisualizerView(audioLevel: 0.5)
    }
}
