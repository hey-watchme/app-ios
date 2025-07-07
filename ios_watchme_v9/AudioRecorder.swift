//
//  AudioRecorder.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/06/11.
//

import Foundation
import AVFoundation
import SwiftUI

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordings: [RecordingModel] = []
    @Published var recordingTime: TimeInterval = 0
    @Published var currentSlot: String = ""
    @Published var totalRecordingSessions: Int = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var slotSwitchTimer: Timer?  // 正確な30分境界でのタイマー
    private var recordingStartTime: Date?
    private var currentSlotStartTime: Date?
    private var pendingRecordings: [RecordingModel] = []  // アップロード待ちキュー
    
    override init() {
        super.init()
        setupAudioSession()
        loadRecordings()
        setupNotificationObserver()
    }
    
    // アップロード完了通知の監視を設定
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUploadedFileDeleted(_:)),
            name: NSNotification.Name("UploadedFileDeleted"),
            object: nil
        )
    }
    
    // アップロード完了ファイル削除の通知を受信
    @objc private func handleUploadedFileDeleted(_ notification: Notification) {
        guard let deletedRecording = notification.object as? RecordingModel else { return }
        
        print("📢 アップロード完了ファイル削除通知を受信: \(deletedRecording.fileName)")
        
        DispatchQueue.main.async {
            // リストから削除
            self.recordings.removeAll { $0.fileName == deletedRecording.fileName }
            self.pendingRecordings.removeAll { $0.fileName == deletedRecording.fileName }
            
            print("✅ リストからファイルを削除: \(deletedRecording.fileName)")
            print("📊 残りファイル数: \(self.recordings.count)")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // オーディオセッションの設定
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("オーディオセッション設定エラー: \(error)")
        }
    }
    
    // 現在の30分スロット時刻を取得（HH-mm形式）
    private func getCurrentSlot() -> String {
        return SlotTimeUtility.getCurrentSlot()
    }
    
    // 特定の時刻のスロットを取得
    private func getSlotForDate(_ date: Date) -> String {
        return SlotTimeUtility.getSlotName(from: date)
    }
    
    // 次のスロット切り替えまでの正確な秒数を計算
    private func getSecondsUntilNextSlot() -> TimeInterval {
        return SlotTimeUtility.getSecondsUntilNextSlot()
    }
    
    // 次のスロット開始時刻を取得
    private func getNextSlotStartTime() -> Date {
        return SlotTimeUtility.getNextSlotStartTime()
    }
    
    // 録音開始
    func startRecording() {
        guard !isRecording else {
            print("⚠️ 既に録音中です")
            return
        }
        
        recordingStartTime = Date()
        currentSlot = getCurrentSlot()
        currentSlotStartTime = Date()
        totalRecordingSessions = 0
        
        print("🎙️ 録音開始 - 開始スロット: \(currentSlot)")
        print("📅 録音開始時刻: \(recordingStartTime!)")
        
        // 最初のスロット録音を開始
        if startRecordingForCurrentSlot() {
            isRecording = true
            setupSlotSwitchTimer()
            startRecordingTimer()
            print("✅ 録音開始成功")
        } else {
            print("❌ 録音開始失敗")
            cleanup()
        }
    }
    
    // 現在のスロット用録音を開始
    @discardableResult
    private func startRecordingForCurrentSlot() -> Bool {
        let fileName = "\(currentSlot).wav"
        let documentPath = getDocumentsDirectory()
        let audioURL = documentPath.appendingPathComponent(fileName)
        
        // 同じファイル名の既存録音を確認（上書き処理）
        handleExistingRecording(fileName: fileName)
        
        print("🔍 新規スロット録音開始:")
        print("   - スロット: \(currentSlot)")
        print("   - ファイル名: \(fileName)")
        print("   - 保存パス: \(audioURL.path)")
        print("   - スロット開始時刻: \(currentSlotStartTime!)")
        
        // 録音設定（16kHz設定）
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,  // 16kHzに変更
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue  // 16kHzに適した品質
        ]
        
        do {
            // 既存のレコーダーを停止
            audioRecorder?.stop()
            audioRecorder = nil
            
            // 新しいレコーダーを作成
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            let success = audioRecorder?.record() ?? false
            
            if success {
                print("✅ スロット録音開始成功: \(fileName)")
                totalRecordingSessions += 1
                return true
            } else {
                print("❌ スロット録音開始失敗: record()がfalseを返却")
                return false
            }
            
        } catch {
            print("❌ スロット録音開始エラー: \(error)")
            print("❌ エラー詳細: \(error.localizedDescription)")
            return false
        }
    }
    
    // 既存録音の処理（自動上書き）
    private func handleExistingRecording(fileName: String) {
        if let existingIndex = recordings.firstIndex(where: { $0.fileName == fileName }) {
            let existingRecording = recordings[existingIndex]
            print("🔄 同一スロット録音の自動上書き: \(fileName)")
            print("   - 既存ファイル作成日時: \(existingRecording.date)")
            print("   - 既存ファイルサイズ: \(existingRecording.fileSizeFormatted)")
            print("   - 既存アップロード状態: \(existingRecording.isUploaded ? "済み" : "未完了")")
            
            // 既存ファイルの物理削除
            let fileURL = existingRecording.getFileURL()
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    print("📁 既存物理ファイル削除: \(fileURL.path)")
                } catch {
                    print("⚠️ 既存ファイル削除エラー: \(error.localizedDescription)")
                }
            }
            
            // アップロード状態クリア（UserDefaultsからも削除）
            clearUploadStatus(fileName: fileName)
            
            // リストから削除
            recordings.remove(at: existingIndex)
            pendingRecordings.removeAll { $0.fileName == fileName }
            
            print("✅ 上書き準備完了 - 新録音を開始します")
        }
    }
    
    // スロット切り替えタイマーを設定（正確な30分境界で実行）
    private func setupSlotSwitchTimer() {
        // 既存のタイマーをクリア
        slotSwitchTimer?.invalidate()
        
        let secondsUntilNextSlot = getSecondsUntilNextSlot()
        print("⏰ 次のスロット切り替えまで: \(Int(secondsUntilNextSlot))秒")
        
        // 最初の切り替えタイマー（次の30分境界まで）
        slotSwitchTimer = Timer.scheduledTimer(withTimeInterval: secondsUntilNextSlot, repeats: false) { [weak self] _ in
            self?.performSlotSwitch()
        }
    }
    
    // スロット切り替えを実行
    private func performSlotSwitch() {
        guard isRecording else {
            print("⚠️ 録音停止中のため、スロット切り替えをスキップ")
            return
        }
        
        let oldSlot = currentSlot
        let newSlot = getCurrentSlot()
        
        print("🔄 スロット切り替え実行: \(oldSlot) → \(newSlot)")
        print("📅 切り替え時刻: \(Date())")
        
        // 現在の録音を完了・保存
        if let completedRecording = finishCurrentSlotRecordingWithReturn() {
            // 自動アップロード機能を削除（手動アップロードのみ対応）
            print("💾 スロット切り替え時の録音完了: \(completedRecording.fileName) - 手動アップロードが必要です")
            
            // 新しいスロットで録音開始
            currentSlot = newSlot
            currentSlotStartTime = Date()
            
            if startRecordingForCurrentSlot() {
                // 次の切り替えタイマーを設定（30分後）
                slotSwitchTimer = Timer.scheduledTimer(withTimeInterval: 1800.0, repeats: false) { [weak self] _ in
                    self?.performSlotSwitch()
                }
                print("✅ スロット切り替え成功")
            } else {
                print("❌ 新スロット録音開始失敗 - 録音を停止")
                stopRecording()
            }
        } else {
            print("❌ 現在スロット録音完了失敗 - 録音を停止")
            stopRecording()
        }
    }
    
    // 現在のスロット録音を完了・保存
    @discardableResult
    private func finishCurrentSlotRecording() -> Bool {
        guard let recorder = audioRecorder else {
            print("❌ オーディオレコーダーが存在しません")
            return false
        }
        
        let recordingURL = recorder.url
        let fileName = recordingURL.lastPathComponent
        
        print("💾 スロット録音完了処理開始: \(fileName)")
        print("   - 録音URL: \(recordingURL.path)")
        print("   - スロット継続時間: \(Date().timeIntervalSince(currentSlotStartTime!))秒")
        
        // 録音停止
        recorder.stop()
        
        // ファイル存在確認
        let fileExists = FileManager.default.fileExists(atPath: recordingURL.path)
        print("   - ファイル存在確認: \(fileExists)")
        
        if fileExists {
            // ファイルサイズ確認
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: recordingURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                print("   - ファイルサイズ: \(fileSize) bytes")
                
                if fileSize > 0 {
                    // RecordingModelを作成・追加
                    let recording = RecordingModel(fileName: fileName, date: currentSlotStartTime!)
                    
                    // 重複チェック
                    if let existingIndex = recordings.firstIndex(where: { $0.fileName == fileName }) {
                        recordings.remove(at: existingIndex)
                        print("🔄 既存の同名録音を置換")
                    }
                    
                    recordings.insert(recording, at: 0)
                    pendingRecordings.append(recording)
                    
                    print("✅ スロット録音完了: \(fileName)")
                    print("📊 総録音ファイル数: \(recordings.count)")
                    return true
                } else {
                    print("❌ ファイルサイズが0bytes")
                    return false
                }
            } catch {
                print("❌ ファイル属性取得エラー: \(error)")
                return false
            }
        } else {
            print("❌ 録音ファイルが存在しません")
            return false
        }
    }
    
    // 現在のスロット録音を完了・保存し、RecordingModelを返す
    private func finishCurrentSlotRecordingWithReturn() -> RecordingModel? {
        guard let recorder = audioRecorder else {
            print("❌ オーディオレコーダーが存在しません")
            return nil
        }
        
        let recordingURL = recorder.url
        let fileName = recordingURL.lastPathComponent
        
        print("💾 スロット録音完了処理開始: \(fileName)")
        print("   - 録音URL: \(recordingURL.path)")
        print("   - スロット継続時間: \(Date().timeIntervalSince(currentSlotStartTime!))秒")
        
        // 録音停止
        recorder.stop()
        
        // ファイル存在確認
        let fileExists = FileManager.default.fileExists(atPath: recordingURL.path)
        print("   - ファイル存在確認: \(fileExists)")
        
        if fileExists {
            // ファイルサイズ確認
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: recordingURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                print("   - ファイルサイズ: \(fileSize) bytes")
                
                if fileSize > 0 {
                    // RecordingModelを作成・追加
                    let recording = RecordingModel(fileName: fileName, date: currentSlotStartTime!)
                    
                    // 重複チェック
                    if let existingIndex = recordings.firstIndex(where: { $0.fileName == fileName }) {
                        recordings.remove(at: existingIndex)
                        print("🔄 既存の同名録音を置換")
                    }
                    
                    recordings.insert(recording, at: 0)
                    pendingRecordings.append(recording)
                    
                    print("✅ スロット録音完了: \(fileName)")
                    print("📊 総録音ファイル数: \(recordings.count)")
                    return recording
                } else {
                    print("❌ ファイルサイズが0bytes")
                    return nil
                }
            } catch {
                print("❌ ファイル属性取得エラー: \(error)")
                return nil
            }
        } else {
            print("❌ 録音ファイルが存在しません")
            return nil
        }
    }
    
    
    
    // 録音時間更新タイマー開始
    private func startRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            self.recordingTime = Date().timeIntervalSince(startTime)
        }
    }
    
    // アップロード待ちキューを取得
    func getPendingUploads() -> [RecordingModel] {
        return pendingRecordings.filter { !$0.isUploaded && $0.fileExists() }
    }
    
    // アップロード待ちキューから削除
    func removeFromPendingUploads(_ recording: RecordingModel) {
        pendingRecordings.removeAll { $0.fileName == recording.fileName }
    }
    
    // 録音停止（ユーザーによる手動停止）
    func stopRecording() {
        guard isRecording else {
            print("⚠️ 既に録音停止中です")
            return
        }
        
        print("⏹️ 録音停止開始")
        print("📅 停止時刻: \(Date())")
        print("📈 総録音時間: \(recordingTime)秒")
        print("📊 総セッション数: \(totalRecordingSessions)")
        
        // 最後のスロット録音を完了
        if finishCurrentSlotRecording() {
            print("✅ 最終スロット録音完了")
        } else {
            print("❌ 最終スロット録音完了失敗")
        }
        
        // クリーンアップ
        cleanup()
        
        print("✅ 録音停止完了 - 保存されたファイル数: \(recordings.count)")
    }
    
    // クリーンアップ処理
    private func cleanup() {
        // タイマーを停止
        recordingTimer?.invalidate()
        slotSwitchTimer?.invalidate()
        recordingTimer = nil
        slotSwitchTimer = nil
        
        // オーディオレコーダーを停止・クリア
        audioRecorder?.stop()
        audioRecorder = nil
        
        // 状態をリセット
        isRecording = false
        recordingTime = 0
        recordingStartTime = nil
        currentSlotStartTime = nil
        currentSlot = ""
        
        print("🧹 クリーンアップ完了")
    }
    
    // 保存された録音ファイルを読み込み（アップロード状態を永続化から復元）
    private func loadRecordings() {
        let documentsPath = getDocumentsDirectory()
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey])
            
            let wavFiles = fileURLs.filter { $0.pathExtension.lowercased() == "wav" }
            
            print("📂 Documents ディレクトリ内のWAVファイル一覧: \(wavFiles.count)個")
            
            var newRecordings: [RecordingModel] = []
            var duplicateCount = 0
            
            for url in wavFiles {
                let fileName = url.lastPathComponent
                
                // 重複チェック
                if newRecordings.contains(where: { $0.fileName == fileName }) {
                    duplicateCount += 1
                    print("⚠️ 重複ファイル名をスキップ: \(fileName)")
                    continue
                }
                
                // ファイルの詳細情報を取得
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                    let creationDate = resourceValues.creationDate ?? Date()
                    let fileSize = Int64(resourceValues.fileSize ?? 0)
                    
                    // RecordingModelを作成（アップロード状態は自動復元）
                    let recording = RecordingModel(fileName: fileName, date: creationDate)
                    newRecordings.append(recording)
                    
                    print("📄 ファイル読み込み: \(fileName) (サイズ: \(recording.fileSizeFormatted), アップロード: \(recording.isUploaded))")
                    
                } catch {
                    print("⚠️ ファイル属性取得エラー: \(fileName) - \(error)")
                    // エラーがあってもファイルを読み込み
                    let recording = RecordingModel(fileName: fileName, date: Date())
                    newRecordings.append(recording)
                }
            }
            
            // 作成日時で並び替え（新しい順）
            newRecordings.sort { $0.date > $1.date }
            recordings = newRecordings
            
            let uploadedCount = recordings.filter { $0.isUploaded }.count
            let pendingCount = recordings.filter { !$0.isUploaded }.count
            
            print("📋 読み込み完了結果:")
            print("   - 総ファイル数: \(recordings.count)")
            print("   - アップロード済み: \(uploadedCount)")
            print("   - アップロード待ち: \(pendingCount)")
            if duplicateCount > 0 {
                print("   - スキップした重複ファイル: \(duplicateCount)")
            }
            
        } catch {
            print("❌ 録音ファイル読み込みエラー: \(error)")
            recordings = []
        }
    }
    
    // 録音ファイルを削除（アップロード状態もクリア）
    func deleteRecording(_ recording: RecordingModel) {
        let fileURL = recording.getFileURL()
        
        print("🗑️ ファイル削除開始: \(recording.fileName)")
        print("   - ファイルパス: \(fileURL.path)")
        print("   - アップロード状態: \(recording.isUploaded)")
        
        do {
            // ファイル削除
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("✅ ファイル削除成功")
            } else {
                print("⚠️ ファイルが存在しません")
            }
            
            // リストから削除
            recordings.removeAll { $0.fileName == recording.fileName }
            pendingRecordings.removeAll { $0.fileName == recording.fileName }
            
            // アップロード状態をクリア（UserDefaultsからも削除）
            clearUploadStatus(fileName: recording.fileName)
            
            print("✅ 録音ファイル削除完了: \(recording.fileName)")
            
        } catch {
            print("❌ ファイル削除エラー: \(error)")
            print("❌ エラー詳細: \(error.localizedDescription)")
        }
    }
    
    // 特定ファイルのアップロード状態をクリア
    private func clearUploadStatus(fileName: String) {
        let uploadStatusKey = "recordingUploadStatus"
        
        if let data = UserDefaults.standard.data(forKey: uploadStatusKey),
           var statusDict = try? JSONDecoder().decode([String: RecordingStatus].self, from: data) {
            statusDict.removeValue(forKey: fileName)
            
            if let updatedData = try? JSONEncoder().encode(statusDict) {
                UserDefaults.standard.set(updatedData, forKey: uploadStatusKey)
                print("📋 アップロード状態クリア: \(fileName)")
            }
        }
    }
    
    // RecordingStatus構造体（プライベートでアクセスできないため再定義）
    private struct RecordingStatus: Codable {
        let isUploaded: Bool
        let uploadAttempts: Int
        let lastUploadError: String?
    }
    
    // 録音時間をフォーマット
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, milliseconds)
    }
    
    // 現在のスロット情報を取得（UI表示用）
    func getCurrentSlotInfo() -> String {
        if isRecording {
            return "現在のスロット: \(currentSlot).wav"
        } else {
            return "次のスロット: \(getCurrentSlot()).wav"
        }
    }
    
    // ドキュメントディレクトリのパスを取得
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsPath = paths[0]
        
        // デバッグ：実際のパスを出力
        print("📂 Documents ディレクトリの実際のパス:")
        print("   \(documentsPath.path)")
        print("📂 ファイルURL形式:")
        print("   \(documentsPath.absoluteString)")
        
        return documentsPath
    }
    
    // 古い形式のファイルや破損ファイルをクリーンアップ
    func cleanupOldFiles() {
        let documentsPath = getDocumentsDirectory()
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.fileSizeKey])
            
            // 古い形式のファイルを特定
            let oldFormatFiles = fileURLs.filter { 
                $0.pathExtension.lowercased() == "wav" && $0.lastPathComponent.hasPrefix("recording_")
            }
            
            // 0バイトファイルを特定
            var emptyFiles: [URL] = []
            for url in fileURLs.filter({ $0.pathExtension.lowercased() == "wav" }) {
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                    if (resourceValues.fileSize ?? 0) == 0 {
                        emptyFiles.append(url)
                    }
                } catch {
                    print("⚠️ ファイルサイズチェックエラー: \(url.lastPathComponent)")
                }
            }
            
            let filesToDelete = oldFormatFiles + emptyFiles
            
            print("🧹 クリーンアップ開始:")
            print("   - 古い形式ファイル: \(oldFormatFiles.count)個")
            print("   - 空ファイル: \(emptyFiles.count)個")
            print("   - 総削除予定: \(filesToDelete.count)個")
            
            var deletedCount = 0
            var errorCount = 0
            
            for fileURL in filesToDelete {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    print("✅ 削除: \(fileURL.lastPathComponent)")
                    deletedCount += 1
                    
                    // 録音リストからも削除
                    recordings.removeAll { $0.fileName == fileURL.lastPathComponent }
                    pendingRecordings.removeAll { $0.fileName == fileURL.lastPathComponent }
                    
                    // アップロード状態もクリア
                    clearUploadStatus(fileName: fileURL.lastPathComponent)
                    
                } catch {
                    print("❌ 削除エラー: \(fileURL.lastPathComponent) - \(error)")
                    errorCount += 1
                }
            }
            
            // 録音一覧を再読み込み（状態同期）
            loadRecordings()
            
            print("🎉 クリーンアップ完了:")
            print("   - 削除成功: \(deletedCount)個")
            print("   - 削除失敗: \(errorCount)個")
            print("   - 現在の録音数: \(recordings.count)個")
            
        } catch {
            print("❌ クリーンアップエラー: \(error)")
        }
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("❌ 録音が失敗しました")
        }
    }
} 