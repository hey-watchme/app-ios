//
//  SampleModeBanner.swift
//  ios_watchme_v9
//
//  Banner above the footer while the demo device is shown. Signed-out visitors
//  (sample mode) get a "使い始める" button that opens the sign-up sheet; signed-in
//  users who still have the sample linked can go back to their own device.
//

import SwiftUI

struct SampleModeBanner: View {
    let isGuest: Bool
    let subjectName: String?
    let onPrimary: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.accentTeal)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.accentTeal.opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text(isGuest ? "ゲストモード・サンプルを表示中" : "これはサンプルデバイスです")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.66))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
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

    private var detail: String {
        let name = (subjectName?.isEmpty == false) ? "\(subjectName!)さん" : "架空の子ども"
        return "\(name)（架空）の記録です"
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.darkBase.ignoresSafeArea()
        SampleModeBanner(isGuest: true, subjectName: "田中みなと", onPrimary: {})
            .padding(16)
    }
}
