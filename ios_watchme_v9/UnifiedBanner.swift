//
//  UnifiedBanner.swift
//  ios_watchme_v9
//
//  統一バナーコンポーネント
//  プッシュ通知と録音タスクの両方で使用する共通バナー
//

import SwiftUI

// MARK: - BannerStyle（バナーの種類）
enum BannerStyle {
    case simple(message: String, icon: String?)  // プッシュ通知用（シンプル）
    case detailed(title: String, subtitle: String?, icon: String, iconColor: Color, progress: Double?)  // 録音タスク用（詳細）
}

// MARK: - UnifiedBanner
struct UnifiedBanner: View {
    let style: BannerStyle
    @Binding var isShowing: Bool
    let autoDismiss: Bool  // 自動非表示するか

    init(style: BannerStyle, isShowing: Binding<Bool>, autoDismiss: Bool = true) {
        self.style = style
        self._isShowing = isShowing
        self.autoDismiss = autoDismiss
    }

    var body: some View {
        VStack {
            if isShowing {
                bannerContent
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        if autoDismiss {
                            // 8秒後に自動で非表示
                            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isShowing = false
                                }
                            }
                        }
                    }
            }
            Spacer()
        }
        .allowsHitTesting(false)  // タップを下のビューに通過させる
    }

    @ViewBuilder
    private var bannerContent: some View {
        switch style {
        case .simple(let message, let icon):
            simpleBanner(message: message, icon: icon)
        case .detailed(let title, let subtitle, let icon, let iconColor, let progress):
            detailedBanner(title: title, subtitle: subtitle, icon: icon, iconColor: iconColor, progress: progress)
        }
    }

    // MARK: - Simple Banner（プッシュ通知用）
    private func simpleBanner(message: String, icon: String?) -> some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color.safeColor("PrimaryActionColor"))
            }

            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Detailed Banner（録音タスク用）
    private func detailedBanner(title: String, subtitle: String?, icon: String, iconColor: Color, progress: Double?) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }

            // プログレスバー（送信中のみ）
            if let progress = progress {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Preview
#Preview("Simple Banner") {
    VStack {
        UnifiedBanner(
            style: .simple(message: "新しい通知が届きました", icon: "bell.fill"),
            isShowing: .constant(true)
        )
        Spacer()
    }
    .background(Color.gray.opacity(0.2))
}

#Preview("Detailed Banner - Uploading") {
    VStack {
        UnifiedBanner(
            style: .detailed(
                title: "送信中...",
                subtitle: "2024-01-01/14-30.wav",
                icon: "arrow.up.circle.fill",
                iconColor: .blue,
                progress: 0.6
            ),
            isShowing: .constant(true),
            autoDismiss: false
        )
        Spacer()
    }
    .background(Color.gray.opacity(0.2))
}

#Preview("Detailed Banner - Success") {
    VStack {
        UnifiedBanner(
            style: .detailed(
                title: "送信完了",
                subtitle: "分析結果をお待ちください",
                icon: "checkmark.circle.fill",
                iconColor: .green,
                progress: nil
            ),
            isShowing: .constant(true)
        )
        Spacer()
    }
    .background(Color.gray.opacity(0.2))
}
