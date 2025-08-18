//
//  HeaderView.swift
//  ios_watchme_v9
//
//  Created by Assistant on 2025/08/02.
//

import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @Binding var showLogoutConfirmation: Bool
    @Binding var showRecordingSheet: Bool
    @State private var subject: Subject? = nil  // ローカル状態として管理
    
    var body: some View {
        HStack {
            // 観測対象または選択中デバイス表示（デバイス設定画面へのリンク）
            NavigationLink(destination: 
                DeviceSettingsView()
                    .environmentObject(authManager)
                    .environmentObject(deviceManager)
                    .environmentObject(dataManager)
            ) {
                currentTargetView
            }
            
            Spacer()
            
            // ユーザー情報/通知 (仮)
            NavigationLink(destination: 
                UserInfoView(
                    authManager: authManager,
                    showLogoutConfirmation: $showLogoutConfirmation
                )
            ) {
                // アバター表示（ユーザーアバターがあれば表示、なければデフォルトアイコン）
                if let userId = authManager.currentUser?.id {
                    AvatarView(userId: userId, size: 32)
                        .environmentObject(dataManager)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color.safeColor("PrimaryActionColor"))
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground).shadow(radius: 1))
        .task(id: deviceManager.selectedDeviceID) {
            // デバイスが選択されたら、Subject情報を取得
            guard let deviceId = deviceManager.selectedDeviceID else { 
                subject = nil
                return 
            }
            
            // Subject情報のみを取得（日付非依存）
            self.subject = await dataManager.fetchSubjectOnly(deviceId: deviceId)
        }
    }
    
    // 現在の観測対象またはデバイス情報を表示するView
    @ViewBuilder
    private var currentTargetView: some View {
        if deviceManager.userDevices.isEmpty {
            // デバイス未連携の場合
            HStack {
                Image(systemName: "iphone.slash")
                Text("デバイス連携: なし")
            }
            .font(.subheadline)
            .foregroundColor(Color.safeColor("WarningColor"))
        } else if let subject = subject {
            // 観測対象が設定されている場合
            HStack(spacing: 8) {
                // アバター表示（AvatarViewコンポーネントを使用）
                AvatarView(type: .subject, id: subject.subjectId, size: 24)
                    .environmentObject(dataManager)
                
                // 観測対象名（「さん」付き）
                if let name = subject.name, !name.isEmpty {
                    Text("\(name)さん")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                } else {
                    Text("観測対象")
                        .font(.subheadline)
                        .foregroundColor(Color.safeColor("BorderLight"))
                }
            }
        } else if let deviceId = deviceManager.selectedDeviceID {
            // 観測対象が未設定の場合、デバイス情報を表示
            HStack(spacing: 8) {
                Image(systemName: "iphone")
                    .font(.title3)
                    .foregroundColor(Color.safeColor("PrimaryActionColor"))
                
                // デバイスIDの最初の8文字を表示
                let shortDeviceId = String(deviceId.prefix(8))
                Text(shortDeviceId)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .monospaced()
            }
        } else {
            // フォールバック
            HStack {
                Image(systemName: "gear")
                Text("デバイス設定")
            }
            .font(.subheadline)
            .foregroundColor(Color.safeColor("PrimaryActionColor"))
        }
    }
}