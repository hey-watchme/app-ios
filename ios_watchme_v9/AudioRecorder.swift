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
    @Published var audioLevels: [CGFloat] = Array(repeating: 0.0, count: 20) // 音声レベル配列（波形表示用）
    @Published var currentAudioLevel: Float = 0.0 // 現在の音声レベル
    @Published var recordingError: String? = nil // 録音エラーメッセージ
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var slotSwitchTimer: Timer?  // 正確な30分境界でのタイマー
    private var recordingStartTime: Date?
    private var currentSlotStartTime: Date?
    private var meterTimer: Timer? // メータリング用タイマー
    private var meterUpdateCount = 0  // デバッグ用カウンター
    
    // DeviceManagerの参照（タイムゾーン取得用）
    var deviceManager: DeviceManager?
    
    // スロット切り替え状態管理
    private var pendingSlotSwitch: SlotSwitchInfo?
    
    // スロット切り替え情報を保持する構造体
    private struct SlotSwitchInfo {
        let oldSlot: String
        let newSlot: String
        let switchTime: Date
    }
    
    override init() {
        super.init()
        setupNotificationObserver()
        // オーディオセッションとファイル読み込みは遅延初期化
        // startLazyInitialization()を外部から呼ぶ
    }

    /// 遅延初期化（アプリ起動後に呼び出す）
    func startLazyInitialization() {
        Task.detached(priority: .background) { [weak self] in
            await self?.performLazyInit()
        }
    }

    private func performLazyInit() async {
        setupAudioSession()
        // 最新30日分のみ読み込む（パフォーマンス改善）
        loadRecordings(daysToLoad: 30)
    }

    // 非同期版のloadRecordings
    private func loadRecordingsAsync() async {
        loadRecordings()
    }
    
    // アップロード完了通知の監視を設定
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUploadedFileDeleted(_:)),
            name: NSNotification.Name("UploadedFileDeleted"),
            object: nil
        )
        
        // アップロード状態変更通知の監視を追加
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRecordingUploadStatusChanged(_:)),
            name: NSNotification.Name("RecordingUploadStatusChanged"),
            object: nil
        )
    }
    
    // アップロード完了ファイル削除の通知を受信
    @objc private func handleUploadedFileDeleted(_ notification: Foundation.Notification) {
        guard let deletedRecording = notification.object as? RecordingModel else { return }
        
        print("📢 アップロード完了ファイル削除通知を受信: \(deletedRecording.fileName)")
        
        DispatchQueue.main.async {
            // リストから削除
            self.recordings.removeAll { $0.fileName == deletedRecording.fileName }
            
            print("✅ リストからファイルを削除: \(deletedRecording.fileName)")
            print("📊 残りファイル数: \(self.recordings.count)")
        }
    }
    
    // アップロード状態変更の通知を受信
    @objc private func handleRecordingUploadStatusChanged(_ notification: Foundation.Notification) {
        guard let changedRecording = notification.object as? RecordingModel else { return }
        
        print("📢 [AudioRecorder] アップロード状態変更通知を受信: \(changedRecording.fileName)")
        print("   - isUploaded: \(changedRecording.isUploaded)")
        print("   - ObjectIdentifier: \(ObjectIdentifier(changedRecording))")
        
        DispatchQueue.main.async {
            // 配列内の対応するRecordingModelを探して状態を確認
            if let index = self.recordings.firstIndex(where: { $0.fileName == changedRecording.fileName }) {
                let recording = self.recordings[index]
                print("📊 [AudioRecorder] 配列内のRecordingModel確認:")
                print("   - ファイル名: \(recording.fileName)")
                print("   - isUploaded: \(recording.isUploaded)")
                print("   - ObjectIdentifier: \(ObjectIdentifier(recording))")
                print("   - 同一インスタンス: \(ObjectIdentifier(recording) == ObjectIdentifier(changedRecording))")
                
                // 配列を強制的に更新してUIを再描画
                self.objectWillChange.send()
                
                // 統計情報の更新を確認
                let uploadedCount = self.recordings.filter { $0.isUploaded }.count
                let pendingCount = self.recordings.filter { !$0.isUploaded }.count
                print("📊 [AudioRecorder] 更新後の統計:")
                print("   - アップロード済み: \(uploadedCount)")
                print("   - アップロード待ち: \(pendingCount)")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // オーディオセッションの設定
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // 録音のみのカテゴリーに変更し、音声記録モードを使用
            try audioSession.setCategory(.record, mode: .spokenAudio, options: [])
            
            // 優先入力ゲインを設定（マイク感度向上）
            if audioSession.isInputGainSettable {
                try audioSession.setInputGain(1.0)  // 最大ゲイン
                print("✅ マイクゲイン設定: 1.0")
            }
            
            try audioSession.setActive(true)
            print("✅ オーディオセッション設定成功: record/spokenAudio with max gain")
        } catch {
            print("❌ オーディオセッション設定エラー: \(error)")
        }
    }
    
    // 現在の30分スロット時刻を取得（HH-mm形式）
    // デバイスのタイムゾーンを考慮
    private func getCurrentSlot() -> String {
        return SlotTimeUtility.getCurrentSlot(timezone: getDeviceTimezone())
    }
    
    // 特定の時刻のスロットを取得
    private func getSlotForDate(_ date: Date) -> String {
        return SlotTimeUtility.getSlotName(from: date, timezone: getDeviceTimezone())
    }
    
    // デバイスのタイムゾーンを取得
    private func getDeviceTimezone() -> TimeZone {
        // DeviceManagerからタイムゾーンを取得
        return deviceManager?.selectedDeviceTimezone ?? TimeZone.current
    }
    
    // 次のスロット切り替えまでの正確な秒数を計算
    private func getSecondsUntilNextSlot() -> TimeInterval {
        return SlotTimeUtility.getSecondsUntilNextSlot(timezone: getDeviceTimezone())
    }
    
    // 次のスロット開始時刻を取得
    private func getNextSlotStartTime() -> Date {
        return SlotTimeUtility.getNextSlotStartTime(timezone: getDeviceTimezone())
    }
    
    // 録音開始
    func startRecording() {
        guard !isRecording else {
            print("⚠️ 既に録音中です")
            return
        }
        
        // エラー状態をクリア
        recordingError = nil
        
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
        // デバイスのタイムゾーンを使用して日付文字列を生成
        let dateString = SlotTimeUtility.getDateString(from: Date(), timezone: getDeviceTimezone())
        let fileName = "\(currentSlot).wav"
        let documentPath = getDocumentsDirectory()
        let dateDirectory = documentPath.appendingPathComponent(dateString)
        
        // 日付ディレクトリを作成
        do {
            try FileManager.default.createDirectory(at: dateDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ 日付ディレクトリ作成エラー: \(error)")
            return false
        }
        
        let audioURL = dateDirectory.appendingPathComponent(fileName)
        
        // 同じファイル名の既存録音を確認（上書き処理）
        handleExistingRecording(fileName: fileName)
        
        print("🔍 新規スロット録音開始:")
        print("   - 日付: \(dateString)")
        print("   - スロット: \(currentSlot)")
        print("   - ファイル名: \(fileName)")
        print("   - 保存パス: \(audioURL.path)")
        print("   - スロット開始時刻: \(currentSlotStartTime!)")
        
        // 録音設定（16kHz高品質設定）
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,  // 16kHzに変更
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue  // 音量向上のため高品質に変更
        ]
        
        do {
            // 既存のレコーダーを停止
            audioRecorder?.stop()
            audioRecorder = nil
            
            // 新しいレコーダーを作成
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            
            // メータリングを有効化（prepareToRecordの前に設定）
            audioRecorder?.isMeteringEnabled = true
            
            // 録音の準備
            let prepared = audioRecorder?.prepareToRecord() ?? false
            print("📊 メータリング有効化: \(audioRecorder?.isMeteringEnabled ?? false)")
            print("📊 録音準備: \(prepared)")
            
            let success = audioRecorder?.record() ?? false
            
            if success {
                print("✅ スロット録音開始成功: \(fileName)")
                totalRecordingSessions += 1
                startMeteringTimer() // メータリングタイマー開始
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
        let dateString = SlotTimeUtility.getDateString(from: Date(), timezone: getDeviceTimezone())
        let fullFileName = "\(dateString)/\(fileName)"
        
        if let existingIndex = recordings.firstIndex(where: { $0.fileName == fullFileName }) {
            let existingRecording = recordings[existingIndex]
            print("⚠️ 同一ファイル名検出！同一スロット録音の自動上書き: \(fileName)")
            print("   - フルファイル名: \(fullFileName)")
            print("   - 既存ファイル作成日時: \(existingRecording.date)")
            print("   - 既存ファイルサイズ: \(existingRecording.fileSizeFormatted)")
            print("   - 既存アップロード状態: \(existingRecording.isUploaded ? "済み" : "未完了")")
            print("   - 🚨 これは本来起こるべきではない状況です（異なるスロット名が期待されます）")
            
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
            clearUploadStatus(fileName: fullFileName)
            
            // リストから削除
            recordings.remove(at: existingIndex)
            
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
    
    // スロット切り替えを実行（堅牢な実装）
    private func performSlotSwitch() {
        guard isRecording else {
            print("⚠️ 録音停止中のため、スロット切り替えをスキップ")
            return
        }
        
        let oldSlot = currentSlot
        
        // 次のスロットの開始時刻を取得
        let nextSlotTime = getNextSlotStartTime()
        // その時刻を使って、新しいスロット名を計算する（デバイスタイムゾーン考慮）
        let newSlot = SlotTimeUtility.getSlotName(from: nextSlotTime, timezone: getDeviceTimezone())
        
        print("🔄 スロット切り替え実行: \(oldSlot) → \(newSlot)")
        print("📅 切り替え時刻: \(Date())")
        print("📅 次のスロット開始時刻: \(nextSlotTime)")
        
        // 次のスロット情報を事前に準備
        pendingSlotSwitch = SlotSwitchInfo(
            oldSlot: oldSlot,
            newSlot: newSlot,
            switchTime: Date()
        )
        
        print("🎯 pendingSlotSwitchを設定: \(oldSlot) → \(newSlot)")
        print("🔍 isRecording状態: \(isRecording)")
        
        // 現在の録音を停止 - 完了通知はaudioRecorderDidFinishRecordingで受け取る
        audioRecorder?.stop()
        print("⏸️ 現在の録音を停止 - 完了をデリゲートで待機")
    }
    
    // 重複メソッドを削除 - 処理はaudioRecorderDidFinishRecordingに統合済み
    
    
    
    // 録音時間更新タイマー開始
    private func startRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            self.recordingTime = Date().timeIntervalSince(startTime)
        }
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
        
        // スロット切り替え状態をクリア（手動停止の場合は次のスロットを開始しない）
        pendingSlotSwitch = nil
        
        // 最後のスロット録音を停止 - 完了処理はデリゲートで実行される
        audioRecorder?.stop()
        print("⏹️ 最終スロット録音停止 - デリゲートで完了処理を待機")
        
        // タイマーだけを停止（currentSlotStartTimeはデリゲートで使用するため保持）
        partialCleanup()
        
        print("✅ 録音停止処理完了")
    }
    
    // 部分クリーンアップ（タイマーと基本状態のみ）
    private func partialCleanup() {
        // タイマーを停止
        recordingTimer?.invalidate()
        slotSwitchTimer?.invalidate()
        meterTimer?.invalidate()
        recordingTimer = nil
        slotSwitchTimer = nil
        meterTimer = nil
        
        // 基本状態をリセット
        isRecording = false
        recordingTime = 0
        recordingStartTime = nil
        
        // 音声レベルをリセット
        audioLevels = Array(repeating: 0.0, count: 20)
        currentAudioLevel = 0.0
        
        print("🧹 部分クリーンアップ完了")
    }
    
    // 完全クリーンアップ（デリゲート処理後に呼び出し）
    private func cleanup() {
        // オーディオレコーダーをクリア
        audioRecorder = nil
        
        // スロット情報をクリア
        currentSlotStartTime = nil
        currentSlot = ""
        
        // スロット切り替え状態もクリア
        pendingSlotSwitch = nil
        
        print("🧹 完全クリーンアップ完了")
    }
    
    // 保存された録音ファイルを読み込み（アップロード状態を永続化から復元）
    private func loadRecordings(daysToLoad: Int? = nil) {
        let documentsPath = getDocumentsDirectory()

        do {
            // 日付ディレクトリを取得
            var dateDirectories = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey])
                .filter { url in
                    // YYYY-MM-DD形式のディレクトリをフィルタ
                    let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    let dirName = url.lastPathComponent
                    return isDirectory && dirName.matches("^\\d{4}-\\d{2}-\\d{2}$")
                }

            // 日付で降順ソート（新しい順）
            dateDirectories.sort { dir1, dir2 in
                dir1.lastPathComponent > dir2.lastPathComponent
            }

            // daysToLoadが指定されている場合は、その日数分のみ処理
            if let days = daysToLoad, days > 0 {
                dateDirectories = Array(dateDirectories.prefix(days))
                print("📂 日付ディレクトリ数: \(dateDirectories.count) (最新\(days)日分)")
            } else {
                print("📂 日付ディレクトリ数: \(dateDirectories.count)")
            }

            var newRecordings: [RecordingModel] = []
            var duplicateCount = 0
            
            // 各日付ディレクトリ内のWAVファイルを読み込み
            for dateDir in dateDirectories {
                let dateDirName = dateDir.lastPathComponent
                
                do {
                    let wavFiles = try FileManager.default.contentsOfDirectory(at: dateDir, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey])
                        .filter { $0.pathExtension.lowercased() == "wav" }
                    
                    print("📁 \(dateDirName): \(wavFiles.count)個のWAVファイル")
                    
                    for url in wavFiles {
                        let fileName = url.lastPathComponent
                        let fullFileName = "\(dateDirName)/\(fileName)"
                        
                        // 重複チェック
                        if newRecordings.contains(where: { $0.fileName == fullFileName }) {
                            duplicateCount += 1
                            print("⚠️ 重複ファイル名をスキップ: \(fullFileName)")
                            continue
                        }
                        
                        // ファイルの詳細情報を取得
                        do {
                            let resourceValues = try url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                            let creationDate = resourceValues.creationDate ?? Date()
                            // fileSizeは使用しないのでコメントアウト
                            // let fileSize = Int64(resourceValues.fileSize ?? 0)
                            
                            // RecordingModelを作成（アップロード状態は自動復元）
                            let recording = RecordingModel(fileName: fullFileName, date: creationDate)
                            
                            // ファイルパス不整合チェック - RecordingModelが実際のファイルを参照できているかチェック
                            if !recording.fileExists() || recording.fileSize == 0 {
                                print("⚠️ ファイルパス不整合検出: RecordingModelパス[\(fullFileName)]が実際のファイル[\(url.path)]を参照できていません")
                                print("   - RecordingModel.fileExists(): \(recording.fileExists())")
                                print("   - RecordingModel.fileSize: \(recording.fileSize)")
                                print("   - 実際のファイルサイズ: \((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)")
                                // この問題ファイルはスキップ（後で修正機能を追加予定）
                                continue
                            }
                            
                            newRecordings.append(recording)
                            
                            print("📄 ファイル読み込み: \(fullFileName) (サイズ: \(recording.fileSizeFormatted), アップロード: \(recording.isUploaded))")
                            
                        } catch {
                            print("⚠️ ファイル属性取得エラー: \(fullFileName) - \(error)")
                            // エラーがあってもファイルを読み込み
                            let recording = RecordingModel(fileName: fullFileName, date: Date())
                            newRecordings.append(recording)
                        }
                    }
                } catch {
                    print("⚠️ 日付ディレクトリ読み込みエラー: \(dateDirName) - \(error)")
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
        print("🎯 audioRecorderDidFinishRecording呼び出し - 成功: \(flag)")
        print("🔍 currentSlotStartTime存在チェック: \(currentSlotStartTime != nil)")
        print("🔍 pendingSlotSwitch存在チェック: \(pendingSlotSwitch != nil)")
        
        if !flag {
            print("❌ 録音が失敗しました")
            // 録音失敗時の処理
            handleRecordingFailure()
            return
        }
        
        // 1. まず録音完了処理を実行（クリーンアップはしない）
        print("📝 録音完了処理を開始します")
        handleRecordingCompletion(recorder: recorder)
        
        // 2. スロット切り替えが待機中の場合は、次のスロットを開始
        if let switchInfo = pendingSlotSwitch {
            print("🔄 スロット切り替え処理を開始します - pendingSlotSwitch有効")
            handleSlotSwitchCompletion(switchInfo: switchInfo)
        } else {
            // 3. 手動停止の場合は、ここで完全クリーンアップを実行
            print("✅ 手動停止のため、ここで完全クリーンアップを実行します")
            cleanup()
        }
    }
    
    // 録音完了処理（RecordingModelの作成と保存）
    private func handleRecordingCompletion(recorder: AVAudioRecorder) {
        guard let currentSlotStartTime = currentSlotStartTime else {
            print("❌ currentSlotStartTimeが設定されていません - 既にクリーンアップされた可能性があります")
            // クリーンアップを完了させる
            cleanup()
            return
        }
        
        let recordingURL = recorder.url
        let fileName = recordingURL.lastPathComponent
        let dateString = SlotTimeUtility.getDateString(from: currentSlotStartTime, timezone: getDeviceTimezone())
        let fullFileName = "\(dateString)/\(fileName)"
        
        print("💾 録音完了処理: \(fullFileName)")
        print("   - 録音URL: \(recordingURL.path)")
        print("   - スロット継続時間: \(Date().timeIntervalSince(currentSlotStartTime))秒")
        
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
                    let recording = RecordingModel(fileName: fullFileName, date: currentSlotStartTime)
                    
                    // メインスレッドで配列を更新
                    DispatchQueue.main.async {
                        // 重複チェック
                        if let existingIndex = self.recordings.firstIndex(where: { $0.fileName == fullFileName }) {
                            self.recordings.remove(at: existingIndex)
                            print("🔄 既存の同名録音を置換")
                        }
                        
                        self.recordings.insert(recording, at: 0)
                        print("✅ 録音完了: \(fullFileName)")
                        print("📊 総録音ファイル数: \(self.recordings.count)")
                    }
                } else {
                    print("❌ ファイルサイズが0bytes - 録音に失敗しました")
                    
                    // 0KBファイルを削除
                    do {
                        try FileManager.default.removeItem(at: recordingURL)
                        print("🗑️ 0KBファイルを削除しました")
                    } catch {
                        print("⚠️ 0KBファイル削除エラー: \(error)")
                    }
                    
                    // メインスレッドでエラーメッセージを設定
                    DispatchQueue.main.async {
                        self.recordingError = "録音に失敗しました。もう一度お試しください。"
                        print("📢 録音エラー設定: \(self.recordingError!)")
                    }
                }
            } catch {
                print("❌ ファイル属性取得エラー: \(error)")
            }
        } else {
            print("❌ 録音ファイルが存在しません")
        }
        
        // クリーンアップは呼び出し元で決定する（責務の分離）
        print("📁 録音保存処理完了 - 後処理は呼び出し元で決定")
    }
    
    // メータリングタイマーを開始
    private func startMeteringTimer() {
        meterTimer?.invalidate()
        print("🎚️ メータリングタイマー開始")
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateAudioMeters()
        }
        
        // タイマーが正しく設定されたか確認
        if meterTimer != nil {
            print("✅ メータリングタイマー設定成功")
        } else {
            print("❌ メータリングタイマー設定失敗")
        }
    }
    
    // 音声レベルを更新
    private func updateAudioMeters() {
        guard let recorder = audioRecorder, recorder.isRecording else { 
            return 
        }
        
        recorder.updateMeters()
        
        // 平均パワーとピークパワーを取得（デシベル値）
        let averagePower = recorder.averagePower(forChannel: 0)
        let peakPower = recorder.peakPower(forChannel: 0)
        
        // デバッグログ（1秒に1回程度）
        meterUpdateCount += 1
        if meterUpdateCount % 20 == 0 {  // 0.05秒 × 20 = 1秒ごと
            print("📊 音声レベル: average=\(averagePower)dB, peak=\(peakPower)dB")
        }
        
        // デシベル値を0-1の範囲に正規化（改善版）
        // -50dB（静音）〜-10dB（通常の話し声）の範囲で正規化
        let minDb: Float = -50.0
        let maxDb: Float = -10.0
        
        // より敏感な正規化
        let normalizedValue = (averagePower - minDb) / (maxDb - minDb)
        let clampedValue = max(0.0, min(1.0, normalizedValue))
        
        if meterUpdateCount % 20 == 0 {
            print("📊 正規化値: \(clampedValue)")
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 現在の音声レベルを更新
            self.currentAudioLevel = Float(clampedValue)
            
            // 波形配列を更新（新しい値を追加し、古い値を削除）
            self.audioLevels.append(CGFloat(clampedValue))
            if self.audioLevels.count > 20 {
                self.audioLevels.removeFirst()
            }
        }
    }
    
    // スロット切り替え完了処理
    private func handleSlotSwitchCompletion(switchInfo: SlotSwitchInfo) {
        print("🔄 スロット切り替え完了処理: \(switchInfo.oldSlot) → \(switchInfo.newSlot)")
        
        // 録音が継続中の場合のみ、次のスロットを開始
        guard isRecording else {
            print("⏹️ ユーザーが録音を停止したため、次のスロットは開始しません")
            pendingSlotSwitch = nil
            cleanup()  // 停止状態なのでクリーンアップ
            return
        }
        
        // 新しいスロット情報を更新
        currentSlot = switchInfo.newSlot
        currentSlotStartTime = Date()
        
        // 次のスロットの録音を開始
        print("▶️ 次のスロットの録音を開始: \(currentSlot)")
        
        if startRecordingForCurrentSlot() {
            // 次の切り替えタイマーを設定（30分後）
            slotSwitchTimer = Timer.scheduledTimer(withTimeInterval: 1800.0, repeats: false) { [weak self] _ in
                self?.performSlotSwitch()
            }
            print("✅ スロット切り替え成功")
        } else {
            print("❌ 次のスロットの録音開始に失敗しました。録音を停止します。")
            DispatchQueue.main.async {
                self.stopRecording()
            }
        }
        
        // スロット切り替え状態をクリア
        pendingSlotSwitch = nil
    }
    
    // 録音失敗時の処理
    private func handleRecordingFailure() {
        print("❌ 録音失敗 - クリーンアップします")
        
        // メインスレッドでエラーメッセージを設定
        DispatchQueue.main.async {
            self.recordingError = "録音に失敗しました。マイクの権限とストレージ容量を確認してください。"
            print("📢 録音失敗エラー設定: \(self.recordingError!)")
        }
        
        // 失敗時は完全クリーンアップを実行
        cleanup()
    }
}

// MARK: - String Extension for Regex
extension String {
    func matches(_ pattern: String) -> Bool {
        return self.range(of: pattern, options: .regularExpression) != nil
    }
} 