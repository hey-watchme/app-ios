//
//  AccountSelectionView.swift
//  ios_watchme_v9
//
//  Account selection screen after onboarding
//  Note: このビューは現在使用されていません（AuthFlowViewで統合済み）
//  後方互換性のために残してあります
//

import SwiftUI

struct AccountSelectionView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var toastManager: ToastManager
    @Binding var isPresented: Bool
    @State private var showEmailSignUp = false
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 24) {
            // Close button
            HStack {
                Spacer()
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.trailing, 20)
            }

            Spacer()

            // Header
            VStack(spacing: 12) {
                Text("WatchMe へようこそ")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("アカウントを作成して\nデータを安全に保存しましょう")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Buttons
            VStack(spacing: 16) {
                // Google Sign In (Real implementation)
                Button(action: {
                    signInWithGoogle()
                }) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Google でサインイン")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                // Email Sign Up (Mock)
                Button(action: {
                    toastManager.showInfo(
                        title: "メールアドレス登録",
                        subtitle: "現在準備中です"
                    )
                }) {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text("メールアドレスで登録")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.safeColor("AppAccentColor"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                // Guest Continue (Anonymous Auth - Working)
                Button(action: {
                    continueAsGuest()
                }) {
                    HStack {
                        Image(systemName: "person.fill")
                        Text("ゲストとして続行")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary, lineWidth: 1.5)
                    )
                    .foregroundColor(.primary)
                }

                // Warning
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("ゲストモードではデータが保護されません")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
            .disabled(isProcessing)
            .opacity(isProcessing ? 0.6 : 1.0)
        }
        .overlay(
            Group {
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("アカウントを作成中...")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                    }
                }
            }
        )
        .onChange(of: userAccountManager.authState) { oldValue, newValue in
            // Monitor authentication state changes
            if newValue.isAuthenticated {
                print("✅ [AccountSelectionView] 認証成功検知 - モーダルを閉じます")

                Task {
                    // Auto-register device
                    if let userId = userAccountManager.currentUser?.profile?.userId {
                        await deviceManager.registerDevice(userId: userId)
                    }

                    await MainActor.run {
                        isPresented = false
                    }
                }
            }
        }
    }

    // Google Sign In
    private func signInWithGoogle() {
        isProcessing = true
        Task {
            // Use direct ASWebAuthenticationSession implementation
            // This ensures OAuth callback is properly received
            await userAccountManager.signInWithGoogleDirect()

            // Note: OAuth flow continues in browser
            // This view stays open until callback is received
            await MainActor.run {
                isProcessing = false
            }
        }
    }

    // Guest Continue (Anonymous Auth)
    private func continueAsGuest() {
        isProcessing = true
        Task {
            await userAccountManager.signInAnonymously()

            // Check success
            if userAccountManager.isAuthenticated {
                // Auto-register device
                if let userId = userAccountManager.currentUser?.profile?.userId {
                    await deviceManager.registerDevice(userId: userId)
                }

                await MainActor.run {
                    isPresented = false
                }
            }

            await MainActor.run {
                isProcessing = false
            }
        }
    }
}

#Preview {
    AccountSelectionView(isPresented: .constant(true))
        .environmentObject(UserAccountManager(deviceManager: DeviceManager()))
        .environmentObject(DeviceManager())
        .environmentObject(ToastManager.shared)
}
