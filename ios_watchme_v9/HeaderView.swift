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
    
    // 通知関連
    @State private var showNotificationSheet = false
    @State private var unreadNotificationCount = 0
    
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
                    
                    // 未読通知がある場合の赤い丸（バッジ）と数
                    if unreadNotificationCount > 0 {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 18, height: 18)
                            
                            Text("\(min(unreadNotificationCount, 99))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
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
            // 通知画面
            NotificationView()
                .environmentObject(authManager)
                .environmentObject(dataManager)
                .onDisappear {
                    // 通知画面を閉じたら未読数を更新
                    Task {
                        await updateUnreadCount()
                    }
                }
        }
        .task {
            // 初回読み込み時に未読数を取得
            await updateUnreadCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // アプリがフォアグラウンドに戻ったら未読数を更新
            Task {
                await updateUnreadCount()
            }
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
    
    // 未読通知数を更新
    private func updateUnreadCount() async {
        guard let userId = authManager.currentUser?.id else { return }
        unreadNotificationCount = await dataManager.fetchUnreadNotificationCount(userId: userId)
    }
}