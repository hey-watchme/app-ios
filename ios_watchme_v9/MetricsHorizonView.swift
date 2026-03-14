//
//  MetricsHorizonView.swift
//  ios_watchme_v9
//
//  Oura-style horizontal metric pills for the top of the dashboard.
//

import SwiftUI

struct HorizonMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let caption: String
    let progress: Double // 0.0 - 1.0
    let color: Color
    let icon: String
}

struct MetricsHorizonView: View {
    let vibeScore: Double?
    let activityCount: Int
    
    // Compute the metrics to show
    private var metrics: [HorizonMetric] {
        var items: [HorizonMetric] = []
        
        // 1. Vibe (Readiness equivalent)
        let vibeVal = vibeScore ?? 0.0
        let normVibe = min(max((vibeVal + 100) / 200, 0), 1)
        items.append(HorizonMetric(
            title: "Vibe",
            value: String(format: "%.0f", vibeVal),
            caption: vibeVal > 50 ? "OPTIMAL" : (vibeVal > 0 ? "GOOD" : "NEEDS CARE"),
            progress: normVibe,
            color: Color.vibeScoreColor(for: vibeVal),
            icon: "waveform.path.ecg"
        ))
        
        // 2. Engagement (Activity equivalent)
        let engagementProg = min(Double(activityCount) / 24.0, 1.0)
        items.append(HorizonMetric(
            title: "Engagement",
            value: "\(activityCount)",
            caption: activityCount > 10 ? "ACTIVE" : "QUIET",
            progress: engagementProg,
            color: Color(white: 0.8), // subtle color
            icon: "person.2.wave.2"
        ))
        
        // 3. Stress 
        let stressVal = vibeScore.map { max(10, min(90, 50 - $0 * 0.4)) } ?? 30.0
        items.append(HorizonMetric(
            title: "Stress",
            value: String(format: "%.0f", stressVal),
            caption: stressVal < 40 ? "LOW" : "ELEVATED",
            progress: stressVal / 100.0,
            color: stressVal < 40 ? .accentTeal : .accentTealMuted,
            icon: "heart.text.square"
        ))
        
        return items
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(metrics) { metric in
                    PillCard(metric: metric)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
}

private struct PillCard: View {
    let metric: HorizonMetric
    
    var body: some View {
        HStack(spacing: 14) {
            // Circular progress indicator
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 2)
                    .frame(width: 44, height: 44)
                
                Circle()
                    .trim(from: 0, to: metric.progress)
                    .stroke(metric.color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 44, height: 44)
                
                Text(metric.value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            // Text area
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: metric.icon)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(metric.color.opacity(0.8))
                    Text(metric.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(white: 0.6))
                }
                
                Text(metric.caption)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(metric.color)
                    .tracking(0.5)
            }
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
        )
    }
}
