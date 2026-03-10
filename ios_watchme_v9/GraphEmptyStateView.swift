//
//  GraphEmptyStateView.swift
//  ios_watchme_v9
//
//  Empty state views - Dark theme
//

import SwiftUI

struct GraphEmptyStateView: View {
    let graphType: GraphType
    let isCompact: Bool

    enum GraphType {
        case vibe
        case behavior
        case emotion

        var defaultIcon: String {
            switch self {
            case .vibe: return "chart.line.uptrend.xyaxis"
            case .behavior: return "chart.bar.doc.horizontal"
            case .emotion: return "heart.text.square"
            }
        }

        var dataTypeName: String {
            switch self {
            case .vibe: return "recording"
            case .behavior: return "behavior"
            case .emotion: return "emotion"
            }
        }
    }

    init(graphType: GraphType, isCompact: Bool = false) {
        self.graphType = graphType
        self.isCompact = isCompact
    }

    var body: some View {
        if isCompact {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    Text("--")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(white: 0.20))

                    Text("NO DATA")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(white: 0.36))
                        .tracking(1.5)
                }
                .padding(.bottom, 16)

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.03))
                    .frame(height: 100)

                Text("No analysis data for this day.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(white: 0.45))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 16)
            }
        } else {
            VStack(spacing: 8) {
                Text("No data for this date")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text("No \(graphType.dataTypeName) data was collected on this day.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.45))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 300)
            .padding(.all, 50)
        }
    }
}

struct DeviceNotSelectedView: View {
    let graphType: GraphEmptyStateView.GraphType
    let isCompact: Bool

    init(graphType: GraphEmptyStateView.GraphType, isCompact: Bool = false) {
        self.graphType = graphType
        self.isCompact = isCompact
    }

    var body: some View {
        VStack(spacing: isCompact ? 16 : 20) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(isCompact ? .largeTitle : .system(size: 50))
                .foregroundColor(Color(white: 0.25))

            VStack(spacing: 8) {
                Text("No device selected")
                    .font(isCompact ? .system(size: 14, weight: .medium) : .system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                if !isCompact {
                    Text("Select a device to view data.")
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.45))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: isCompact ? 120 : 300)
        .padding(isCompact ? .vertical : .all, isCompact ? 20 : 50)
    }
}

#Preview {
    VStack(spacing: 20) {
        GraphEmptyStateView(graphType: .vibe, isCompact: true)
        DeviceNotSelectedView(graphType: .vibe, isCompact: true)
    }
    .padding()
    .background(Color.darkBase)
}
