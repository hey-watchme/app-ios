//
//  ModernVibeCard.swift
//  ios_watchme_v9
//
//  Vibe graph card - Dark theme redesign
//

import SwiftUI
import Charts

struct ModernVibeCard: View {
    let dashboardSummary: DashboardSummary?
    let timeBlocks: [DashboardTimeBlock]
    var onNavigateToDetail: (() -> Void)? = nil
    var showTitle: Bool = true
    @State private var isAnimating = false
    @State private var cardScale: CGFloat = 1.0
    @State private var showBurstBubbles = false
    @State private var burstScore: Double = 0
    @State private var emojiRotation: Double = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.darkCard)

            // Rich gradient overlay (Oura My Health-style: multi-tone mesh)
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            scoreColor.opacity(0.12),
                            scoreColor.opacity(0.04),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Secondary gradient for depth (cross-direction)
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color(white: 0.08).opacity(0.5),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Inner glow at top (premium feel)
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    RadialGradient(
                        colors: [
                            scoreColor.opacity(0.08),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 200
                    )
                )

            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            VStack(spacing: 0) {
                // Header: score + status
                if showTitle {
                    headerSection
                        .padding(.bottom, 20)
                } else {
                    compactScoreSection
                        .padding(.bottom, 12)
                }

                // Motivational message (Oura-style)
                if let msg = motivationalMessage {
                    motivationalBanner(message: msg)
                        .padding(.bottom, 16)
                }

                // Timeline graph
                let validTimeBlocks = timeBlocks.filter { block in
                    block.displayTime != "⚠\u{FE0F} ERROR" && block.displayTime != "⚠\u{FE0F} PARSE ERROR"
                }

                if !validTimeBlocks.isEmpty {
                    InteractiveTimelineView(
                        timeBlocks: validTimeBlocks,
                        burstEvents: dashboardSummary?.burstEvents,
                        onEventBurst: { score in
                            triggerBurst(score: score)
                        }
                    )
                }

                // Daily insights
                if let insights = dashboardSummary?.insights, !insights.isEmpty {
                    Text(insights)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(white: 0.78))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(15 * 0.5)
                        .padding(.top, 20)
                }

                // Navigation link
                HStack {
                    Spacer()

                    Button(action: {
                        onNavigateToDetail?()
                    }) {
                        HStack(spacing: 4) {
                            Text("All analyses")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(white: 0.45))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(white: 0.45))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                    .allowsHitTesting(false)
                }
                .padding(.top, 16)
            }
            .padding(20)
        }
        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
        .shadow(color: scoreColor.opacity(0.08), radius: 20, x: 0, y: 0)
        .scaleEffect(cardScale)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                isAnimating = true
                cardScale = 1.01
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    cardScale = 1.0
                }
            }
        }
    }

    // MARK: - Header Section (with title)

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Vibe")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(white: 0.45))
                        .tracking(1.0)
                        .textCase(.uppercase)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if let avgVibe = dashboardSummary?.averageVibe {
                            Text(String(format: "%.0f", avgVibe))
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        } else {
                            Text("--")
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(white: 0.30))
                        }

                        Text("pt")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color(white: 0.36))
                    }
                }

                Spacer()

                // Status badge
                VStack(alignment: .trailing, spacing: 6) {
                    Text(emotionLabel.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(scoreColor)
                        .tracking(0.8)

                    // Micro ring gauge
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 3)
                            .frame(width: 44, height: 44)

                        Circle()
                            .trim(from: 0, to: scoreProgress)
                            .stroke(scoreColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 44, height: 44)

                        Text(emotionEmoji)
                            .font(.system(size: 20))
                            .rotationEffect(.degrees(emojiRotation))
                    }
                }
            }
        }
    }

    // MARK: - Compact Score (no title)

    private var compactScoreSection: some View {
        HStack(alignment: .center) {
            // Score
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let avgVibe = dashboardSummary?.averageVibe {
                    Text(String(format: "%.0f", avgVibe))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Text("--")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(white: 0.30))
                }

                Text("pt")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(white: 0.36))
            }

            Spacer()

            // Status
            HStack(spacing: 8) {
                Text(emotionLabel.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(scoreColor)
                    .tracking(0.8)

                Circle()
                    .fill(scoreColor)
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Burst Trigger

    private func triggerBurst(score: Double) {
        burstScore = score

        withAnimation(Animation.linear(duration: 0.05)) {
            emojiRotation = -2
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(Animation.linear(duration: 0.1)) {
                emojiRotation = 2
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(Animation.linear(duration: 0.1)) {
                emojiRotation = -1.5
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(Animation.linear(duration: 0.1)) {
                emojiRotation = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(Animation.linear(duration: 0.1)) {
                emojiRotation = 0
            }
        }

        HapticManager.shared.playEventBurst()
    }

    // MARK: - Computed Properties

    private var actualAverageScore: Double? {
        if let avgVibe = dashboardSummary?.averageVibe {
            return Double(avgVibe)
        }
        return nil
    }

    private var scoreProgress: Double {
        guard let score = actualAverageScore else { return 0 }
        return min(max((score + 100) / 200, 0), 1)
    }

    private var scoreColor: Color {
        guard let score = actualAverageScore else { return Color(white: 0.30) }
        return Color.vibeScoreColor(for: score)
    }

    private var emotionEmoji: String {
        guard let score = actualAverageScore else { return "?" }
        if score > 50 { return "+" }
        else if score > 30 { return "+" }
        else if score > 0 { return "+" }
        else if score > -30 { return "~" }
        else if score > -50 { return "-" }
        else { return "-" }
    }

    private var emotionLabel: String {
        guard let score = actualAverageScore else { return "No data" }
        if score > 50 { return "Excellent" }
        else if score > 30 { return "Positive" }
        else if score > 0 { return "Good" }
        else if score > -30 { return "Neutral" }
        else if score > -50 { return "Challenging" }
        else { return "Difficult" }
    }

    private var motivationalMessage: (headline: String, subtext: String)? {
        guard let score = actualAverageScore else { return nil }
        if score > 50 {
            return ("今日は調子が良さそう", "気分が上向きです。難しいタスクがあれば、今日こそ取り組む日にしてみては。")
        } else if score > 20 {
            return ("安定した一日", "今日の気分は落ち着いています。小さな積み重ねが大きな成果につながります。")
        } else if score > -20 {
            return ("無理せずに", "ペースを落としても大丈夫。休息と回復も大切な時間です。")
        } else {
            return ("自分を労わって", "つらい日もあります。できることに集中し、必要なら周りに頼ってください。")
        }
    }

    private func motivationalBanner(message: (headline: String, subtext: String)) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.headline)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Text(message.subtext)
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.62))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                scoreColor.opacity(0.06),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }
        )
    }
}
