//
//  SkeletonView.swift
//  ios_watchme_v9
//
//  Skeleton loading placeholder - Dark theme
//

import SwiftUI

struct SkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 20) {
            // Metrics bar skeleton
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonRectangle(height: 56, width: 120)
                        .cornerRadius(22)
                }
            }
            .padding(.horizontal, 20)

            // Vibe card skeleton
            VStack(alignment: .leading, spacing: 12) {
                SkeletonRectangle(height: 20, width: 80)
                SkeletonRectangle(height: 140, width: nil)
                HStack(spacing: 8) {
                    SkeletonRectangle(height: 10, width: 50)
                    SkeletonRectangle(height: 10, width: 50)
                    SkeletonRectangle(height: 10, width: 50)
                }
            }
            .padding(20)
            .background(Color.darkCard)
            .cornerRadius(20)
            .padding(.horizontal, 20)

            // Spot analysis skeleton
            VStack(alignment: .leading, spacing: 16) {
                SkeletonRectangle(height: 20, width: 100)

                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SkeletonRectangle(height: 12, width: 50)
                            Spacer()
                            SkeletonRectangle(height: 12, width: 36)
                        }
                        SkeletonRectangle(height: 10, width: nil)
                        SkeletonRectangle(height: 10, width: 180)
                    }
                    .padding(16)
                    .background(Color.darkCard)
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
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
