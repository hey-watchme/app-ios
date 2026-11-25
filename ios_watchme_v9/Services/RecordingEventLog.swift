//
//  RecordingEventLog.swift
//  ios_watchme_v9
//
//  What happened to the microphone during recordings, in a file on the device:
//  Documents/recording-events.log. When a recording stops unexpectedly this says why
//  (interruption and its reason, route changes, resume attempts, the watchdog) without
//  a USB cable or the system log. Read it over Wi-Fi with
//  `xcrun devicectl device copy from ... --source Documents/recording-events.log`.
//  Kept to about the last 512 KB. Also sent to the unified log (subsystem com.watchme.watchme,
//  category recording).
//

import Foundation
import os

enum RecordingEventLog {
    static let url = UploadJournal.documentsDirectory.appendingPathComponent("recording-events.log")
    private static let maxBytes = 512 * 1024
    private static let logger = Logger(subsystem: "com.watchme.watchme", category: "recording")
    private static let queue = DispatchQueue(label: "com.watchme.recording-event-log")
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = .current
        return f
    }()

    static func write(_ message: String) {
        let line = "\(formatter.string(from: Date())) \(message)\n"
        logger.notice("\(message, privacy: .public)")
        queue.async {
            guard let data = line.data(using: .utf8) else { return }
            let manager = FileManager.default
            if let size = (try? manager.attributesOfItem(atPath: url.path)[.size]) as? Int, size > maxBytes,
               let old = try? Data(contentsOf: url) {
                // Keep the newer half.
                try? old.suffix(maxBytes / 2).write(to: url, options: .atomic)
            }
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}
