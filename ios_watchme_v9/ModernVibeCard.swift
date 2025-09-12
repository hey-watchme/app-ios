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
    let dashboardSummary: DashboardSummary?  // 新規追加
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
            
            // 軽い境界線
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.safeColor("BorderLight").opacity(0.1), lineWidth: 1)
            
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
                // dashboard_summaryのvibeScoresを優先、なければvibeReportから取得（フォールバック）
                if let vibeScores = dashboardSummary?.vibeScores ?? vibeReport.vibeScores {
                    InteractiveTimelineView(
                        vibeScores: vibeScores,
                        vibeChanges: vibeReport.vibeChanges,  // vibeChangesは引き続きvibeReportから
                        onEventBurst: { score in
                            // バーストエフェクトをトリガー
                            triggerBurst(score: score)
                        }
                    )
                    // ID管理は親のNewHomeViewに委ねる（ID削除）
                }
                
                // Cumulative Evaluation（analysis_resultから取得）
                if let cumulativeEvaluation = dashboardSummary?.analysisResult?.cumulativeEvaluation,
                   !cumulativeEvaluation.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(cumulativeEvaluation.enumerated()), id: \.offset) { index, comment in
                            Text(comment)
                                .font(.system(size: 18))
                                .foregroundStyle(Color.safeColor("BehaviorTextPrimary"))
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .padding(.vertical, 24)
                }
            }
            .padding(20)
        }
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
                .foregroundStyle(Color.safeColor("BehaviorTextPrimary")) // #1a1a1a
            
            Spacer()
            
            // 心理グラフへのリンクボタン
            Button(action: {
                // 心理グラフ詳細への遷移
                onNavigateToDetail?()
            }) {
                HStack(spacing: 4) {
                    Text("心理グラフ")
                        .font(.caption)
                        .foregroundStyle(Color.safeColor("BehaviorTextSecondary")) // #666666
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Color.safeColor("BehaviorTextSecondary")) // #666666
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.safeColor("BorderLight").opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(Color.safeColor("BorderLight").opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .allowsHitTesting(false) // タップイベントを透過させる
        }
    }
    
    // MARK: - Main Score View
    private var mainScoreView: some View {
        VStack(spacing: 8) {
            // 絵文字（1.5倍に拡大）
            Text(emotionEmoji)
                .font(.system(size: 108))
            
            // ステータステキスト（小さく表示）
            Text(emotionLabel)
                .font(.caption)
                .foregroundStyle(scoreColor)
                .textCase(.uppercase)
                .tracking(1.0)
            
            // 平均スコア（1行で簡潔に）
            HStack(spacing: 4) {
                Text("平均スコア:")
                    .font(.caption2)
                    .foregroundStyle(Color.safeColor("BehaviorTextSecondary")) // #666666
                
                // dashboard_summaryのaverage_vibeのみを使用（フォールバックなし）
                Group {
                    if let avgVibe = dashboardSummary?.averageVibe {
                        Text(String(format: "%.1f pt", Double(avgVibe)))
                    } else {
                        Text("--")
                    }
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(scoreColor.opacity(0.8))
            }
        }
        .padding(.bottom, 24)  // 下に24pxの余白を追加
    }
    
    // MARK: - Time Distribution View（削除済み）
    // 時間分布パネルは心理グラフ詳細ページで表示されるため、
    // ダッシュボードのModernVibeCardからは削除しました
    
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
    // dashboard_summaryのaverage_vibeのみを使用（フォールバックなし）
    private var actualAverageScore: Double? {
        if let avgVibe = dashboardSummary?.averageVibe {
            return Double(avgVibe)
        }
        return nil
    }
    
    private var scoreColor: Color {
        guard let score = actualAverageScore else { return .gray }
        if score > 30 {
            return .green
        } else if score < -30 {
            return .red
        } else {
            return .gray
        }
    }
    
    private var emotionEmoji: String {
        guard let score = actualAverageScore else { return "❓" }
        if score > 50 {
            return "👏"
        } else if score > 30 {
            return "✌️"
        } else if score > 0 {
            return "👍"
        } else if score > -30 {
            return "👌"
        } else if score > -50 {
            return "💪"
        } else {
            return "💔"
        }
    }
    
    private var emotionLabel: String {
        guard let score = actualAverageScore else { return "No data" }
        if score > 50 {
            return "Excellent"
        } else if score > 30 {
            return "Positive"
        } else if score > 0 {
            return "Good"
        } else if score > -30 {
            return "Neutral"
        } else if score > -50 {
            return "Challenging"
        } else {
            return "Difficult"
        }
    }
}