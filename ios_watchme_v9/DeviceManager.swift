//
//  DeviceManager.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/07/04.
//

import SwiftUI
import Foundation
import UIKit
import Supabase

// デバイス登録管理クラス
class DeviceManager: ObservableObject {
    // MARK: - Constants
    static let sampleDeviceID = "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d"  // サンプルデバイスID（全ユーザー共通）

    // MARK: - State Management（権限ベース設計 - シンプル化）
    enum DeviceState: Equatable {
        case idle                       // 初期状態（未初期化）
        case loading                    // デバイス情報取得中
        case available([Device])        // デバイスあり（0個以上、サンプル含む）
        case error(String)              // エラー
    }

    @Published var state: DeviceState = .idle

    @Published var selectedDeviceID: String? = nil

    // Selected device's subject (computed from selectedDeviceID - Single Source of Truth)
    var selectedSubject: Subject? {
        guard let selectedDeviceID = selectedDeviceID else { return nil }
        return devices.first(where: { $0.device_id == selectedDeviceID })?.subject
    }

    // デバイスリストを状態から取得
    var devices: [Device] {
        if case .available(let devices) = state {
            return devices
        }
        return []
    }



    var hasDevices: Bool {
        !devices.isEmpty
    }

    // デモデバイスを除外した実際のデバイスリスト
    var realDevices: [Device] {
        devices.filter { !$0.isDemo }
    }

    // 実際のデバイスが存在するかどうか
    var hasRealDevices: Bool {
        !realDevices.isEmpty
    }

    var isViewingSample: Bool {
        selectedDeviceID == DeviceManager.sampleDeviceID
    }

    // MARK: - State-based Helper Properties (SSOT)

    /// Whether the device manager is ready to use (has loaded devices and selected one)
    var isReady: Bool {
        guard case .available = state else { return false }
        return selectedDeviceID != nil
    }

    /// Whether the device manager is currently loading
    var isLoadingDevices: Bool {
        if case .loading = state { return true }
        return false
    }

    /// Whether the device manager has encountered an error
    var hasError: Bool {
        if case .error = state { return true }
        return false
    }

    // UserDefaults キー
    private let selectedDeviceIDKey = "watchme_selected_device_id"  // 選択中のデバイスID永続化用


    init() {
        let startTime = Date()
        print("⏱️ [DM-INIT] DeviceManager初期化開始")

        restoreSelectedDevice()
        print("⏱️ [DM-INIT] 選択デバイス復元完了: \(Date().timeIntervalSince(startTime))秒")

        // APNsトークン受信の監視
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("APNsTokenReceived"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let token = notification.userInfo?["token"] as? String else { return }
            self?.saveAPNsTokenToSupabase(token)
        }
        print("⏱️ [DM-INIT] APNsトークン監視開始")

        print("⏱️ [DM-INIT] DeviceManager初期化完了: \(Date().timeIntervalSince(startTime))秒")
    }

    // MARK: - Public API (Simplified Design)

    /// Load devices for a user and update state
    func loadDevices(for userId: String) async {
        await MainActor.run {
            state = .loading
        }

        print("🚀 DeviceManager: Loading devices for user \(userId)")

        do {
            // Fetch devices from Supabase
            let devices = try await fetchDevicesFromSupabase(userId: userId)

            // Update state
            await MainActor.run {
                state = .available(devices)
            }

            print("✅ Loaded \(devices.count) device(s)")

            // Determine selected device if not set or invalid
            await MainActor.run {
                if selectedDeviceID == nil || !devices.contains(where: { $0.device_id == selectedDeviceID }) {
                    selectedDeviceID = determineDefaultDevice(from: devices)
                    print("📱 Selected device: \(selectedDeviceID ?? "none")")
                }
            }

        } catch {
            print("❌ Failed to load devices: \(error)")
            await MainActor.run {
                state = .error(error.localizedDescription)
            }
        }
    }

    /// Register a new device and return its ID
    @discardableResult
    func registerDevice(userId: String) async throws -> String {
        print("📱 DeviceManager: Registering new device for user \(userId)")

        let deviceId = try await registerDeviceToSupabase(userId: userId)

        print("✅ Device registered: \(deviceId)")
        return deviceId
    }

