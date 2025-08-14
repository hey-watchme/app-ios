//
//  ModernVibeCard.swift
//  ios_watchme_v9
//
//  モダンな気分グラフカード - Phase 1: ダークテーマとグラデーション
//

import SwiftUI
import Charts

struct ModernVibeCard: View {
    let vibeReport: DailyVibeReport
    var onNavigateToDetail: (() -> Void)? = nil
    @State private var isAnimating = false
    @State private var cardScale: CGFloat = 1.0
    @State private var showBurstBubbles = false
    @State private var burstScore: Double = 0
    
    // ライトテーマのカラーパレット
    private let lightBackground = Color.white // #ffffff
    
    private let positiveGradient = LinearGradient(
        colors: [
            Color(red: 0, green: 1, blue: 0.53),
            Color(red: 0, green: 0.85, blue: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    private let negativeGradient = LinearGradient(
        colors: [
            Color(red: 1, green: 0.42, blue: 0.42),
            Color(red: 0.79, green: 0.16, blue: 0.16)
        ],
        startPoint: .bottom,
        endPoint: .top
    )
    
    var body: some View {
        ZStack {
            // 背景 (白)
            RoundedRectangle(cornerRadius: 24)
                .fill(lightBackground)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            // 波アニメーション（Phase 4: その他の演出）
            WaveAnimationView(
                color: scoreColor.opacity(0.1),
                amplitude: 10,
                frequency: 2
            )
            .blendMode(.multiply)
            
            // 軽い境界線
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            
            // バーストバブル（イベント時のみ表示）
            if showBurstBubbles {
                BurstBubbleView(emotionScore: burstScore)
                    .opacity(0.5)
                    .transition(.opacity)
            }
            
            VStack(spacing: 24) {
                // ヘッダー部分
                headerView
                
                // メインスコア表示
                mainScoreView
                
                // インタラクティブタイムライン（Phase 2）
                if let vibeScores = vibeReport.vibeScores {
                    InteractiveTimelineView(
                        vibeScores: vibeScores,
                        vibeChanges: vibeReport.vibeChanges,
                        onEventBurst: { score in
                            // バーストエフェクトをトリガー
                            triggerBurst(score: score)
                        }
                    )
                    // データが変わったら確実にViewを再生成
                    .id("\(vibeReport.deviceId)_\(vibeReport.date)")
                }
                
                // 時間分布バー
                timeDistributionView
            }
            .padding(20)
        }
        .frame(height: 650)
        .scaleEffect(cardScale)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                isAnimating = true
                cardScale = 1.02
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    cardScale = 1.0
                }
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            // シンプルな気分タイトル（大きく表示）
            Text("気分")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1)) // #1a1a1a
            
            Spacer()
            
            // 心理グラフへのリンクボタン
            Button(action: {
                // 心理グラフ詳細への遷移
                onNavigateToDetail?()
            }) {
                HStack(spacing: 4) {
                    Text("心理グラフ")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4)) // #666666
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4)) // #666666
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.gray.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - Main Score View
    private var mainScoreView: some View {
        VStack(spacing: 8) {
            // 絵文字（大きく表示）
            Text(emotionEmoji)
                .font(.system(size: 72))
            
            // ステータステキスト（小さく表示）
            Text(emotionLabel)
                .font(.caption)
                .foregroundStyle(scoreColor)
                .textCase(.uppercase)
                .tracking(1.0)
            
            // Average Scoreとスコア（1行で簡潔に）
            HStack(spacing: 4) {
                Text("Average Score:")
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4)) // #666666
                
                Text(String(format: "%.1f", vibeReport.averageScore))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(scoreColor.opacity(0.8))
            }
        }
    }
    
    // MARK: - Time Distribution View
    private var timeDistributionView: some View {
        HStack(spacing: 12) {
            timeDistributionItem(
                label: "Positive",
                hours: vibeReport.positiveHours,
                color: Color.green,
                icon: "arrow.up.circle.fill",
                showSparkle: vibeReport.positiveHours > 8
            )
            
            timeDistributionItem(
                label: "Neutral",
                hours: vibeReport.neutralHours,
                color: Color.gray,
                icon: "minus.circle.fill",
                showSparkle: false
            )
            
            timeDistributionItem(
                label: "Negative",
                hours: vibeReport.negativeHours,
                color: Color.red,
                icon: "arrow.down.circle.fill",
                showSparkle: vibeReport.negativeHours > 8
            )
        }
    }
    
    private func timeDistributionItem(label: String, hours: Double, color: Color, icon: String, showSparkle: Bool) -> some View {
        ZStack {
            // スパークルエフェクト（条件付き）
            if showSparkle {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "sparkle")
                        .font(.caption)
                        .foregroundStyle(color)
                        .offset(
                            x: CGFloat.random(in: -30...30),
                            y: CGFloat.random(in: -20...20)
                        )
                        .opacity(0)
                        .animation(
                            Animation.easeInOut(duration: 2)
                                .repeatForever()
                                .delay(Double(index) * 0.3),
                            value: isAnimating
                        )
                        .scaleEffect(isAnimating ? 1.2 : 0.5)
                }
            }
            
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .symbolEffect(.pulse, isActive: showSparkle)
                
                Text(String(format: "%.1fh", hours))
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1)) // #1a1a1a
                
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4)) // #666666
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            ZStack {
                // グラデーション背景
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.3),
                                color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // ボーダーのグロー効果
                if showSparkle {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color, lineWidth: 1)
                        .blur(radius: 3)
                        .opacity(0.5)
                }
                
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            }
        )
    }
    
    // MARK: - Burst Trigger
    private func triggerBurst(score: Double) {
        burstScore = score
        withAnimation(.spring()) {
            showBurstBubbles = true
        }
        
        // 2秒後に自動的に非表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut) {
                showBurstBubbles = false
            }
        }
    }
    
    // MARK: - Computed Properties
    private var scoreColor: Color {
        if vibeReport.averageScore > 30 {
            return .green
        } else if vibeReport.averageScore < -30 {
            return .red
        } else {
            return .gray
        }
    }
    
    private var emotionEmoji: String {
        if vibeReport.averageScore > 50 {
            return "👏"
        } else if vibeReport.averageScore > 30 {
            return "✌️"
        } else if vibeReport.averageScore > 0 {
            return "👍"
        } else if vibeReport.averageScore > -30 {
            return "👌"
        } else if vibeReport.averageScore > -50 {
            return "💪"
        } else {
            return "💔"
        }
    }
    
    private var emotionLabel: String {
        if vibeReport.averageScore > 50 {
            return "Excellent"
        } else if vibeReport.averageScore > 30 {
            return "Positive"
        } else if vibeReport.averageScore > 0 {
            return "Good"
        } else if vibeReport.averageScore > -30 {
            return "Neutral"
        } else if vibeReport.averageScore > -50 {
            return "Challenging"
        } else {
            return "Difficult"
        }
    }
}