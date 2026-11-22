//
//  CustomCalendarView.swift
//  ios_watchme_v9
//
//  The calendar the home's date header opens: pick a day; the days with a recording carry a
//  dot. No score in the cells: a number next to the date was read as part of it (2026-11-22).
//

import SwiftUI
import Supabase

struct CustomCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    @EnvironmentObject var deviceManager: DeviceManager

    @State private var displayMonth = Date()
    /// local_date (yyyy-MM-dd) of the shown month's days that have a recording
    @State private var recordedDays: Set<String> = []

    private var calendar: Calendar { deviceManager.deviceCalendar }
    private var timezone: TimeZone { deviceManager.selectedDeviceTimezone }

    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: displayMonth)?.start ?? displayMonth
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(displayMonth, equalTo: Date(), toGranularity: .month)
    }

    /// The month as weeks of seven, nil for the blanks before the 1st and after the last day.
    private var cells: [Date?] {
        let leading = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        var days: [Date?] = Array(repeating: nil, count: leading)
        days += (0..<count).map { calendar.date(byAdding: .day, value: $0, to: monthStart) }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private var weekdaySymbols: [String] {
        let symbols = ["日", "月", "火", "水", "木", "金", "土"]
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var body: some View {
        VStack(spacing: 16) {
            header

            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(white: 0.45))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }

            HStack(spacing: 6) {
                Circle().fill(Color.accentTeal).frame(width: 5, height: 5)
                Text("録音がある日")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.5))
                Spacer()
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.darkBase)
        .preferredColorScheme(.dark)
        .task(id: displayMonth) { await loadRecordedDays() }
        .onAppear { displayMonth = selectedDate }
    }

    // MARK: Parts

    private var header: some View {
        HStack(spacing: 4) {
            monthArrow("chevron.left", enabled: true) { moveMonth(-1) }
            Text(monthTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .monospacedDigit()
                .frame(minWidth: 120)
            monthArrow("chevron.right", enabled: !isCurrentMonth) { moveMonth(1) }
            Spacer()
            CloseButton { isPresented = false }
        }
    }

    private func monthArrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(enabled ? .white : Color(white: 0.25))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > Date()
        let hasRecording = recordedDays.contains(LocalDate.string(from: date, timezone: timezone))

        return Button {
            selectedDate = date
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { isPresented = false }
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: isSelected || isToday ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundColor(isSelected ? .darkBase : isFuture ? Color(white: 0.25) : isToday ? .accentTeal : .white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(isSelected ? Color.accentTeal : Color.clear))
                Circle()
                    .fill(Color.accentTeal)
                    .frame(width: 5, height: 5)
                    .opacity(hasRecording ? 1 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    // MARK: Data

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = timezone
        return formatter.string(from: displayMonth)
    }

    private func moveMonth(_ by: Int) {
        if let month = calendar.date(byAdding: .month, value: by, to: displayMonth) {
            displayMonth = month
        }
    }

    private func loadRecordedDays() async {
        guard let deviceId = deviceManager.selectedDeviceID,
              let interval = calendar.dateInterval(of: .month, for: displayMonth),
              let last = calendar.date(byAdding: .day, value: -1, to: interval.end) else { return }
        struct Row: Decodable { let local_date: String? }
        let rows: [Row] = (try? await SupabaseClientManager.shared.client
            .from("spot_results")
            .select("local_date")
            .eq("device_id", value: deviceId)
            .gte("local_date", value: LocalDate.string(from: interval.start, timezone: timezone))
            .lte("local_date", value: LocalDate.string(from: last, timezone: timezone))
            .execute()
            .value) ?? []
        recordedDays = Set(rows.compactMap(\.local_date))
    }
}
