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
            return Color.safeColor("SuccessColor")
        } else if emotionScore < -30 {
            return Color.safeColor("ErrorColor")
        } else {
            return Color.safeColor("BorderLight")
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
            return Color.safeColor("SuccessColor")
        } else if emotionScore < -5 {
            return Color.safeColor("ErrorColor")
        } else {
            return Color.safeColor("BorderLight")
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
                                distance: geometry.size.width * 2
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
        // カード中心から放射状に広がる花火のようなパーティクル生成
        bubbles = (0..<50).map { index in
            // 360度を均等に分割し、ランダム性を加える
            let baseAngle = (Double(index) / 50.0) * Double.pi * 2
            let angleVariation = Double.random(in: -0.2...0.2)  // 角度に少しランダム性を加える
            let finalAngle = baseAngle + angleVariation
            
            return BurstBubble(
                size: CGFloat.random(in: 20...60),  // パーティクルサイズ
                xPosition: 0.5,  // カード中心からスタート
                yPosition: 0.5,  // カード中心からスタート
                delay: Double.random(in: 0...0.2),  // 少しの遅延で自然な広がり
                duration: Double.random(in: 1.5...2.5),  // アニメーション時間
                opacity: 0.5,  // 透明度0.5に変更
                angle: finalAngle  // 放射状の角度
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
            .scaleEffect(isAnimating ? 0.1 : 1.0)  // 小さくなって消える
            .opacity(isAnimating ? 0 : 0.5)  // 透明度0.5から始まり消える
            .offset(
                x: isAnimating ? cos(angle) * distance : 0,  // 角度に応じたx方向へ移動
                y: isAnimating ? sin(angle) * distance : 0   // 角度に応じたy方向へ移動
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