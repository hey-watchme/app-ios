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
    
    // 通知関連のプレースホルダー
    @State private var showNotificationSheet = false
    @State private var hasUnreadNotifications = true  // TODO: 実際の未読通知数はバックエンドから取得
    
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
            
            // 通知アイコン（プレースホルダー）
            Button(action: {
                showNotificationSheet = true
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.title2)
                        .foregroundColor(Color.safeColor("PrimaryActionColor"))
                    
                    // 未読通知がある場合の赤い丸（バッジ）
                    if hasUnreadNotifications {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .offset(x: 8, y: -4)
                    }
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
            
            // Subject情報のみを取得（軽量なRPC関数を使用）
            self.subject = await dataManager.fetchSubjectInfo(deviceId: deviceId)
        }
        .sheet(isPresented: $showNotificationSheet) {
            // 通知画面のプレースホルダー
            NotificationPlaceholderView()
        }
    }
    
    // 現在の観測対象またはデバイス情報を表示するView
    @ViewBuilder
    private var currentTargetView: some View {
        if deviceManager.userDevices.isEmpty {
            // デバイス未連携の場合
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.safeColor("WarningColor").opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "iphone.slash")
                        .font(.system(size: 18))
                        .foregroundColor(Color.safeColor("WarningColor"))
                }
                
                Text("デバイス連携: なし")
                    .font(.subheadline)
                    .foregroundColor(Color.safeColor("WarningColor"))
            }
        } else if let subject = subject {
            // 観測対象が設定されている場合
            HStack(spacing: 8) {
                // アバター表示（AvatarViewコンポーネントを使用）
                AvatarView(type: .subject, id: subject.subjectId, size: 32)
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
                ZStack {
                    Circle()
                        .fill(Color.safeColor("PrimaryActionColor").opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "iphone")
                        .font(.system(size: 18))
                        .foregroundColor(Color.safeColor("PrimaryActionColor"))
                }
                
                // デバイスIDの最初の8文字を表示
                let shortDeviceId = String(deviceId.prefix(8))
                Text(shortDeviceId)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .monospaced()
            }
        } else {
            // フォールバック
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.safeColor("PrimaryActionColor").opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "gear")
                        .font(.system(size: 18))
                        .foregroundColor(Color.safeColor("PrimaryActionColor"))
                }
                
                Text("デバイス設定")
                    .font(.subheadline)
                    .foregroundColor(Color.safeColor("PrimaryActionColor"))
            }
        }
    }
}