//
//  NetworkManager.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/06/11.
//

import SwiftUI
import Foundation

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
        // アップロード可能チェック
        guard recording.canUpload else {
            print("⚠️ アップロード不可: \(recording.fileName)")
            print("   - アップロード済み: \(recording.isUploaded)")
            print("   - ファイル存在: \(recording.fileExists())")
            print("   - アップロード試行回数: \(recording.uploadAttempts)/3")
            
            DispatchQueue.main.async {
                self.connectionStatus = .failed
                self.currentUploadingFile = nil
            }
            return
        }
        
        print("🚀 アップロード開始: \(recording.fileName)")
        print("   - ファイルサイズ: \(recording.fileSizeFormatted)")
        print("   - アップロード試行: \(recording.uploadAttempts + 1)回目")
        print("   - ユーザーID: \(currentUserID)")
        
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
        if let deviceInfo = deviceManager?.getDeviceInfo() {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"device_id\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(deviceInfo.deviceID)\r\n".data(using: .utf8)!)
            print("📱 送信デバイスID: \(deviceInfo.deviceID)")
        } else {
            print("❌ デバイス登録が完了していません。アップロードを中断します。")
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
        
        // URLSessionでリクエストを送信
        URLSession.shared.dataTask(with: request) { data, response, error in
            progressTimer.invalidate()
            
            DispatchQueue.main.async {
                if let error = error {
                    let errorMsg = "ネットワークエラー: \(error.localizedDescription)"
                    print("❌ \(errorMsg)")
                    print("❌ エラー詳細: \(error)")
                    
                    recording.markAsUploadFailed(error: errorMsg)
                    
                    self.connectionStatus = .failed
                    self.uploadProgress = 0.0
                    self.currentUploadingFile = nil
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    let errorMsg = "無効なレスポンス"
                    print("❌ \(errorMsg)")
                    
                    recording.markAsUploadFailed(error: errorMsg)
                    
                    self.connectionStatus = .failed
                    self.uploadProgress = 0.0
                    self.currentUploadingFile = nil
                    return
                }
                
                print("📡 レスポンスステータス: \(httpResponse.statusCode)")
                print("📡 レスポンスヘッダー: \(httpResponse.allHeaderFields)")
                
                if let data = data {
                    print("📡 レスポンスデータサイズ: \(data.count) bytes")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📡 レスポンスボディ: \(responseString)")
                    }
                }
                
                if httpResponse.statusCode == 200 {
                    print("✅ アップロード成功: \(recording.fileName) (ユーザー: \(self.currentUserID))")
                    print("📋 ファイルサイズ: \(recording.fileSizeFormatted)")
                    
                    // RecordingModelの状態を更新（永続化される）
                    recording.markAsUploaded()
                    
                    self.connectionStatus = .connected
                    self.uploadProgress = 1.0
                    
                    // 少し遅らせてUIをリセット（順次処理のため）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.currentUploadingFile = nil
                    }
                    
                } else {
                    let errorMsg = "サーバーエラー - ステータスコード: \(httpResponse.statusCode)"
                    print("❌ \(errorMsg)")
                    
                    // レスポンスボディの詳細を表示
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("❌ サーバーレスポンス: \(responseString)")
                    }
                    
                    recording.markAsUploadFailed(error: errorMsg)
                    
                    self.connectionStatus = .failed
                    self.uploadProgress = 0.0
                    
                    // 少し遅らせてUIをリセット
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.currentUploadingFile = nil
                    }
                }
            }
        }.resume()
    }
} 