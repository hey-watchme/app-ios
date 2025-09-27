//
//  BehaviorGraphView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/25.
//

import SwiftUI

struct BehaviorGraphView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    
    // オプショナルでデータを受け取る
    var behaviorReport: BehaviorReport?
    var selectedDate: Date = Date()  // 日付を受け取る
    
    @State private var selectedTimeBlock: TimeBlock? = nil
    
    var body: some View {
        ScrollView {
                VStack(spacing: 16) {
                    // 日付表示
                    DetailPageDateHeader(selectedDate: selectedDate)
                        .padding(.top, -8)  // ScrollViewのデフォルトパディングを調整
                    if dataManager.isLoading {
                        ProgressView("データを読み込み中...")
                            .padding(.top, 50)
                    } else if let report = behaviorReport ?? dataManager.dailyBehaviorReport {
                        // 検出された生活音カード
                        UnifiedCard(title: "検出された生活音") {
                            VStack(spacing: 16) {
                                // 合計件数表示
                                HStack {
                                    Text("音響イベント数")
                                        .font(.caption)
                                        .foregroundColor(Color.safeColor("BehaviorTextSecondary"))
                                    Spacer()
                                    Text("\(report.totalEventCount)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color.safeColor("BehaviorTextPrimary"))
                                    Text("件")
                                        .font(.caption)
                                        .foregroundColor(Color.safeColor("BehaviorTextSecondary"))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.safeColor("PrimaryActionColor").opacity(0.05))
                                )
                                
                                // ランキングリスト
                                VStack(spacing: 12) {
                                    ForEach(Array(report.summaryRanking.prefix(10).enumerated()), id: \.offset) { index, event in
                                        HStack(spacing: 16) {
                                            Text(event.event)
                                                .font(.body)
                                                .foregroundColor(Color.safeColor("BehaviorTextPrimary"))
                                            
                                            Spacer()
                                            
                                            HStack(spacing: 4) {
                                                Text("\(event.count)")
                                                    .font(.callout)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(Color.safeColor("BehaviorTextSecondary"))
                                                Text("回")
                                                    .font(.caption)
                                                    .foregroundColor(Color.safeColor("BehaviorTextTertiary"))
                                            }
                                        }
                                        
                                        if index < min(9, report.summaryRanking.count - 1) {
                                            Divider()
                                                .background(Color.safeColor("BehaviorBackgroundSecondary"))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // 時間帯別分布カード
                        UnifiedCard(title: "時間帯別分布") {
                            VStack(spacing: 16) {
                                // アクティブスロット数
                                HStack {
                                    Text("アクティブな時間帯")
                                        .font(.caption)
                                        .foregroundColor(Color.safeColor("BehaviorTextSecondary"))
                                    Spacer()
                                    Text("\(report.activeTimeBlocks.count)")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color.safeColor("BehaviorTextPrimary"))
                                    Text("/ 48 スロット")
                                        .font(.caption)
                                        .foregroundColor(Color.safeColor("BehaviorTextTertiary"))
                                }
                                
                                // 時間帯グリッド
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 10) {
                                    ForEach(report.sortedTimeBlocks, id: \.time) { block in
                                        TimeBlockCell(timeBlock: block) {
                                            if !block.isEmpty {
                                                selectedTimeBlock = block
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                    } else {
                        // エンプティステート表示（共通コンポーネント使用）
                        GraphEmptyStateView(
                            graphType: .behavior,
                            isDeviceLinked: !deviceManager.userDevices.isEmpty
                        )
                        .padding(.top, 50)
                    }
                }
                .padding(.bottom, 20)
            }
        .background(Color.safeColor("BehaviorBackgroundPrimary"))
        .navigationTitle("行動グラフ")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedTimeBlock) { block in
            TimeBlockDetailView(timeBlock: block) {
                selectedTimeBlock = nil
            }
            .presentationDetents([.medium])
        }
    }
    
    private func rankColor(for index: Int) -> Color {
        switch index {
        case 0:
            return Color.safeColor("BehaviorGoldMedal") // Gold
        case 1:
            return Color.safeColor("BehaviorSilverMedal") // Silver
        case 2:
            return Color.safeColor("BehaviorBronzeMedal") // Bronze
        default:
            return Color.safeColor("BehaviorTextSecondary") // Gray
        }
    }
}

// MARK: - Time Block Cell
struct TimeBlockCell: View {
    let timeBlock: TimeBlock
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(timeBlock.displayTime)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(timeBlock.isEmpty ? Color.safeColor("BehaviorTextTertiary") : Color.safeColor("BehaviorTextSecondary"))
                
                if timeBlock.isEmpty {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.safeColor("BehaviorBackgroundSecondary").opacity(0.5))
                        .frame(height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.safeColor("BehaviorBackgroundSecondary"), lineWidth: 1)
                        )
                        .overlay(
                            Text("-")
                                .font(.caption)
                                .foregroundColor(Color.safeColor("BehaviorTextTertiary"))
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(backgroundGradient(for: timeBlock.hourInt))
                        .frame(height: 28)
                        .overlay(
                            Text("\(timeBlock.events?.count ?? 0)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func backgroundGradient(for hour: Int) -> LinearGradient {
        let colors: [Color]
        switch hour {
        case 0..<6:
            colors = [.purple, .indigo] // 深夜
        case 6..<9:
            colors = [.orange, .yellow] // 朝
        case 9..<12:
            colors = [.blue, .cyan] // 午前
        case 12..<15:
            colors = [.green, .mint] // 午後早め
        case 15..<18:
            colors = [.teal, .blue] // 午後
        case 18..<21:
            colors = [.orange, .red] // 夕方
        default:
            colors = [.indigo, .purple] // 夜
        }
        
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Time Block Detail View
struct TimeBlockDetailView: View {
    let timeBlock: TimeBlock
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // カスタムヘッダー
            HStack {
                Text("時間帯詳細")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color.secondary.opacity(0.6))
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            
            Divider()
            
            // コンテンツ
            List {
                Section(header: Text("\(timeBlock.displayTime) の行動")) {
                    if let events = timeBlock.events, !events.isEmpty {
                        ForEach(events) { event in
                            HStack {
                                Text(event.event)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(event.count)回")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    } else {
                        Text("この時間帯にデータがありません")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
    }
}

#Preview {
    NavigationView {
        BehaviorGraphView()
    }
}