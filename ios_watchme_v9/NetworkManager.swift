//
//  NetworkManager.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/06/11.
//

import SwiftUI
import Foundation
import Combine

class NetworkManager: ObservableObject {
    @Published var serverURL: String = "https://api.hey-watch.me"
    @Published var connectionStatus: ConnectionStatus = .unknown
    @Published var currentUserID: String
    @Published var uploadProgress: Double = 0.0
    @Published var currentUploadingFile: String? = nil
    
    private var authManager: SupabaseAuthManager?
    private var deviceManager: DeviceManager?
    
    init(authManager: SupabaseAuthManager? = nil, deviceManager: DeviceManager? = nil) {
        self.authManager = authManager
        self.deviceManager = deviceManager
        
        // 認証済みユーザーIDを優先、フォールバックとして従来のユーザーID
        if let authenticatedUser = authManager?.currentUser {
            self.currentUserID = authenticatedUser.id
            print("🔐 認証済みユーザーIDを使用: \(authenticatedUser.id)")
        } else {
            self.currentUserID = NetworkManager.getUserID()
            print("👤 従来のユーザーIDを使用: \(self.currentUserID)")
        }
    }
    
    // ユーザーIDを取得または新規作成
    private static func getUserID() -> String {
        let userDefaults = UserDefaults.standard
        let userIDKey = "app_user_id"
        
        if let existingUserID = userDefaults.string(forKey: userIDKey) {
            print("既存のユーザーIDを使用: \(existingUserID)")
            return existingUserID
        } else {
            // 新しいユーザーIDを生成（UUID形式）
            let newUserID = "user_\(UUID().uuidString.prefix(8))"
            userDefaults.set(newUserID, forKey: userIDKey)
            print("新しいユーザーIDを生成: \(newUserID)")
            return newUserID
        }
    }
    
    // ユーザーIDを手動で変更する（デバッグ・テスト用）
    func setUserID(_ userID: String) {
        currentUserID = userID
        UserDefaults.standard.set(userID, forKey: "app_user_id")
        print("ユーザーIDを変更: \(userID)")
    }
    
    // 認証済みユーザーIDに更新
    func updateToAuthenticatedUserID(_ authUserID: String) {
        currentUserID = authUserID
        print("🔐 認証済みユーザーIDに更新: \(authUserID)")
    }
    
    // ログアウト時にフォールバックユーザーIDに戻す
    func resetToFallbackUserID() {
        currentUserID = NetworkManager.getUserID()
        print("👤 フォールバックユーザーIDに復元: \(currentUserID)")
    }
    
    func uploadRecording(_ recording: RecordingModel) {
        // 基本的なチェックのみ（ファイル存在と最大試行回数）
        guard recording.fileExists() else {
            print("⚠️ アップロード不可: ファイルが存在しません - \(recording.fileName)")
            DispatchQueue.main.async {
                self.connectionStatus = .failed
                self.currentUploadingFile = nil
            }
            return
        }
        
        guard recording.uploadAttempts < 3 else {
            print("⚠️ アップロード不可: 最大試行回数超過 - \(recording.fileName)")
            DispatchQueue.main.async {
                self.connectionStatus = .failed
                self.currentUploadingFile = nil
            }
            return
        }
        
        // アップロード済みでも実行可能（サーバー側で上書き処理される）
        if recording.isUploaded {
            print("ℹ️ アップロード済みファイルの再送信: \(recording.fileName)")
        }
        
        print("🚀 アップロード開始: \(recording.fileName)")
        print("   - ファイルサイズ: \(recording.fileSizeFormatted)")
        print("   - アップロード試行: \(recording.uploadAttempts + 1)回目")
        print("   - ユーザーID: \(currentUserID)")
        print("   - サーバーURL: \(serverURL)")
        print("   - デバイス登録状態: \(deviceManager?.isDeviceRegistered ?? false)")
        print("   - 認証状態: \(authManager?.isAuthenticated ?? false)")
        
        // 接続ステータスを更新
        DispatchQueue.main.async {
            self.connectionStatus = .uploading
            self.uploadProgress = 0.0
            self.currentUploadingFile = recording.fileName
        }
        
        // 録音ファイルのURLを取得
        let fileURL = recording.getFileURL()
        
        // ファイルの存在確認
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let errorMsg = "ファイルが見つかりません: \(fileURL.path)"
            print("❌ \(errorMsg)")
            
            recording.markAsUploadFailed(error: errorMsg)
            
            DispatchQueue.main.async {
                self.connectionStatus = .failed
                self.currentUploadingFile = nil
            }
            return
        }
        