    /// Select a device by ID
    func selectDevice(_ deviceId: String?) {
        selectedDeviceID = deviceId
        if let deviceId = deviceId {
            UserDefaults.standard.set(deviceId, forKey: selectedDeviceIDKey)
            print("📱 Device selected: \(deviceId)")
        } else {
            UserDefaults.standard.removeObject(forKey: selectedDeviceIDKey)
            print("📱 Device selection cleared")
        }
    }
    
    // MARK: - Private Helper Functions

    /// Register device to Supabase and return device ID
    private func registerDeviceToSupabase(userId: String) async throws -> String {
        // Step 1: Register to devices table
        let timezone = TimeZone.current.identifier
        print("🌍 Device timezone: \(timezone)")

        let deviceData = DeviceInsert(
            device_type: "ios",
            timezone: timezone
        )

        let response: [Device] = try await supabase
            .from("devices")
            .upsert(deviceData)
            .select()
            .execute()
            .value

        guard let device = response.first else {
            throw DeviceRegistrationError.noDeviceReturned
        }

        let deviceId = device.device_id
        print("✅ Step 1: Device registered: \(deviceId)")

        // Step 2: Register user-device relationship
        let userDeviceRelation = UserDeviceInsert(
            user_id: userId,
            device_id: deviceId,
            role: "owner"
        )

        try await supabase
            .from("user_devices")
            .insert(userDeviceRelation, returning: .minimal)
            .execute()

        print("✅ Step 2: User-device relationship registered")

        // Step 3: Add sample device (best-effort)
        let sampleDeviceRelation = UserDeviceInsert(
            user_id: userId,
            device_id: DeviceManager.sampleDeviceID,
            role: "viewer"
        )

        do {
            try await supabase
                .from("user_devices")
                .insert(sampleDeviceRelation, returning: .minimal)
                .execute()
            print("✅ Step 3: Sample device added")
        } catch {
            print("⚠️ Step 3: Sample device already exists (skipped)")
        }

        // Step 4: Generate QR code (non-blocking)
        Task {
            do {
                let qrCodeUrl = try await QRCodeService.shared.generateQRCode(for: deviceId)
                print("✅ QR code generated: \(qrCodeUrl)")
            } catch {
                print("⚠️ QR code generation failed: \(error)")
            }
        }

        return deviceId
    }

    /// Fetch devices from Supabase
    private func fetchDevicesFromSupabase(userId: String) async throws -> [Device] {
        print("📡 Fetching devices from Supabase for user: \(userId)")

        // Fetch user-device relationships
        let userDevices: [UserDevice] = try await supabase
            .from("user_devices")
            .select("*")
            .eq("user_id", value: userId)
            .execute()
            .value

        print("📊 Found \(userDevices.count) user-device relationship(s)")

        guard !userDevices.isEmpty else {
            return []
        }

        let deviceIds = userDevices.map { $0.device_id }

        // Fetch devices with subjects
        var devices: [Device] = try await supabase
            .from("devices")
            .select("*, subjects(*)")
            .in("device_id", values: deviceIds)
            .execute()
            .value

        // Attach roles to devices
        for i in 0..<devices.count {
            if let userDevice = userDevices.first(where: { $0.device_id == devices[i].device_id }) {
                devices[i].role = userDevice.role
            }
        }

        print("✅ Fetched \(devices.count) device(s)")
        return devices
    }

    /// Determine default device from a list
    private func determineDefaultDevice(from devices: [Device]) -> String? {
        // 1. Check saved selection
        if let saved = UserDefaults.standard.string(forKey: selectedDeviceIDKey),
           devices.contains(where: { $0.device_id == saved }) {
            print("📱 Using saved device selection: \(saved)")
            return saved
        }

        // 2. Prefer owner real device (exclude demo)
        if let owner = devices.first(where: { $0.role == "owner" && !$0.isDemo }) {
            print("📱 Selected owner device: \(owner.device_id)")
            return owner.device_id
        }

        // 3. Use first real device (exclude demo)
        if let first = devices.first(where: { !$0.isDemo }) {
            print("📱 Selected first real device: \(first.device_id)")
            return first.device_id
        }

        // 4. No real devices available
        print("📱 No real devices available. Selection remains nil.")
        return nil
    }
    

