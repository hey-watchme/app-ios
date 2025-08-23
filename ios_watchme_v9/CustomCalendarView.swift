//
//  CustomCalendarView.swift
//  ios_watchme_v9
//
//  カスタムカレンダービュー - 気分の絵文字表示機能付き
//

import SwiftUI

// MARK: - 月間の気分データ
struct MonthlyVibeData {
    let date: Date
    let averageScore: Double?
    
    var emoji: String? {
        guard let score = averageScore else { return nil }
        // DailyVibeReportの共通絵文字ロジックを使用
        return DailyVibeReport.getEmotionEmoji(for: score)
    }
}

// MARK: - カスタムカレンダービュー
struct CustomCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    
    @State private var displayMonth: Date = Date()
    @State private var monthlyVibeData: [Date: MonthlyVibeData] = [:]
    @State private var isLoadingData = false
    
    private var calendar: Calendar {
        deviceManager.deviceCalendar
    }
    
    private var timezone: TimeZone {
        deviceManager.selectedDeviceTimezone
    }
    
    // 月の最初の日
    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: displayMonth)?.start ?? displayMonth
    }
    
    // 月の日数
    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: displayMonth)?.count ?? 30
    }
    
    // 月の最初の日の曜日（0=日曜日）
    private var firstWeekday: Int {
        (calendar.component(.weekday, from: monthStart) - 1)
    }
    
    // カレンダーグリッドの日付配列
    private var calendarDays: [Date?] {
        var days: [Date?] = []
        
        // 月初めの空白
        for _ in 0..<firstWeekday {
            days.append(nil)
        }
        
        // 月の日付
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }
        
        // 最後の週を埋める空白
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 月選択ヘッダー
                HStack {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Text(monthYearString)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                
                // 曜日ヘッダー
                HStack {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                
                // カレンダーグリッド
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, date in
                        if let date = date {
                            CalendarDayCell(
                                date: date,
                                isSelected: isSameDay(date, selectedDate),
                                isToday: calendar.isDateInToday(date),
                                vibeEmoji: getVibeEmoji(for: date),
                                action: {
                                    selectedDate = date
                                    // 少し遅延してからシートを閉じる
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isPresented = false
                                    }
                                }
                            )
                        } else {
                            Color.clear
                                .frame(height: 60)
                        }
                    }
                }
                .padding()
                
                Spacer()
                
                if isLoadingData {
                    ProgressView("データを読み込み中...")
                        .padding()
                }
            }
            .navigationTitle("日付を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("今日") {
                        selectedDate = Date()
                        displayMonth = Date()
                        Task {
                            await loadMonthlyData()
                        }
                    }
                }
            }
        }
        .task {
            displayMonth = selectedDate
            await loadMonthlyData()
        }
        .onChange(of: displayMonth) { _, _ in
            Task {
                await loadMonthlyData()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = timezone
        return formatter.string(from: displayMonth)
    }
    
    private var weekdaySymbols: [String] {
        ["日", "月", "火", "水", "木", "金", "土"]
    }
    
    private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        calendar.isDate(date1, inSameDayAs: date2)
    }
    
    private func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth) {
            displayMonth = newMonth
        }
    }
    
    private func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth) {
            displayMonth = newMonth
        }
    }
    
    private func getVibeEmoji(for date: Date) -> String? {
        // 日付の正規化（時刻を00:00:00にする）
        let normalizedDate = calendar.startOfDay(for: date)
        return monthlyVibeData[normalizedDate]?.emoji
    }
    
    private func loadMonthlyData() async {
        guard let deviceId = deviceManager.selectedDeviceID ?? deviceManager.localDeviceIdentifier else { return }
        
        isLoadingData = true
        defer { isLoadingData = false }
        
        // 月間のデータを取得
        let vibeData = await dataManager.fetchMonthlyVibeScores(
            deviceId: deviceId,
            month: displayMonth,
            timezone: timezone
        )
        
        // データを辞書形式に変換
        var dataDict: [Date: MonthlyVibeData] = [:]
        for data in vibeData {
            let normalizedDate = calendar.startOfDay(for: data.date)
            dataDict[normalizedDate] = data
        }
        
        await MainActor.run {
            self.monthlyVibeData = dataDict
        }
    }
}

// MARK: - カレンダー日付セル
struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let vibeEmoji: String?
    let action: () -> Void
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(dayNumber)
                    .font(.system(size: 16, weight: isToday ? .bold : .medium))
                    .foregroundColor(textColor)
                
                if let emoji = vibeEmoji {
                    Text(emoji)
                        .font(.system(size: 16))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .cornerRadius(8)
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return .blue
        } else {
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.safeColor("AppAccentColor")
        } else {
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        if isToday && !isSelected {
            return .blue
        } else if isSelected {
            return Color.clear
        } else {
            return Color.gray.opacity(0.2)
        }
    }
    
    private var borderWidth: CGFloat {
        if isToday && !isSelected {
            return 2
        } else {
            return 1
        }
    }
}