        // ファイルサイズをチェック
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            print("📁 ファイル情報 - 名前: \(recording.fileName), サイズ: \(fileSize) bytes")
        } catch {
            print("⚠️ ファイル属性取得エラー: \(error)")
        }
        
        // アップロード用のURLを作成
        guard let uploadURL = URL(string: "\(serverURL)/upload") else {
            let errorMsg = "無効なアップロードURL: \(serverURL)/upload"
            print("❌ \(errorMsg)")
            
            recording.markAsUploadFailed(error: errorMsg)
            
            DispatchQueue.main.async {
                self.connectionStatus = .failed
                self.currentUploadingFile = nil
            }
            return
        }
        
        print("🌐 アップロード先URL: \(uploadURL)")
        
        // multipart/form-data リクエストを作成
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 120.0  // タイムアウトを120秒に延長
        
        // X-File-Pathヘッダーを設定（device_id/YYYY-MM-DD/HH-MM.wav形式）
        if let deviceInfo = deviceManager?.getDeviceInfo() {
            // 共通ユーティリティを使用してファイルパスを生成
            let filePath = SlotTimeUtility.generateFilePath(deviceID: deviceInfo.deviceID, date: recording.date)
            request.setValue(filePath, forHTTPHeaderField: "X-File-Path")
            print("📋 X-File-Path設定: \(filePath)")
        }
        
        // Boundary文字列を生成
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // HTTPボディを作成
        var body = Data()
        
        // ① user_id パラメータを追加
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(currentUserID)\r\n".data(using: .utf8)!)
        print("👤 送信ユーザーID: \(currentUserID)")
        
        // ② timestamp パラメータを追加
        let timestampFormatter = ISO8601DateFormatter()
        let timestampString = timestampFormatter.string(from: recording.date)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"timestamp\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(timestampString)\r\n".data(using: .utf8)!)
        print("⏰ 送信タイムスタンプ: \(timestampString)")
        
        // ③ device_id パラメータを追加
        print("🔍 デバイス情報チェック開始")
        print("   - deviceManager存在: \(deviceManager != nil)")
        print("   - deviceManager登録状態: \(deviceManager?.isDeviceRegistered ?? false)")
        print("   - deviceManager現在ID: \(deviceManager?.currentDeviceID ?? "なし")")
        
        if let deviceInfo = deviceManager?.getDeviceInfo() {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"device_id\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(deviceInfo.deviceID)\r\n".data(using: .utf8)!)
            print("📱 送信デバイスID: \(deviceInfo.deviceID)")
        } else {
            print("❌ デバイス登録が完了していません。アップロードを中断します。")
            print("   - deviceManager: \(deviceManager != nil ? "存在" : "nil")")
            print("   - isDeviceRegistered: \(deviceManager?.isDeviceRegistered ?? false)")
            print("   - currentDeviceID: \(deviceManager?.currentDeviceID ?? "nil")")
            
            let errorMsg = "デバイス登録が必要です"
            recording.markAsUploadFailed(error: errorMsg)
            
            DispatchQueue.main.async {
                self.connectionStatus = .failed
                self.currentUploadingFile = nil
            }
            return
        }
        
        // ④ file パラメータを追加
        do {
            let fileData = try Data(contentsOf: fileURL)
            print("📄 ファイルデータ読み込み成功: \(fileData.count) bytes")
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(recording.fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
            
        } catch {
            let errorMsg = "ファイルデータ読み込み失敗: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            print("❌ ファイルパス: \(fileURL.path)")
            
            recording.markAsUploadFailed(error: errorMsg)
            
            DispatchQueue.main.async {
                self.connectionStatus = .failed
                self.currentUploadingFile = nil
            }
            return
        }
        
        // boundary終了
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        print("📦 リクエストボディサイズ: \(body.count) bytes")
        
        print("🚀 アップロード開始 - ユーザーID: \(currentUserID), ファイル: \(recording.fileName)")
        
        // 進捗表示のためのタイマー
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            DispatchQueue.main.async {
                if self.connectionStatus == .uploading {
                    // 疑似的な進捗表示（実際のアップロード進捗は取得困難）
                    if self.uploadProgress < 0.9 {
                        self.uploadProgress += 0.05
                    }
                } else {
                    timer.invalidate()
                }
            }
        }
        
        // アップロード開始時刻を記録
        let uploadStartTime = Date()
        
        // URLSessionでリクエストを送信
        let uploadTask = URLSession.shared.dataTask(with: request) { data, response, error in
            progressTimer.invalidate()
            
            // アップロード終了時刻
            let uploadEndTime = Date()
            let uploadDuration = uploadEndTime.timeIntervalSince(uploadStartTime)
            
            DispatchQueue.main.async {
                if let error = error {
                    let errorMsg: String
                    let nsError = error as NSError
                    
                    // エラーの詳細な分析
                    switch nsError.code {
                    case NSURLErrorTimedOut:
                        errorMsg = "タイムアウト: サーバーが応答しませんでした"
                    case NSURLErrorNotConnectedToInternet:
                        errorMsg = "インターネット接続がありません"
                    case NSURLErrorNetworkConnectionLost:
                        errorMsg = "ネットワーク接続が失われました"
                    case NSURLErrorCannotConnectToHost:
                        errorMsg = "サーバーに接続できません: \(self.serverURL)"
                    default:
                        errorMsg = "ネットワークエラー: \(error.localizedDescription)"
                    }
                    
                    print("❌ \(errorMsg)")
                    print("❌ エラーコード: \(nsError.code)")
                    print("❌ エラードメイン: \(nsError.domain)")
                    print("❌ エラー詳細: \(nsError.userInfo)")
                    
                    recording.markAsUploadFailed(error: errorMsg)
                    
                    self.connectionStatus = .failed
                    self.uploadProgress = 0.0
                    self.currentUploadingFile = nil
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    let errorMsg = "無効なレスポンス: HTTPレスポンスではありません"
                    print("❌ \(errorMsg)")
                    
                    recording.markAsUploadFailed(error: errorMsg)
                    
                    self.connectionStatus = .failed
                    self.uploadProgress = 0.0
                    self.currentUploadingFile = nil
                    return
                }
                
                // レスポンス詳細ログ
                print("📡 アップロード完了: \(recording.fileName)")
                print("📡 レスポンスステータス: \(httpResponse.statusCode)")
                print("📡 アップロード時間: \(String(format: "%.2f", uploadDuration))秒")
                
                // レスポンスヘッダーの主要項目を表示
                if let contentType = httpResponse.allHeaderFields["Content-Type"] as? String {
                    print("📡 Content-Type: \(contentType)")
                }
                if let serverHeader = httpResponse.allHeaderFields["Server"] as? String {
                    print("📡 Server: \(serverHeader)")
                }
                
                // レスポンスボディの解析
                var responseBody: String? = nil
                var responseJSON: [String: Any]? = nil
                
                if let data = data {
                    print("📡 レスポンスデータサイズ: \(data.count) bytes")
                    
                    // テキストとして解析
                    if let responseString = String(data: data, encoding: .utf8) {
                        responseBody = responseString
                        print("📡 レスポンスボディ: \(responseString)")
                    }
                    
                    // JSONとして解析を試みる
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        responseJSON = json
                        print("📡 レスポンスJSON: \(json)")
                    }
                }
                
                // ステータスコードに基づく処理
                switch httpResponse.statusCode {
                case 200...299:
                    // 成功
                    print("✅ アップロード成功: \(recording.fileName)")
                    print("✅ ユーザーID: \(self.currentUserID)")
                    print("✅ ファイルサイズ: \(recording.fileSizeFormatted)")
                    print("✅ アップロード試行回数: \(recording.uploadAttempts + 1)")
                    
                    // サーバーレスポンスから追加情報を取得
                    if let json = responseJSON {
                        if let fileId = json["file_id"] as? String {
                            print("✅ サーバー側ファイルID: \(fileId)")
                        }
                        if let uploadedAt = json["uploaded_at"] as? String {
                            print("✅ サーバー側アップロード時刻: \(uploadedAt)")
                        }
                    }
                    
                    // RecordingModelの状態を更新（永続化される）
                    recording.markAsUploaded()
                    
                    self.connectionStatus = .connected
                    self.uploadProgress = 1.0
                    
                    // UIリセットを遅らせる（UploadManagerが監視できるようにする）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.currentUploadingFile = nil
                        self.uploadProgress = 0.0
                    }
                    
                case 400:
                    let errorMsg = "リクエストエラー (400): 不正なリクエスト形式"
                    print("❌ \(errorMsg)")
                    if let body = responseBody {
                        print("❌ エラー詳細: \(body)")
                    }
                    recording.markAsUploadFailed(error: errorMsg)
                    self.handleUploadFailure()
                    
                case 401:
                    let errorMsg = "認証エラー (401): 認証情報が無効です"
                    print("❌ \(errorMsg)")
                    recording.markAsUploadFailed(error: errorMsg)
                    self.handleUploadFailure()
                    
                case 403:
                    let errorMsg = "アクセス拒否 (403): 権限がありません"
                    print("❌ \(errorMsg)")
                    recording.markAsUploadFailed(error: errorMsg)
                    self.handleUploadFailure()
                    
                case 404:
                    let errorMsg = "エンドポイントエラー (404): アップロードURLが見つかりません"
                    print("❌ \(errorMsg)")
                    print("❌ URL: \(self.serverURL)/upload")
                    recording.markAsUploadFailed(error: errorMsg)
                    self.handleUploadFailure()
                    
                case 413:
                    let errorMsg = "ファイルサイズエラー (413): ファイルが大きすぎます"
                    print("❌ \(errorMsg)")
                    print("❌ ファイルサイズ: \(recording.fileSizeFormatted)")
                    recording.markAsUploadFailed(error: errorMsg)
                    self.handleUploadFailure()
                    
                case 500...599:
                    let errorMsg = "サーバーエラー (\(httpResponse.statusCode)): サーバー側で問題が発生しました"
                    print("❌ \(errorMsg)")
                    if let body = responseBody {
                        print("❌ エラー詳細: \(body)")
                    }
                    recording.markAsUploadFailed(error: errorMsg)
                    self.handleUploadFailure()
                    
                default:
                    let errorMsg = "予期しないステータスコード: \(httpResponse.statusCode)"
                    print("⚠️ \(errorMsg)")
                    if let body = responseBody {
                        print("⚠️ レスポンス: \(body)")
                    }
                    recording.markAsUploadFailed(error: errorMsg)
                    self.handleUploadFailure()
                }
            }
        }
        
        uploadTask.resume()
        print("🚀 アップロードタスク開始")
    }
    
    // アップロード失敗時の共通処理
    private func handleUploadFailure() {
        self.connectionStatus = .failed
        self.uploadProgress = 0.0
        
        // UIリセット
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.currentUploadingFile = nil
        }
    }
    
    // サーバー接続テスト機能
    func testServerConnection(completion: @escaping (Bool, String) -> Void) {
        guard let testURL = URL(string: "\(serverURL)/health") else {
            completion(false, "無効なサーバーURL: \(serverURL)")
            return
        }
        
        print("🔍 サーバー接続テスト開始: \(testURL)")
        
        var request = URLRequest(url: testURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    let errorMessage = "接続エラー: \(error.localizedDescription)"
                    print("❌ \(errorMessage)")
                    completion(false, errorMessage)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 サーバーレスポンス: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 {
                        completion(true, "サーバー接続成功")
                    } else if httpResponse.statusCode == 404 {
                        // /healthエンドポイントがない場合、/uploadで確認
                        self.testUploadEndpoint(completion: completion)
                    } else {
                        completion(false, "サーバーエラー: \(httpResponse.statusCode)")
                    }
                } else {
                    completion(false, "無効なレスポンス")
                }
            }
        }.resume()
    }
    
    // アップロードエンドポイントのテスト
    private func testUploadEndpoint(completion: @escaping (Bool, String) -> Void) {
        guard let uploadURL = URL(string: "\(serverURL)/upload") else {
            completion(false, "無効なアップロードURL")
            return
        }
        
        print("🔍 アップロードエンドポイントテスト: \(uploadURL)")
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 10.0
        
        // 空のリクエストを送信して、エンドポイントの存在確認
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 アップロードエンドポイントレスポンス: \(httpResponse.statusCode)")
                    
                    // 400は「リクエストが不正」なので、エンドポイントは存在している
                    if httpResponse.statusCode == 400 || httpResponse.statusCode == 422 {
                        completion(true, "アップロードエンドポイント確認済み")
                    } else if httpResponse.statusCode == 404 {
                        completion(false, "アップロードエンドポイントが見つかりません")
                    } else {
                        completion(true, "サーバー応答確認済み (ステータス: \(httpResponse.statusCode))")
                    }
                } else {
                    completion(false, "エンドポイントテスト失敗")
                }
            }
        }.resume()
    }
    
    // 同一ファイル名での上書きテスト
    func testDuplicateFileUpload(_ recording: RecordingModel, completion: @escaping (Bool, String) -> Void) {
        print("🧪 同一ファイル名アップロードテスト: \(recording.fileName)")
        
        // 通常のアップロード処理を実行し、結果を監視
        var statusObserver: AnyCancellable?
        
        statusObserver = $connectionStatus
            .combineLatest($currentUploadingFile)
            .sink { status, uploadingFile in
                
                if uploadingFile == recording.fileName {
                    switch status {
                    case .connected:
                        print("✅ 同一ファイル名アップロード成功")
                        statusObserver?.cancel()
                        completion(true, "同一ファイル名でのアップロード成功（サーバー側で上書き処理された可能性）")
                        
                    case .failed:
                        print("❌ 同一ファイル名アップロード失敗")
                        statusObserver?.cancel()
                        completion(false, "同一ファイル名でのアップロード失敗（サーバー側で重複拒否された可能性）")
                        
                    default:
                        break
                    }
                }
            }
        
        // 実際のアップロードを実行
        uploadRecording(recording)
        
        // タイムアウト処理
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            statusObserver?.cancel()
            completion(false, "テストタイムアウト")
        }
    }
} 