    // MARK: - Deprecated (Old initialization logic removed)
    // MARK: - サンプルデバイス選択（DB連携済みのみ）
    @discardableResult
    func selectSampleDevice() -> Bool {
        print("👤 サンプルデバイス選択開始（DB連携済みのみ）")

        // DB上で連携済みの demo デバイスのみ選択する（ローカル疑似注入はしない）
        if let sample = devices.first(where: { $0.isDemo }) {
            selectDevice(sample.device_id)
            print("✅ サンプルデバイス選択完了: \(sample.device_id)")
            return true
        }

        // 互換性のため、固定IDが存在する場合はそれを選択（型がdemoでないケースにも対応）
        if devices.contains(where: { $0.device_id == DeviceManager.sampleDeviceID }) {
            selectDevice(DeviceManager.sampleDeviceID)
            print("✅ サンプルデバイス選択完了（固定ID）: \(DeviceManager.sampleDeviceID)")
            return true
        }

        print("⚠️ 連携済みのサンプルデバイスが見つかりません")
        return false
    }

    // 後方互換性のため（非推奨）
    @available(*, deprecated, message: "Use selectSampleDevice() instead")
    func selectSampleDeviceForGuest() {
        _ = selectSampleDevice()
    }

    // MARK: - 状態クリア（権限ベース設計）
    @MainActor
    func clearState() {
        let clearStart = Date()
        print("⏱️ [DM-CLEAR] 状態クリア開始")

        state = .idle
        selectedDeviceID = nil

        // UserDefaultsに保存されたデバイスIDもクリア
        UserDefaults.standard.removeObject(forKey: selectedDeviceIDKey)

        print("⏱️ [DM-CLEAR] 状態クリア完了: \(Date().timeIntervalSince(clearStart))秒")
    }

    // 状態リセット（ログイン時に使用）
    @MainActor
    func resetState() {
        print("🔄 DeviceManager: 状態リセット（Full Access Mode用）")
        self.state = .idle
        self.selectedDeviceID = nil
        UserDefaults.standard.removeObject(forKey: selectedDeviceIDKey)
    }
    
    // 内部用のデバイス取得関数（エラーをthrowする）
    private func fetchUserDevicesInternal(for userId: String) async throws -> [Device] {
        print("📡 Fetching user devices for userId: \(userId)")

        // 📊 Phase 2-B: セッション確認を削除（トークンリフレッシュ済みのため不要）
        // 認証状態は UserAccountManager で既に確認済み

        // Step 1: user_devicesテーブルからデータを取得
        let userDevices: [UserDevice] = try await supabase
            .from("user_devices")
            .select("*")
            .eq("user_id", value: userId)
            .execute()
            .value

        print("📊 Found \(userDevices.count) user-device relationships")

        if userDevices.isEmpty {
            return []
        }

        // Step 2: device_idのリストを作成してdevicesテーブルから詳細を取得
        let deviceIds = userDevices.map { $0.device_id }

        // Step 3: devicesテーブルから詳細情報を取得（subjects情報もJOINで一括取得）
        // 🚀 パフォーマンス最適化: subjects情報を同時に取得することで、後続のRPC呼び出しを削減
        // 🔧 subjects()内のnotesカラムを明示的に指定してnotesが確実に取得されるようにする
        var devices: [Device] = try await supabase
            .from("devices")
            .select("*, subjects(subject_id, name, age, gender, avatar_url, notes, prefecture, city, created_by_user_id, created_at, updated_at)")
            .in("device_id", values: deviceIds)
            .execute()
            .value

        // Step 4: roleの情報をデバイスに付与 + デバッグログ
        for i in devices.indices {
            if let userDevice = userDevices.first(where: { $0.device_id == devices[i].device_id }) {
                devices[i].role = userDevice.role
            }

            // デバッグ: デバイスごとにSubject情報を確認
            let device = devices[i]
            print("🔍 Device[\(i)]: \(device.device_id) (type: \(device.device_type))")
            print("   subject_id: \(device.subject_id ?? "nil")")
            print("   subject.name: \(device.subject?.name ?? "nil")")
            print("   subject.avatarUrl: \(device.subject?.avatarUrl ?? "nil")")
        }

        return devices
    }

