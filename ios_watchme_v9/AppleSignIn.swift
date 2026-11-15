//
//  AppleSignIn.swift
//  ios_watchme_v9
//
//  Sign in with Apple: the native button, the nonce Supabase checks, and a
//  re-authorization used before deleting an Apple account (the server needs a
//  fresh authorization code to revoke the app's Apple tokens).
//

import AuthenticationServices
import CryptoKit
import SwiftUI
import UIKit

enum AppleSignInNonce {
    /// A random string; Apple gets its SHA-256, Supabase gets the raw value.
    static func make(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        if SecRandomCopyBytes(kSecRandomDefault, length, &bytes) != errSecSuccess {
            return UUID().uuidString + UUID().uuidString
        }
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// The standard "Sign in with Apple" button, wired to UserAccountManager.
struct AppleSignInButton: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    var label: SignInWithAppleButton.Label = .signIn
    var height: CGFloat = 52
    var cornerRadius: CGFloat = 14

    @State private var nonce = ""

    var body: some View {
        SignInWithAppleButton(label) { request in
            nonce = AppleSignInNonce.make()
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInNonce.sha256(nonce)
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let tokenData = credential.identityToken,
                      let idToken = String(data: tokenData, encoding: .utf8) else {
                    userAccountManager.reportAppleSignInError("Apple から認証情報を受け取れませんでした")
                    return
                }
                let rawNonce = nonce
                Task {
                    await userAccountManager.signInWithApple(
                        idToken: idToken, nonce: rawNonce, fullName: credential.fullName
                    )
                }
            case .failure(let error):
                if (error as? ASAuthorizationError)?.code == .canceled { return }
                userAccountManager.reportAppleSignInError("Apple でのサインインに失敗しました: \(error.localizedDescription)")
            }
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .disabled(userAccountManager.isLoading)
    }
}

/// Asks Apple once more for an authorization code (shown as the Apple sheet).
/// Used right before deleting an account that signed in with Apple.
@MainActor
final class AppleReauthorizer: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<String, Error>?
    private static var current: AppleReauthorizer?

    static func authorizationCode() async throws -> String {
        let reauthorizer = AppleReauthorizer()
        current = reauthorizer
        defer { current = nil }
        return try await reauthorizer.run()
    }

    private func run() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
           let codeData = credential.authorizationCode,
           let code = String(data: codeData, encoding: .utf8) {
            continuation?.resume(returning: code)
        } else {
            continuation?.resume(throwing: NSError(domain: "AppleReauthorizer", code: -1,
                                                   userInfo: [NSLocalizedDescriptionKey: "Apple から認証情報を受け取れませんでした"]))
        }
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
