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
    
    @State private var selectedDate = Date()
    @State private var emotionReport: EmotionReport?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var selectedEmotions: Set<EmotionType> = Set(EmotionType.allCases)
    @State private var showingLegend = true
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Date Navigation
            HStack(spacing: 20) {
                Button(action: { changeDate(by: -1) }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Text(dateFormatter.string(from: selectedDate))
                    .font(.headline)
                    .frame(minWidth: 150)
                
                Button(action: { changeDate(by: 1) }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.separator)),
                alignment: .bottom
            )
            
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView("データを読み込み中...")
                            .padding(.top, 50)
                    } else if let report = emotionReport {
                        // Emotion Ranking Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "list.number")
                                    .foregroundColor(.blue)
                                Text("1日の感情ランキング")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            ForEach(Array(report.emotionRanking.prefix(8).enumerated()), id: \.offset) { index, emotion in
                                if emotion.value > 0 {
                                    HStack {
                                        Text("\(index + 1).")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                            .frame(width: 25, alignment: .trailing)
                                        
                                        Circle()
                                            .fill(emotion.color)
                                            .frame(width: 12, height: 12)
                                        
                                        Text(emotion.name)
                                            .font(.subheadline)
                                        
                                        Spacer()
                                        
                                        Text("\(emotion.value)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray6))
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Emotion Chart Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "chart.line")
                                    .foregroundColor(.blue)
                                Text("時間帯別感情推移")
                                    .font(.headline)
                                Spacer()
                                Button(action: { showingLegend.toggle() }) {
                                    Image(systemName: showingLegend ? "eye.fill" : "eye.slash.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Line Chart
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
                                .frame(height: 300)
                                .padding(.horizontal)
                                .chartXScale(domain: 0...24)
                                .chartXAxis {
                                    AxisMarks(values: [0, 6, 12, 18, 24]) { value in
                                        AxisGridLine()
                                        AxisTick()
                                        AxisValueLabel {
                                            if let hour = value.as(Double.self) {
                                                Text("\(Int(hour)):00")
                                            }
                                        }
                                    }
                                }
                                .chartYScale(domain: 0...10)
                                .chartYAxis {
                                    AxisMarks(position: .leading)
                                }
                                
                                // Legend
                                if showingLegend {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("感情の種類")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal)
                                        
                                        LazyVGrid(columns: [
                                            GridItem(.flexible()),
                                            GridItem(.flexible())
                                        ], spacing: 8) {
                                            ForEach(EmotionType.allCases, id: \.self) { emotionType in
                                                Button(action: {
                                                    toggleEmotion(emotionType)
                                                }) {
                                                    HStack(spacing: 6) {
                                                        Circle()
                                                            .fill(emotionType.color)
                                                            .frame(width: 10, height: 10)
                                                        Text(emotionType.rawValue)
                                                            .font(.caption)
                                                            .foregroundColor(selectedEmotions.contains(emotionType) ? .primary : .secondary)
                                                        Spacer()
                                                    }
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .fill(selectedEmotions.contains(emotionType) ? emotionType.lightColor : Color(.systemGray6))
                                                    )
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                    .padding(.top, 8)
                                }
                            } else {
                                Text("データがありません")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(height: 200)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 12)
                        
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("この日のデータがありません")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 50)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("感情グラフ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchEmotionData()
        }
        .alert("エラー", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "不明なエラーが発生しました")
        }
    }
    
    private func fetchEmotionData() {
        guard authManager.isAuthenticated else {
            errorMessage = "ログインが必要です"
            showingError = true
            return
        }
        
        guard let deviceId = deviceManager.selectedDeviceID ?? deviceManager.actualDeviceID else {
            errorMessage = "デバイスが登録されていません"
            showingError = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let dateString = formatter.string(from: selectedDate)
                
                let report = try await dataManager.fetchEmotionReport(
                    deviceId: deviceId,
                    date: dateString
                )
                
                await MainActor.run {
                    self.emotionReport = report
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func changeDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
            fetchEmotionData()
        }
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
}

#Preview {
    NavigationView {
        EmotionGraphView()
    }
}