//
//  VitalsRangeCard.swift
//  ios_watchme_v9
//
//  A vitals card that shows a metric against an optimal range zone.
//

import SwiftUI

struct VitalsRangeCard: View {
    let title: String
    let value: Double
    let maxValue: Double
    let label: String
    let optimalRange: (Double, Double) // 0.0 - 1.0 percentages
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 20) {
            // Header Row
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                    
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(white: 0.8))
                }
                
                Spacer()
                
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
                    .tracking(1.0)
            }
            
            // Score Row
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.0f", value))
                    .font(.system(size: 40, weight: .medium, design: .serif))
                    .foregroundColor(.white)
                Text("/ \(Int(maxValue))")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(white: 0.5))
                Spacer()
            }
            
            // Range Slider
            VStack(spacing: 8) {
                GeometryReader { geo in
                    let w = geo.size.width
                    let progress = min(value / maxValue, 1.0)
                    
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 6)
                        
                        // Optimal zone indicator
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: w * (optimalRange.1 - optimalRange.0), height: 6)
                            .offset(x: w * optimalRange.0)
                        
                        // Current value line
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .frame(width: w * progress, height: 6)
                        
                        // Current value dot
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle().stroke(color, lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.4), radius: 3)
                            .offset(x: w * progress - 7)
                    }
                }
                .frame(height: 14)
                
                // Axis labels
                HStack {
                    Text("0")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.4))
                    Spacer()
                    Text("Optimal")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(white: 0.6))
                    Spacer()
                    Text("\(Int(maxValue))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.4))
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 4)
        )
    }
}
