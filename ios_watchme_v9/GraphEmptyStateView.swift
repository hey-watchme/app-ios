//
//  GraphEmptyStateView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/30.
//

import SwiftUI

/// グラフビューのエンプティステート（データなし/デバイス未連携）を表示する共通コンポーネント
struct GraphEmptyStateView: View {
    let graphType: GraphType
    let isDeviceLinked: Bool
    let isCompact: Bool
    
    enum GraphType {
        case vibe       // 心理グラフ
        case behavior   // 行動グラフ
        case emotion    // 感情グラフ
        
        var defaultIcon: String {
            switch self {
            case .vibe:
                return "chart.line.uptrend.xyaxis"
            case .behavior:
                return "chart.bar.doc.horizontal"
            case .emotion:
                return "heart.text.square"
            }
        }
        
        var dataTypeName: String {
            switch self {
            case .vibe:
                return "録音データ"
            case .behavior:
                return "行動データ"
            case .emotion:
                return "感情データ"
            }
        }
    }
    
    init(graphType: GraphType, isDeviceLinked: Bool, isCompact: Bool = false) {
        self.graphType = graphType
        self.isDeviceLinked = isDeviceLinked
        self.isCompact = isCompact
    }
    
    var body: some View {
        VStack(spacing: isCompact ? 12 : 20) {
            // アイコン
            Image(systemName: isDeviceLinked ? graphType.defaultIcon : "iphone.slash")
                .font(isCompact ? .largeTitle : .system(size: 60))
                .foregroundColor(isDeviceLinked ? Color.safeColor("BorderLight").opacity(0.5) : Color.safeColor("WarningColor"))
            
            // メッセージ
            if isCompact {
                // ダッシュボード用の簡潔な表示
                Text(isDeviceLinked ? "データがありません" : "デバイス未連携")
                    .font(.subheadline)
                    .foregroundColor(isDeviceLinked ? .secondary : Color.safeColor("WarningColor"))
            } else {
                // 通常のグラフビュー用の詳細な表示
                VStack(spacing: 8) {
                    Text(isDeviceLinked ? "指定した日付のデータがありません" : "デバイスが連携されていません")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(isDeviceLinked ? 
                        "この日は\(graphType.dataTypeName)が\n収集されていません" : 
                        "ユーザー情報画面から\nデバイスを連携してください")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: isCompact ? 100 : 300)
        .padding(isCompact ? 0 : 50)
    }
}

// MARK: - Preview
struct GraphEmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 通常サイズ - デバイス未連携
            GraphEmptyStateView(graphType: .vibe, isDeviceLinked: false)
                .previewDisplayName("Vibe - No Device")
            
            // 通常サイズ - データなし
            GraphEmptyStateView(graphType: .behavior, isDeviceLinked: true)
                .previewDisplayName("Behavior - No Data")
            
            // コンパクトサイズ - デバイス未連携
            GraphEmptyStateView(graphType: .emotion, isDeviceLinked: false, isCompact: true)
                .previewDisplayName("Emotion - Compact No Device")
                .frame(height: 200)
                .background(Color.safeColor("BorderLight").opacity(0.1))
        }
    }
}