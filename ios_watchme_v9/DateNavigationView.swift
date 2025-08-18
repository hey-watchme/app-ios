//
//  DateNavigationView.swift
//  ios_watchme_v9
//
//  Created by Assistant on 2025/08/02.
//

import SwiftUI

struct DateNavigationView: View {
    @Binding var selectedDate: Date
    @Binding var showDatePicker: Bool
    @EnvironmentObject var deviceManager: DeviceManager
    
    /// デバイスのタイムゾーンを考慮したCalendar
    private var calendar: Calendar {
        deviceManager.deviceCalendar
    }
    
    /// デバイスのタイムゾーンを考慮したDateFormatter
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = deviceManager.selectedDeviceTimezone
        return formatter
    }
    
    private var canGoToNextDay: Bool {
        // selectedDateが「今日」でなければtrueを返す
        // （今日より前の日付なら、次の日に進める）
        return !calendar.isDateInToday(selectedDate)
    }
    
    var body: some View {
        HStack {
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
            
            Button(action: {
                showDatePicker = true
            }) {
                VStack(spacing: 4) {
                    Text(dateFormatter.string(from: selectedDate))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if calendar.isDateInToday(selectedDate) {
                        Text("今日")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    // 今日でない場合のみ、次の日に進む
                    if !calendar.isDateInToday(selectedDate) {
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
        .background(Color(.systemBackground).shadow(radius: 1))
    }
}