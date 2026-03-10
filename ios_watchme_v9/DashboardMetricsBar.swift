//
//  DashboardMetricsBar.swift
//  ios_watchme_v9
//
//  Horizontal scrollable metrics pills (Oura-style, refined details)
//

import SwiftUI

// MARK: - Metric Pill Data

struct MetricPill: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let progress: Double  // 0.0 - 1.0
    let color: Color
    let icon: String
    let optimalRange: (Double, Double)?  // optional optimal zone (start, end) 0-1
}

// MARK: - Dashboard Metrics Bar

struct DashboardMetricsBar: View {
    let averageVibe: Float?
    let timeBlockCount: Int

    private var pills: [MetricPill] {
        var result: [MetricPill] = []

        // Vibe Score (real data)
        if let vibe = averageVibe {
            let normalized = min(max((Double(vibe) + 100) / 200, 0), 1)
            result.append(MetricPill(
                label: "Vibe",
                value: String(format: "%.0f", vibe),
                progress: normalized,
                color: Color.vibeScoreColor(for: Double(vibe)),
                icon: "waveform.path.ecg",
                optimalRange: (0.45, 0.75)
            ))
        }

        // Mock: Stress Level (inverse of vibe for realism)
        let stressValue = averageVibe.map { max(10, min(90, 50 - Double($0) * 0.4)) } ?? 42.0
        result.append(MetricPill(
            label: "Stress",
            value: String(format: "%.0f", stressValue),
            progress: stressValue / 100,
            color: stressValue < 40 ? .accentEmerald : (stressValue < 65 ? .accentAmber : .accentCoral),
            icon: "heart.text.square",
            optimalRange: (0, 0.4)
        ))

        // Mock: Focus Score
        let focusValue = averageVibe.map { max(20, min(95, 60 + Double($0) * 0.3)) } ?? 72.0
        result.append(MetricPill(
            label: "Focus",
            value: String(format: "%.0f", focusValue),
            progress: focusValue / 100,
            color: .accentTeal,
            icon: "brain.head.profile",
            optimalRange: (0.55, 0.85)
        ))

        // Activity (real: number of analysis blocks)
        if timeBlockCount > 0 {
            let activityProgress = min(Double(timeBlockCount) / 24.0, 1.0)
            result.append(MetricPill(
                label: "Activity",
                value: "\(timeBlockCount)",
                progress: activityProgress,
                color: Color(red: 0.35, green: 0.68, blue: 1.0),
                icon: "chart.bar.fill",
                optimalRange: (0.2, 0.8)
            ))
        }

        return result
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(pills) { pill in
                    metricPillView(pill)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func metricPillView(_ pill: MetricPill) -> some View {
        HStack(spacing: 12) {
            // Circular progress ring with optimal range indicator
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 2.5)
                    .frame(width: 40, height: 40)

                // Optimal range arc (subtle)
                if let range = pill.optimalRange {
                    Circle()
                        .trim(from: range.0, to: range.1)
                        .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 40, height: 40)
                }

                Circle()
                    .trim(from: 0, to: pill.progress)
                    .stroke(pill.color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 40, height: 40)

                Text(pill.value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: pill.icon)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(pill.color.opacity(0.8))
                    Text(pill.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(white: 0.45))
                }

                statusLabel(for: pill)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 2)
        )
    }

    private func statusLabel(for pill: MetricPill) -> some View {
        let (text, color) = statusInfo(for: pill)
        return Text(text.uppercased())
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(color)
            .tracking(0.6)
    }

    private func statusInfo(for pill: MetricPill) -> (String, Color) {
        switch pill.label {
        case "Vibe":
            if pill.progress > 0.65 { return ("Good", .accentEmerald) }
            if pill.progress > 0.45 { return ("Neutral", Color(white: 0.50)) }
            return ("Low", .accentAmber)
        case "Stress":
            if pill.progress < 0.35 { return ("Low", .accentEmerald) }
            if pill.progress < 0.60 { return ("Moderate", .accentAmber) }
            return ("High", .accentCoral)
        case "Focus":
            if pill.progress > 0.70 { return ("Sharp", .accentTeal) }
            if pill.progress > 0.45 { return ("Normal", Color(white: 0.50)) }
            return ("Low", .accentAmber)
        case "Activity":
            if pill.progress > 0.50 { return ("Active", Color(red: 0.35, green: 0.68, blue: 1.0)) }
            return ("Light", Color(white: 0.50))
        default:
            return ("--", Color(white: 0.50))
        }
    }
}

// MARK: - Stress Gauge (Oura Vitals-style with range zones)

struct StressGaugeCard: View {
    let stressLevel: Double

    private var stressColor: Color {
        if stressLevel < 35 { return .accentEmerald }
        if stressLevel < 60 { return .accentAmber }
        return .accentCoral
    }

    private var stressLabel: String {
        if stressLevel < 35 { return "LOW" }
        if stressLevel < 60 { return "MODERATE" }
        return "HIGH"
    }

    // Optimal range: 0-40 (green zone)
    private let optimalStart: Double = 0
    private let optimalEnd: Double = 40

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cumulative Stress")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(white: 0.45))

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%.0f", stressLevel))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("/ 100")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(white: 0.36))
                    }
                }

                Spacer()

                Text(stressLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(stressColor)
                    .tracking(0.8)
            }

            // Vitals-style horizontal slider with range zones
            VStack(spacing: 12) {
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 6)

                        // Optimal zone (0-40)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.accentEmerald.opacity(0.15))
                            .frame(width: w * optimalEnd / 100, height: 6)

                        // Fill (current value)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(stressColor)
                            .frame(width: w * min(stressLevel / 100, 1), height: 6)

                        // Indicator dot (Oura-style)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(stressColor, lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 2)
                            .offset(x: w * min(stressLevel / 100, 1) - 6)
                    }
                }
                .frame(height: 12)

                // Range labels
                HStack {
                    Text("0")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.32))
                    Spacer()
                    Text("Optimal")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color.accentEmerald.opacity(0.8))
                    Spacer()
                    Text("100")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.32))
                }
            }

            // Sub-metrics (refined layout)
            HStack(spacing: 0) {
                subMetric(label: "Recovery", value: stressLevel < 50 ? "Good" : "Needs rest", color: stressLevel < 50 ? .accentEmerald : .accentAmber)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1, height: 28)
                Spacer()
                subMetric(label: "Balance", value: stressLevel < 40 ? "Balanced" : "Unbalanced", color: stressLevel < 40 ? .accentTeal : .accentAmber)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1, height: 28)
                Spacer()
                subMetric(label: "Trend", value: "Stable", color: Color(white: 0.56))
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
                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 3)
        )
    }

    private func subMetric(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Color(white: 0.32))
                .tracking(0.5)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

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
                    areaPill("Emotion", color: .accentAmber)
                    areaPill("Vibe", color: .accentEmerald)
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
