//
//  DetailPageDateHeader.swift
//  ios_watchme_v9
//
//  詳細ページ用の日付ヘッダー表示
//

import SwiftUI

struct DetailPageDateHeader: View {
    let selectedDate: Date
    @EnvironmentObject var deviceManager: DeviceManager
    
    private var calendar: Calendar {
        deviceManager.deviceCalendar
    }
    
    private var timezone: TimeZone {
        deviceManager.selectedDeviceTimezone
    }
    
    private func formatDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = timezone
        
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        weekdayFormatter.locale = Locale(identifier: "ja_JP")
        weekdayFormatter.timeZone = timezone
        
        return "\(formatter.string(from: selectedDate))（\(weekdayFormatter.string(from: selectedDate))）"
    }
    
    var body: some View {
        HStack {
            Spacer()
            Text(formatDate())
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.safeColor("BehaviorTextSecondary"))
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color.safeColor("BehaviorBackgroundSecondary").opacity(0.3))
    }
}

#Preview {
    DetailPageDateHeader(selectedDate: Date())
        .environmentObject(DeviceManager())
}