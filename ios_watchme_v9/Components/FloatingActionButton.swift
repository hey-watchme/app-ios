//
//  FloatingActionButton.swift
//  ios_watchme_v9
//
//  Reusable FAB component
//

import SwiftUI

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    var size: CGFloat = 56
    var iconSize: CGFloat = 24

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.darkCard)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.accentTeal.opacity(0.8), Color.accentTeal.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: Color.accentTeal.opacity(0.3), radius: 10, x: 0, y: 4)

                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(.white)
                    .foregroundColor(.white)
            }
        }
    }
}
