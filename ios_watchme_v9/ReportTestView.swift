//
//  ReportTestView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/25.
//

import SwiftUI

struct ReportTestView: View {
    @StateObject private var dataManager = SupabaseDataManager()
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    
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
                
                // デバイス選択UI
                VStack(spacing: 12) {
                    if deviceManager.userDevices.count > 1 {
                        // 複数デバイスがある場合はPicker表示
                        VStack(alignment: .leading, spacing: 8) {
                            Text("デバイスを選択")
                                .font(.headline)
                            
                            Picker("デバイス", selection: Binding(
                                get: { deviceManager.selectedDeviceID ?? "" },
                                set: { deviceManager.selectDevice($0) }
                            )) {
                                ForEach(deviceManager.userDevices, id: \.device_id) { device in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("デバイス \(deviceManager.userDevices.firstIndex(where: { $0.device_id == device.device_id })! + 1)")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                            Text(device.device_id)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                    }
                                    .tag(device.device_id)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding()
                            .background(Color.safeColor("BorderLight").opacity(0.1))
                            .cornerRadius(10)
                        }
                    } else if deviceManager.userDevices.isEmpty {
                        // デバイスが見つからない場合
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color.safeColor("WarningColor"))
                            Text("デバイスを取得中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.safeColor("WarningColor").opacity(0.1))
                        .cornerRadius(8)
                    } else if let deviceId = deviceManager.selectedDeviceID {
                        // デバイスが選択されている場合
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.safeColor("SuccessColor"))
                            Text("デバイスID: \(deviceId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.safeColor("SuccessColor").opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                
                // 日付選択セクション
                VStack(spacing: 10) {
                    Text("レポート日付")
                        .font(.headline)
                    
                    Button(action: {
                        showDatePicker.toggle()
                    }) {
                        HStack {
                            Image(systemName: "calendar")
                            Text(dateFormatter.string(from: selectedDate))
                        }
                        .padding()
                        .background(Color.safeColor("PrimaryActionColor").opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    if showDatePicker {
                        DatePicker("",
                                 selection: $selectedDate,
                                 in: ...Date(),
                                 displayedComponents: .date)
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .padding()
                            .background(Color.safeColor("BorderLight").opacity(0.1))
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                
                // データ取得ボタン
                HStack(spacing: 15) {
                    Button(action: {
                        fetchDailyReport()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("今日のレポートを取得")
                        }
                        .padding()
                        .background(Color.safeColor("PrimaryActionColor"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        fetchSelectedDateReport()
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                            Text("選択日のレポート")
                        }
                        .padding()
                        .background(Color.safeColor("SuccessColor"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                
                // ローディング表示
                if dataManager.isLoading {
                    ProgressView("データを取得中...")
                        .padding()
                }
                
                // エラー表示
                if let error = dataManager.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(Color.safeColor("ErrorColor"))
                        Text("エラー")
                            .font(.headline)
                            .foregroundColor(Color.safeColor("ErrorColor"))
                        Text(error)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.safeColor("ErrorColor").opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // データ表示
                if let report = dataManager.dailyReport {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("📊 レポートデータ")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        // 基本情報
                        GroupBox("基本情報") {
                            VStack(alignment: .leading, spacing: 10) {
                                LabeledContent("デバイスID", value: report.deviceId)
                                LabeledContent("日付", value: report.date)
                                LabeledContent("平均スコア", value: String(format: "%.2f", report.averageScore))
                            }
                            .font(.system(.body, design: .monospaced))
                        }
                        
                        // 感情の時間分布
                        GroupBox("感情の時間分布") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label("ポジティブ", systemImage: "face.smiling")
                                        .foregroundColor(Color.safeColor("SuccessColor"))
                                    Spacer()
                                    Text("\(String(format: "%.1f", report.positiveHours))時間 (\(String(format: "%.1f", report.positivePercentage))%)")
                                }
                                
                                HStack {
                                    Label("ネガティブ", systemImage: "face.dashed")
                                        .foregroundColor(Color.safeColor("ErrorColor"))
                                    Spacer()
                                    Text("\(String(format: "%.1f", report.negativeHours))時間 (\(String(format: "%.1f", report.negativePercentage))%)")
                                }
                                
                                HStack {
                                    Label("ニュートラル", systemImage: "face.smiling.inverse")
                                        .foregroundColor(Color.safeColor("BorderLight"))
                                    Spacer()
                                    Text("\(String(format: "%.1f", report.neutralHours))時間 (\(String(format: "%.1f", report.neutralPercentage))%)")
                                }
                            }
                        }
                        
                        // インサイト
                        if !report.insights.isEmpty {
                            GroupBox("インサイト") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(report.insights.enumerated()), id: \.offset) { index, insight in
                                        HStack(alignment: .top) {
                                            Text("•")
                                                .foregroundColor(Color.safeColor("PrimaryActionColor"))
                                            Text(insight)
                                                .font(.callout)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Vibeスコア詳細（存在する場合）
                        if let vibeScores = report.vibeScores {
                            GroupBox("時間帯別スコア") {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(vibeScores.enumerated()), id: \.offset) { index, score in
                                            if let scoreValue = score {
                                                VStack {
                                                    Text("\(index/2):\(index%2 == 0 ? "00" : "30")")
                                                        .font(.caption2)
                                                    Text(String(format: "%.0f", scoreValue))
                                                        .font(.caption)
                                                        .fontWeight(.bold)
                                                }
                                                .padding(8)
                                                .background(scoreColor(for: scoreValue))
                                                .cornerRadius(8)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 処理情報
                        if let processedAt = report.processedAt {
                            Text("処理日時: \(processedAt)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.safeColor("BorderLight").opacity(0.05))
                    .cornerRadius(15)
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 50)
            }
        }
        .navigationTitle("Vibeデータテスト")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("📊 ReportTestView onAppear")
            print("   - selectedDeviceID: \(deviceManager.selectedDeviceID ?? "nil")")
            print("   - userDevices count: \(deviceManager.userDevices.count)")
            
            // もしデバイスが取得されていない場合は再取得
            if deviceManager.userDevices.isEmpty, let userId = userAccountManager.currentUser?.id {
                print("🔄 デバイスが未取得のため再取得を実行")
                Task {
                    await deviceManager.fetchUserDevices(for: userId)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchDailyReport() {
        guard userAccountManager.isAuthenticated else {
            dataManager.errorMessage = "ログインしていません"
            return
        }
        
        guard let deviceId = deviceManager.selectedDeviceID else {
            dataManager.errorMessage = "デバイスが選択されていません"
            return
        }
        
        print("🔍 Using device ID: \(deviceId)")
        
        Task {
            await dataManager.fetchDailyReport(for: deviceId, date: Date())
        }
    }
    
    private func fetchSelectedDateReport() {
        guard userAccountManager.isAuthenticated else {
            dataManager.errorMessage = "ログインしていません"
            return
        }
        
        guard let deviceId = deviceManager.selectedDeviceID else {
            dataManager.errorMessage = "デバイスが選択されていません"
            return
        }
        
        print("🔍 Using device ID: \(deviceId)")
        
        Task {
            await dataManager.fetchDailyReport(for: deviceId, date: selectedDate)
        }
    }
    
    private func scoreColor(for score: Double) -> Color {
        switch score {
        case 0..<3:
            return Color.safeColor("ErrorColor").opacity(0.2)
        case 3..<7:
            return Color.safeColor("EmotionJoy").opacity(0.2)
        case 7...10:
            return Color.safeColor("SuccessColor").opacity(0.2)
        default:
            return Color.safeColor("BorderLight").opacity(0.2)
        }
    }
}

// 日付フォーマッター
private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    formatter.locale = Locale(identifier: "ja_JP")
    return formatter
}()

// MARK: - Preview
struct ReportTestView_Previews: PreviewProvider {
    static var previews: some View {
        let deviceManager = DeviceManager()
        let userAccountManager = UserAccountManager(deviceManager: deviceManager)
        return NavigationView {
            ReportTestView()
                .environmentObject(userAccountManager)
                .environmentObject(deviceManager)
        }
    }
}