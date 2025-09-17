//
//  UnifiedCard.swift
//  ios_watchme_v9
//
//  統一されたカードコンポーネント - ミニマルでクリーンなデザイン
//

import SwiftUI

struct UnifiedCard<Content: View>: View {
    let title: String
    var navigationLabel: String? = nil
    var onNavigate: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        ZStack {
            // 背景 (白)
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
            
            // 軽い境界線
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.safeColor("BorderLight").opacity(0.1), lineWidth: 1)
            
            VStack(spacing: 24) {
                // ヘッダー部分
                HStack {
                    // タイトル（アイコンなし）
                    Text(title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.safeColor("BehaviorTextPrimary")) // #1a1a1a
                    
                    Spacer()
                }
                
                // コンテンツ部分
                content()
                
                // ナビゲーションリンク（右下に配置）
                if let navigationLabel = navigationLabel, let onNavigate = onNavigate {
                    HStack {
                        Spacer()
                        
                        Button(action: onNavigate) {
                            HStack(spacing: 4) {
                                Text(navigationLabel)
                                    .font(.caption)
                                    .foregroundStyle(Color.safeColor("BehaviorTextSecondary")) // #666666
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(Color.safeColor("BehaviorTextSecondary")) // #666666
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.safeColor("BorderLight").opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.safeColor("BorderLight").opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .allowsHitTesting(false) // タップイベントを透過させる
                    }
                }
            }
            .padding(16)  // 内側の余白を16pxに変更
        }
    }
}

// プレビュー用
struct UnifiedCard_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedCard(
            title: "サンプル",
            navigationLabel: "詳細へ",
            onNavigate: { }
        ) {
            Text("コンテンツ")
        }
        .padding()
        .background(Color.safeColor("BehaviorBackgroundPrimary"))
    }
}