//
//  RecordingModel.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/06/11.
//

import Foundation

class RecordingModel: ObservableObject, Codable {
    @Published var fileName: String
    @Published var date: Date
    @Published var isUploaded: Bool = false
    @Published var fileSize: Int64 = 0
    @Published var uploadAttempts: Int = 0
    @Published var lastUploadError: String?
    
    private static let uploadStatusKey = "recordingUploadStatus"
    
    init(fileName: String, date: Date) {
        self.fileName = fileName
        self.date = date
        self.loadUploadStatus()
        self.updateFileSize()
    }
    
    // MARK: - Codable実装
    enum CodingKeys: String, CodingKey {
        case fileName, date, isUploaded, fileSize, uploadAttempts, lastUploadError
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileName = try container.decode(String.self, forKey: .fileName)
        date = try container.decode(Date.self, forKey: .date)
        isUploaded = try container.decode(Bool.self, forKey: .isUploaded)
        fileSize = try container.decode(Int64.self, forKey: .fileSize)
        uploadAttempts = try container.decode(Int.self, forKey: .uploadAttempts)
        lastUploadError = try container.decodeIfPresent(String.self, forKey: .lastUploadError)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(date, forKey: .date)
        try container.encode(isUploaded, forKey: .isUploaded)
        try container.encode(fileSize, forKey: .fileSize)
        try container.encode(uploadAttempts, forKey: .uploadAttempts)
        try container.encodeIfPresent(lastUploadError, forKey: .lastUploadError)
    }
    
    // MARK: - 永続化メソッド
    private func loadUploadStatus() {
        if let data = UserDefaults.standard.data(forKey: Self.uploadStatusKey),
           let statusDict = try? JSONDecoder().decode([String: RecordingStatus].self, from: data),
           let status = statusDict[fileName] {
            self.isUploaded = status.isUploaded
            self.uploadAttempts = status.uploadAttempts
            self.lastUploadError = status.lastUploadError
            print("📋 アップロード状態復元: \(fileName) - アップロード済み: \(isUploaded)")
        }
    }
    
    func saveUploadStatus() {
        var statusDict: [String: RecordingStatus] = [:]
        
        // 既存のデータを読み込み
        if let data = UserDefaults.standard.data(forKey: Self.uploadStatusKey),
           let existingDict = try? JSONDecoder().decode([String: RecordingStatus].self, from: data) {
            statusDict = existingDict
        }
        
        // 現在の状態を保存
        statusDict[fileName] = RecordingStatus(
            isUploaded: isUploaded,
            uploadAttempts: uploadAttempts,
            lastUploadError: lastUploadError
        )
        
        if let data = try? JSONEncoder().encode(statusDict) {
            UserDefaults.standard.set(data, forKey: Self.uploadStatusKey)
            print("💾 アップロード状態保存: \(fileName) - アップロード済み: \(isUploaded)")
        }
    }
    
    // MARK: - ファイル管理
    private func updateFileSize() {
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            self.fileSize = attributes[.size] as? Int64 ?? 0
        } catch {
            self.fileSize = 0
        }
    }
    
    func markAsUploaded() {
        print("📌 [RecordingModel] markAsUploaded呼び出し開始")
        print("📌 [RecordingModel] ObjectIdentifier: \(ObjectIdentifier(self))")
        print("📌 [RecordingModel] ファイル名: \(fileName)")
        print("📌 [RecordingModel] 変更前のisUploaded: \(isUploaded)")
        
        // メインスレッドで実行されているか確認
        if Thread.isMainThread {
            print("📌 [RecordingModel] メインスレッドで実行中")
        } else {
            print("📌 [RecordingModel] バックグラウンドスレッドで実行中")
        }
        
        isUploaded = true
        print("📌 [RecordingModel] 変更後のisUploaded: \(isUploaded)")
        lastUploadError = nil
        saveUploadStatus()
        print("📌 [RecordingModel] markAsUploaded完了 - 永続化済み")
        
        // @Published属性が正しく動作しているか確認
        DispatchQueue.main.async {
            print("📌 [RecordingModel] メインスレッドでのisUploaded: \(self.isUploaded)")
            print("📌 [RecordingModel] メインスレッドでのObjectIdentifier: \(ObjectIdentifier(self))")
        }
    }
    
    func markAsUploadFailed(error: String) {
        isUploaded = false
        uploadAttempts += 1
        lastUploadError = error
        saveUploadStatus()
    }
    
    func resetUploadStatus() {
        isUploaded = false
        uploadAttempts = 0
        lastUploadError = nil
        saveUploadStatus()
    }
    
    // 強制再アップロード用（アップロード済み状態をリセット）
    func prepareForceUpload() {
        print("🔄 強制再アップロード準備: \(fileName)")
        isUploaded = false
        uploadAttempts = 0
        lastUploadError = "強制再アップロード"
        saveUploadStatus()
    }
    
    // ファイルの存在確認
    func fileExists() -> Bool {
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    // ファイルの完全パス取得
    func getFileURL() -> URL {
        return getDocumentsDirectory().appendingPathComponent(fileName)
    }
}

// MARK: - 補助構造体
private struct RecordingStatus: Codable {
    let isUploaded: Bool
    let uploadAttempts: Int
    let lastUploadError: String?
}

// MARK: - 拡張メソッド
extension RecordingModel {
    // ファイル名からスロット時刻を取得
    var slotTime: String {
        // 日付ディレクトリを含む場合の処理
        let components = fileName.split(separator: "/")
        if components.count == 2 {
            // YYYY-MM-DD/HH-MM.wav 形式
            return String(components[1].dropLast(4))
        } else {
            // 旧形式: HH-MM.wav
            return String(fileName.dropLast(4))
        }
    }
    
    // ファイル名から日付を取得
    var dateString: String? {
        let components = fileName.split(separator: "/")
        if components.count == 2 {
            return String(components[0])
        }
        return nil
    }
    
    // アップロード可能かチェック（試行回数制限なし）
    var canUpload: Bool {
        return !isUploaded && fileExists() && fileSize > 0
    }
    
    // 強制アップロード可能かチェック（既にアップロード済みでも可能、試行回数制限なし）
    var canForceUpload: Bool {
        return fileExists() && fileSize > 0
    }
    
    // 表示用のファイルサイズ
    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    // 録音失敗ファイル（0KB）かどうかをチェック
    var isRecordingFailed: Bool {
        return fileExists() && fileSize == 0
    }
}

// Documents Directory を取得するためのヘルパー関数
func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
} 