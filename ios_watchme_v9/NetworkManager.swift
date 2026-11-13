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
    
    private var userAccountManager: UserAccountManager?
    private var deviceManager: DeviceManager?
    
    init(userAccountManager: UserAccountManager? = nil, deviceManager: DeviceManager? = nil) {
        self.userAccountManager = userAccountManager
        self.deviceManager = deviceManager
        
        // 認証済みユーザーIDを優先、フォールバックとして従来のユーザーID
        if let authenticatedUser = userAccountManager?.currentUser {
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
    
    func uploadRecording(_ recording: RecordingModel, completion: @escaping (Bool) -> Void = { _ in }) {
        // 基本的なチェックのみ（ファイル存在と最大試行回数）
        guard recording.fileExists() else {
            print("⚠️ アップロード不可: ファイルが存在しません - \(recording.fileName)")
            DispatchQueue.main.async {
                self.connectionStatus = .failed
                self.currentUploadingFile = nil
            }
            completion(false)
            return
        }

        // 試行回数制限は撤廃（何度でもリトライ可能）
        // アップロード済みでも実行可能（サーバー側で上書き処理される）
        if recording.isUploaded {
            print("ℹ️ アップロード済みファイルの再送信: \(recording.fileName)")
        }
        
        print("🚀 アップロード開始: \(recording.fileName)")
        print("   - ファイルサイズ: \(recording.fileSizeFormatted)")
        print("   - アップロード試行: \(recording.uploadAttempts + 1)回目")
        print("   - ユーザーID: \(currentUserID)")
        print("   - サーバーURL: \(serverURL)")
        print("   - 選択中のデバイスID: \(deviceManager?.selectedDeviceID ?? "nil")")
        print("   - 認証状態: \(userAccountManager?.isAuthenticated ?? false)")
        
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
            completion(false)
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
            completion(false)
            return
        }
        
        print("🌐 アップロード先URL: \(uploadURL)")
        
        // multipart/form-data リクエストを作成
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 120.0  // タイムアウトを120秒に延長
        
        // X-File-Pathヘッダーは廃止されました
        
        // Boundary文字列を生成
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 一時ファイルのパスを生成
        let tempFileName = "\(UUID().uuidString).tmp"
        let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(tempFileName)
        print("📝 一時ファイルパス: \(tempFileURL.path)")
        
        // 一時ファイルを作成してリクエストボディを書き込む
        do {
            // ファイルハンドルを作成
            FileManager.default.createFile(atPath: tempFileURL.path, contents: nil, attributes: nil)
            guard let fileHandle = FileHandle(forWritingAtPath: tempFileURL.path) else {
                throw NSError(domain: "NetworkManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "一時ファイルの作成に失敗しました"])
            }
            
            defer {
                fileHandle.closeFile()
            }
            
            // ① metadata JSONパラメータを追加
            if let deviceInfo = deviceManager?.getDeviceInfo() {
                // ユーザー体験のため、時刻は常にデバイスのローカルタイムゾーンを基準とします。
                // UTCに変換せず、タイムゾーン情報(+09:00など)を付与したままサーバーに送信します。
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone, .withFractionalSeconds]
                // 明示的にローカルタイムゾーンを設定
                isoFormatter.timeZone = TimeZone.current
                let recordedAtString = isoFormatter.string(from: recording.date)
                
                // S3にアップロードするメタデータ
                // プレフィックスを削除し、純粋なdevice_idを使用
                let metadata: [String: Any] = [
                    "device_id": deviceInfo.deviceID,  // プレフィックスなしの純粋なdevice_id
                    "recorded_at": recordedAtString
                ]
                
                if let jsonData = try? JSONSerialization.data(withJSONObject: metadata, options: []),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    fileHandle.write("--\(boundary)\r\n".data(using: .utf8)!)
                    fileHandle.write("Content-Disposition: form-data; name=\"metadata\"\r\n".data(using: .utf8)!)
                    fileHandle.write("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
                    fileHandle.write("\(jsonString)\r\n".data(using: .utf8)!)
                    print("📋 メタデータJSON: \(jsonString)")
                }
            } else {
                print("❌ デバイス登録が完了していません。アップロードを中断します。")
                let errorMsg = "デバイス登録が必要です"
                recording.markAsUploadFailed(error: errorMsg)
                
                // 一時ファイルを削除
                try? FileManager.default.removeItem(at: tempFileURL)
                
                DispatchQueue.main.async {
                    self.connectionStatus = .failed
                    self.currentUploadingFile = nil
                }
                completion(false)
                return
            }
            
            // ② user_id パラメータを追加
            fileHandle.write("--\(boundary)\r\n".data(using: .utf8)!)
            fileHandle.write("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
            fileHandle.write("\(currentUserID)\r\n".data(using: .utf8)!)
            print("👤 送信ユーザーID: \(currentUserID)")
            
            // ③ timestamp パラメータを追加
            // ユーザーの生活時間と一致させるため、ローカルタイムゾーン情報を含めます
            let timestampFormatter = ISO8601DateFormatter()
            timestampFormatter.formatOptions = [.withInternetDateTime, .withTimeZone, .withFractionalSeconds]
            // 明示的にローカルタイムゾーンを設定
            timestampFormatter.timeZone = TimeZone.current
            let timestampString = timestampFormatter.string(from: recording.date)
            
            fileHandle.write("--\(boundary)\r\n".data(using: .utf8)!)
            fileHandle.write("Content-Disposition: form-data; name=\"timestamp\"\r\n\r\n".data(using: .utf8)!)
            fileHandle.write("\(timestampString)\r\n".data(using: .utf8)!)
            print("⏰ 送信タイムスタンプ: \(timestampString)")
            
            // device_idフィールドは廃止されました（metadataに統合）
            
            // ④ file パラメータを追加（ストリーミング方式で読み込み）
            fileHandle.write("--\(boundary)\r\n".data(using: .utf8)!)
            fileHandle.write("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
            fileHandle.write("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
            
            // 音声ファイルをストリーミングでコピー
            guard let audioFileHandle = FileHandle(forReadingAtPath: fileURL.path) else {
                throw NSError(domain: "NetworkManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "音声ファイルを開けません"])
            }
            
            defer {
                audioFileHandle.closeFile()
            }
            
            // 64KBごとにファイルをコピー（メモリ効率化）
            let bufferSize = 65536 // 64KB
            var totalCopied: Int64 = 0
            
            while true {
                let chunk = audioFileHandle.readData(ofLength: bufferSize)
                if chunk.isEmpty {
                    break
                }
                fileHandle.write(chunk)
                totalCopied += Int64(chunk.count)
            }
            
            print("📄 音声ファイルコピー完了: \(totalCopied) bytes")
            
            fileHandle.write("\r\n".data(using: .utf8)!)
            
            // boundary終了
            fileHandle.write("--\(boundary)--\r\n".data(using: .utf8)!)
            
            // ファイルサイズを取得
            let tempFileAttributes = try FileManager.default.attributesOfItem(atPath: tempFileURL.path)
            let tempFileSize = tempFileAttributes[.size] as? Int64 ?? 0
            print("📦 一時ファイルサイズ: \(tempFileSize) bytes")
            
        } catch {
            let errorMsg = "一時ファイル作成エラー: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            
            // 一時ファイルを削除
            try? FileManager.default.removeItem(at: tempFileURL)
            
            recording.markAsUploadFailed(error: errorMsg)
            
            DispatchQueue.main.async {
                self.connectionStatus = .failed
                self.currentUploadingFile = nil
            }
            completion(false)
            return
        }
        
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
        
        // URLSessionでリクエストを送信（ストリーミングアップロード）
        let uploadTask = URLSession.shared.uploadTask(with: request, fromFile: tempFileURL) { data, response, error in
            progressTimer.invalidate()
            
            // 一時ファイルを削除
            defer {
                do {
                    try FileManager.default.removeItem(at: tempFileURL)
                    print("🗑 一時ファイル削除完了: \(tempFileURL.lastPathComponent)")
                } catch {
                    print("⚠️ 一時ファイル削除エラー: \(error.localizedDescription)")
                }
            }
            
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
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    let errorMsg = "無効なレスポンス: HTTPレスポンスではありません"
                    print("❌ \(errorMsg)")
                    
                    recording.markAsUploadFailed(error: errorMsg)
                    
                    self.connectionStatus = .failed
                    self.uploadProgress = 0.0
                    self.currentUploadingFile = nil
                    completion(false)
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
                    
                    // RecordingModelの状態を更新（メインスレッドで実行）
                    print("🔍 [NetworkManager] アップロード前のisUploaded: \(recording.isUploaded)")
                    print("🔍 [NetworkManager] RecordingModelのObjectIdentifier: \(ObjectIdentifier(recording))")
                    
                    // メインスレッドで状態を更新
                    DispatchQueue.main.async {
                        recording.markAsUploaded()
                        print("🔍 [NetworkManager] メインスレッドでmarkAsUploaded実行完了")
                        
                        // AudioRecorderの配列更新を通知
                        NotificationCenter.default.post(
                            name: NSNotification.Name("RecordingUploadStatusChanged"),
                            object: recording
                        )
                    }
                    
                    // 状態が正しく更新されたか確認
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("🔍 [NetworkManager] 0.1秒後のisUploaded: \(recording.isUploaded)")
                        print("🔍 [NetworkManager] 0.1秒後のObjectIdentifier: \(ObjectIdentifier(recording))")
                    }
                    
                    self.connectionStatus = .connected
                    self.uploadProgress = 1.0
                    completion(true)
                    
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
                    completion(false)
                    
                case 401:
                    let errorMsg = "認証エラー (401): 認証情報が無効です"
                    print("❌ \(errorMsg)")
                    recording.markAsUploadFailed(error: errorMsg)
                    self.handleUploadFailure()
                    completion(false)
                    
                case 403:
                    let errorMsg = "アクセス拒否 (403): 権限がありません"
                    print("❌ \(errorMsg)")
                    recording.markAsUploadFailed(error: errorMsg)
                    self.handleUploadFailure()
                    completion(false)
                    
                case 404:
                    let errorMsg = "エンドポイントエラー (404): アップロードURLが見つかりません"
                    print("❌ \(errorMsg)")
                    print("❌ URL: \(self.serverURL)/upload")
                    recording.markAsUploadFailed(error: errorMsg)
                    self.handleUploadFailure()
                    completion(false)
                    
                case 413:
                    let errorMsg = "ファイルサイズエラー (413): ファイルが大きすぎます"
                    print("❌ \(errorMsg)")
                    print("❌ ファイルサイズ: \(recording.fileSizeFormatted)")
                    recording.markAsUploadFailed(error: errorMsg)
                    self.handleUploadFailure()
                    completion(false)
                    
                case 500...599:
                    let errorMsg = "サーバーエラー (\(httpResponse.statusCode)): サーバー側で問題が発生しました"
                    print("❌ \(errorMsg)")
                    if let body = responseBody {
                        print("❌ エラー詳細: \(body)")
                    }
                    recording.markAsUploadFailed(error: errorMsg)
                    self.handleUploadFailure()
                    completion(false)
                    
                default:
                    let errorMsg = "予期しないステータスコード: \(httpResponse.statusCode)"
                    print("⚠️ \(errorMsg)")
                    if let body = responseBody {
                        print("⚠️ レスポンス: \(body)")
                    }
                    recording.markAsUploadFailed(error: errorMsg)
                    self.handleUploadFailure()
                    completion(false)
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
        uploadRecording(recording) { _ in
            // completion handler is handled by statusObserver
        }

        // タイムアウト処理
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            statusObserver?.cancel()
            completion(false, "テストタイムアウト")
        }
    }

    /// Result of DELETE /devices/{id}: the device is deleted only when no other account
    /// is linked to it; otherwise just this account's link is removed.
    struct DeviceRemoval: Decodable {
        let deleted: Bool
        let other_users: Int
    }

    /// DELETE /account: delete the signed-in user's account and data on the server
    /// (platform backend/functions/account). Throws with the server's reason on failure.
    func deleteAccount(userId: String) async throws {
        _ = try await accountRequest(method: "DELETE", path: "/account")
        print("✅ アカウント削除成功: \(userId)")
    }

    /// DELETE /devices/{id}: delete a device and its recordings, or only unlink it when
    /// another account is still linked.
    func deleteDevice(deviceId: String) async throws -> DeviceRemoval {
        let data = try await accountRequest(method: "DELETE", path: "/devices/\(deviceId.lowercased())")
        return try JSONDecoder().decode(DeviceRemoval.self, from: data)
    }

    /// The signed-in user's research consent (GET /account/research-consent).
    func fetchResearchConsent() async throws -> ResearchConsentState {
        let data = try await accountRequest(method: "GET", path: "/account/research-consent")
        return try JSONDecoder().decode(ResearchConsentState.self, from: data)
    }

    /// Record the user's choice (PUT /account/research-consent). Turning it off deletes
    /// the kept audio of this account's devices on the server.
    func setResearchConsent(_ consented: Bool, source: String) async throws -> ResearchConsentState {
        let body: [String: Any] = [
            "consented": consented,
            "policy_version": ResearchConsentInfo.policyVersion,
            "source": source,
        ]
        let data = try await accountRequest(method: "PUT", path: "/account/research-consent",
                                            body: try JSONSerialization.data(withJSONObject: body))
        return try JSONDecoder().decode(ResearchConsentState.self, from: data)
    }

    private func accountRequest(method: String, path: String, body: Data? = nil) async throws -> Data {
        guard let url = URL(string: "\(serverURL)\(path)") else {
            throw NSError(domain: "NetworkManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "無効なURL"])
        }
        guard let bearer = await SupabaseClientManager.shared.bearerToken() else {
            throw NSError(domain: "NetworkManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "ログインし直してからもう一度お試しください"])
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 60
        request.setValue(bearer, forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "NetworkManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "サーバーの応答が読めませんでした"])
        }
        // Only a JSON 200 from the API counts: a page served at the wrong address must
        // never look like success.
        let isJSON = (http.value(forHTTPHeaderField: "Content-Type") ?? "").contains("application/json")
        guard http.statusCode == 200, isJSON else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
            let message: String
            switch http.statusCode {
            case 401: message = "ログインし直してからもう一度お試しください"
            case 404: message = detail ?? "見つかりませんでした"
            default: message = "処理できませんでした（\(http.statusCode)）。時間をおいてもう一度お試しください"
            }
            print("❌ \(method) \(path): \(http.statusCode) \(detail ?? "")")
            throw NSError(domain: "NetworkManager", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return data
    }
} 