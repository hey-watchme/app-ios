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
    private let glassBaseOpacity: Double = 0.56
    private let glassMaterialOpacity: Double = 0.35
    
    var body: some View {
        HStack(spacing: 10) {
            // 分析対象または選択中デバイス表示（デバイス設定画面へのリンク）
            NavigationLink(destination: 
                DeviceSettingsView()
                    .environmentObject(userAccountManager)
                    .environmentObject(deviceManager)
                    .environmentObject(dataManager)
            ) {
                currentTargetView
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(glassBaseOpacity))
                            .overlay(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .opacity(glassMaterialOpacity)
                            )
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            
            Spacer()

            HStack(spacing: 8) {
                myPageButton
                notificationButton
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.black.opacity(glassBaseOpacity))
                    .overlay(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .opacity(glassMaterialOpacity)
                    )
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 5)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
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
    
    // 現在の分析対象またはデバイス情報を表示するView
    @ViewBuilder
    private var currentTargetView: some View {
        if let subject = deviceManager.selectedSubject {
            // 分析対象が設定されている場合
            HStack(spacing: 8) {
                // アバター表示（SSOT: Subject.avatarUrl を渡す）
                AvatarView(type: .subject, id: subject.subjectId, size: 32, avatarUrl: subject.avatarUrl)
                    .environmentObject(dataManager)

                // 分析対象名（「さん」付き）
                if let name = subject.name, !name.isEmpty {
                    Text("\(name)さん")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))
                } else {
                    Text("分析対象")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        } else if let deviceId = deviceManager.selectedDeviceID {
            // デバイスが選択されている場合
            if deviceManager.isSampleDeviceSelected {
                // サンプルデバイス選択中
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 32, height: 32)

                        Image(systemName: "eye.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }

                    Text("サンプルデバイス")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.86))
                }
            } else {
                // 通常のデバイス選択中（分析対象未設定）
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 32, height: 32)

                        Image(systemName: "iphone")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.86))
                    }

                    // デバイスIDの最初の8文字を表示
                    let shortDeviceId = String(deviceId.prefix(8))
                    Text(shortDeviceId)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.92))
                }
            }
        } else if !deviceManager.hasRealDevices {
            // 実際のデバイス（デモ以外）が未連携の場合
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 32, height: 32)

                    Image(systemName: "iphone.slash")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.86))
                }

                Text("デバイス連携: なし")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
        } else {
            // フォールバック（デバイスはあるが選択されていない）
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 32, height: 32)

                    Image(systemName: "iphone")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.86))
                }

                Text("デバイスを選択")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }

    private var myPageButton: some View {
        Button(action: {
            showMyPage = true
        }) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.white.opacity(0.95))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    private var notificationButton: some View {
        Button(action: {
            showNotificationSheet = true
        }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )

                if unreadNotificationCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 18, height: 18)
                        Text("\(min(unreadNotificationCount, 99))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 7, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    // 未読通知数を更新
    private func updateUnreadCount() async {
        // public.usersのuser_id優先、未取得時はauth user_idにフォールバック
        guard let userId = userAccountManager.effectiveUserId else { return }
        unreadNotificationCount = await dataManager.fetchUnreadNotificationCount(userId: userId)
    }
}
