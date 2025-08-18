//
//  EmotionGraphView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/25.
//

import SwiftUI
import Charts

struct EmotionGraphView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    
    // オプショナルでデータを受け取る
    var emotionReport: EmotionReport?
    
    @State private var selectedEmotions: Set<EmotionType> = Set(EmotionType.allCases)
    @State private var showingLegend = true
    
    var body: some View {
        ScrollView {
                VStack(spacing: 16) {
                    if dataManager.isLoading {
                        ProgressView("データを読み込み中...")
                            .padding(.top, 50)
                    } else if let report = emotionReport ?? dataManager.dailyEmotionReport {
                        // 感情ランキングカード
                        UnifiedCard(title: "感情ランキング") {
                            VStack(spacing: 12) {
                                ForEach(Array(report.emotionRanking.prefix(8).enumerated()), id: \.offset) { index, emotion in
                                    if emotion.value > 0 {
                                        HStack(spacing: 16) {
                                            // ランク表示
                                            ZStack {
                                                Circle()
                                                    .fill(rankBackgroundColor(for: index))
                                                    .frame(width: 32, height: 32)
                                                Text("\(index + 1)")
                                                    .font(.callout)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                            }
                                            
                                            // 感情インジケーター
                                            Circle()
                                                .fill(emotion.color)
                                                .frame(width: 16, height: 16)
                                            
                                            Text(emotion.name)
                                                .font(.body)
                                                .foregroundColor(Color.safeColor("BehaviorTextPrimary"))
                                            
                                            Spacer()
                                            
                                            // スコア表示
                                            Text("\(emotion.value)")
                                                .font(.callout)
                                                .fontWeight(.semibold)
                                                .foregroundColor(Color.safeColor("BehaviorTextPrimary").opacity(0.8))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 4)
                                                .background(
                                                    Capsule()
                                                        .fill(emotion.color.opacity(0.1))
                                                )
                                        }
                                        
                                        if index < min(7, report.emotionRanking.filter { $0.value > 0 }.count - 1) {
                                            Divider()
                                                .background(Color.gray.opacity(0.2))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // 感情推移グラフカード
                        UnifiedCard(
                            title: "時間帯別推移",
                            navigationLabel: showingLegend ? "凡例を非表示" : "凡例を表示",
                            onNavigate: { showingLegend.toggle() }
                        ) {
                            VStack(spacing: 16) {
                                if report.activeTimePoints.count > 0 {
                                    Chart {
                                        ForEach(EmotionType.allCases, id: \.self) { emotionType in
                                            if selectedEmotions.contains(emotionType) {
                                                ForEach(report.emotionGraph, id: \.time) { point in
                                                    LineMark(
                                                        x: .value("時間", point.timeValue),
                                                        y: .value("値", getValue(for: emotionType, from: point))
                                                    )
                                                    .foregroundStyle(emotionType.color)
                                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                                    .symbol(Circle().strokeBorder(lineWidth: 2))
                                                    .symbolSize(30)
                                                    .interpolationMethod(.catmullRom)
                                                }
                                            }
                                        }
                                    }
                                    .frame(height: 260)
                                    .chartXScale(domain: 0...24)
                                    .chartXAxis {
                                        AxisMarks(values: [0, 6, 12, 18, 24]) { value in
                                            AxisGridLine()
                                            AxisTick()
                                            AxisValueLabel {
                                                if let hour = value.as(Double.self) {
                                                    Text("\(Int(hour)):00")
                                                        .font(.caption2)
                                                        .foregroundColor(Color.safeColor("BehaviorTextSecondary"))
                                                }
                                            }
                                        }
                                    }
                                    .chartYScale(domain: 0...10)
                                    .chartYAxis {
                                        AxisMarks(position: .leading) { value in
                                            AxisGridLine()
                                            AxisTick()
                                            AxisValueLabel {
                                                if let val = value.as(Int.self) {
                                                    Text("\(val)")
                                                        .font(.caption2)
                                                        .foregroundColor(Color.safeColor("BehaviorTextSecondary"))
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    VStack(spacing: 12) {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.largeTitle)
                                            .foregroundColor(Color.safeColor("BehaviorTextTertiary").opacity(0.8))
                                        Text("データがありません")
                                            .font(.body)
                                            .foregroundColor(Color.safeColor("BehaviorTextSecondary"))
                                    }
                                    .frame(height: 200)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // 凡例カード（表示時のみ）
                        if showingLegend && report.activeTimePoints.count > 0 {
                            UnifiedCard(title: "感情の種類") {
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 12) {
                                    ForEach(EmotionType.allCases, id: \.self) { emotionType in
                                        Button(action: {
                                            toggleEmotion(emotionType)
                                        }) {
                                            HStack(spacing: 8) {
                                                Circle()
                                                    .fill(emotionType.color)
                                                    .frame(width: 14, height: 14)
                                                Text(emotionType.rawValue)
                                                    .font(.body)
                                                    .foregroundColor(
                                                        selectedEmotions.contains(emotionType) 
                                                        ? Color.safeColor("BehaviorTextPrimary")
                                                        : Color.safeColor("BehaviorTextTertiary")
                                                    )
                                                Spacer()
                                                if selectedEmotions.contains(emotionType) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.body)
                                                        .foregroundColor(emotionType.color)
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(selectedEmotions.contains(emotionType) 
                                                        ? emotionType.color.opacity(0.08)
                                                        : Color.gray.opacity(0.05)
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .stroke(
                                                                selectedEmotions.contains(emotionType) 
                                                                ? emotionType.color.opacity(0.3)
                                                                : Color.gray.opacity(0.2),
                                                                lineWidth: 1
                                                            )
                                                    )
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                    } else {
                        // エンプティステート表示（共通コンポーネント使用）
                        GraphEmptyStateView(
                            graphType: .emotion,
                            isDeviceLinked: !deviceManager.userDevices.isEmpty
                        )
                        .padding(.top, 50)
                    }
                }
                .padding(.bottom, 20)
            }
        .background(Color.safeColor("BehaviorBackgroundPrimary"))
        .navigationTitle("感情グラフ")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func toggleEmotion(_ emotionType: EmotionType) {
        if selectedEmotions.contains(emotionType) {
            selectedEmotions.remove(emotionType)
        } else {
            selectedEmotions.insert(emotionType)
        }
    }
    
    private func getValue(for emotionType: EmotionType, from point: EmotionTimePoint) -> Int {
        switch emotionType {
        case .joy: return point.joy
        case .fear: return point.fear
        case .anger: return point.anger
        case .trust: return point.trust
        case .disgust: return point.disgust
        case .sadness: return point.sadness
        case .surprise: return point.surprise
        case .anticipation: return point.anticipation
        }
    }
    
    private func rankBackgroundColor(for index: Int) -> Color {
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

#Preview {
    NavigationView {
        EmotionGraphView()
    }
}