    // サンプルデバイス取得関数（内部用）
    private func fetchSampleDeviceInternal() async throws -> Device? {
        print("📡 Fetching sample device: \(DeviceManager.sampleDeviceID)")

        let devices: [Device] = try await supabase
            .from("devices")
            .select("*, subjects(subject_id, name, age, gender, avatar_url, notes, prefecture, city, created_by_user_id, created_at, updated_at)")
            .eq("device_id", value: DeviceManager.sampleDeviceID)
            .execute()
            .value

        if let device = devices.first {
            print("✅ Sample device fetched")
            print("🔍 Sample device subject_id: \(device.subject_id ?? "nil")")
            print("🔍 Sample device subject: \(device.subject?.name ?? "nil")")
            print("🔍 Sample device subject.avatarUrl: \(device.subject?.avatarUrl ?? "nil")")
            return device
        } else {
            print("⚠️ Sample device not found")
            return nil
        }
    }
    
    // MARK: - ユーザーのデバイスを取得（後方互換性）
    // Deprecated: Use loadDevices(for:) instead
    @available(*, deprecated, message: "Use loadDevices(for:) instead")
    func fetchUserDevices(for userId: String) async {
        await loadDevices(for: userId)
    }

    // MARK: - Device Selection (removed duplicate, using simplified version from Public API)
    
    // 後方互換性のため（非推奨）
    @available(*, deprecated, message: "Use resetState() instead")
    @MainActor
    func resetToIdleState() {
        resetState()
    }
    
    // MARK: - 選択中デバイスの復元
    private func restoreSelectedDevice() {
        if let savedDeviceId = UserDefaults.standard.string(forKey: selectedDeviceIDKey) {
            selectedDeviceID = savedDeviceId
            print("📱 Restored selected device: \(savedDeviceId)")
        }
    }
    
    // MARK: - デバイス情報取得
    func getDeviceInfo() -> DeviceInfo? {
        guard let deviceID = selectedDeviceID else {
            return nil
        }

        return DeviceInfo(
            deviceID: deviceID,
            deviceType: "ios"
        )
    }
    
    // MARK: - サンプルデバイス判定
    /// サンプルデバイスが選択されているかどうか
    var isSampleDeviceSelected: Bool {
        selectedDeviceID == DeviceManager.sampleDeviceID
    }

    /// 選択中のデバイスがデモデバイス（device_type == "demo"）かどうか
    var isDemoDeviceSelected: Bool {
        guard let deviceId = selectedDeviceID,
              let device = devices.first(where: { $0.device_id == deviceId }) else {
            return false
        }
        return device.isDemo
    }

    // MARK: - FAB表示判定
    /// 選択中のデバイスタイプがobserverの場合はFABを非表示
    var shouldShowFAB: Bool {
        guard let deviceId = selectedDeviceID else {
            return false  // デバイス未選択の場合はFABを非表示
        }

        // サンプルデバイスの場合（device_type = "observer"）
        if deviceId == DeviceManager.sampleDeviceID {
            return false  // observerなのでFABを非表示
        }

        // devicesから選択中のデバイスを取得
        guard let device = devices.first(where: { $0.device_id == deviceId }) else {
            return false  // デバイスが見つからない場合はFABを非表示
        }

        // device_typeが "observer" の場合のみFABを非表示
        // それ以外（ios, android, その他）の場合は表示
        return device.device_type.lowercased() != "observer"
    }
    
    // MARK: - タイムゾーン関連
    /// 選択中のデバイスのタイムゾーンを取得
    var selectedDeviceTimezone: TimeZone {
        // 選択されたデバイスIDがあればそのタイムゾーンを返す
        if let deviceId = selectedDeviceID,
           let device = devices.first(where: { $0.device_id == deviceId }),
           let timezoneString = device.timezone,
           let timezone = TimeZone(identifier: timezoneString) {
            return timezone
        }

        // フォールバック：現在のデバイスのタイムゾーン
        return TimeZone.current
    }

