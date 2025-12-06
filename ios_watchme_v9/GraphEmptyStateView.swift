//
//  GraphEmptyStateView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/30.
//

import SwiftUI

/// グラフビューのエンプティステート（データなし）を表示する共通コンポーネント
struct GraphEmptyStateView: View {
    let graphType: GraphType
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

    init(graphType: GraphType, isCompact: Bool = false) {
        self.graphType = graphType
        self.isCompact = isCompact
    }
    
    var body: some View {
        if isCompact {
            // ダッシュボード用: ModernVibeCardと同じフォーマット
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    // 絵文字（無表情）
                    Text("😑")
                        .font(.system(size: 108))

                    // ステータステキスト（黒・太字・20px）
                    Text("NO DATA")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.safeColor("BehaviorTextPrimary"))
                        .textCase(.uppercase)
                        .tracking(1.0)

                    // スコア表示（-- pt）
                    HStack(spacing: 4) {
                        Text("気分")
                            .font(.caption2)
                            .foregroundStyle(Color.safeColor("BehaviorTextSecondary"))

                        Text("-- pt")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.gray.opacity(0.8))
                    }
                }
                .padding(.bottom, 24)

                // 空のグラフエリア（薄いグレーの背景）
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.safeColor("BorderLight").opacity(0.05))
                    .frame(height: 120)

                // サマリーテキスト（同じフォーマット）
                Text("この日の分析データが存在しないようです。")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.safeColor("BehaviorTextPrimary"))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(18 * 0.6)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
            }
        } else {
            // 通常のグラフビュー用の詳細な表示
            VStack(spacing: 8) {
                Text("指定した日付のデータがありません")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("この日は\(graphType.dataTypeName)が\n収集されていません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 300)
            .padding(.all, 50)
        }
    }

    private var emptyStateTitle: String {
        switch graphType {
        case .vibe:
            return "現在データがありません"
        case .behavior:
            return "行動データがありません"
        case .emotion:
            return "感情データがありません"
        }
    }

    private var emptyStateMessage: String {
        switch graphType {
        case .vibe:
            return "音声情報から、あなたの気分や今日の出来事を分析してみましょう"
        case .behavior:
            return "録音することで、行動パターンを分析できます"
        case .emotion:
            return "録音することで、感情の変化を分析できます"
        }
    }
}

/// デバイス未選択状態を表示するビュー
struct DeviceNotSelectedView: View {
    let graphType: GraphEmptyStateView.GraphType
    let isCompact: Bool

    init(graphType: GraphEmptyStateView.GraphType, isCompact: Bool = false) {
        self.graphType = graphType
        self.isCompact = isCompact
    }

    var body: some View {
        VStack(spacing: isCompact ? 16 : 20) {
            // アイコン
            Image(systemName: "square.stack.3d.up.slash")
                .font(isCompact ? .largeTitle : .system(size: 60))
                .foregroundColor(Color.safeColor("BorderLight").opacity(0.5))

            // メッセージ
            VStack(spacing: 8) {
                Text("デバイスが選択されていません")
                    .font(isCompact ? .subheadline : .headline)
                    .fontWeight(isCompact ? .medium : .regular)
                    .foregroundColor(.primary)

                if !isCompact {
                    Text("デバイス選択画面から\nデバイスを選択してください")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: isCompact ? 120 : 300)
        .padding(isCompact ? .vertical : .all, isCompact ? 20 : 50)
    }
}

// MARK: - Preview
struct GraphEmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 通常サイズ - データなし
            GraphEmptyStateView(graphType: .vibe)
                .previewDisplayName("Vibe - No Data")

            // コンパクトサイズ - データなし
            GraphEmptyStateView(graphType: .behavior, isCompact: true)
                .previewDisplayName("Behavior - Compact No Data")
                .frame(height: 200)
                .background(Color.safeColor("BorderLight").opacity(0.1))

            // デバイス未選択
            DeviceNotSelectedView(graphType: .emotion)
                .previewDisplayName("Device Not Selected")

            // デバイス未選択 - コンパクト
            DeviceNotSelectedView(graphType: .vibe, isCompact: true)
                .previewDisplayName("Device Not Selected - Compact")
                .frame(height: 200)
                .background(Color.safeColor("BorderLight").opacity(0.1))
        }
    }
}