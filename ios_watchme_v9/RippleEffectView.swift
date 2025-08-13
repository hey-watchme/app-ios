//
//  RippleEffectView.swift
//  ios_watchme_v9
//
//  波紋エフェクトコンポーネント
//

import SwiftUI

// MARK: - Ripple Effect Modifier
struct RippleEffect: ViewModifier {
    @State private var ripples: [Ripple] = []
    let color: Color
    let maxRipples: Int = 3
    
    struct Ripple: Identifiable {
        let id = UUID()
        let position: CGPoint
        let startTime: Date
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    ZStack {
                        ForEach(ripples) { ripple in
                            RippleCircle(
                                color: color,
                                startTime: ripple.startTime,
                                position: ripple.position
                            )
                        }
                    }
                }
                .allowsHitTesting(false)
            )
            .onTapGesture { location in
                addRipple(at: location)
            }
    }
    
    private func addRipple(at location: CGPoint) {
        let newRipple = Ripple(position: location, startTime: Date())
        ripples.append(newRipple)
        
        // 古い波紋を削除
        if ripples.count > maxRipples {
            ripples.removeFirst()
        }
        
        // アニメーション後に削除
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            ripples.removeAll { $0.id == newRipple.id }
        }
    }
}

// MARK: - Ripple Circle View
struct RippleCircle: View {
    let color: Color
    let startTime: Date
    let position: CGPoint
    
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(position)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) {
                    scale = 3.0
                    opacity = 0
                }
            }
    }
}

// MARK: - Pulse Effect
struct PulseEffect: ViewModifier {
    @State private var isPulsing = false
    let color: Color
    let intensity: Double
    
    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .fill(color)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .opacity(isPulsing ? 0 : intensity)
                    .blur(radius: 10)
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Wave Animation
struct WaveAnimationView: View {
    @State private var phase: CGFloat = 0
    let color: Color
    let amplitude: CGFloat
    let frequency: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midHeight = height / 2
                
                path.move(to: CGPoint(x: 0, y: midHeight))
                
                for x in stride(from: 0, to: width, by: 1) {
                    let relativeX = x / width
                    let y = midHeight + sin((relativeX + phase) * frequency * .pi * 2) * amplitude
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(
                LinearGradient(
                    colors: [color.opacity(0), color, color.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 2
            )
        }
        .onAppear {
            withAnimation(
                .linear(duration: 2)
                .repeatForever(autoreverses: false)
            ) {
                phase = 1
            }
        }
    }
}

// MARK: - Floating Bubble Effect
struct FloatingBubbleView: View {
    @State private var bubbles: [Bubble] = []
    let emotionScore: Double
    
    struct Bubble: Identifiable {
        let id = UUID()
        let size: CGFloat
        let xPosition: CGFloat
        let delay: Double
        let duration: Double
        let opacity: Double
    }
    
    var bubbleColor: Color {
        if emotionScore > 30 {
            return .green
        } else if emotionScore < -30 {
            return .red
        } else {
            return .gray
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(bubbles) { bubble in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    bubbleColor.opacity(bubble.opacity),
                                    bubbleColor.opacity(0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: bubble.size / 2
                            )
                        )
                        .frame(width: bubble.size, height: bubble.size)
                        .position(
                            x: geometry.size.width * bubble.xPosition,
                            y: geometry.size.height + bubble.size
                        )
                        .modifier(
                            FloatingModifier(
                                delay: bubble.delay,
                                duration: bubble.duration,
                                height: geometry.size.height + bubble.size * 2
                            )
                        )
                }
            }
            .onAppear {
                generateBubbles()
            }
        }
        .allowsHitTesting(false)
    }
    
    private func generateBubbles() {
        bubbles = (0..<10).map { _ in
            Bubble(
                size: CGFloat.random(in: 60...150),
                xPosition: CGFloat.random(in: 0...1),
                delay: Double.random(in: 0...3),
                duration: Double.random(in: 8...15),
                opacity: Double.random(in: 0.3...0.7)
            )
        }
    }
}

// MARK: - Floating Modifier
struct FloatingModifier: ViewModifier {
    let delay: Double
    let duration: Double
    let height: CGFloat
    
    @State private var isFloating = false
    
    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? -height : 0)
            .animation(
                Animation.linear(duration: duration)
                    .repeatForever(autoreverses: false)
                    .delay(delay),
                value: isFloating
            )
            .onAppear {
                isFloating = true
            }
    }
}

// MARK: - Burst Bubble Effect (for event bursts)
struct BurstBubbleView: View {
    let emotionScore: Double
    @State private var bubbles: [BurstBubble] = []
    
    struct BurstBubble: Identifiable {
        let id = UUID()
        let size: CGFloat
        let xPosition: CGFloat
        let yPosition: CGFloat
        let delay: Double
        let duration: Double
        let opacity: Double
        let angle: Double
    }
    
    var bubbleColor: Color {
        if emotionScore > 5 {
            return .green
        } else if emotionScore < -5 {
            return .red
        } else {
            return .gray
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(bubbles) { bubble in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    bubbleColor.opacity(bubble.opacity),
                                    bubbleColor.opacity(0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: bubble.size / 2
                            )
                        )
                        .frame(width: bubble.size, height: bubble.size)
                        .position(
                            x: geometry.size.width * bubble.xPosition,
                            y: geometry.size.height * bubble.yPosition
                        )
                        .modifier(
                            BurstAnimationModifier(
                                delay: bubble.delay,
                                duration: bubble.duration,
                                angle: bubble.angle,
                                distance: geometry.size.width * 0.5
                            )
                        )
                }
            }
            .onAppear {
                generateBurstBubbles()
            }
        }
        .allowsHitTesting(false)
    }
    
    private func generateBurstBubbles() {
        // バースト用に最適化された上昇パーティクル生成
        bubbles = (0..<30).map { _ in
            BurstBubble(
                size: CGFloat.random(in: 30...100),  // 様々なサイズ
                xPosition: CGFloat.random(in: -0.1...1.1),  // 画面全体＋少し外側
                yPosition: CGFloat.random(in: 0.3...1.3),  // 画面の中央〜下部の広範囲から発生
                delay: Double.random(in: 0...0.6),  // ランダムな遅延
                duration: Double.random(in: 2...3.5),  // アニメーション時間
                opacity: Double.random(in: 0.3...0.7),  // 透明度
                angle: -Double.pi / 2  // 上方向（-90度）
            )
        }
    }
}

// MARK: - Burst Animation Modifier
struct BurstAnimationModifier: ViewModifier {
    let delay: Double
    let duration: Double
    let angle: Double
    let distance: CGFloat
    
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.3 : 0.6)
            .opacity(isAnimating ? 0 : 0.7)
            .offset(
                x: isAnimating ? CGFloat.random(in: -80...80) : 0,  // 横方向の広いブレ
                y: isAnimating ? -distance * 3 : 0  // 上方向への移動（画面全体をカバー）
            )
            .animation(
                Animation.easeOut(duration: duration)
                    .delay(delay),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Extension for Easy Use
extension View {
    func rippleEffect(color: Color = .cyan) -> some View {
        modifier(RippleEffect(color: color))
    }
    
    func pulseEffect(color: Color = .cyan, intensity: Double = 0.3) -> some View {
        modifier(PulseEffect(color: color, intensity: intensity))
    }
}