    /// デバイスのタイムゾーンを考慮したCalendarを取得
    var deviceCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = selectedDeviceTimezone
        return calendar
    }

    /// 指定したデバイスIDのタイムゾーンを取得
    func getTimezone(for deviceId: String) -> TimeZone {
        if let device = devices.first(where: { $0.device_id == deviceId }),
           let timezoneString = device.timezone,
           let timezone = TimeZone(identifier: timezoneString) {
            return timezone
        }
        return TimeZone.current
    }
    
    // MARK: - QRコードによるデバイス追加
    // TODO: 将来的にQRコードにはデバイスIDとタイムゾーンの両方を含める必要があります
    // 現在はデバイスIDのみですが、後日以下の対応が必要です：
    // 1. QRコード生成時にタイムゾーン情報も含める
    // 2. スキャン時にデバイスIDとタイムゾーンの両方を取得
    // 3. デバイス追加時にタイムゾーンもDBに保存
    func addDeviceByQRCode(_ deviceId: String, for userId: String) async throws {
        // 既に追加済みかチェック
        if devices.contains(where: { $0.device_id == deviceId }) {
            throw DeviceAddError.alreadyAdded
        }
        
        // まずdevicesテーブルにデバイスが存在するか確認
        do {
            let existingDevices: [Device] = try await supabase
                .from("devices")
                .select("*")
                .eq("device_id", value: deviceId)
                .execute()
                .value
            
            if existingDevices.isEmpty {
                throw DeviceAddError.deviceNotFound
            }
            
            // user_devicesテーブルに追加（ownerロールで）
            let userDevice = UserDeviceInsert(
                user_id: userId,
                device_id: deviceId,
                role: "owner"  // デフォルトでownerロールに変更
            )
            
            try await supabase
                .from("user_devices")
                .insert(userDevice)
                .execute()
            
            print("✅ Device added via QR code: \(deviceId)")
            
            // デバイス一覧を再取得
            await fetchUserDevices(for: userId)
            
        } catch {
            print("❌ Failed to add device via QR code: \(error)")
            throw error
        }
    }
    
    // MARK: - デバイス連携解除
    func unlinkDevice(_ deviceId: String) async throws {
        print("🔓 Unlinking device: \(deviceId)")
        
        // 現在のユーザーIDを取得
        guard let userId = try? await supabase.auth.session.user.id else {
            throw DeviceUnlinkError.userNotAuthenticated
        }
        
        print("📍 Attempting to delete from user_devices table")
        print("   User ID: \(userId)")
        print("   Device ID: \(deviceId)")
        
        // user_devicesテーブルから該当レコードを削除
        do {
            // まず削除前にレコードが存在するか確認
            let existingRecords: [UserDevice] = try await supabase
                .from("user_devices")
                .select("*")
                .eq("user_id", value: userId)
                .eq("device_id", value: deviceId)
                .execute()
                .value
            
            print("🔍 Found \(existingRecords.count) records to delete")
            
            if existingRecords.isEmpty {
                print("⚠️ No records found to delete")
                throw DeviceUnlinkError.unlinkFailed("削除対象のデバイス連携が見つかりません")
            }
            
            // 削除実行
            let deleteResponse = try await supabase
                .from("user_devices")
                .delete()
                .eq("user_id", value: userId)
                .eq("device_id", value: deviceId)
                .execute()
            
            print("🔧 Delete response status: \(deleteResponse.status)")
            
            // 削除後に確認
            let verifyRecords: [UserDevice] = try await supabase
                .from("user_devices")
                .select("*")
                .eq("user_id", value: userId)
                .eq("device_id", value: deviceId)
                .execute()
                .value
            
            if !verifyRecords.isEmpty {
                print("❌ Delete failed - record still exists!")
                throw DeviceUnlinkError.unlinkFailed("デバイス連携の削除に失敗しました")
            }
            
            print("✅ Successfully unlinked device: \(deviceId)")

            // このデバイスを他のユーザーが参照しているかチェック
            let remainingReferences: [UserDevice] = try await supabase
                .from("user_devices")
                .select("*")
                .eq("device_id", value: deviceId)
                .execute()
                .value

            print("🔍 Remaining references for device \(deviceId): \(remainingReferences.count)")

            // 誰も参照していない場合、devicesテーブルのstatusをinactiveに更新
            if remainingReferences.isEmpty {
                print("⚠️ No users referencing this device. Updating status to inactive...")

                // devicesテーブルのstatusを更新
                struct DeviceStatusUpdate: Codable {
                    let status: String
                }

                let statusUpdate = DeviceStatusUpdate(status: "inactive")

                try await supabase
                    .from("devices")
                    .update(statusUpdate)
                    .eq("device_id", value: deviceId)
                    .execute()

                print("✅ Device status updated to inactive")
            } else {
                print("ℹ️ Device still referenced by \(remainingReferences.count) user(s), keeping status as is")
            }

            // ローカルのデバイスリストから削除
            await MainActor.run {
                var updatedDevices = devices
                updatedDevices.removeAll { $0.device_id == deviceId }
                self.state = .available(updatedDevices)

                // 選択中のデバイスが削除された場合、選択をクリア
                if selectedDeviceID == deviceId {
                    selectedDeviceID = nil
                    UserDefaults.standard.removeObject(forKey: selectedDeviceIDKey)

                    // 別の実デバイスがある場合のみ自動選択
                    if let fallbackDeviceId = determineDefaultDevice(from: updatedDevices) {
                        selectDevice(fallbackDeviceId)
                    }
                }
            }

            print("✅ Device list updated after unlinking")
            
        } catch {
            print("❌ Failed to unlink device: \(error)")
            throw DeviceUnlinkError.unlinkFailed(error.localizedDescription)
        }
    }

    // MARK: - APNsトークン保存

    private func saveAPNsTokenToSupabase(_ token: String) {
        // ユーザーIDを取得
        guard let userId = UserDefaults.standard.string(forKey: "current_user_id") else {
            print("⚠️ [PUSH] ユーザーIDが見つかりません")
            print("   トークンを一時保存します。ログイン後に自動保存されます")
            UserDefaults.standard.set(token, forKey: "pending_apns_token")
            return
        }

        // Determine APNs environment based on build configuration
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif

        Task {
            do {
                let supabase = SupabaseClientManager.shared.client

                try await supabase
                    .from("users")
                    .update([
                        "apns_token": token,
                        "apns_environment": environment
                    ])
                    .eq("user_id", value: userId)
                    .execute()

                print("✅ [PUSH] APNsトークン保存成功: userId=\(userId), token=\(token.prefix(20))..., environment=\(environment)")

                // 一時保存を削除
                UserDefaults.standard.removeObject(forKey: "pending_apns_token")
            } catch {
                print("❌ [PUSH] APNsトークン保存失敗: \(error)")
            }
        }
    }

}

