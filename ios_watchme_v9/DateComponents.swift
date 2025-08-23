//
//  DateComponents.swift
//  ios_watchme_v9
//
//  共通の日付選択コンポーネント
//

import SwiftUI

// MARK: - 共通の日付ピッカーシート
struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    @EnvironmentObject var deviceManager: DeviceManager
    
    private var calendar: Calendar {
        deviceManager.deviceCalendar
    }
    
    var body: some View {
        NavigationView {
            DatePicker("日付を選択", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("日付を選択")
                .navigationBarTitleDisplayMode(.inline)
                .environment(\.calendar, calendar)
                .onChange(of: selectedDate) { oldValue, newValue in
                    // 日付が選択されたら自動的にシートを閉じる
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isPresented = false
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            isPresented = false
                        }
                    }
                }
        }
    }
}

// MARK: - 共通の日付フォーマッター
extension DateFormatter {
    static func largeDateFormatter(timezone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = timezone
        return formatter
    }
    
    static func dayOfWeekFormatter(timezone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = timezone
        return formatter
    }
    
    static func compactDateFormatter(timezone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = timezone
        return formatter
    }
}

// MARK: - 大きい日付セクション（スクロール可能なコンテンツ）
struct LargeDateSection: View {
    @Binding var selectedDate: Date
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @State private var showDatePicker = false
    
    private var calendar: Calendar {
        deviceManager.deviceCalendar
    }
    
    private var timezone: TimeZone {
        deviceManager.selectedDeviceTimezone
    }
    
    private var canGoToNextDay: Bool {
        !calendar.isDateInToday(selectedDate)
    }
    
    private func getYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = timezone
        return formatter.string(from: date)
    }
    
    private func getMonthDayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = timezone
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 大きな日付表示
            VStack(spacing: 8) {
                if calendar.isDateInToday(selectedDate) {
                    // 今日の特別表示
                    Text("今日")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                    
                    // 実際の日付と曜日を小さく表示
                    Text("\(DateFormatter.largeDateFormatter(timezone: timezone).string(from: selectedDate))\(DateFormatter.dayOfWeekFormatter(timezone: timezone).string(from: selectedDate))")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    // 今日以外の表示を年・月日・曜日で分けて表示
                    VStack(spacing: 4) {
                        // 年を小さく表示
                        Text(getYearString(from: selectedDate))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        // 月日を大きく表示
                        Text(getMonthDayString(from: selectedDate))
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                        
                        // 曜日を小さく表示
                        Text(DateFormatter.dayOfWeekFormatter(timezone: timezone).string(from: selectedDate))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .multilineTextAlignment(.center)
            
            // 日付変更ボタン
            HStack(spacing: 40) {
                // 前日ボタン
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("前日")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.2))
                    )
                }
                
                // カレンダーボタン
                Button(action: {
                    showDatePicker = true
                }) {
                    Image(systemName: "calendar")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.2))
                        )
                }
                
                // 翌日ボタン
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if canGoToNextDay {
                            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("翌日")
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(canGoToNextDay ? .white : Color.white.opacity(0.4))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(canGoToNextDay ? 0.2 : 0.1))
                    )
                }
                .disabled(!canGoToNextDay)
            }
            
            // 将来的にハイライトや吹き出しを表示するスペース
            // TODO: ハイライト表示を追加
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(Color.safeColor("AppAccentColor"))
        .sheet(isPresented: $showDatePicker) {
            CustomCalendarView(selectedDate: $selectedDate, isPresented: $showDatePicker)
                .environmentObject(deviceManager)
                .environmentObject(dataManager)
        }
    }
}

// MARK: - 固定日付ヘッダー（条件付き表示）
struct StickyDateHeader: View {
    @Binding var selectedDate: Date
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @State private var showDatePicker = false
    
    private var calendar: Calendar {
        deviceManager.deviceCalendar
    }
    
    private var timezone: TimeZone {
        deviceManager.selectedDeviceTimezone
    }
    
    private var canGoToNextDay: Bool {
        !calendar.isDateInToday(selectedDate)
    }
    
    var body: some View {
        HStack {
            // 前日ボタン
            Button(action: {
                withAnimation {
                    selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(Color.safeColor("PrimaryActionColor"))
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            // 日付表示とピッカー
            Button(action: {
                showDatePicker = true
            }) {
                VStack(spacing: 4) {
                    if calendar.isDateInToday(selectedDate) {
                        // 今日の特別表示
                        Text("今日")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(DateFormatter.largeDateFormatter(timezone: timezone).string(from: selectedDate))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        // 今日以外の通常表示
                        Text(DateFormatter.largeDateFormatter(timezone: timezone).string(from: selectedDate))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            Spacer()
            
            // 翌日ボタン
            Button(action: {
                withAnimation {
                    if canGoToNextDay {
                        selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    }
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(canGoToNextDay ? Color.safeColor("PrimaryActionColor") : Color.safeColor("BorderLight").opacity(0.3))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoToNextDay)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
        )
        .sheet(isPresented: $showDatePicker) {
            CustomCalendarView(selectedDate: $selectedDate, isPresented: $showDatePicker)
                .environmentObject(deviceManager)
                .environmentObject(dataManager)
        }
    }
}