//
//  ToastBannerView.swift
//  ios_watchme_v9
//
//  プッシュ通知受信時のトーストバナー
//

import SwiftUI

struct ToastBannerView: View {
    let message: String
    @Binding var isShowing: Bool

    var body: some View {
        VStack {
            if isShowing {
                HStack(spacing: 12) {
                    Text("✨")
                        .font(.system(size: 20))

                    Text(message)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    Color.safeColor("AppAccentColor")
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    // 3秒後に自動で非表示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isShowing = false
                        }
                    }
                }
            }

            Spacer()
        }
        .allowsHitTesting(false) // タップを下のビューに通過させる
    }
}
