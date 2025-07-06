//
//  UploadManager.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/07/06.
//

import Foundation
import Combine

// アップロード履歴項目
struct UploadHistoryItem {
    let fileName: String
    let originalDate: Date
    let uploadedAt: Date
    let fileSize: Int64
    
    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

// アップロードタスクを管理する構造体
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

// シングルトンのアップロードマネージャー
class UploadManager: ObservableObject {
    static let shared = UploadManager()
    
    @Published var uploadQueue: [UploadTask] = []
    @Published var currentTask: UploadTask?
    @Published var isProcessing: Bool = false
    @Published var totalProgress: Double = 0.0
    @Published var successCount: Int = 0
    @Published var failureCount: Int = 0
    
    private var networkManager: NetworkManager?
    private var cancellables = Set<AnyCancellable>()
    private let maxRetryCount = 3
    private let uploadDelay: TimeInterval = 1.0 // アップロード間の遅延
    private let processQueue = DispatchQueue(label: "com.watchme.uploadQueue", qos: .background)
    
    private init() {
        print("📤 UploadManager初期化")
    }
    
    func configure(networkManager: NetworkManager) {
        self.networkManager = networkManager
        print("📤 UploadManager設定完了")
    }
    
    // アップロードタスクを追加
    func addToQueue(_ recording: RecordingModel) {
        guard recording.canUpload else {
            print("⚠️ アップロード不可: \(recording.fileName)")
            return
        }
        
        // 既にキューに存在するかチェック
        if uploadQueue.contains(where: { $0.recording.fileName == recording.fileName }) {
            print("ℹ️ 既にキューに存在: \(recording.fileName)")
            return
        }
        
        let task = UploadTask(recording: recording)
        
        DispatchQueue.main.async {
            self.uploadQueue.append(task)
            print("📤 アップロードキューに追加: \(recording.fileName) (キュー内: \(self.uploadQueue.count)件)")
        }
        
        // 処理が実行中でない場合は開始
        if !isProcessing {
            startProcessing()
        }
    }
    
    // 複数のファイルを一括でキューに追加
    func addMultipleToQueue(_ recordings: [RecordingModel]) {
        print("📤 複数ファイルをキューに追加: \(recordings.count)件")
        
        for recording in recordings {
            addToQueue(recording)
        }
    }
    
    // アップロード処理を開始
    private func startProcessing() {
        guard !isProcessing else {
            print("ℹ️ 既にアップロード処理実行中")
            return
        }
        
        DispatchQueue.main.async {
            self.isProcessing = true
        }
        
        processQueue.async { [weak self] in
            self?.processNextTask()
        }
    }
    
    // 次のタスクを処理
    private func processNextTask() {
        // ペンディングタスクを取得
        guard let nextTaskIndex = uploadQueue.firstIndex(where: { $0.status == .pending }) else {
            print("✅ 全てのアップロードタスク完了")
            DispatchQueue.main.async {
                self.isProcessing = false
                self.updateTotalProgress()
            }
            return
        }
        
        // タスクのステータスを更新
        DispatchQueue.main.async {
            self.uploadQueue[nextTaskIndex].status = .uploading
            self.currentTask = self.uploadQueue[nextTaskIndex]
            self.updateTotalProgress()
        }
        
        let task = uploadQueue[nextTaskIndex]
        print("🚀 アップロード開始: \(task.recording.fileName) (試行: \(task.retryCount + 1)/\(maxRetryCount))")
        
        // NetworkManagerを使用してアップロード
        guard let networkManager = networkManager else {
            print("❌ NetworkManagerが設定されていません")
            handleTaskFailure(at: nextTaskIndex, error: "NetworkManagerが未設定")
            return
        }
        
        // アップロード実行
        DispatchQueue.main.async {
            networkManager.uploadRecording(task.recording)
        }
        
        // アップロード結果を監視（簡単なロジックに変更）
        var statusObserver: AnyCancellable?
        
        statusObserver = networkManager.$connectionStatus
            .sink { [weak self] status in
                guard let self = self else { return }
                
                print("📊 UploadManager監視: status=\(status), targetFile=\(task.recording.fileName)")
                
                switch status {
                case .connected:
                    // アップロード成功 - RecordingModelの状態を確認
                    print("✅ UploadManager: アップロード成功の可能性 \(task.recording.fileName)")
                    
                    // 少し待ってからRecordingModelの状態を確認
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if task.recording.isUploaded {
                            print("✅ RecordingModelもアップロード済みになりました: \(task.recording.fileName)")
                            self.handleTaskSuccess(at: nextTaskIndex)
                            statusObserver?.cancel()
                        } else {
                            print("⚠️ RecordingModelがまだアップロード済みになっていません: \(task.recording.fileName)")
                            // 再度確認
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if task.recording.isUploaded {
                                    print("✅ 遅延でRecordingModelがアップロード済みになりました: \(task.recording.fileName)")
                                    self.handleTaskSuccess(at: nextTaskIndex)
                                    statusObserver?.cancel()
                                } else {
                                    print("❌ RecordingModelのアップロード状態が更新されませんでした: \(task.recording.fileName)")
                                    self.handleTaskFailure(at: nextTaskIndex, error: "アップロード状態未更新")
                                    statusObserver?.cancel()
                                }
                            }
                        }
                    }
                    
                case .failed:
                    print("❌ UploadManager: アップロード失敗 \(task.recording.fileName)")
                    self.handleTaskFailure(at: nextTaskIndex, error: "アップロード失敗")
                    statusObserver?.cancel()
                    
                default:
                    break
                }
            }
        
