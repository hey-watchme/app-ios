//
//  SignUpPromptView.swift
//  ios_watchme_v9
//
//  Shown to signed-out visitors (sample mode) when they start using WatchMe or try
//  something that needs an account. Offers every sign-up method in one place.
//

import SwiftUI

struct SignUpPromptView: View {
    /// What the visitor tried to do ("録音する"); nil when they pressed "使い始める".
    let action: String?

    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var toastManager: ToastManager
    @Environment(\.dismiss) private var dismiss

    @State private var showSignUp = false
    @State private var showLogin = false

    private var message: String {
        if let action {
            return "いまはサンプルを表示しています。\(action)には、アカウントの登録が必要です。"
        }
        return "アカウントを登録すると、ご家族の録音を分析して記録できます。"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text("WatchMe を使い始める")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.70))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 28)
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                AppleSignInButton(label: .signUp, height: 50, cornerRadius: 12)

                Button(action: signInWithGoogle) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Google で登録")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.darkElevated)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                }

                Button(action: { showSignUp = true }) {
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
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .disabled(userAccountManager.isLoading)

            Button(action: { showLogin = true }) {
                Text("アカウントをお持ちの方はログイン")
                    .font(.footnote)
                    .foregroundColor(Color.accentTeal)
            }
            .padding(.top, 18)

            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity)
        .background(Color.darkSurface.ignoresSafeArea())
        .presentationDetents([.height(440), .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showSignUp) {
            SignUpView()
                .environmentObject(userAccountManager)
        }
        .sheet(isPresented: $showLogin) {
            LoginView(onStartNew: nil)
                .environmentObject(userAccountManager)
                .environmentObject(toastManager)
                .environmentObject(deviceManager)
        }
        .onChange(of: userAccountManager.authState) { _, newValue in
            if newValue.isAuthenticated {
                dismiss()
            }
        }
    }

    private func signInWithGoogle() {
        Task { await userAccountManager.signInWithGoogleDirect() }
    }
}

#Preview {
    SignUpPromptView(action: "録音する")
        .environmentObject(UserAccountManager(deviceManager: DeviceManager()))
        .environmentObject(DeviceManager())
        .environmentObject(ToastManager.shared)
}
