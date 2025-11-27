//
//  PushNotificationManager.swift
//  ios_watchme_v9
//
//  Centralized push notification manager for scalable notification handling
//

import Foundation
import Combine

/// Centralized manager for handling all push notifications
/// Design: Single Source of Truth pattern for scalability
class PushNotificationManager: ObservableObject {
    static let shared = PushNotificationManager()

    // MARK: - Published Properties

    /// Latest notification update (SwiftUI views observe this via .onChange)
    @Published var latestUpdate: PushNotificationUpdate?

    // MARK: - Notification Types

    /// All supported push notification types (extensible)
    enum NotificationType: String {
        case refreshDashboard = "refresh_dashboard"
        // Future notification types can be added here:
        // case newMessage = "new_message"
        // case analysisComplete = "analysis_complete"
        // case systemAlert = "system_alert"
    }

    /// Push notification update payload
    struct PushNotificationUpdate: Equatable {
        let type: NotificationType
        let deviceId: String
        let date: String
        let message: String
        let timestamp: Date
        let metadata: [String: Any]?

        static func == (lhs: PushNotificationUpdate, rhs: PushNotificationUpdate) -> Bool {
            lhs.type == rhs.type &&
            lhs.deviceId == rhs.deviceId &&
            lhs.date == rhs.date &&
            lhs.message == rhs.message &&
            lhs.timestamp == rhs.timestamp
        }
    }

    // MARK: - Private Properties

    private init() {
        print("✅ [PUSH-MANAGER] PushNotificationManager initialized")
    }

    // MARK: - Public Methods

    /// Handle dashboard refresh notification
    /// - Parameters:
    ///   - deviceId: Target device ID
    ///   - date: Date string (YYYY-MM-DD)
    ///   - message: Display message for toast
    func handleDashboardUpdate(deviceId: String, date: String, message: String) {
        handleNotification(
            type: .refreshDashboard,
            deviceId: deviceId,
            date: date,
            message: message,
            metadata: nil
        )
    }

    /// Generic notification handler (for future extensibility)
    /// - Parameters:
    ///   - type: Notification type
    ///   - deviceId: Target device ID
    ///   - date: Date string
    ///   - message: Display message
    ///   - metadata: Additional metadata (optional)
    func handleNotification(
        type: NotificationType,
        deviceId: String,
        date: String,
        message: String,
        metadata: [String: Any]?
    ) {
        DispatchQueue.main.async { [weak self] in
            let update = PushNotificationUpdate(
                type: type,
                deviceId: deviceId,
                date: date,
                message: message,
                timestamp: Date(),
                metadata: metadata
            )

            self?.latestUpdate = update

            print("📬 [PUSH-MANAGER] Notification handled:")
            print("   Type: \(type.rawValue)")
            print("   Device: \(deviceId)")
            print("   Date: \(date)")
            print("   Message: \(message)")
        }
    }

    /// Parse APNs payload and handle notification
    /// - Parameter userInfo: APNs notification payload
    /// - Returns: True if successfully handled
    func handleAPNsPayload(_ userInfo: [AnyHashable: Any]) -> Bool {
        // Extract action type
        guard let actionString = userInfo["action"] as? String,
              let type = NotificationType(rawValue: actionString) else {
            print("⚠️ [PUSH-MANAGER] Unknown notification action")
            return false
        }

        // Extract required fields
        guard let deviceId = userInfo["device_id"] as? String,
              let date = userInfo["date"] as? String else {
            print("❌ [PUSH-MANAGER] Missing required fields (device_id, date)")
            return false
        }

        // Extract message from aps payload
        let message: String
        if let aps = userInfo["aps"] as? [String: Any],
           let alert = aps["alert"] as? [String: Any],
           let body = alert["body"] as? String {
            message = body
        } else {
            message = "データが更新されました"
            print("⚠️ [PUSH-MANAGER] Message not found in payload, using default")
        }

        // Handle notification
        handleNotification(
            type: type,
            deviceId: deviceId,
            date: date,
            message: message,
            metadata: userInfo as? [String: Any]
        )

        return true
    }

    /// Clear latest update (for cleanup)
    func clearUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.latestUpdate = nil
        }
    }
}
