//
//  UploaderService.swift
//  ios_watchme_v9
//
//  ファイルアップロードの実行にのみ責任を持つサービス
//  ネットワーク通信に特化
//

import Foundation
import Combine
import UIKit

// MARK: - UploadRequest（純粋なデータ構造）
struct UploadRequest {
    let fileURL: URL
    let fileName: String
    let userID: String
    let deviceID: String
    let recordedAt: Date
    let timezone: TimeZone
}

// MARK: - UploaderService（アップロード専門サービス）
final class UploaderService {
    // MARK: - Limits

    /// Largest file the server accepts today. API Gateway hands the body to Lambda base64-encoded
    /// (about 4/3 larger) and Lambda takes at most 6 MB, so about 2 min 17 s of 16 kHz mono WAV.
    /// Goes away when uploads move to S3 presigned URLs.
    static let maxUploadBytes: Int64 = 4_400_000

    // MARK: - Properties
    private let serverURL = "https://api.hey-watch.me"
    private var uploadTask: URLSessionUploadTask?

    // MARK: - Initialization
    init() {
        // 依存関係なし：純粋な実行部隊
    }

    // MARK: - Public Methods

    /// 録音ファイルをアップロード
    func upload(_ request: UploadRequest) async throws {
        // ファイル存在確認
        guard FileManager.default.fileExists(atPath: request.fileURL.path) else {
            throw UploadError.fileNotFound
        }

        // ファイルサイズ確認
        let attributes = try FileManager.default.attributesOfItem(atPath: request.fileURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        guard fileSize > 0 else {
            throw UploadError.emptyFile
        }
        guard fileSize <= Self.maxUploadBytes else {
            throw UploadError.tooLarge
        }

        // アップロードURL生成
        guard let uploadURL = URL(string: "\(serverURL)/upload") else {
            throw UploadError.invalidURL
        }

        print("📤 UploaderService: アップロード開始 - \(request.fileName)")
        print("   - サイズ: \(fileSize) bytes")
        print("   - URL: \(uploadURL)")

        // マルチパートボディ作成（Dataとして）
        let boundary = UUID().uuidString
        let multipartBody = try createMultipartBody(request: request, boundary: boundary)

        // リクエスト設定
        var uploadRequest = URLRequest(url: uploadURL)
        uploadRequest.httpMethod = "POST"
        uploadRequest.timeoutInterval = 120.0
        uploadRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Keep the upload alive if the screen locks or the app is closed right after stopping.
        let backgroundTask = await BackgroundTask.begin(name: "recording-upload")
        defer { Task { await backgroundTask.end() } }

        // アップロード実行（Dataを直接送信、二重ラップ解消）
        let (data, response) = try await URLSession.shared.upload(for: uploadRequest, from: multipartBody)

        // レスポンス確認
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }

        // 409: the server already has this recording (an earlier attempt got through but its
        // response was lost). Treat as sent so the local copy is not resent forever.
        if httpResponse.statusCode == 409 {
            print("ℹ️ UploaderService: already received by the server - \(request.fileName)")
            return
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // サーバーからのエラーメッセージを取得
            var serverMessage: String? = nil
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                serverMessage = detail
            }
            throw UploadError.serverError(statusCode: httpResponse.statusCode, message: serverMessage)
        }

        print("✅ UploaderService: アップロード成功 - \(request.fileName)")
    }

    /// アップロードをキャンセル
    func cancelUpload() {
        uploadTask?.cancel()
        uploadTask = nil
        print("⏸️ UploaderService: アップロードキャンセル")
    }

    // MARK: - Private Methods

    private func createMultipartBody(
        request: UploadRequest,
        boundary: String
    ) throws -> Data {
        var body = Data()

        // Metadata: Send recorded_at in UTC
        // All timestamps are stored in UTC on the server
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(identifier: "UTC")

        let metadata: [String: Any] = [
            "device_id": request.deviceID,
            "recorded_at": formatter.string(from: request.recordedAt)
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: metadata),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"metadata\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
            body.append("\(jsonString)\r\n".data(using: .utf8)!)
        }

        // user_id追加
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(request.userID)\r\n".data(using: .utf8)!)

        // device_id追加
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"device_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(request.deviceID)\r\n".data(using: .utf8)!)

        // ファイル追加
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(request.fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)

        // Determine content type based on file extension
        let contentType: String
        switch request.fileURL.pathExtension.lowercased() {
        case "m4a":
            contentType = "audio/mp4"
        case "mp3":
            contentType = "audio/mpeg"
        default:
            contentType = "audio/wav"
        }
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)

        let fileData = try Data(contentsOf: request.fileURL)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // 終端
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return body
    }
}

// MARK: - BackgroundTask

/// Asks iOS for extra time to finish work after the app leaves the foreground.
@MainActor
private final class BackgroundTask {
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    static func begin(name: String) -> BackgroundTask {
        let task = BackgroundTask()
        task.identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak task] in
            task?.end()
        }
        return task
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}

// MARK: - Errors
enum UploadError: LocalizedError {
    case fileNotFound
    case emptyFile
    case tooLarge
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "ファイルが見つかりません"
        case .emptyFile:
            return "ファイルが空です"
        case .tooLarge:
            return "録音が長すぎて今は送れません（上限は約2分）"
        case .invalidURL:
            return "無効なURLです"
        case .invalidResponse:
            return "サーバーからの応答が無効です"
        case .serverError(let code, let message):
            if let message = message {
                return "サーバーエラー: \(message)"
            } else {
                return "サーバーエラー（\(code)）"
            }
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        }
    }
}
