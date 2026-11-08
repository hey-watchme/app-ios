//
//  StageProgressRow.swift
//  ios_watchme_v9
//
//  A row of chips, one per analysis stage, showing how far a recording has got.
//

import SwiftUI

struct StageProgressRow: View {
    let stages: [SpotStage]
    var compact: Bool = false

    var body: some View {
        let ordered = stages.ordered
        return VStack(alignment: .leading, spacing: 6) {
            if !compact {
                Text(stages.isInProgress ? "分析中" : "分析の記録")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(white: 0.45))
                    .tracking(0.8)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ordered) { stage in
                        chip(stage)
                    }
                }
            }
            if !compact {
                ForEach(ordered.filter { $0.status == "failed" }) { failed in
                    Text("\(failed.label): \(failed.error ?? "失敗")")
                        .font(.system(size: 10))
                        .foregroundColor(.accentCoral)
                        .lineLimit(2)
                }
            }
        }
    }

    private func chip(_ stage: SpotStage) -> some View {
        HStack(spacing: 4) {
            icon(stage.status)
            Text(stage.label)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(color(stage.status))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color(stage.status).opacity(0.12)))
    }

    @ViewBuilder
    private func icon(_ status: String) -> some View {
        switch status {
        case "running":
            ProgressView().scaleEffect(0.5).frame(width: 10, height: 10).tint(.accentTeal)
        case "completed":
            Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
        case "failed":
            Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
        case "skipped":
            Image(systemName: "minus").font(.system(size: 8, weight: .bold))
        default:
            Circle().frame(width: 5, height: 5)
        }
    }

    private func color(_ status: String) -> Color {
        switch status {
        case "running": return .accentTeal
        case "completed": return .accentTealMuted
        case "failed": return .accentCoral
        case "skipped": return Color(white: 0.45)
        default: return Color(white: 0.35)
        }
    }
}
