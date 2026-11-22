//
//  ModernHeroGaugeView.swift
//  ios_watchme_v9
//
//  Oura-style large hero arc gauge for daily summary.
//

import SwiftUI

struct ModernHeroGaugeView: View {
    let dashboardSummary: DashboardSummary?
    /// A recording of the day is being analysed: the day's Vibe is on its way.
    var isAnalysing = false
    /// What the arc shows; moves to the score with an animation, from 0 on first appearance
    /// and from the old value when a new one arrives.
    @State private var shownFraction: Double = 0
    
    private var vibeScore: Double {
        if let s = dashboardSummary?.averageVibe { return Double(s) }
        return 0
    }
    
    private var normalizedScore: Double {
        return min(max((vibeScore + 100) / 200, 0), 1)
    }
    
    private var scoreColor: Color {
        if dashboardSummary == nil { return Color(white: 0.3) }
        return Color.vibeScoreColor(for: vibeScore)
    }
    
    private var gaugeLabel: String {
        guard dashboardSummary != nil else { return "--" }
        return String(format: "%.0f", vibeScore)
    }
    
    private var insightTitle: String {
        guard dashboardSummary != nil else { return isAnalysing ? "Analysing" : "No Recordings Yet" }
        if vibeScore > 50 { return "Radiant Energy" }
        else if vibeScore > 20 { return "Steady & Clear" }
        else if vibeScore > -20 { return "Finding Balance" }
        else { return "Needs Care" }
    }
    
    /// The day's summary as the analysis wrote it. Nothing made up when it has none: the
    /// fixed English lines that used to stand in were not based on any measurement.
    private var insightText: String {
        if let text = dashboardSummary?.insights, !text.isEmpty {
            return text
        }
        guard dashboardSummary != nil else {
            if isAnalysing {
                return "The recording is being analysed. The day's Vibe and what happened will appear here."
            }
            return "Record a moment at home with the button below. The day's Vibe and what happened will appear here."
        }
        return ""
    }

    var body: some View {
        ZStack {
            // Ambient glow background based on score
            RadialGradient(
                colors: [scoreColor.opacity(0.15), Color.clear],
                center: .top,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // The big arch gauge
                ZStack {
                    // Track Arc
                    ArcShape()
                        .stroke(Color.white.opacity(0.05), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 280, height: 140)
                    
                    // Progress Arc
                    ArcShape()
                        .trim(from: 0, to: CGFloat(shownFraction))
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 280, height: 140)
                        .shadow(color: scoreColor.opacity(0.6), radius: 8, x: 0, y: 0)
                    
                    // Center content
                    VStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.8))
                            .opacity(vibeScore > 50 ? 1 : 0)
                            .padding(.bottom, 4)
                        
                        Text(gaugeLabel)
                            .font(.system(size: 64, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            // The digits roll from the old value to the new one
                            .contentTransition(.numericText(value: vibeScore))
                            .animation(.easeOut(duration: 1.0), value: gaugeLabel)
                        
                        Text("VIBE SCORE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(white: 0.5))
                            .tracking(2.0)
                    }
                    .offset(y: 20)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                // Insights section
                VStack(spacing: 12) {
                    Text(insightTitle)
                        .font(.custom("Georgia", size: 28)) // Using a serif font for an elegant editorial look
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.5), value: insightTitle)
                    
                    // The summary is rebuilt after every recording: the day so far, not a finished day
                    if let count = dashboardSummary?.processedCount, count > 0 {
                        Text("\(SpotStage.dayAnalysisLabel(for: dashboardSummary?.date))・\(count) 件の録音から")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(white: 0.45))
                            .tracking(0.5)
                    }

                    if !insightText.isEmpty {
                    Text(insightText)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(white: 0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 30)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.5), value: insightText)
                    }
                }
                
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).delay(0.2)) {
                shownFraction = dashboardSummary == nil ? 0 : normalizedScore
            }
        }
        .onChange(of: dashboardSummary == nil ? -1 : normalizedScore) { _, _ in
            // A new value: the meter moves from where it is to the new score
            withAnimation(.easeOut(duration: 1.2)) {
                shownFraction = dashboardSummary == nil ? 0 : normalizedScore
            }
        }
    }
}

// Helper shape for the arch
struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: rect.width / 2,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        return path
    }
}
