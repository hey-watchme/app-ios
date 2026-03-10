//
//  UnifiedCard.swift
//  ios_watchme_v9
//
//  Unified card component - Dark theme
//

import SwiftUI

struct UnifiedCard<Content: View>: View {
    let title: String
    var navigationLabel: String? = nil
    var onNavigate: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.darkCard)

            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)

            VStack(spacing: 24) {
                HStack {
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()
                }

                content()

                if let navigationLabel = navigationLabel, let onNavigate = onNavigate {
                    HStack {
                        Spacer()

                        Button(action: onNavigate) {
                            HStack(spacing: 4) {
                                Text(navigationLabel)
                                    .font(.caption)
                                    .foregroundStyle(Color(white: 0.56))
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(Color(white: 0.56))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.06))
                            )
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
            .padding(16)
        }
    }
}

struct UnifiedCard_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedCard(
            title: "Sample",
            navigationLabel: "Details",
            onNavigate: { }
        ) {
            Text("Content")
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.darkBase)
    }
}
