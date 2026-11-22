//
//  SampleModeIntroView.swift
//  ios_watchme_v9
//
//  Modal over the sample when a signed-out visitor first enters sample mode. They
//  either look at the sample on purpose or go straight to sign-up.
//

import SwiftUI

struct SampleModeIntroView: View {
    let onView: () -> Void
    let onStart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(Color.accentTeal)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.accentTeal.opacity(0.14)))

                Text("サンプルモード")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.top, 14)

                Text("架空の人物の分析結果で、WatchMe でできることを見られます。録音や設定はできません。")
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.70))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                VStack(spacing: 12) {
                    Button(action: onView) {
                        Text("サンプルモードを見る")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.accentTeal)
                            .foregroundColor(Color.darkBase)
                            .cornerRadius(12)
                    }

                    Button(action: onStart) {
                        Text("使い始める")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.darkElevated)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    }
                }
                .padding(.top, 22)
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.darkSurface)
            )
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    SampleModeIntroView(onView: {}, onStart: {})
}
