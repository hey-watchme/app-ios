//
//  OnboardingView.swift
//  ios_watchme_v9
//
//  オンボーディング画面
//  ログアウト時に4ページのオンボーディングを表示
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages = [
        "onboarding-001",
        "onboarding-002",
        "onboarding-003",
        "onboarding-004"
    ]

    var body: some View {
        ZStack {
            // ページコンテンツ
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Image(pages[index])
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .ignoresSafeArea()
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // スキップボタン（最後のページ以外で表示）
            VStack {
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("スキップ")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(20)
                        }
                        .padding(.top, 60)
                        .padding(.trailing, 20)
                    }
                }
                Spacer()
            }

            // 最後のページの「始める」ボタン
            if currentPage == pages.count - 1 {
                VStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("始める")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("AppAccentColor"))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 80)
                }
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
