//
//  AWSManager.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/31.
//

import Foundation
import UIKit
import CryptoKit

// MARK: - Avatar Upload Manager
/// アバター画像のアップロードを管理するクラス
/// 
/// ⚠️ 現在ペンディング状態 ⚠️
/// - アバターアップロード専用APIの実装待ち
/// - APIエンドポイントが提供され次第、実装を更新予定
/// - 現在はローカルファイルシステムに保存する暫定実装
///
@MainActor
class AWSManager: ObservableObject {
    
    // MARK: - Properties
    static let shared = AWSManager()
    
    // S3設定（環境変数または設定ファイルから読み込むことを推奨）
    private let bucketName = "watchme-avatars"
    private let region = "ap-northeast-1"  // 東京リージョン
    private let s3Endpoint: String
    
    // AWS認証情報（本番環境では安全な方法で管理すること）
    // TODO: これらの値を環境変数やKeychain、またはサーバー経由で取得するように変更
    private let accessKeyId = "YOUR_ACCESS_KEY_ID"
    private let secretAccessKey = "YOUR_SECRET_ACCESS_KEY"
    
    // MARK: - Initialization
    private init() {
        self.s3Endpoint = "https://\(bucketName).s3.\(region).amazonaws.com"
    }
    
    // MARK: - Public Methods
    
    /// アバター画像をアップロード
    /// - Parameters:
    ///   - image: アップロードする画像
    ///   - type: アバターのタイプ（"users" または "subjects"）
    ///   - id: ユーザーIDまたはサブジェクトID
    /// - Returns: アップロードされた画像のURL
    func uploadAvatar(image: UIImage, type: String, id: String) async throws -> URL {
        print("📤 Starting avatar upload for \(type)/\(id)")
        
        // ========================================
        // ⚠️ ペンディング実装 ⚠️
        // 
        // TODO: アバターアップロード専用APIが実装され次第、以下の処理に置き換える
        // 
        // 想定されるAPI仕様:
        // - エンドポイント: POST /api/avatar/upload
        // - リクエスト: multipart/form-data
        //   - file: 画像ファイル
        //   - type: "users" or "subjects"
        //   - id: ユーザーIDまたはサブジェクトID
        // - レスポンス: { url: "https://..." }
        //
        // 実装例:
        // ```swift
        // let endpoint = "https://api.hey-watch.me/avatar/upload"
        // var request = URLRequest(url: URL(string: endpoint)!)
        // request.httpMethod = "POST"
        // 
        // let boundary = UUID().uuidString
        // request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        // 
        // // multipart/form-dataのボディを構築
        // var body = Data()
        // // ... (実装詳細)
        // 
        // let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        // let result = try JSONDecoder().decode(AvatarUploadResponse.self, from: data)
        // return URL(string: result.url)!
        // ```
        // ========================================
        
        // 画像をJPEGに変換（品質80%）
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AWSError.imageConversionFailed
        }
        
        // ========================================
        // 暫定実装: ローカルファイルシステムに保存
        // API実装完了後は削除予定
        // ========================================
        let fileName = "avatar.jpg"
        let key = "\(type)/\(id)/\(fileName)"
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let typePath = documentsPath.appendingPathComponent(type)
        let idPath = typePath.appendingPathComponent(id)
        
        // ディレクトリを作成
        try? FileManager.default.createDirectory(at: idPath, withIntermediateDirectories: true)
        
        // ファイルに保存
        let fileURL = idPath.appendingPathComponent(fileName)
        try imageData.write(to: fileURL)
        
        print("⚠️ PENDING: Avatar saved locally (API not yet implemented): \(fileURL)")
        
        // S3のURLフォーマットで返す（実際にはアップロードしていない）
        return URL(string: "\(s3Endpoint)/\(key)")!
    }
    
    /// アバター画像のURLを取得
    /// - Parameters:
    ///   - type: アバターのタイプ（"users" または "subjects"）
    ///   - id: ユーザーIDまたはサブジェクトID
    /// - Returns: アバター画像のURL
    func getAvatarURL(type: String, id: String) -> URL {
        let key = "\(type)/\(id)/avatar.jpg"
        return URL(string: "\(s3Endpoint)/\(key)")!
    }
    
    // MARK: - Private Methods
    
    /// S3に直接アップロード（AWS SDK不使用）
    private func uploadToS3(data: Data, key: String, contentType: String) async throws -> URL {
        let url = URL(string: "\(s3Endpoint)/\(key)")!
        
        // リクエストを作成
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("public-read", forHTTPHeaderField: "x-amz-acl")
        
        // AWS Signature V4を生成（簡略版）
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let timestamp = dateFormatter.string(from: Date())
        
        request.setValue(timestamp, forHTTPHeaderField: "x-amz-date")
        
        // TODO: 実際のAWS Signature V4の実装が必要
        // ここでは簡略化のため、認証なしでアップロードすることを想定
        // 本番環境では、サーバー経由でのアップロードや、
        // 一時的な認証トークンの使用を検討してください
        
        // アップロード実行
        do {
            let (_, response) = try await URLSession.shared.upload(for: request, from: data)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AWSError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                return url
            } else {
                throw AWSError.uploadFailed(statusCode: httpResponse.statusCode)
            }
        } catch {
            throw AWSError.networkError(error)
        }
    }
}

// MARK: - Error Types
enum AWSError: Error, LocalizedError {
    case imageConversionFailed
    case invalidResponse
    case uploadFailed(statusCode: Int)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "画像の変換に失敗しました"
        case .invalidResponse:
            return "無効なレスポンスです"
        case .uploadFailed(let statusCode):
            return "アップロードに失敗しました (ステータス: \(statusCode))"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        }
    }
}

// MARK: - 暫定的な実装の注意事項
/*
 重要: このAWSManagerは、デモンストレーション用の簡略化された実装です。
 
 本番環境での実装には以下の対応が必要です：
 
 1. AWS認証情報の安全な管理
    - Keychainに保存
    - サーバー経由で一時的な認証トークンを取得
    - AWS CognitoやSTSを使用
 
 2. AWS Signature V4の完全な実装
    - 現在の実装では認証が含まれていません
    - AWS SDK for iOSの使用を推奨
 
 3. エラーハンドリングの強化
    - リトライロジック
    - より詳細なエラー情報
 
 4. 画像の最適化
    - 複数サイズの生成（サムネイル等）
    - WebP形式への変換
 
 代替案として、以下の方法も検討してください：
 - サーバー経由でのアップロード（サーバーがS3にアップロード）
 - Supabase Storageの継続使用
 - CloudinaryやImgixなどの画像専用CDNサービス
 */