        // タイムアウト処理（120秒）
        DispatchQueue.global().asyncAfter(deadline: .now() + 120) { [weak self] in
            guard let self = self else { return }
            
            // まだアップロード中の場合はタイムアウト
            if let currentTask = self.currentTask, 
               currentTask.id == task.id && currentTask.status == .uploading {
                print("⏱️ アップロードタイムアウト: \(task.recording.fileName)")
                statusObserver?.cancel()
                self.handleTaskFailure(at: nextTaskIndex, error: "タイムアウト")
            }
        }
    }
    
    // タスク成功処理
    private func handleTaskSuccess(at index: Int) {
        guard index < uploadQueue.count else { return }
        
        let task = uploadQueue[index]
        
        DispatchQueue.main.async {
            self.uploadQueue[index].status = .completed
            self.successCount += 1
            self.currentTask = nil
            self.updateTotalProgress()
            
            print("📊 アップロード統計 - 成功: \(self.successCount), 失敗: \(self.failureCount), 残り: \(self.pendingTaskCount)件")
            
            // 自動削除を一時的に無効化（デバッグ用）
            print("ℹ️ 自動削除を一時的に無効化: \(task.recording.fileName)")
            // self.autoDeleteUploadedFile(task.recording)
        }
        
        // 次のタスクを処理（少し遅延を入れる）
        processQueue.asyncAfter(deadline: .now() + uploadDelay) { [weak self] in
            self?.processNextTask()
        }
    }
    
    // アップロード完了ファイルの自動削除
    private func autoDeleteUploadedFile(_ recording: RecordingModel) {
        print("🗑️ アップロード完了ファイルを自動削除: \(recording.fileName)")
        
        let fileURL = recording.getFileURL()
        
        do {
            // 物理ファイルを削除
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("✅ 物理ファイル削除成功: \(recording.fileName)")
            }
            
            // アップロード履歴に追加
            addToUploadHistory(recording)
            
            // AudioRecorderのリストからも削除（通知を送信）
            NotificationCenter.default.post(
                name: NSNotification.Name("UploadedFileDeleted"),
                object: recording
            )
            
        } catch {
            print("❌ ファイル削除エラー: \(recording.fileName) - \(error)")
        }
    }
    
    // アップロード履歴に追加
    private func addToUploadHistory(_ recording: RecordingModel) {
        let historyKey = "uploadHistory"
        
        var history: [[String: Any]] = []
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let existingHistory = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            history = existingHistory
        }
        
        let historyItem: [String: Any] = [
            "fileName": recording.fileName,
            "originalDate": recording.date.timeIntervalSince1970,
            "uploadedAt": Date().timeIntervalSince1970,
            "fileSize": recording.fileSize
        ]
        
        history.insert(historyItem, at: 0) // 最新を先頭に
        
        // 履歴は最大100件まで保持
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: history) {
            UserDefaults.standard.set(data, forKey: historyKey)
            print("📋 アップロード履歴に追加: \(recording.fileName)")
        }
    }
    
    // タスク失敗処理
    private func handleTaskFailure(at index: Int, error: String) {
        guard index < uploadQueue.count else { return }
        
        let task = uploadQueue[index]
        
        // リトライ可能かチェック
        if task.retryCount < maxRetryCount - 1 {
            // リトライ
            DispatchQueue.main.async {
                self.uploadQueue[index].retryCount += 1
                self.uploadQueue[index].status = .pending
                self.uploadQueue[index].error = error
                self.currentTask = nil
                
                print("🔄 リトライ予定: \(task.recording.fileName) (次回試行: \(self.uploadQueue[index].retryCount + 1)/\(self.maxRetryCount))")
            }
        } else {
            // 最大リトライ回数に達した
            DispatchQueue.main.async {
                self.uploadQueue[index].status = .failed
                self.uploadQueue[index].error = error
                self.failureCount += 1
                self.currentTask = nil
                self.updateTotalProgress()
                
                print("❌ アップロード最終失敗: \(task.recording.fileName) - \(error)")
            }
        }
        
        // 次のタスクを処理
        processQueue.asyncAfter(deadline: .now() + uploadDelay * 2) { [weak self] in
            self?.processNextTask()
        }
    }
    
    // キューから特定のタスクを削除
    func removeFromQueue(_ recording: RecordingModel) {
        DispatchQueue.main.async {
            self.uploadQueue.removeAll { $0.recording.fileName == recording.fileName }
            self.updateTotalProgress()
            print("🗑️ キューから削除: \(recording.fileName)")
        }
    }
    
    // キューをクリア
    func clearQueue() {
        DispatchQueue.main.async {
            self.uploadQueue.removeAll()
            self.currentTask = nil
            self.isProcessing = false
            self.successCount = 0
            self.failureCount = 0
            self.totalProgress = 0.0
            print("🧹 アップロードキューをクリア")
        }
    }
    
    // 失敗したタスクをリトライ
    func retryFailedTasks() {
        let failedTasks = uploadQueue.filter { $0.status == .failed }
        
        guard !failedTasks.isEmpty else {
            print("ℹ️ リトライ対象のタスクがありません")
            return
        }
        
        print("🔄 失敗タスクをリトライ: \(failedTasks.count)件")
        
        DispatchQueue.main.async {
            for (index, task) in self.uploadQueue.enumerated() {
                if task.status == .failed {
                    self.uploadQueue[index].status = .pending
                    self.uploadQueue[index].retryCount = 0
                    self.uploadQueue[index].error = nil
                }
            }
        }
        
        if !isProcessing {
            startProcessing()
        }
    }
    
    // 進捗率を更新
    private func updateTotalProgress() {
        let total = uploadQueue.count
        guard total > 0 else {
            totalProgress = 0.0
            return
        }
        
        let completed = uploadQueue.filter { $0.status == .completed }.count
        totalProgress = Double(completed) / Double(total)
    }
    
    // ペンディングタスク数を取得
    var pendingTaskCount: Int {
        uploadQueue.filter { $0.status == .pending }.count
    }
    
    // アップロード中のタスク数を取得
    var uploadingTaskCount: Int {
        uploadQueue.filter { $0.status == .uploading }.count
    }
    
    // 完了したタスク数を取得
    var completedTaskCount: Int {
        uploadQueue.filter { $0.status == .completed }.count
    }
    
    // 失敗したタスク数を取得
    var failedTaskCount: Int {
        uploadQueue.filter { $0.status == .failed }.count
    }
    
    // キューの状態サマリーを取得
    func getQueueSummary() -> String {
        return """
        📊 アップロードキュー状態:
        - 総タスク数: \(uploadQueue.count)
        - ペンディング: \(pendingTaskCount)
        - アップロード中: \(uploadingTaskCount)
        - 完了: \(completedTaskCount)
        - 失敗: \(failedTaskCount)
        - 進捗率: \(Int(totalProgress * 100))%
        """
    }
    
    // アップロード履歴を取得
    static func getUploadHistory() -> [UploadHistoryItem] {
        let historyKey = "uploadHistory"
        var items: [UploadHistoryItem] = []
        
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let history = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            
            for item in history {
                if let fileName = item["fileName"] as? String,
                   let originalTimestamp = item["originalDate"] as? TimeInterval,
                   let uploadedTimestamp = item["uploadedAt"] as? TimeInterval,
                   let fileSize = item["fileSize"] as? Int64 {
                    
                    items.append(UploadHistoryItem(
                        fileName: fileName,
                        originalDate: Date(timeIntervalSince1970: originalTimestamp),
                        uploadedAt: Date(timeIntervalSince1970: uploadedTimestamp),
                        fileSize: fileSize
                    ))
                }
            }
        }
        
        return items
    }
}