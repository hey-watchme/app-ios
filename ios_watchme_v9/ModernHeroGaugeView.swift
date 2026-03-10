//
//  ModernHeroGaugeView.swift
//  ios_watchme_v9
//
//  Oura-style large hero arc gauge for daily summary.
//

import SwiftUI

struct ModernHeroGaugeView: View {
    let dashboardSummary: DashboardSummary?
    @State private var appearAnimation = false
    
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
        guard dashboardSummary != nil else { return "No Data Yet" }
        if vibeScore > 50 { return "Radiant Energy" }
        else if vibeScore > 20 { return "Steady & Clear" }
        else if vibeScore > -20 { return "Finding Balance" }
        else { return "Needs Care" }
    }
    
    private var insightText: String {
        if let text = dashboardSummary?.insights, !text.isEmpty {
            return text
        }
        guard dashboardSummary != nil else {
            return "Wear your device to start capturing your daily Vibe and behavior insights."
        }
        if vibeScore > 20 {
            return "Your psychological state is remarkably positive today. Keep engaging in the activities that bring you this clarity."
        } else {
            return "It looks like today has some challenging moments. Remember to take a step back and breathe when needed."
        }
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
                        .trim(from: 0, to: appearAnimation ? CGFloat(normalizedScore) : 0)
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
                    
                    Text(insightText)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(white: 0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 30)
                }
                
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).delay(0.2)) {
                appearAnimation = true
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
