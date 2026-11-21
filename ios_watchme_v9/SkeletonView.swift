//
//  SkeletonView.swift
//  ios_watchme_v9
//
//  Skeleton loading placeholder - Dark theme
//

import SwiftUI

/// What the home shows while the day loads, laid out like the day itself (DayContentView):
/// the score gauge and the day's summary, then the recordings, each with its picture.
struct SkeletonView: View {
    var body: some View {
        VStack(spacing: 16) {
            // The score gauge and the day's summary
            VStack(spacing: 14) {
                SkeletonArc()
                    .frame(width: 280, height: 140)
                    .padding(.top, 40)
                SkeletonRectangle(height: 26, width: 180)
                    .padding(.top, 12)
                SkeletonRectangle(height: 10, width: 140)
                VStack(spacing: 8) {
                    SkeletonRectangle(height: 12, width: nil)
                    SkeletonRectangle(height: 12, width: nil)
                    SkeletonRectangle(height: 12, width: 200)
                }
                .padding(.horizontal, 30)
                .padding(.top, 4)
            }
            .padding(.bottom, 20)

            // The recordings, each with its picture
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        SkeletonRectangle(height: 16, width: 110)
                        SkeletonRectangle(height: 16, width: 36)
                        Spacer()
                        SkeletonRectangle(height: 12, width: 44)
                    }
                    SkeletonRectangle(height: 200, width: nil)
                    SkeletonRectangle(height: 11, width: nil)
                    SkeletonRectangle(height: 11, width: 220)
                }
                .detailCard()
            }
        }
        .padding(.horizontal, 20)
    }
}

/// The outline of the score gauge: a half ring.
private struct SkeletonArc: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            Path { path in
                path.addArc(center: CGPoint(x: width / 2, y: geometry.size.height),
                            radius: width / 2 - 10, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            }
            .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 16, lineCap: .round))
        }
    }
}

struct SkeletonRectangle: View {
    let height: CGFloat
    let width: CGFloat?
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.04),
                        Color.white.opacity(0.08),
                        Color.white.opacity(0.04)
                    ]),
                    startPoint: isAnimating ? .leading : .trailing,
                    endPoint: isAnimating ? .trailing : .leading
                )
            )
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

#Preview {
    SkeletonView()
        .background(Color.darkBase)
}
