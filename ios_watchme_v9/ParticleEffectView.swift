//
//  ParticleEffectView.swift
//  ios_watchme_v9
//
//  パーティクルエフェクトコンポーネント
//

import SwiftUI

// MARK: - Particle Model
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var size: CGFloat
    var opacity: Double
    var color: Color
    var lifespan: Double
    var age: Double = 0
    var rotation: Double = 0
    var scale: CGFloat = 1.0
}

// MARK: - Particle System
class ParticleSystem: ObservableObject {
    @Published var particles: [Particle] = []
    private var timer: Timer?
    private var emotionState: EmotionState = .neutral
    
    enum EmotionState {
        case positive
        case negative
        case neutral
        case burst // イベント時の爆発的なエフェクト
    }
    
    func startEmitting(emotionScore: Double, in size: CGSize) {
        // 通常のパーティクル生成は完全に停止（バーストのみ使用）
        // 感情スコアに基づいてステートを決定（参照用に保持）
        if emotionScore > 5 {
            emotionState = .positive
        } else if emotionScore < -5 {
            emotionState = .negative
        } else {
            emotionState = .neutral
        }
        
        // タイマーは起動しない（バーストイベントのみ対応）
        stopEmitting()
    }
    
    func triggerBurst(at position: CGPoint, emotionScore: Double) {
        emotionState = .burst
        
        // バーストエフェクト用のパーティクルを大量生成
        for _ in 0..<30 {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = Double.random(in: 50...150)
            
            let particle = Particle(
                position: position,
                velocity: CGVector(
                    dx: cos(angle) * speed,
                    dy: sin(angle) * speed
                ),
                size: CGFloat.random(in: 4...12),
                opacity: 1.0,
                color: emotionScore > 0 ? 
                    Color(hue: Double.random(in: 0.3...0.5), saturation: 1, brightness: 1) : // 緑〜青系
                    Color(hue: Double.random(in: 0...0.1), saturation: 1, brightness: 1),    // 赤〜オレンジ系
                lifespan: Double.random(in: 1.5...2.5),
                rotation: Double.random(in: 0...360)
            )
            particles.append(particle)
        }
    }
    
    private func emitParticles(in size: CGSize) {
        // ニュートラル時はパーティクルを生成しない（パフォーマンス最適化）
        guard emotionState != .neutral else { return }
        
        // ポジティブ/ネガティブ時のみパーティクル生成
        let particleCount = 2
        
        for _ in 0..<particleCount {
            let particle = createParticle(in: size)
            particles.append(particle)
        }
        
        // 古いパーティクルを削除
        particles.removeAll { $0.age >= $0.lifespan }
    }
    
    private func createParticle(in size: CGSize) -> Particle {
        switch emotionState {
        case .positive:
            return createPositiveParticle(in: size)
        case .negative:
            return createNegativeParticle(in: size)
        case .neutral:
            return createNeutralParticle(in: size)
        case .burst:
            return createBurstParticle(in: size)
        }
    }
    
    private func createPositiveParticle(in size: CGSize) -> Particle {
        Particle(
            position: CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: size.height * 0.7
            ),
            velocity: CGVector(
                dx: CGFloat.random(in: -20...20),
                dy: CGFloat.random(in: -80 ... -40) // 上昇
            ),
            size: CGFloat.random(in: 3...8),
            opacity: Double.random(in: 0.6...1.0),
            color: Color(
                hue: Double.random(in: 0.35...0.55), // 緑〜シアン
                saturation: 1,
                brightness: Double.random(in: 0.8...1.0)
            ),
            lifespan: Double.random(in: 2...4),
            rotation: Double.random(in: 0...360)
        )
    }
    
    private func createNegativeParticle(in size: CGSize) -> Particle {
        Particle(
            position: CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: size.height * 0.3
            ),
            velocity: CGVector(
                dx: CGFloat.random(in: -20...20),
                dy: CGFloat.random(in: 40...80) // 下降
            ),
            size: CGFloat.random(in: 3...8),
            opacity: Double.random(in: 0.6...1.0),
            color: Color(
                hue: Double.random(in: 0...0.1), // 赤〜オレンジ
                saturation: 1,
                brightness: Double.random(in: 0.8...1.0)
            ),
            lifespan: Double.random(in: 2...4),
            rotation: Double.random(in: 0...360)
        )
    }
    
    private func createNeutralParticle(in size: CGSize) -> Particle {
        Particle(
            position: CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: size.height / 2
            ),
            velocity: CGVector(
                dx: CGFloat.random(in: -30...30),
                dy: CGFloat.random(in: -10...10)
            ),
            size: CGFloat.random(in: 2...5),
            opacity: Double.random(in: 0.3...0.6),
            color: Color.safeColor("BorderLight").opacity(0.6),
            lifespan: Double.random(in: 1...2),
            rotation: Double.random(in: 0...360)
        )
    }
    
    private func createBurstParticle(in size: CGSize) -> Particle {
        let angle = Double.random(in: 0...(2 * .pi))
        let speed = Double.random(in: 100...200)
        
        return Particle(
            position: CGPoint(x: size.width / 2, y: size.height / 2),
            velocity: CGVector(
                dx: cos(angle) * speed,
                dy: sin(angle) * speed
            ),
            size: CGFloat.random(in: 5...15),
            opacity: 1.0,
            color: Color(
                hue: Double.random(in: 0...1),
                saturation: 1,
                brightness: 1
            ),
            lifespan: Double.random(in: 1...2),
            rotation: Double.random(in: 0...360)
        )
    }
    
    private func updateParticles() {
        for i in particles.indices {
            // 位置更新
            particles[i].position.x += particles[i].velocity.dx * 0.016
            particles[i].position.y += particles[i].velocity.dy * 0.016
            
            // 速度減衰
            particles[i].velocity.dx *= 0.98
            particles[i].velocity.dy *= 0.98
            
            // 重力効果（ポジティブは上昇、ネガティブは下降）
            if emotionState == .positive {
                particles[i].velocity.dy -= 1 // 上向きの力
            } else if emotionState == .negative {
                particles[i].velocity.dy += 1 // 下向きの力
            }
            
            // 年齢更新
            particles[i].age += 0.016
            
            // フェードアウト
            let lifeRatio = particles[i].age / particles[i].lifespan
            particles[i].opacity = max(0, 1 - lifeRatio)
            
            // 回転
            particles[i].rotation += 2
            
            // スケール変化
            particles[i].scale = 1 - (lifeRatio * 0.5)
        }
    }
    
    func stopEmitting() {
        timer?.invalidate()
        timer = nil
    }
    
    deinit {
        stopEmitting()
    }
}

