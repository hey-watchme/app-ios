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
    @Published var isDeviceRegistered: Bool = false
    @Published var localDeviceIdentifier: String? = nil  // この物理デバイス自身のID
    @Published var userDevices: [Device] = []  // ユーザーの全デバイス
    @Published var selectedDeviceID: String? = nil  // 選択中のデバイスID
    @Published var registrationError: String? = nil
    @Published var isLoading: Bool = false
    
    // Supabase設定（URLとキーは参照用に残しておく）
    private let supabaseURL = "https://qvtlwotzuzbavrzqhyvt.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dGx3b3R6dXpiYXZyenFoeXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzODAzMzAsImV4cCI6MjA2Njk1NjMzMH0.g5rqrbxHPw1dKlaGqJ8miIl9gCXyamPajinGCauEI3k"
    
    // UserDefaults キー
    private let localDeviceIdentifierKey = "watchme_device_id"  // UserDefaultsのキーは互換性のため維持
    private let isRegisteredKey = "watchme_device_registered"
    private let platformIdentifierKey = "watchme_platform_identifier"
    
    init() {
        checkDeviceRegistrationStatus()
    }
    
    // MARK: - デバイス登録状態確認
    private func checkDeviceRegistrationStatus() {
        let savedDeviceID = UserDefaults.standard.string(forKey: localDeviceIdentifierKey)
        let isSupabaseRegistered = UserDefaults.standard.bool(forKey: "watchme_supabase_registered")
        
        if let deviceID = savedDeviceID, isSupabaseRegistered {
            self.localDeviceIdentifier = deviceID
            self.isDeviceRegistered = true
            print("📱 Supabaseデバイス登録確認: \(deviceID)")
        } else {
            self.isDeviceRegistered = false
            print("📱 デバイス未登録 - Supabase登録が必要")
            
            // 古いローカル登録データがあれば削除
            if UserDefaults.standard.string(forKey: localDeviceIdentifierKey) != nil {
                print("🗑️ 古いローカル登録データを削除")
                UserDefaults.standard.removeObject(forKey: localDeviceIdentifierKey)
                UserDefaults.standard.removeObject(forKey: isRegisteredKey)
                UserDefaults.standard.removeObject(forKey: platformIdentifierKey)
            }
        }
    }
    
    
    // MARK: - プラットフォーム識別子取得
    private func getPlatformIdentifier() -> String? {
        return UIDevice.current.identifierForVendor?.uuidString
    }
    
    // MARK: - デバイス登録処理（Supabase直接Insert版）
    func registerDevice(ownerUserID: String? = nil) {
        guard let platformIdentifier = getPlatformIdentifier() else {
            registrationError = "デバイス識別子の取得に失敗しました"
            print("❌ identifierForVendor取得失敗")
            return
        }
        
        isLoading = true
        registrationError = nil
        
        print("📱 Supabaseデバイス登録開始")
        print("   - Platform Identifier: \(platformIdentifier)")
        print("   - Owner User ID: \(ownerUserID ?? "ゲストユーザー")")
        
        // Supabase直接Insert実装
        registerDeviceToSupabase(platformIdentifier: platformIdentifier, ownerUserID: ownerUserID)
    }
    
    // MARK: - Supabase UPSERT登録（改善版）
    private func registerDeviceToSupabase(platformIdentifier: String, ownerUserID: String?) {
        Task { @MainActor in
            do {
                let deviceData = DeviceInsert(
                    platform_identifier: platformIdentifier,
                    device_type: "ios",
                    platform_type: "iOS",
                    owner_user_id: ownerUserID
                )
                
                // UPSERT: INSERT ON CONFLICT DO UPDATE を使用
                let response: [Device] = try await supabase
                    .from("devices")
                    .upsert(deviceData)
                    .select()
                    .execute()
                    .value
                
                if let device = response.first {
                    self.saveSupabaseDeviceRegistration(
                        deviceID: device.device_id,
                        platformIdentifier: platformIdentifier
                    )
                    self.isLoading = false
                    print("✅ デバイス情報を取得/登録完了: \(device.device_id)")
                } else {
                    throw DeviceRegistrationError.noDeviceReturned
                }
                
            } catch {
                print("❌ デバイス情報取得エラー: \(error)")
                self.registrationError = "デバイス情報の取得に失敗しました: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // MARK: - ユーザーIDを指定したSupabase登録（内部用）
    private func registerDeviceToSupabase(userId: String) async {
        guard let platformIdentifier = getPlatformIdentifier() else {
            print("❌ デバイス識別子の取得に失敗しました")
            return
        }
        
        do {
            let deviceData = DeviceInsert(
                platform_identifier: platformIdentifier,
                device_type: "ios",
                platform_type: "iOS",
                owner_user_id: userId
            )
            
            // UPSERT: INSERT ON CONFLICT DO UPDATE を使用
            let response: [Device] = try await supabase
                .from("devices")
                .upsert(deviceData)
                .select()
                .execute()
                .value
            
            if let device = response.first {
                await MainActor.run {
                    self.saveSupabaseDeviceRegistration(
                        deviceID: device.device_id,
                        platformIdentifier: platformIdentifier
                    )
                }
                print("✅ デバイス情報を取得/登録完了: \(device.device_id)")
            } else {
                throw DeviceRegistrationError.noDeviceReturned
            }
            
        } catch {
            print("❌ デバイス情報取得エラー: \(error)")
        }
    }
    
    // MARK: - Supabaseデバイス登録情報保存
    private func saveSupabaseDeviceRegistration(deviceID: String, platformIdentifier: String) {
        UserDefaults.standard.set(deviceID, forKey: localDeviceIdentifierKey)
        UserDefaults.standard.set(platformIdentifier, forKey: platformIdentifierKey)
        UserDefaults.standard.set(true, forKey: "watchme_supabase_registered")
        
        self.localDeviceIdentifier = deviceID
        self.isDeviceRegistered = true
        
        print("💾 Supabaseデバイス登録完了")
        print("   - Device ID: \(deviceID)")
        print("   - Platform Identifier: \(platformIdentifier)")
    }
    
    // MARK: - デバイス登録状態リセット（デバッグ用）
    func resetDeviceRegistration() {
        UserDefaults.standard.removeObject(forKey: localDeviceIdentifierKey)
        UserDefaults.standard.removeObject(forKey: platformIdentifierKey)
        UserDefaults.standard.removeObject(forKey: "watchme_supabase_registered")
        
        self.localDeviceIdentifier = nil
        self.isDeviceRegistered = false
        self.registrationError = nil
        
        print("🔄 デバイス登録状態リセット完了")
    }
    
    // MARK: - ユーザーのデバイスを取得
    func fetchUserDevices(for userId: String) async {
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
                print("⚠️ No devices found for user: \(userId)")
                await MainActor.run {
                    self.userDevices = []
                    // ユーザーに紐付くデバイスがない場合、このデバイス自身のIDを使用
                    if let localId = self.localDeviceIdentifier {
                        self.selectedDeviceID = localId
                        print("⚠️ Using local device: \(localId)")
                    }
                }
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
            
            await MainActor.run {
                self.userDevices = devices
                print("✅ Found \(devices.count) devices for user: \(userId)")
                
                // ownerロールのデバイスを優先的に選択
                let ownerDevices = devices.filter { $0.role == "owner" }
                let viewerDevices = devices.filter { $0.role == "viewer" }
                
                if let firstOwnerDevice = ownerDevices.first {
                    self.selectedDeviceID = firstOwnerDevice.device_id
                    print("🔍 Auto-selected owner device: \(firstOwnerDevice.device_id)")
                } else if let firstViewerDevice = viewerDevices.first {
                    self.selectedDeviceID = firstViewerDevice.device_id
                    print("🔍 Auto-selected viewer device: \(firstViewerDevice.device_id)")
                } else if let firstDevice = devices.first {
                    self.selectedDeviceID = firstDevice.device_id
                    print("🔍 Selected first device: \(firstDevice.device_id)")
                }
            }
            
        } catch {
            print("❌ Device fetch error: \(error)")
        }
    }
    
    // MARK: - デバイス選択
    func selectDevice(_ deviceId: String) {
        if userDevices.contains(where: { $0.device_id == deviceId }) {
            selectedDeviceID = deviceId
            print("📱 Selected device: \(deviceId)")
        }
    }
    
    // MARK: - デバイス情報取得
    func getDeviceInfo() -> DeviceInfo? {
        // 選択されたデバイスIDがあればそれを使用、なければこの物理デバイスのIDを使用
        let deviceID = selectedDeviceID ?? localDeviceIdentifier
        
        guard let deviceID = deviceID,
              let platformIdentifier = UserDefaults.standard.string(forKey: platformIdentifierKey) else {
            return nil
        }
        
        return DeviceInfo(
            deviceID: deviceID,
            platformIdentifier: platformIdentifier,
            deviceType: "ios",
            platformType: "iOS"
        )
    }
    
    // MARK: - Public Methods for Auth Integration
    
    /// ログイン成功後に呼ぶ統括関数：デバイス登録とユーザーデバイス取得を実行
    func checkAndRegisterDevice(for userId: String) {
        Task {
            print("🔄 DeviceManager: デバイス登録とユーザーデバイス取得を開始")
            
            // 1. まず現在のデバイスをSupabaseに登録（既存の場合は更新）
            await registerDeviceToSupabase(userId: userId)
            
            // 2. ユーザーのデバイスリストを取得
            await fetchUserDevices(for: userId)
            
            print("✅ DeviceManager: デバイス処理が完了しました")
        }
    }
}

// MARK: - データモデル

// デバイス情報
struct DeviceInfo {
    let deviceID: String
    let platformIdentifier: String
    let deviceType: String
    let platformType: String
}

// Supabase Insert用データモデル
struct DeviceInsert: Codable {
    let platform_identifier: String
    let device_type: String
    let platform_type: String
    let owner_user_id: String?
}

// Supabase Response用データモデル
struct Device: Codable {
    let device_id: String
    let platform_identifier: String
    let device_type: String
    let platform_type: String
    let owner_user_id: String?
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