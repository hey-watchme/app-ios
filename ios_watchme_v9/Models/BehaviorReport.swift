//
//  BehaviorReport.swift
//  ios_watchme_v9
//
//  Created by Claude Code on 2025/07/26.
//

import Foundation

// MARK: - Behavior Event Model
struct BehaviorEvent: Codable, Identifiable {
    let count: Int
    let event: String
    
    var id: String {
        "\(event)_\(count)"
    }
}

// MARK: - Time Block Model
struct TimeBlock: Codable, Identifiable {
    let time: String
    let events: [BehaviorEvent]?
    
    var id: String {
        time
    }
    
    var isEmpty: Bool {
        events == nil || events?.isEmpty == true
    }
    
    var displayTime: String {
        // "00-00" -> "00:00"
        time.replacingOccurrences(of: "-", with: ":")
    }
    
    var hourInt: Int {
        Int(time.prefix(2)) ?? 0
    }
    
    var minuteInt: Int {
        Int(time.suffix(2)) ?? 0
    }
}

// MARK: - Behavior Report Model
struct BehaviorReport: Codable {
    let deviceId: String
    let date: String
    let summaryRanking: [BehaviorEvent]
    let timeBlocks: [String: [BehaviorEvent]?]
    
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case date
        case summaryRanking = "summary_ranking"
        case timeBlocks = "time_blocks"
    }
    
    // Helper method to get sorted time blocks
    var sortedTimeBlocks: [TimeBlock] {
        let allTimeSlots = generateAllTimeSlots()
        return allTimeSlots.map { slot in
            TimeBlock(time: slot, events: timeBlocks[slot] ?? nil)
        }
    }
    
    // Generate all 48 time slots for the day
    private func generateAllTimeSlots() -> [String] {
        var slots: [String] = []
        for hour in 0..<24 {
            for minute in [0, 30] {
                let slot = String(format: "%02d-%02d", hour, minute)
                slots.append(slot)
            }
        }
        return slots
    }
    
    // Get time blocks with data (non-empty)
    var activeTimeBlocks: [TimeBlock] {
        sortedTimeBlocks.filter { !$0.isEmpty }
    }
    
    // Get total event count for the day
    var totalEventCount: Int {
        summaryRanking.reduce(0) { $0 + $1.count }
    }
    
    // Format date for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let dateObj = formatter.date(from: date) {
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: dateObj)
        }
        return date
    }
}