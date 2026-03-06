//
//  LocalDate.swift
//  ios_watchme_v9
//
//  Home dashboard local_date helpers
//

import Foundation

enum LocalDate {
    static func formatter(timezone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar(timezone: timezone)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timezone
        return formatter
    }

    static func calendar(timezone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar
    }

    static func string(from date: Date, timezone: TimeZone) -> String {
        formatter(timezone: timezone).string(from: date)
    }

    static func date(from localDate: String, timezone: TimeZone) -> Date? {
        formatter(timezone: timezone).date(from: localDate)
    }

    static func today(timezone: TimeZone) -> String {
        string(from: Date(), timezone: timezone)
    }

    static func addingDays(_ days: Int, to localDate: String, timezone: TimeZone) -> String? {
        guard let date = date(from: localDate, timezone: timezone) else { return nil }
        guard let shiftedDate = calendar(timezone: timezone).date(byAdding: .day, value: days, to: date) else {
            return nil
        }
        return string(from: shiftedDate, timezone: timezone)
    }

    static func trailingDays(endingAt endLocalDate: String, count: Int, timezone: TimeZone) -> [String] {
        guard count > 0, let endDate = date(from: endLocalDate, timezone: timezone) else {
            return []
        }

        let calendar = calendar(timezone: timezone)
        guard let startDate = calendar.date(byAdding: .day, value: -(count - 1), to: endDate) else {
            return [endLocalDate]
        }

        var dates: [String] = []
        var currentDate = startDate

        while currentDate <= endDate {
            dates.append(string(from: currentDate, timezone: timezone))
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return dates
    }
}
