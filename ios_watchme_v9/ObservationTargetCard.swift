//
//  ObservationTargetCard.swift
//  ios_watchme_v9
//
//  観測対象専用カードコンポーネント - 紫背景に白文字
//

import SwiftUI

struct ObservationTargetCard<Content: View>: View {
    let title: String
    var navigationLabel: String? = nil
    var onNavigate: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        ZStack {
            // 背景 (紫)
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.safeColor("AppAccentColor")) // #6200ff
            
            VStack(spacing: 24) {
                // ヘッダー部分
                HStack {
                    // タイトル（白文字）
                    Text(title)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    // ナビゲーションリンク（オプション）
                    if let navigationLabel = navigationLabel, let onNavigate = onNavigate {
                        Button(action: onNavigate) {
                            HStack(spacing: 4) {
                                Text(navigationLabel)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.9))
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(.white.opacity(0.2))
                                    .overlay(
                                        Capsule()
                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
                
                // コンテンツ部分
                content()
            }
            .padding(20)
        }
    }
}

// プレビュー用
struct ObservationTargetCard_Previews: PreviewProvider {
    static var previews: some View {
        ObservationTargetCard(
            title: "観測対象"
        ) {
            Text("コンテンツ")
                .foregroundStyle(.white)
        }
        .padding()
        .background(Color.safeColor("BehaviorBackgroundPrimary"))
    }
}