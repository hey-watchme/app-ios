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
    
    static func shortDayOfWeekFormatter(timezone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"  // 短縮形式（月、火、水...）
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

    private func getMonthDayWithWeekdayString(from date: Date) -> String {
        let monthDayFormatter = DateFormatter()
        monthDayFormatter.dateFormat = "M月d日"
        monthDayFormatter.locale = Locale(identifier: "ja_JP")
        monthDayFormatter.timeZone = timezone
        
        let weekdayFormatter = DateFormatter.shortDayOfWeekFormatter(timezone: timezone)
        
        return "\(monthDayFormatter.string(from: date))(\(weekdayFormatter.string(from: date)))"
    }
    
    var body: some View {
        // One line: the date with its weekday, the calendar, and the arrows on either side.
        // Every day is written the same way (no "今日", no year).
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.safeColor("BehaviorTextPrimary"))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Button(action: {
                showDatePicker = true
            }) {
                HStack(spacing: 10) {
                    Text(getMonthDayWithWeekdayString(from: selectedDate))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color.safeColor("PrimaryText"))
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                        .foregroundColor(Color.safeColor("BehaviorTextPrimary"))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // On the newest day the arrow stays, greyed out, so the row stays balanced
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if canGoToNextDay {
                        selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    }
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(canGoToNextDay ? Color.safeColor("BehaviorTextPrimary") : Color(white: 0.3))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoToNextDay)
        }
        .padding(.top, 45)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Color.darkBase)
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

    /// Same as the large header: 11月21日(金)
    private var stickyDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = deviceManager.selectedDeviceTimezone
        return formatter.string(from: selectedDate)
    }
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
                HStack(spacing: 8) {
                    Text(stickyDateText)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
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
        .background(Color.darkBase)
        .sheet(isPresented: $showDatePicker) {
            CustomCalendarView(selectedDate: $selectedDate, isPresented: $showDatePicker)
                .environmentObject(deviceManager)
                .environmentObject(dataManager)
        }
    }
}
