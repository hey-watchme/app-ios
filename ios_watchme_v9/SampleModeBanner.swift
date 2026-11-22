//
//  SampleModeBanner.swift
//  ios_watchme_v9
//
//  Banner above the footer while the sample is shown. Signed-out visitors
//  (sample mode) get a "使い始める" button that opens the sign-up sheet; signed-in
//  users who opened the sample can go back to their own record.
//

import SwiftUI

struct SampleModeBanner: View {
    let isGuest: Bool
    let onPrimary: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.accentTeal)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.accentTeal.opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text("サンプルを表示中")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("分析結果は架空の人物です")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Button(action: onPrimary) {
                Text(isGuest ? "使い始める" : "自分の記録へ")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.darkBase)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Capsule().fill(Color.accentTeal))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: 460)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.darkSurface.opacity(0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.accentTeal.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 8)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.darkBase.ignoresSafeArea()
        SampleModeBanner(isGuest: true, onPrimary: {})
            .padding(16)
    }
}
