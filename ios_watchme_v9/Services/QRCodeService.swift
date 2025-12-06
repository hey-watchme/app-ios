//
//  QRCodeService.swift
//  ios_watchme_v9
//
//  QR code generation and deletion service for device sharing
//

import Foundation

class QRCodeService {
    static let shared = QRCodeService()
    private let baseURL = "https://api.hey-watch.me/qrcode"

    private init() {}

    // Generate QR code for a device
    func generateQRCode(for deviceId: String) async throws -> String {
        let url = URL(string: "\(baseURL)/v1/devices/\(deviceId)/qrcode")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30

        print("📡 [QRCodeService] Sending request to: \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [QRCodeService] Invalid response type")
            throw QRCodeError.invalidResponse
        }

        print("📊 [QRCodeService] HTTP Status Code: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            print("❌ [QRCodeService] Generation failed with status code: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("   Response body: \(responseString)")
            }
            throw QRCodeError.generationFailed(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let qrResponse = try decoder.decode(QRCodeResponse.self, from: data)
        print("✅ [QRCodeService] QR code URL received: \(qrResponse.qrCodeUrl)")
        return qrResponse.qrCodeUrl
    }

    // Delete QR code for a device
    func deleteQRCode(for deviceId: String) async throws {
        let url = URL(string: "\(baseURL)/v1/devices/\(deviceId)/qrcode")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 30

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QRCodeError.invalidResponse
        }

        guard httpResponse.statusCode == 204 else {
            throw QRCodeError.deletionFailed(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Response Models

struct QRCodeResponse: Codable {
    let qrCodeUrl: String
}

// MARK: - Error Types

enum QRCodeError: Error, LocalizedError {
    case generationFailed(statusCode: Int)
    case deletionFailed(statusCode: Int)
    case invalidURL
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .generationFailed(let statusCode):
            return "QRコードの生成に失敗しました (ステータスコード: \(statusCode))"
        case .deletionFailed(let statusCode):
            return "QRコードの削除に失敗しました (ステータスコード: \(statusCode))"
        case .invalidURL:
            return "無効なURLです"
        case .invalidResponse:
            return "サーバーからの応答が無効です"
        }
    }
}
