//
//  HomeView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/25.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var dataManager = SupabaseDataManager()
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var deviceManager: DeviceManager
    @ObservedObject var networkManager: NetworkManager
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    @Binding var showUserInfoSheet: Bool
    
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    
    // 日付フォーマッター
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 日付ナビゲーション
                HStack {
                    Button(action: {
                        withAnimation {
                            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                            fetchReport(for: selectedDate)
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text(dateFormatter.string(from: selectedDate))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if Calendar.current.isDateInToday(selectedDate) {
                            Text("今日")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                            if tomorrow <= Date() {
                                selectedDate = tomorrow
                                fetchReport(for: selectedDate)
                            }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(canGoToNextDay ? .blue : .gray.opacity(0.3))
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!canGoToNextDay)
                }
                .padding(.horizontal)
                .padding(.top)
                
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
                            .foregroundColor(.orange)
                        Text("データを取得できませんでした")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(error)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button(action: { fetchReport(for: selectedDate) }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("再試行")
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // レポート表示
                if let report = dataManager.dailyReport {
                    VStack(alignment: .leading, spacing: 16) {
                        // 感情サマリーカード
                        VStack(spacing: 16) {
                            // 平均スコア
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("今日の平均スコア")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.1f", report.averageScore))
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundColor(scoreColor(for: report.averageScore))
                                }
                                Spacer()
                                Image(systemName: emotionIcon(for: report.averageScore))
                                    .font(.system(size: 60))
                                    .foregroundColor(scoreColor(for: report.averageScore))
                            }
                            .padding()
                            .background(scoreColor(for: report.averageScore).opacity(0.1))
                            .cornerRadius(16)
                            
                            // 感情の時間分布
                            VStack(spacing: 12) {
                                EmotionTimeBar(
                                    label: "ポジティブ",
                                    hours: report.positiveHours,
                                    percentage: report.positivePercentage,
                                    color: .green
                                )
                                EmotionTimeBar(
                                    label: "ニュートラル",
                                    hours: report.neutralHours,
                                    percentage: report.neutralPercentage,
                                    color: .gray
                                )
                                EmotionTimeBar(
                                    label: "ネガティブ",
                                    hours: report.negativeHours,
                                    percentage: report.negativePercentage,
                                    color: .red
                                )
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // インサイト
                        if !report.insights.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("今日のインサイト")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(report.insights.enumerated()), id: \.offset) { index, insight in
                                        HStack(alignment: .top, spacing: 12) {
                                            Image(systemName: "lightbulb.fill")
                                                .foregroundColor(.yellow)
                                                .font(.caption)
                                            Text(insight)
                                                .font(.subheadline)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.yellow.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                        
                        // 時間帯別グラフ (簡易版)
                        if let vibeScores = report.vibeScores {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("時間帯別の推移")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 4) {
                                        ForEach(Array(vibeScores.enumerated()), id: \.offset) { index, score in
                                            if let scoreValue = score {
                                                VStack {
                                                    Rectangle()
                                                        .fill(scoreColor(for: scoreValue))
                                                        .frame(width: 20, height: CGFloat(scoreValue * 10))
                                                    Text("\(index/2)")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                                .frame(height: 120, alignment: .bottom)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                    }
                } else if !dataManager.isLoading && dataManager.errorMessage == nil {
                    // 初期状態（データ未取得）
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("レポートデータがありません")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("録音データを収集すると\nここにレポートが表示されます")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .padding()
                }
                
                Spacer(minLength: 50)
            }
        }
        .navigationTitle("心理グラフ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showUserInfoSheet = true
                }) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            if deviceManager.userDevices.isEmpty, let userId = authManager.currentUser?.id {
                Task {
                    await deviceManager.fetchUserDevices(for: userId)
                    // デバイス取得後に自動でレポートを取得
                    fetchReport(for: selectedDate)
                }
            } else {
                // デバイスがある場合は直接レポートを取得
                fetchReport(for: selectedDate)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchReport(for date: Date) {
        guard authManager.isAuthenticated else {
            dataManager.errorMessage = "ログインが必要です"
            return
        }
        
        guard let deviceId = deviceManager.selectedDeviceID ?? deviceManager.actualDeviceID else {
            dataManager.errorMessage = "デバイスが登録されていません"
            return
        }
        
        Task {
            await dataManager.fetchDailyReport(for: deviceId, date: date)
        }
    }
    
    private var canGoToNextDay: Bool {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        return tomorrow <= Date()
    }
    
    private func scoreColor(for score: Double) -> Color {
        switch score {
        case 0..<3:
            return .red
        case 3..<7:
            return .orange
        case 7...10:
            return .green
        default:
            return .gray
        }
    }
    
    private func emotionIcon(for score: Double) -> String {
        switch score {
        case 0..<3:
            return "face.dashed"
        case 3..<7:
            return "face.smiling"
        case 7...10:
            return "face.smiling.fill"
        default:
            return "questionmark.circle"
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(String(format: "%.1f", hours))時間 (\(String(format: "%.0f", percentage))%)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * (percentage / 100), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    NavigationView {
        HomeView(
            networkManager: NetworkManager(
                authManager: SupabaseAuthManager(),
                deviceManager: DeviceManager()
            ),
            showAlert: .constant(false),
            alertMessage: .constant(""),
            showUserInfoSheet: .constant(false)
        )
        .environmentObject(SupabaseAuthManager())
        .environmentObject(DeviceManager())
    }
}