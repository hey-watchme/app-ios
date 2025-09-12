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
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var deviceManager: DeviceManager
    
    // オプショナルでデータを受け取る
    var vibeReport: DailyVibeReport?
    var subject: Subject?
    var dashboardSummary: DashboardSummary?  // 新規追加
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
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
                
                // レポート表示（引数で渡されたデータを優先）
                if let report = vibeReport ?? dataManager.dailyReport {
                    VStack(spacing: 16) {
                        // 概要カード
                        UnifiedCard(title: "概要") {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("平均スコア")
                                        .font(.caption)
                                        .foregroundColor(Color.safeColor("BehaviorTextSecondary"))
                                    Text(String(format: "%.1f pt", report.averageScore))
                                        .font(.system(size: 56, weight: .bold, design: .rounded))
                                        .foregroundColor(report.averageScoreColor)
                                }
                                Spacer()
                                Text(report.averageScoreEmoji)
                                    .font(.system(size: 70))
                                    .padding()
                                    .background(
                                        Circle()
                                            .fill(report.averageScoreColor.opacity(0.1))
                                    )
                            }
                        }
                        .padding(.horizontal)
                        
                        // 感情の時間分布カード
                        UnifiedCard(title: "時間分布") {
                            VStack(spacing: 16) {
                                EmotionTimeBar(
                                    label: "ポジティブ",
                                    hours: report.positiveHours,
                                    percentage: report.positivePercentage,
                                    color: Color.safeColor("SuccessColor")
                                )
                                EmotionTimeBar(
                                    label: "ニュートラル",
                                    hours: report.neutralHours,
                                    percentage: report.neutralPercentage,
                                    color: Color.safeColor("BorderLight")
                                )
                                EmotionTimeBar(
                                    label: "ネガティブ",
                                    hours: report.negativeHours,
                                    percentage: report.negativePercentage,
                                    color: Color.safeColor("ErrorColor")
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // インサイトカード
                        if !report.insights.isEmpty {
                            UnifiedCard(title: "インサイト") {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(Array(report.insights.enumerated()), id: \.offset) { index, insight in
                                        HStack(alignment: .top, spacing: 12) {
                                            Image(systemName: "lightbulb.fill")
                                                .foregroundColor(Color.safeColor("WarningColor"))
                                                .font(.body)
                                            Text(insight)
                                                .font(.body)
                                                .foregroundColor(Color.safeColor("BehaviorTextPrimary"))
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        if index < report.insights.count - 1 {
                                            Divider()
                                                .background(Color.safeColor("BorderLight").opacity(0.2))
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // 時間帯別グラフカード
                        // dashboard_summaryのvibeScoresを優先、なければreportから取得（フォールバック）
                        if let vibeScores = dashboardSummary?.vibeScores ?? report.vibeScores {
                            UnifiedCard(title: "時間帯別推移") {
                                VibeLineChartView(vibeScores: vibeScores, vibeChanges: report.vibeChanges, showTitle: false, compactMode: false)
                                    .frame(height: 260)
                            }
                            .padding(.horizontal)
                        }
                    }
                } else if !dataManager.isLoading && dataManager.errorMessage == nil {
                    // エンプティステート表示（共通コンポーネント使用）
                    GraphEmptyStateView(
                        graphType: .vibe,
                        isDeviceLinked: !deviceManager.userDevices.isEmpty
                    )
                }
                
                Spacer(minLength: 50)
            }
        }
        .background(Color.safeColor("BehaviorBackgroundPrimary"))
        .navigationTitle("心理グラフ")
        .navigationBarTitleDisplayMode(.inline)
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
    let authManager = SupabaseAuthManager(deviceManager: deviceManager)
    return NavigationView {
        HomeView()
        .environmentObject(authManager)
        .environmentObject(SupabaseDataManager())
        .environmentObject(deviceManager)
    }
}