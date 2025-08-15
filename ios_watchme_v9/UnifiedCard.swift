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
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            // 軽い境界線
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            
            VStack(spacing: 24) {
                // ヘッダー部分
                HStack {
                    // タイトル（アイコンなし）
                    Text(title)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1)) // #1a1a1a
                    
                    Spacer()
                    
                    // ナビゲーションリンク（オプション）
                    if let navigationLabel = navigationLabel, let onNavigate = onNavigate {
                        Button(action: onNavigate) {
                            HStack(spacing: 4) {
                                Text(navigationLabel)
                                    .font(.caption)
                                    .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4)) // #666666
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4)) // #666666
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.gray.opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .allowsHitTesting(false) // タップイベントを透過させる
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
        .background(Color(red: 0.937, green: 0.937, blue: 0.937))
    }
}