//
//  HeaderView.swift
//  ios_watchme_v9
//
//  Created by Assistant on 2025/08/02.
//

import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @Binding var showLogoutConfirmation: Bool
    @Binding var showRecordingSheet: Bool
    @Binding var showMyPage: Bool  // マイページ表示制御

    // 通知関連
    @State private var showNotificationSheet = false
    @State private var unreadNotificationCount = 0
    
    var body: some View {
        HStack {
            // 観測対象または選択中デバイス表示（デバイス設定画面へのリンク）
            NavigationLink(destination: 
                DeviceSettingsView()
                    .environmentObject(userAccountManager)
                    .environmentObject(deviceManager)
                    .environmentObject(dataManager)
            ) {
                currentTargetView
            }
            
            Spacer()

            // マイページアイコン
            Button(action: {
                showMyPage = true
            }) {
                Image(systemName: "person.circle")
                    .font(.title2)
                    .foregroundColor(Color.safeColor("BehaviorTextPrimary"))
            }
            .padding(.trailing, 12)

            // 通知アイコン
            Button(action: {
                showNotificationSheet = true
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.title2)
                        .foregroundColor(Color.safeColor("BehaviorTextPrimary"))

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
        .sheet(isPresented: $showNotificationSheet) {
            // 通知画面
            NotificationView()
                .environmentObject(userAccountManager)
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
        if let subject = deviceManager.selectedSubject {
            // 観測対象が設定されている場合
            HStack(spacing: 8) {
                // アバター表示（SSOT: Subject.avatarUrl を渡す）
                AvatarView(type: .subject, id: subject.subjectId, size: 32, avatarUrl: subject.avatarUrl)
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
            // デバイスが選択されている場合
            if deviceManager.isSampleDeviceSelected {
                // サンプルデバイス選択中
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.1))
                            .frame(width: 32, height: 32)

                        Image(systemName: "eye.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.black)
                    }

                    Text("サンプルデバイス")
                        .font(.subheadline)
                        .foregroundColor(.black)
                }
            } else {
                // 通常のデバイス選択中（観測対象未設定）
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.1))
                            .frame(width: 32, height: 32)

                        Image(systemName: "iphone")
                            .font(.system(size: 18))
                            .foregroundColor(.black)
                    }

                    // デバイスIDの最初の8文字を表示
                    let shortDeviceId = String(deviceId.prefix(8))
                    Text(shortDeviceId)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospaced()
                }
            }
        } else if !deviceManager.hasRealDevices {
            // 実際のデバイス（デモ以外）が未連携の場合
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.05))
                        .frame(width: 32, height: 32)

                    Image(systemName: "iphone.slash")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                }

                Text("デバイス連携: なし")
                    .font(.subheadline)
                    .foregroundColor(.black)
            }
        } else {
            // フォールバック（デバイスはあるが選択されていない）
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.05))
                        .frame(width: 32, height: 32)

                    Image(systemName: "iphone")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                }

                Text("デバイスを選択")
                    .font(.subheadline)
                    .foregroundColor(.black)
            }
        }
    }
    
    // 未読通知数を更新
    private func updateUnreadCount() async {
        // ✅ CLAUDE.md: public.usersのuser_idを使用
        guard let userId = userAccountManager.currentUser?.profile?.userId else { return }
        unreadNotificationCount = await dataManager.fetchUnreadNotificationCount(userId: userId)
    }
}