// MARK: - データモデル

// デバイス情報
struct DeviceInfo {
    let deviceID: String
    let deviceType: String
}

// Supabase Insert用データモデル
struct DeviceInsert: Codable {
    let device_type: String
    let timezone: String // IANAタイムゾーン識別子（例: "Asia/Tokyo"）
}

// Supabase Response用データモデル
struct Device: Codable, Equatable {
    let device_id: String
    let device_type: String
    let timezone: String? // IANAタイムゾーン識別子（例: "Asia/Tokyo"）
    let owner_user_id: String?
    let subject_id: String?
    let created_at: String? // デバイス登録日時
    let status: String? // デバイスステータス（active, inactive等）
    let qr_code_url: String? // QRコード画像のS3 URL
    // user_devicesテーブルから取得した場合のrole情報を保持
    var role: String?
    // JOIN取得した場合のsubject情報を保持（パフォーマンス最適化）
    var subject: Subject?

    // MARK: - Permission Helpers

    // Demo device (read-only sample data)
    var isDemo: Bool {
        return device_type == "demo"
    }

    // Can edit device settings (timezone, etc.)
    var canEditDevice: Bool {
        // Owner can edit (except demo devices)
        if role == "owner" && !isDemo {
            return true
        }
        return false
    }

    // Can delete device from database
    var canDeleteDevice: Bool {
        // Only non-demo owners can delete
        return role == "owner" && !isDemo
    }

    // Can unlink device from user_devices (disconnect)
    var canUnlinkDevice: Bool {
        // Anyone with a role can unlink (including demo viewers)
        return role != nil
    }

    // Can view device details
    var canViewDeviceDetails: Bool {
        // All devices can be viewed
        return true
    }

    // Can edit subject
    var canEditSubject: Bool {
        // Owner can edit subject (except demo devices)
        return role == "owner" && !isDemo
    }

