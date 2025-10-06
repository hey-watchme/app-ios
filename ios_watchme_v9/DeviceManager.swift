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

    // MARK: - State Management
    enum State: Equatable {
        case idle           // 初期状態
        case loading        // デバイスリストを取得中
        case ready          // 準備完了（データ取得可能）
        case noDevices      // ユーザーに紐づくデバイスが存在しない
        case error(String)  // エラーが発生
        
        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.ready, .ready), (.noDevices, .noDevices):
                return true
            case (.error(let l), .error(let r)):
                return l == r
            default:
                return false
            }
        }
    }
    
    @Published var state: State = .idle
    @Published var userDevices: [Device] = []  // ユーザーの全デバイス
    @Published var selectedDeviceID: String? = nil {  // 選択中のデバイスID
        didSet {
            print("✅ DeviceManager: selectedDeviceID changed to \(selectedDeviceID ?? "nil")")
            // デバイスが選択されたら、準備完了状態に遷移
            if selectedDeviceID != nil && !userDevices.isEmpty {
                state = .ready
            }
        }
    }
    @Published var registrationError: String? = nil
    @Published var isLoading: Bool = false
    
    // Supabase設定（URLとキーは参照用に残しておく）
    private let supabaseURL = "https://qvtlwotzuzbavrzqhyvt.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dGx3b3R6dXpiYXZyenFoeXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzODAzMzAsImV4cCI6MjA2Njk1NjMzMH0.g5rqrbxHPw1dKlaGqJ8miIl9gCXyamPajinGCauEI3k"
    
    // UserDefaults キー
    private let selectedDeviceIDKey = "watchme_selected_device_id"  // 選択中のデバイスID永続化用

    init() {
        restoreSelectedDevice()
    }
    
    // MARK: - デバイス登録処理（ユーザーが明示的に登録する場合のみ使用）
    func registerDevice(userId: String) async {
        await MainActor.run {
            isLoading = true
            registrationError = nil
        }

        print("📱 Supabaseデバイス登録開始（ユーザーの明示的な操作による）")
        print("   - User ID: \(userId)")

        // Supabase直接Insert実装（完了まで待機）
        await registerDeviceToSupabase(userId: userId)
    }
    
    // MARK: - Supabase UPSERT登録（改善版）
    private func registerDeviceToSupabase(userId: String) async {
        do {
            // --- ステップ1: devicesテーブルにデバイスを登録 ---
            // iOSのIANAタイムゾーン識別子を取得
            let timezone = TimeZone.current.identifier // 例: "Asia/Tokyo"
            print("🌍 デバイスタイムゾーン: \(timezone)")

            let deviceData = DeviceInsert(
                device_type: "ios",
                timezone: timezone
            )

            // UPSERT: INSERT ON CONFLICT DO UPDATE を使用
            let response: [Device] = try await supabase
                .from("devices")
                .upsert(deviceData)
                .select()
                .execute()
                .value

            guard let device = response.first else {
                throw DeviceRegistrationError.noDeviceReturned
            }

            let newDeviceId = device.device_id
            print("✅ Step 1: Device registered/fetched: \(newDeviceId)")

            // --- ステップ2: user_devicesテーブルに所有関係を登録 ---
            let userDeviceRelation = UserDeviceInsert(
                user_id: userId,
                device_id: newDeviceId,
                role: "owner"
            )

            // 競合した場合は何もしない (ON CONFLICT DO NOTHING相当)
            do {
                try await supabase
                    .from("user_devices")
                    .insert(userDeviceRelation, returning: .minimal)
                    .execute()

                print("✅ Step 2: User-Device ownership registered for user: \(userId)")
            } catch {
                // エラーの詳細を確認
                print("❌ User-Device relation insert failed: \(error)")

                if let postgrestError = error as? PostgrestError {
                    print("   - Code: \(postgrestError.code ?? "unknown")")
                    print("   - Message: \(postgrestError.message)")
                    print("   - Detail: \(postgrestError.detail ?? "none")")
                    print("   - Hint: \(postgrestError.hint ?? "none")")

                    // RLSエラーの場合の対処法を提案
                    if postgrestError.code == "42501" {
                        print("   ⚠️ RLS Policy Error: user_devicesテーブルのRLSポリシーを確認してください")
                        print("   💡 解決方法: Supabaseダッシュボードで以下のSQLを実行してください:")
                        print("      CREATE POLICY \"Users can insert their own device associations\"")
                        print("      ON user_devices FOR INSERT")
                        print("      WITH CHECK (auth.uid() = user_id);")
                    }
                }
            }

            // 登録成功後、ユーザーのデバイス一覧を再取得
            await self.fetchUserDevices(for: userId)

            // 登録完了
            await MainActor.run {
                self.isLoading = false
                self.registrationError = nil  // エラーをクリア
            }

        } catch {
            print("❌ デバイス登録処理全体でエラー: \(error)")
            await MainActor.run {
                self.registrationError = "デバイス登録に失敗しました: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    
    // MARK: - 統合初期化処理（State管理版）
    @MainActor
    func initializeDeviceState(for userId: String) async {
        // 既に処理中、または準備完了なら何もしない
        switch state {
        case .idle, .error:
            // 処理を続行
            break
        case .loading, .ready, .noDevices:
            print("⚠️ DeviceManager: Already in state \(state), skipping initialization")
            return
        }
        
        print("🚀 DeviceManager: Starting device initialization for user \(userId)")
        self.state = .loading
        
        do {
            // デバイスリストを取得
            let devices = try await fetchUserDevicesInternal(for: userId)
            
            if devices.isEmpty {
                print("📱 DeviceManager: No devices found for user")
                self.userDevices = []
                self.selectedDeviceID = nil
                UserDefaults.standard.removeObject(forKey: selectedDeviceIDKey)
                self.state = .noDevices
            } else {
                self.userDevices = devices
                print("✅ DeviceManager: Found \(devices.count) devices")
                
                // selectedDeviceIDを決定
                determineSelectedDevice(from: devices)
                
                // 準備完了状態に遷移
                self.state = .ready
                print("🎯 DeviceManager: State is now READY with selectedDeviceID: \(selectedDeviceID ?? "nil")")
            }
        } catch {
            print("❌ DeviceManager: Failed to initialize - \(error)")
            self.state = .error(error.localizedDescription)
        }
    }
    
    // デバイス選択ロジック
    private func determineSelectedDevice(from devices: [Device]) {
        // 1. 保存された選択デバイスがある場合はそれを優先
        if let savedDeviceId = UserDefaults.standard.string(forKey: selectedDeviceIDKey),
           devices.contains(where: { $0.device_id == savedDeviceId }) {
            self.selectedDeviceID = savedDeviceId
            print("🔍 Restored previously selected device: \(savedDeviceId)")
            return
        }

        // 2. ownerロールのデバイスを優先
        let ownerDevices = devices.filter { $0.role == "owner" }
        if let firstOwnerDevice = ownerDevices.first {
            self.selectedDeviceID = firstOwnerDevice.device_id
            print("🔍 Auto-selected owner device: \(firstOwnerDevice.device_id)")
            return
        }

        // 3. viewerロールのデバイス
        let viewerDevices = devices.filter { $0.role == "viewer" }
        if let firstViewerDevice = viewerDevices.first {
            self.selectedDeviceID = firstViewerDevice.device_id
            print("🔍 Auto-selected viewer device: \(firstViewerDevice.device_id)")
            return
        }

        // 4. 最後の手段：リストの最初のデバイス
        if let firstDevice = devices.first {
            self.selectedDeviceID = firstDevice.device_id
            print("🔍 Auto-selected first device: \(firstDevice.device_id)")
        }
    }

    // MARK: - ゲストモード対応
    func selectSampleDeviceForGuest() {
        print("👤 ゲストモード: サンプルデバイスを自動選択")

        // サンプルデバイスを作成（データベースから取得しない）
        var sampleDevice = Device(
            device_id: DeviceManager.sampleDeviceID,
            device_type: "observer",
            timezone: "Asia/Tokyo",
            owner_user_id: nil,
            subject_id: nil,
            created_at: nil,
            status: "active",
            role: nil
        )
        sampleDevice.role = "viewer"

        // userDevicesリストにサンプルデバイスのみを設定
        userDevices = [sampleDevice]
        selectedDeviceID = DeviceManager.sampleDeviceID
        state = .ready

        print("✅ ゲストモード: サンプルデバイスを選択完了")
    }

    // MARK: - 状態クリア
    func clearState() {
        print("🧹 DeviceManager: 状態をクリア")
        userDevices = []
        selectedDeviceID = nil
        state = .ready  // デバイス未選択でもready状態にする（ガイド画面を表示するため）
        registrationError = nil
        isLoading = false

        // UserDefaultsに保存されたデバイスIDもクリア
        UserDefaults.standard.removeObject(forKey: selectedDeviceIDKey)

        print("✅ DeviceManager: 状態クリア完了（state = .ready）")
    }
    
    // 内部用のデバイス取得関数（エラーをthrowする）
    private func fetchUserDevicesInternal(for userId: String) async throws -> [Device] {
        print("📡 Fetching user devices for userId: \(userId)")
        
        // デバッグ: 現在の認証状態を確認
        if let currentUser = try? await supabase.auth.session.user {
            print("✅ 認証済みユーザー: \(currentUser.id)")
        } else {
            print("❌ 認証されていません - supabase.auth.session.userがnil")
            throw DeviceManagerError.notAuthenticated
        }
        
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

        // Step 3: devicesテーブルから詳細情報を取得
        var devices: [Device] = try await supabase
            .from("devices")
            .select("*")
            .in("device_id", values: deviceIds)
            .execute()
            .value

        print("📊 Fetched \(devices.count) device details")

        // Step 4: roleの情報をデバイスに付与
        for i in devices.indices {
            if let userDevice = userDevices.first(where: { $0.device_id == devices[i].device_id }) {
                devices[i].role = userDevice.role
            }
        }

        return devices
    }
    
    // MARK: - ユーザーのデバイスを取得（旧バージョン - 互換性のため残す）
    func fetchUserDevices(for userId: String) async {
        print("🔄 DeviceManager: fetchUserDevices called for user \(userId)")
        
        // 新しい初期化処理を呼び出す
        await initializeDeviceState(for: userId)
        
        // 旧コードとの互換性のため、isLoadingを更新
        await MainActor.run {
            self.isLoading = false
        }
        
        // Supabaseクライアントを使用してuser_devicesを取得
        do {
            print("📡 Fetching user devices for userId: \(userId)")
            
            // デバッグ: 現在の認証状態を確認
            if let currentUser = try? await supabase.auth.session.user {
                print("✅ 認証済みユーザー: \(currentUser.id)")
            } else {
                print("❌ 認証されていません - supabase.auth.session.userがnil")
            }
            
            // Step 1: user_devicesテーブルからデータを取得
            let userDevices: [UserDevice] = try await supabase
                .from("user_devices")
                .select("*")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            print("📊 Decoded user_devices count: \(userDevices.count)")
            for userDevice in userDevices {
                print("   - Device: \(userDevice.device_id), Role: \(userDevice.role)")
            }
            
            if userDevices.isEmpty {
                print("⚠️ DeviceManager: No user devices found.")
                await MainActor.run {
                    self.userDevices = []
                    self.isLoading = false  // ローディング状態を解除
                    self.selectedDeviceID = nil
                }
                print("➡️ DeviceManager: fetchUserDevices completed. No devices available.")
                return
            }
            
            print("📄 Found \(userDevices.count) user-device relationships")
            
            // Step 2: device_idのリストを作成してdevicesテーブルから詳細を取得
            let deviceIds = userDevices.map { $0.device_id }
            
            // Step 3: devicesテーブルから詳細情報を取得
            var devices: [Device] = try await supabase
                .from("devices")
                .select("*")
                .in("device_id", values: deviceIds)
                .execute()
                .value
            
            print("📊 Fetched \(devices.count) device details")
            
            // Step 4: roleの情報をデバイスに付与
            for i in devices.indices {
                if let userDevice = userDevices.first(where: { $0.device_id == devices[i].device_id }) {
                    devices[i].role = userDevice.role
                }
            }
            
            await MainActor.run { [devices] in
                self.userDevices = devices
                print("✅ Found \(devices.count) devices for user: \(userId)")
                
                // ownerロールのデバイスを優先的に選択
                let ownerDevices = devices.filter { $0.role == "owner" }
                let viewerDevices = devices.filter { $0.role == "viewer" }
                
                // 保存された選択デバイスがある場合はそれを優先
                if let savedDeviceId = UserDefaults.standard.string(forKey: self.selectedDeviceIDKey),
                   devices.contains(where: { $0.device_id == savedDeviceId }) {
                    self.selectedDeviceID = savedDeviceId
                    print("🔍 Restored previously selected device: \(savedDeviceId)")
                } else if let firstOwnerDevice = ownerDevices.first {
                    self.selectedDeviceID = firstOwnerDevice.device_id
                    print("🔍 Auto-selected owner device: \(firstOwnerDevice.device_id)")
                } else if let firstViewerDevice = viewerDevices.first {
                    self.selectedDeviceID = firstViewerDevice.device_id
                    print("🔍 Auto-selected viewer device: \(firstViewerDevice.device_id)")
                } else if let firstDevice = devices.first {
                    self.selectedDeviceID = firstDevice.device_id
                    print("🔍 Selected first device: \(firstDevice.device_id)")
                }
                
                print("➡️ DeviceManager: fetchUserDevices completed. Final selectedDeviceID: \(self.selectedDeviceID ?? "nil")")
            }
            
        } catch {
            print("❌ Device fetch error: \(error)")
        }
        
        // ローディング状態を解除
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    // MARK: - デバイス選択
    func selectDevice(_ deviceId: String?) {
        // nilの場合は選択を解除
        guard let deviceId = deviceId else {
            selectedDeviceID = nil
            UserDefaults.standard.removeObject(forKey: selectedDeviceIDKey)
            print("📱 Device selection cleared")

            // デバイスなし状態に遷移
            if userDevices.isEmpty {
                self.state = .noDevices
            } else {
                self.state = .ready
            }
            return
        }

        // サンプルデバイスまたはuserDevicesに含まれるデバイスの場合のみ選択可能
        let isSampleDevice = deviceId == DeviceManager.sampleDeviceID
        let isUserDevice = userDevices.contains(where: { $0.device_id == deviceId })

        if isSampleDevice || isUserDevice {
            // 一旦loadingに戻してから選択を更新
            self.state = .loading
            selectedDeviceID = deviceId
            // 選択したデバイスIDを永続化
            UserDefaults.standard.set(deviceId, forKey: selectedDeviceIDKey)

            if isSampleDevice {
                print("📱 Sample device selected: \(deviceId)")
            } else {
                print("📱 Selected device saved: \(deviceId)")
            }

            // 少し遅延を入れてからready状態に遷移（UIの更新を確実にするため）
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                self.state = .ready
                print("🎯 DeviceManager: State transitioned to READY after device selection")
            }
        }
    }
    
    // MARK: - デバイス切り替え時の状態リセット
    func resetToIdleState() {
        print("🔄 DeviceManager: Resetting to idle state")
        self.state = .idle
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

    // MARK: - FAB表示判定
    /// 選択中のデバイスタイプがobserverの場合はFABを非表示
    var shouldShowFAB: Bool {
        guard let deviceId = selectedDeviceID else {
            return true  // デバイス未選択の場合はデフォルトで表示
        }

        // サンプルデバイスの場合（device_type = "observer"）
        if deviceId == DeviceManager.sampleDeviceID {
            return false  // observerなのでFABを非表示
        }

        // userDevicesから選択中のデバイスを取得
        guard let device = userDevices.first(where: { $0.device_id == deviceId }) else {
            return true  // デバイスが見つからない場合はデフォルトで表示
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
           let device = userDevices.first(where: { $0.device_id == deviceId }),
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
        if let device = userDevices.first(where: { $0.device_id == deviceId }),
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
        if userDevices.contains(where: { $0.device_id == deviceId }) {
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
            
            print("🔧 Delete response status: \(deleteResponse.status ?? -1)")
            
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
                userDevices.removeAll { $0.device_id == deviceId }

                // 選択中のデバイスが削除された場合、選択をクリア
                if selectedDeviceID == deviceId {
                    selectedDeviceID = nil
                    UserDefaults.standard.removeObject(forKey: selectedDeviceIDKey)

                    // 別のデバイスがある場合は最初のデバイスを選択
                    if let firstDevice = userDevices.first {
                        selectDevice(firstDevice.device_id)
                    }
                }
            }

            print("✅ Device list updated after unlinking")
            
        } catch {
            print("❌ Failed to unlink device: \(error)")
            throw DeviceUnlinkError.unlinkFailed(error.localizedDescription)
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
struct Device: Codable {
    let device_id: String
    let device_type: String
    let timezone: String? // IANAタイムゾーン識別子（例: "Asia/Tokyo"）
    let owner_user_id: String?
    let subject_id: String?
    let created_at: String? // デバイス登録日時
    let status: String? // デバイスステータス（active, inactive等）
    // user_devicesテーブルから取得した場合のrole情報を保持
    var role: String?
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