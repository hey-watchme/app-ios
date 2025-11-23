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
                    .fill(Color.accentPurple)
                    .frame(width: size, height: size)
                    .shadow(color: Color.accentPurple.opacity(0.4), radius: 8, x: 0, y: 4)

                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
}
