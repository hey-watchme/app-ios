//
//  ModernVibeCard.swift
//  ios_watchme_v9
//
//  モダンな気分グラフカード - Phase 1: ダークテーマとグラデーション
//

import SwiftUI
import Charts

struct ModernVibeCard: View {
    let dashboardSummary: DashboardSummary?  // 平均スコアとサマリー用
    let timeBlocks: [DashboardTimeBlock]  // グラフ用データ（spot_resultsから取得）
    var onNavigateToDetail: (() -> Void)? = nil
    var showTitle: Bool = true  // タイトル表示制御用
    @State private var isAnimating = false
    @State private var cardScale: CGFloat = 1.0
    @State private var showBurstBubbles = false
    @State private var burstScore: Double = 0
    @State private var emojiRotation: Double = 0  // 絵文字の振動用
    
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
            
            // バーストバブルは削除（パーティクルエフェクトを使わない）
            
            VStack(spacing: 16) {  // 他の要素との間隔は16に戻す
                // ヘッダー部分（タイトルのみ）
                if showTitle {
                    VStack(spacing: 8) {  // タイトルと絵文字の間だけ8pxに
                        HStack {
                            // シンプルな気分タイトル（大きく表示）
                            Text("気分")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(Color.safeColor("BehaviorTextPrimary")) // #1a1a1a
                            
                            Spacer()
                        }
                        
                        // メインスコア表示
                        mainScoreView
                    }
                } else {
                    // メインスコア表示
                    mainScoreView
                }
                
                // インタラクティブタイムライン（Phase 2）
                // spot_resultsから取得したtimeBlocksを使用
                // ⚠️ エラーデータはグラフから除外（グラフのジャンプ問題を防ぐ）
                let validTimeBlocks = timeBlocks.filter { block in
                    block.displayTime != "⚠️ ERROR" && block.displayTime != "⚠️ PARSE ERROR"
                }

                if !validTimeBlocks.isEmpty {
                    InteractiveTimelineView(
                        timeBlocks: validTimeBlocks,
                        burstEvents: dashboardSummary?.burstEvents,  // dashboard_summaryから取得
                        onEventBurst: { score in
                            // バーストエフェクトをトリガー
                            triggerBurst(score: score)
                        }
                    )
                }
                
                // 1日のサマリー（insightsから取得）
                if let insights = dashboardSummary?.insights, !insights.isEmpty {
                    Text(insights)
                        .font(.system(size: 18, weight: .bold))  // 太字に変更
                        .foregroundStyle(Color.safeColor("BehaviorTextPrimary"))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(18 * 0.6)  // フォントサイズ18ptの60%で行間を設定（line-height: 160%相当）
                        .padding(.top, 24)  // グラフとの間に24px余白
                        .padding(.bottom, 16)  // 下部は少し余白を減らす
                }
                
                // ナビゲーションリンク（右下に配置）
                HStack {
                    Spacer()
                    
                    Button(action: {
                        // 分析結果の一覧への遷移
                        onNavigateToDetail?()
                    }) {
                        HStack(spacing: 4) {
                            Text("分析結果の一覧")
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
            .padding(16)  // 内側の余白を16pxに変更（UnifiedCardと統一）
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
    
    // MARK: - Main Score View
    private var mainScoreView: some View {
        VStack(spacing: 8) {
            // 絵文字（1.5倍に拡大）- 振動アニメーション付き
            Text(emotionEmoji)
                .font(.system(size: 108))
                .rotationEffect(.degrees(emojiRotation))
            
            // ステータステキスト（黒・太字・20px）
            Text(emotionLabel)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.safeColor("BehaviorTextPrimary"))  // 黒
                .textCase(.uppercase)
                .tracking(1.0)
            
            // 気分スコア（1行で簡潔に）
            HStack(spacing: 4) {
                Text("気分")
                    .font(.caption2)
                    .foregroundStyle(Color.safeColor("BehaviorTextSecondary")) // #666666
                
                // dashboard_summaryのaverage_vibeのみを使用（フォールバックなし）
                Group {
                    if let avgVibe = dashboardSummary?.averageVibe {
                        Text(String(format: "%.0f pt", Double(avgVibe)))  // 小数点なしに変更
                    } else {
                        Text("-- pt")
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
    // 時間分布パネルは気分詳細ページで表示されるため、
    // ダッシュボードのModernVibeCardからは削除しました
    
    // MARK: - Burst Trigger
    private func triggerBurst(score: Double) {
        burstScore = score
        
        // 絵文字を振動させる
        // 左右に小刻みに揺れるアニメーション
        withAnimation(Animation.linear(duration: 0.05)) {
            emojiRotation = -2  // 左に2度
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(Animation.linear(duration: 0.1)) {
                emojiRotation = 2  // 右に2度
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(Animation.linear(duration: 0.1)) {
                emojiRotation = -1.5  // 左に1.5度
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(Animation.linear(duration: 0.1)) {
                emojiRotation = 1  // 右に1度
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(Animation.linear(duration: 0.1)) {
                emojiRotation = -0.5  // 左に0.5度
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(Animation.linear(duration: 0.1)) {
                emojiRotation = 0  // 元の位置に戻る
            }
        }
        
        // Hapticフィードバック（バイブレーション）も追加
        HapticManager.shared.playEventBurst()
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