// MARK: - Particle Effect View
struct ParticleEffectView: View {
    @StateObject private var particleSystem = ParticleSystem()
    let emotionScore: Double
    let isActive: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particleSystem.particles) { particle in
                    ParticleView(particle: particle)
                }
            }
            .onChange(of: emotionScore) { _, newScore in
                if isActive {
                    particleSystem.startEmitting(emotionScore: newScore, in: geometry.size)
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    particleSystem.startEmitting(emotionScore: emotionScore, in: geometry.size)
                } else {
                    particleSystem.stopEmitting()
                }
            }
            .onAppear {
                if isActive {
                    particleSystem.startEmitting(emotionScore: emotionScore, in: geometry.size)
                }
            }
            .onDisappear {
                particleSystem.stopEmitting()
            }
        }
        .allowsHitTesting(false) // パーティクルはタッチイベントを透過
    }
    
    // イベント発生時のバーストエフェクトを呼び出すメソッド
    func triggerBurst(at position: CGPoint) {
        particleSystem.triggerBurst(at: position, emotionScore: emotionScore)
    }
}

// MARK: - Individual Particle View
struct ParticleView: View {
    let particle: Particle
    
    var body: some View {
        ZStack {
            // グロー効果
            Circle()
                .fill(particle.color)
                .frame(width: particle.size * 2, height: particle.size * 2)
                .blur(radius: particle.size / 2)
                .opacity(particle.opacity * 0.3)
            
            // メインパーティクル
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            particle.color,
                            particle.color.opacity(0.5)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: particle.size / 2
                    )
                )
                .frame(width: particle.size, height: particle.size)
                .opacity(particle.opacity)
        }
        .rotationEffect(.degrees(particle.rotation))
        .scaleEffect(particle.scale)
        .position(particle.position)
        .animation(.linear(duration: 0.016), value: particle.position)
    }
}

// MARK: - Sparkle Effect (軽量版パーティクル)
struct SparkleEffect: View {
    @State private var sparkles: [Sparkle] = []
    let count: Int = 20
    
    struct Sparkle: Identifiable {
        let id = UUID()
        let position: CGPoint
        let delay: Double
        let duration: Double
        let size: CGFloat
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(sparkles) { sparkle in
                    Image(systemName: "sparkle")
                        .font(.system(size: sparkle.size))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.safeColor("EmotionSurprise"), Color.safeColor("PrimaryActionColor")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .position(sparkle.position)
                        .opacity(0)
                        .animation(
                            Animation.easeInOut(duration: sparkle.duration)
                                .repeatForever()
                                .delay(sparkle.delay),
                            value: UUID()
                        )
                        .modifier(SparkleModifier())
                }
            }
            .onAppear {
                generateSparkles(in: geometry.size)
            }
        }
    }
    
    private func generateSparkles(in size: CGSize) {
        sparkles = (0..<count).map { _ in
            Sparkle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                delay: Double.random(in: 0...2),
                duration: Double.random(in: 1...3),
                size: CGFloat.random(in: 4...12)
            )
        }
    }
}

// MARK: - Sparkle Animation Modifier
struct SparkleModifier: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.2 : 0.8)
            .opacity(isAnimating ? 1 : 0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
    }
}