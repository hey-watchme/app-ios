//
//  AuthFlowView.swift
//  ios_watchme_v9
//
//  Unified authentication flow (Onboarding + Account Selection)
//  Solves the fullScreenCover nesting issue
//

import SwiftUI

struct AuthFlowView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var toastManager: ToastManager
    @Binding var isPresented: Bool

    // Authentication flow steps
    @State private var currentStep: AuthStep = .onboarding
    @State private var currentPage = 0

    // Account selection state
    @State private var isProcessing = false
    @State private var showLogin = false
    @State private var showSignUp = false  // メール登録画面表示フラグ

    enum AuthStep {
        case onboarding
        case accountSelection
    }

    private let onboardingPages = [
        "onboarding-001",
        "onboarding-002",
        "onboarding-003",
        "onboarding-004"
    ]

    var body: some View {
        ZStack {
            switch currentStep {
            case .onboarding:
                onboardingView
            case .accountSelection:
                accountSelectionView
            }
        }
        .onChange(of: userAccountManager.authState) { _, newValue in
            // Monitor authentication state changes
            if newValue.isAuthenticated {
                print("✅ [AuthFlowView] Authentication successful - closing modal")
                // Note: デバイス登録はUserAccountManager.initializeAuthenticatedUser()で実行される
                isPresented = false
            }
        }
        .onOpenURL { url in
            // Handle OAuth callback
            print("🔗 [AuthFlowView] URL received: \(url)")
            Task {
                await userAccountManager.handleOAuthCallback(url: url)
            }
        }
    }

    // MARK: - Onboarding View

    private var onboardingView: some View {
        ZStack {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(0..<onboardingPages.count, id: \.self) { index in
                    Image(onboardingPages[index])
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .ignoresSafeArea()
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Skip button (shown except on last page)
            VStack {
                HStack {
                    Spacer()
                    if currentPage < onboardingPages.count - 1 {
                        Button(action: {
                            currentStep = .accountSelection
                        }) {
                            Text("スキップ")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(20)
                        }
                        .padding(.top, 60)
                        .padding(.trailing, 20)
                    }
                }
                Spacer()
            }

            // "Get Started" button on last page
            if currentPage == onboardingPages.count - 1 {
                VStack {
                    Spacer()
                    Button(action: {
                        currentStep = .accountSelection
                    }) {
                        Text("はじめる")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("AppAccentColor"))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 80)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Account Selection View

    private var accountSelectionView: some View {
        VStack(spacing: 24) {
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

                // Email Sign Up
                Button(action: {
                    showSignUp = true
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
            .disabled(isProcessing)
            .opacity(isProcessing ? 0.6 : 1.0)

            // Login link
            Button(action: {
                showLogin = true
            }) {
                Text("アカウントをお持ちの方はこちら")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
                .environmentObject(userAccountManager)
                .environmentObject(toastManager)
                .environmentObject(deviceManager)
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
                .environmentObject(userAccountManager)
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
    }

    // MARK: - Actions

    private func signInWithGoogle() {
        isProcessing = true
        Task {
            // Use direct ASWebAuthenticationSession implementation
            await userAccountManager.signInWithGoogleDirect()

            // Note: OAuth flow continues in browser
            // This view stays open until callback is received
            await MainActor.run {
                isProcessing = false
            }
        }
    }

    private func continueAsGuest() {
        isProcessing = true
        Task {
            await userAccountManager.signInAnonymously()

            // Check success
            if userAccountManager.isAuthenticated {
                // Note: デバイス登録はUserAccountManager.initializeAuthenticatedUser()で実行される
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
    AuthFlowView(isPresented: .constant(true))
        .environmentObject(UserAccountManager(deviceManager: DeviceManager()))
        .environmentObject(DeviceManager())
        .environmentObject(ToastManager.shared)
}