    // Can view subject details
    var canViewSubjectDetails: Bool {
        // All subjects can be viewed
        return true
    }

    // Custom decoding to handle Supabase JOIN response
    enum CodingKeys: String, CodingKey {
        case device_id, device_type, timezone, owner_user_id, subject_id
        case created_at, status, qr_code_url, role
        case subjects  // Supabase returns this as an array
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        device_id = try container.decode(String.self, forKey: .device_id)
        device_type = try container.decode(String.self, forKey: .device_type)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        owner_user_id = try container.decodeIfPresent(String.self, forKey: .owner_user_id)
        subject_id = try container.decodeIfPresent(String.self, forKey: .subject_id)
        created_at = try container.decodeIfPresent(String.self, forKey: .created_at)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        qr_code_url = try container.decodeIfPresent(String.self, forKey: .qr_code_url)
        role = try container.decodeIfPresent(String.self, forKey: .role)

        // Decode subjects (many-to-one relationship returns single object, not array)
        if let singleSubject = try? container.decode(Subject.self, forKey: .subjects) {
            // Many-to-one: single object
            subject = singleSubject
        } else if let subjects = try? container.decode([Subject].self, forKey: .subjects),
                  let firstSubject = subjects.first {
            // Fallback: array (just in case)
            subject = firstSubject
        } else {
            subject = nil
        }
    }

    // Custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(device_id, forKey: .device_id)
        try container.encode(device_type, forKey: .device_type)
        try container.encodeIfPresent(timezone, forKey: .timezone)
        try container.encodeIfPresent(owner_user_id, forKey: .owner_user_id)
        try container.encodeIfPresent(subject_id, forKey: .subject_id)
        try container.encodeIfPresent(created_at, forKey: .created_at)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(qr_code_url, forKey: .qr_code_url)
        try container.encodeIfPresent(role, forKey: .role)
        if let subject = subject {
            try container.encode([subject], forKey: .subjects)
        }
    }

    // Manual initializer for non-JOIN cases
    init(device_id: String, device_type: String, timezone: String?, owner_user_id: String?, subject_id: String?, created_at: String?, status: String?, qr_code_url: String? = nil, role: String? = nil, subject: Subject? = nil) {
        self.device_id = device_id
        self.device_type = device_type
        self.timezone = timezone
        self.owner_user_id = owner_user_id
        self.subject_id = subject_id
        self.created_at = created_at
        self.status = status
        self.qr_code_url = qr_code_url
        self.role = role
        self.subject = subject
    }
}

// user_devicesテーブル用のモデル
struct UserDevice: Codable {
    let user_id: String
    let device_id: String
    let role: String
    let created_at: String?
}

// user_devicesテーブルへのInsert用モデル
struct UserDeviceInsert: Codable {
    let user_id: String
    let device_id: String
    let role: String
}

// エラータイプ
enum DeviceRegistrationError: Error {
    case noDeviceReturned
    case supabaseNotAvailable
    case registrationFailed
    
    var localizedDescription: String {
        switch self {
        case .noDeviceReturned:
            return "デバイス情報の取得に失敗しました"
        case .supabaseNotAvailable:
            return "Supabaseライブラリが利用できません"
        case .registrationFailed:
            return "デバイス登録処理に失敗しました"
        }
    }
}

// DeviceManagerのエラー
enum DeviceManagerError: Error, LocalizedError {
    case notAuthenticated
    case fetchFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "認証が必要です"
        case .fetchFailed(let message):
            return "デバイス取得エラー: \(message)"
        }
    }
}

// デバイス追加エラー
enum DeviceAddError: Error, LocalizedError {
    case invalidDeviceId
    case deviceNotFound
    case alreadyAdded
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidDeviceId:
            return "無効なデバイスIDです"
        case .deviceNotFound:
            return "デバイスが見つかりません"
        case .alreadyAdded:
            return "このデバイスは既に追加されています"
        case .unauthorized:
            return "デバイスの追加権限がありません"
        }
    }
}

// デバイス連携解除のエラー
enum DeviceUnlinkError: Error, LocalizedError {
    case userNotAuthenticated
    case unlinkFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "ユーザー認証が必要です"
        case .unlinkFailed(let message):
            return "デバイス連携の解除に失敗しました: \(message)"
        }
    }
}
