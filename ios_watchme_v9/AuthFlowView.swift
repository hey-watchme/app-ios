//
//  AuthFlowView.swift
//  ios_watchme_v9
//
//  Onboarding for new visitors. When it ends they enter sample mode directly
//  (no account is created); signing up comes later from the sample-mode banner.
//

import SwiftUI

struct AuthFlowView: View {
    /// Called when the visitor finishes or skips the onboarding.
    let onFinish: () -> Void

    @State private var currentPage = 0

    private let onboardingPages = [
        "onboarding-001",
        "onboarding-002",
        "onboarding-003",
        "onboarding-004",
        "onboarding-005"
    ]

    private var isLastPage: Bool { currentPage == onboardingPages.count - 1 }

    var body: some View {
        ZStack {
            TabView(selection: $currentPage) {
                ForEach(0..<onboardingPages.count, id: \.self) { index in
                    Image(onboardingPages[index])
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
            .ignoresSafeArea()

            // Skip (all pages but the last)
            VStack {
                HStack {
                    Spacer()
                    if !isLastPage {
                        Button(action: onFinish) {
                            Text("スキップ")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(20)
                        }
                        .padding(.trailing, 20)
                    }
                }
                .padding(.top, 8)
                Spacer()
            }

            // Next / start on the last page
            VStack {
                Spacer()
                Button(action: {
                    if isLastPage {
                        onFinish()
                    } else {
                        withAnimation { currentPage += 1 }
                    }
                }) {
                    Text(isLastPage ? "はじめる" : "次へ")
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
        .background(Color.darkBase.ignoresSafeArea())
    }
}

#Preview {
    AuthFlowView(onFinish: {})
}
