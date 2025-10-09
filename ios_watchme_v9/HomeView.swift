//
//  HomeView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/25.
//

import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    
    // オプショナルでデータを受け取る
    var subject: Subject?
    var dashboardSummary: DashboardSummary?  // メインデータソース
    var selectedDate: Date  // 日付を受け取る
    
    @State private var timeBlocks: [DashboardTimeBlock] = []
    @State private var isLoadingTimeBlocks = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 日付表示
                DetailPageDateHeader(selectedDate: selectedDate)
                    .padding(.top, -8)  // ScrollViewのデフォルトパディングを調整
                
                // ローディング表示
                if dataManager.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("レポートを取得中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding()
                }
                
                // エラー表示
                if let error = dataManager.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(Color.safeColor("WarningColor"))
                        Text("データを取得できませんでした")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(error)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.safeColor("WarningColor").opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // 時間詳細リスト表示
                if isLoadingTimeBlocks {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("時間詳細を取得中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding()
                } else if !timeBlocks.isEmpty {
                    VStack(spacing: 16) {
                        // 時間ごとの詳細リスト
                        UnifiedCard(title: "時間ごとの詳細") {
                            VStack(spacing: 0) {
                                ForEach(timeBlocks, id: \.timeBlock) { block in
                                    TimeBlockRowView(timeBlock: block)
                                    
                                    if block.timeBlock != timeBlocks.last?.timeBlock {
                                        Divider()
                                            .background(Color.safeColor("BorderLight").opacity(0.3))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                } else if !isLoadingTimeBlocks && !dataManager.isLoading && dataManager.errorMessage == nil {
                    // エンプティステート表示（共通コンポーネント使用）
                    GraphEmptyStateView(
                        graphType: .vibe,
                        isDeviceLinked: !deviceManager.devices.isEmpty
                    )
                }
                
                Spacer(minLength: 50)
            }
        }
        .background(Color.safeColor("BehaviorBackgroundPrimary"))
        .navigationTitle("気分詳細")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedDate) {
            await loadTimeBlocks()
        }
    }
    
    // データ取得メソッド
    private func loadTimeBlocks() async {
        guard let deviceId = deviceManager.selectedDeviceID else {
            print("❌ No device selected")
            return
        }
        
        isLoadingTimeBlocks = true
        timeBlocks = await dataManager.fetchDashboardTimeBlocks(deviceId: deviceId, date: selectedDate)
        isLoadingTimeBlocks = false
    }
}

// MARK: - Time Block Row View

struct TimeBlockRowView: View {
    let timeBlock: DashboardTimeBlock
    @State private var isExpanded = false
    
    // サマリーの最初の1行を取得
    private var summaryFirstLine: String? {
        guard let summary = timeBlock.summary else { return nil }
        let lines = summary.components(separatedBy: .newlines)
        return lines.first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // behaviorを取得（カンマ区切りで最初の3つまで）
    private var behaviorDisplay: String? {
        guard let behavior = timeBlock.behavior, !behavior.isEmpty else { return nil }
        let behaviors = behavior.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return behaviors.prefix(3).joined(separator: ", ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // メイン行（時間、スコア、サマリー1行目、展開アイコン）
            HStack(alignment: .center, spacing: 12) {
                // 時間表示
                Text(timeBlock.displayTime)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.safeColor("BehaviorTextPrimary"))
                    .frame(width: 45, alignment: .leading)

                // スコア表示
                Group {
                    if let score = timeBlock.vibeScore {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(timeBlock.scoreColor)
                                .frame(width: 6, height: 6)
                            Text(String(format: "%@%.0fpt", score >= 0 ? "+" : "", score))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(timeBlock.scoreColor)
                        }
                        .frame(width: 60, alignment: .leading)
                    } else {
                        Text("-")
                            .font(.system(size: 13))
                            .foregroundColor(Color.safeColor("BehaviorTextTertiary"))
                            .frame(width: 60, alignment: .center)
                    }
                }

                // behaviorまたはサマリーの1行目を表示
                VStack(alignment: .leading, spacing: 2) {
                    if let behavior = behaviorDisplay {
                        Text(behavior)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.safeColor("PrimaryActionColor"))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    if let firstLine = summaryFirstLine {
                        Text(firstLine)
                            .font(.system(size: 11))
                            .foregroundColor(Color.safeColor("BehaviorTextSecondary"))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 展開/折りたたみアイコン（ここだけクリック可能）
                if timeBlock.summary != nil || timeBlock.behavior != nil {
                    Button(action: {
                        isExpanded.toggle()
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(Color.safeColor("BehaviorTextSecondary"))
                            .frame(width: 44, height: 44)  // タップ領域を広げる
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Color.clear.frame(width: 44)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            
            // 展開時の詳細表示
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let behavior = timeBlock.behavior, !behavior.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Text("行動:")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.safeColor("BehaviorTextPrimary"))
                            Text(behavior)
                                .font(.system(size: 14))
                                .foregroundColor(Color.safeColor("PrimaryActionColor"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    if let summary = timeBlock.summary {
                        Text(summary)
                            .font(.system(size: 14))
                            .foregroundColor(Color.safeColor("BehaviorTextSecondary"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Supporting Views

struct EmotionTimeBar: View {
    let label: String
    let hours: Double
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                    Text(label)
                        .font(.body)
                        .foregroundColor(Color.safeColor("BehaviorTextPrimary"))
                }
                Spacer()
                Text("\(String(format: "%.1f", hours))時間")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(Color.safeColor("BehaviorTextSecondary"))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.safeColor("BorderLight").opacity(0.1))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: geometry.size.width * (percentage / 100), height: 12)
                }
            }
            .frame(height: 12)
            
            HStack {
                Spacer()
                Text("\(String(format: "%.0f", percentage))%")
                    .font(.caption)
                    .foregroundColor(Color.safeColor("BehaviorTextTertiary"))
            }
        }
    }
}

#Preview {
    let deviceManager = DeviceManager()
    let userAccountManager = UserAccountManager(deviceManager: deviceManager)
    NavigationView {
        HomeView(selectedDate: Date())
        .environmentObject(userAccountManager)
        .environmentObject(SupabaseDataManager())
        .environmentObject(deviceManager)
    }
}