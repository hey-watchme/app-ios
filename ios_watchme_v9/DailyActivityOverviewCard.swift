//
//  DailyActivityOverviewCard.swift
//  ios_watchme_v9
//
//  Today's recording count against a target (dashboard)
//

import SwiftUI

// MARK: - Daily Activity Overview (Oura Habits-style comparison bars)

struct DailyActivityOverviewCard: View {
    let analysisCount: Int
    let targetCount: Int  // e.g. 48 for Observer, 24 for typical day

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Activity")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(white: 0.45))

            // Comparison bars (Oura Activity Burn style)
            VStack(spacing: 10) {
                comparisonBar(label: "Today", value: analysisCount, color: .accentTeal)
                comparisonBar(label: "Target", value: targetCount, color: Color.white.opacity(0.15))
            }

            // Supported areas pills
            HStack(spacing: 8) {
                Text("Supported areas")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(white: 0.36))

                HStack(spacing: 6) {
                    areaPill("Behavior", color: .accentTeal)
                    areaPill("Emotion", color: .accentTealMuted)
                    areaPill("Vibe", color: .accentTeal)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 2)
        )
    }

    private func comparisonBar(label: String, value: Int, color: Color) -> some View {
        let maxVal = max(analysisCount, targetCount, 1)
        let progress = Double(value) / Double(maxVal)

        return HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(white: 0.56))
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * min(progress, 1), height: 8)
                }
            }
            .frame(height: 8)

            Text("\(value)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private func areaPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .cornerRadius(8)
    }
}
