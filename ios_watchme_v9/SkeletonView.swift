//
//  SkeletonView.swift
//  ios_watchme_v9
//
//  Skeleton loading placeholder for dashboard
//

import SwiftUI

struct SkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 20) {
            // Vibe card skeleton
            VStack(alignment: .leading, spacing: 12) {
                SkeletonRectangle(height: 24, width: 100)
                SkeletonRectangle(height: 120, width: nil)
                HStack(spacing: 8) {
                    SkeletonRectangle(height: 12, width: 60)
                    SkeletonRectangle(height: 12, width: 60)
                    SkeletonRectangle(height: 12, width: 60)
                }
            }
            .padding()
            .background(Color.safeColor("CardBackground"))
            .cornerRadius(16)
            .padding(.horizontal, 20)

            // Spot analysis skeleton
            VStack(alignment: .leading, spacing: 16) {
                SkeletonRectangle(height: 24, width: 120)

                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SkeletonRectangle(height: 14, width: 60)
                            Spacer()
                            SkeletonRectangle(height: 14, width: 40)
                        }
                        SkeletonRectangle(height: 12, width: nil)
                        SkeletonRectangle(height: 12, width: 200)
                    }
                    .padding()
                    .background(Color.safeColor("CardBackground"))
                    .cornerRadius(12)
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
                        Color.safeColor("BorderLight").opacity(0.3),
                        Color.safeColor("BorderLight").opacity(0.5),
                        Color.safeColor("BorderLight").opacity(0.3)
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
        .background(Color.safeColor("BehaviorBackgroundPrimary"))
}
