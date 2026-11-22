//
//  AppleSignIn.swift
//  ios_watchme_v9
//
//  Sign in with Apple: the button, the nonce Supabase checks, and a
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

/// "Apple でサインイン" button, drawn with the shared form button so it matches the
/// Google and email buttons (a custom Sign in with Apple button: Apple logo, white,
/// approved title). Wired to UserAccountManager.
struct AppleSignInButton: View {
    enum Purpose {
        case signIn, signUp

        var title: String {
            switch self {
            case .signIn: return "Apple でサインイン"
            case .signUp: return "Apple で登録"
            }
        }
    }

    @EnvironmentObject var userAccountManager: UserAccountManager
    var purpose: Purpose = .signIn

    var body: some View {
        AppFormButton(title: purpose.title, systemImage: "apple.logo", style: .light) {
            Task { await signIn() }
        }
        .disabled(userAccountManager.isLoading)
    }

    private func signIn() async {
        let nonce = AppleSignInNonce.make()
        do {
            let credential = try await AppleIDAuthorizer.credential(
                scopes: [.fullName, .email], nonceHash: AppleSignInNonce.sha256(nonce)
            )
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                userAccountManager.reportAppleSignInError("Apple から認証情報を受け取れませんでした")
                return
            }
            await userAccountManager.signInWithApple(
                idToken: idToken, nonce: nonce, fullName: credential.fullName
            )
        } catch {
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            userAccountManager.reportAppleSignInError("Apple でのサインインに失敗しました: \(error.localizedDescription)")
        }
    }
}

/// Asks Apple once more for an authorization code (shown as the Apple sheet).
/// Used right before deleting an account that signed in with Apple.
enum AppleReauthorizer {
    @MainActor
    static func authorizationCode() async throws -> String {
        let credential = try await AppleIDAuthorizer.credential(scopes: [], nonceHash: nil)
        guard let codeData = credential.authorizationCode,
              let code = String(data: codeData, encoding: .utf8) else {
            throw NSError(domain: "AppleReauthorizer", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Apple から認証情報を受け取れませんでした"])
        }
        return code
    }
}

/// Runs one Apple ID request (the Apple sheet) and returns the credential.
@MainActor
final class AppleIDAuthorizer: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private static var current: AppleIDAuthorizer?

    static func credential(scopes: [ASAuthorization.Scope], nonceHash: String?) async throws -> ASAuthorizationAppleIDCredential {
        let authorizer = AppleIDAuthorizer()
        current = authorizer
        defer { current = nil }
        return try await authorizer.run(scopes: scopes, nonceHash: nonceHash)
    }

    private func run(scopes: [ASAuthorization.Scope], nonceHash: String?) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = scopes
            if let nonceHash { request.nonce = nonceHash }
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation?.resume(returning: credential)
        } else {
            continuation?.resume(throwing: NSError(domain: "AppleIDAuthorizer", code: -1,
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
