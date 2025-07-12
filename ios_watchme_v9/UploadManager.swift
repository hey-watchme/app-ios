//
//  UploadManager.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/07/06.
//

import Foundation
import Combine

// アップロードタスクを管理する構造体（一時的に定義を維持）
struct UploadTask {
    let id: UUID = UUID()
    let recording: RecordingModel
    var retryCount: Int = 0
    var status: UploadTaskStatus = .pending
    var error: String?
    let createdAt: Date = Date()
}

enum UploadTaskStatus {
    case pending
    case uploading
    case completed
    case failed
    case cancelled
}

// シングルトンのアップロードマネージャー（一時的に無効化）
class UploadManager: ObservableObject {
    static let shared = UploadManager()
    
    @Published var uploadQueue: [UploadTask] = []
    @Published var isProcessing: Bool = false
    
    // configureメソッドだけ残し、中身は空にする
    func configure(networkManager: NetworkManager) {
        // 何もしない
    }
    
    // 他のメソッドはすべてコメントアウト
}