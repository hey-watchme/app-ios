//
//  AudioRecorderService.swift
//  ios_watchme_v9
//
//  録音の実行にのみ責任を持つ、状態を持たないサービス
//  AVFoundationの操作に特化
//

import Foundation
import AVFoundation
import Combine

// MARK: - AudioRecorderService（録音専門サービス）
final class AudioRecorderService: NSObject {
    // MARK: - Properties
    private var audioRecorder: AVAudioRecorder?
    private var currentRecordingURL: URL?
    private var audioSession: AVAudioSession

    // MARK: - Publishers
    private let recordingCompletedSubject = PassthroughSubject<Result<RecordingInfo, Error>, Never>()
    private let audioLevelSubject = PassthroughSubject<Float, Never>()

    var recordingCompletedPublisher: AnyPublisher<Result<RecordingInfo, Error>, Never> {
        recordingCompletedSubject.eraseToAnyPublisher()
    }

    var audioLevelPublisher: AnyPublisher<Float, Never> {
        audioLevelSubject.eraseToAnyPublisher()
    }

    // MARK: - Metering
    private var meterTimer: Timer?

    // MARK: - Initialization
    override init() {
        self.audioSession = AVAudioSession.sharedInstance()
        super.init()
    }

    // MARK: - Public Methods

    /// オーディオセッションの事前準備（重い処理を先に実行）
    func prepareAudioSession() async throws {
        // バックグラウンドスレッドで実行してメインスレッドをブロックしない
        try await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                do {
                    // iOS 17対応: カテゴリーを先に設定してからアクティブ化
                    try self.audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])

                    // セッションをアクティブ化
                    try self.audioSession.setActive(true, options: [])

                    // マイクゲイン設定（設定可能な場合のみ）
                    if self.audioSession.isInputGainSettable {
                        // 1.0は最大値すぎる可能性があるので0.8に
                        try? self.audioSession.setInputGain(0.8)
                    }

                    print("✅ AudioRecorderService: オーディオセッション準備完了")
                    continuation.resume()
                } catch {
                    print("❌ AudioRecorderService: オーディオセッション準備失敗 - \(error)")

                    // エラー時は代替設定を試す
                    do {
                        try self.audioSession.setCategory(.record, mode: .default)
                        try self.audioSession.setActive(true)
                        print("⚠️ AudioRecorderService: 代替設定で成功")
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }.value
    }

    /// 録音開始
    func startRecording(fileName: String) async throws {
        // 既存の録音を停止
        if audioRecorder?.isRecording == true {
            audioRecorder?.stop()
            audioRecorder = nil
        }

        // ファイルURL生成
        let documentsPath = getDocumentsDirectory()
        let components = fileName.split(separator: "/")

        var fileURL: URL
        if components.count == 2 {
            // 日付ディレクトリを含む形式
            let dateDir = documentsPath.appendingPathComponent(String(components[0]))
            try? FileManager.default.createDirectory(at: dateDir, withIntermediateDirectories: true)
            fileURL = dateDir.appendingPathComponent(String(components[1]))
        } else {
            fileURL = documentsPath.appendingPathComponent(fileName)
        }

        currentRecordingURL = fileURL

        // 録音設定（16kHz、高品質）
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // レコーダー作成
        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()

        // 録音開始
        guard audioRecorder?.record() == true else {
            throw RecordingError.startFailed
        }

        // メータリング開始（0.1秒間隔）
        startMetering()

        print("🎙️ AudioRecorderService: 録音開始 - \(fileName)")
    }

    /// 録音停止
    func stopRecording() async throws -> URL {
        guard let recorder = audioRecorder, recorder.isRecording else {
            throw RecordingError.notRecording
        }

        // メータリング停止
        stopMetering()

        // 録音停止
        recorder.stop()
        audioRecorder = nil

        guard let url = currentRecordingURL else {
            throw RecordingError.noRecordingURL
        }

        print("⏹️ AudioRecorderService: 録音停止 - \(url.lastPathComponent)")

        return url
    }

    /// 録音ファイル削除
    func deleteRecordingFile(url: URL) async throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
            print("🗑️ AudioRecorderService: ファイル削除 - \(url.lastPathComponent)")
        }
    }

    /// 既存録音ファイルの読み込み
    func loadRecordings() async throws -> [RecordingModel] {
        let documentsPath = getDocumentsDirectory()
        var recordings: [RecordingModel] = []

        // 日付ディレクトリを取得（最新30日分）
        let dateDirectories = try FileManager.default.contentsOfDirectory(
            at: documentsPath,
            includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey]
        ).filter { url in
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let dirName = url.lastPathComponent
            // Check for YYYY-MM-DD format using regex
            return isDirectory && dirName.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil
        }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        .prefix(30)

        // 各日付ディレクトリ内のWAVファイルを読み込み
        for dateDir in dateDirectories {
            let dateDirName = dateDir.lastPathComponent

            let wavFiles = try FileManager.default.contentsOfDirectory(
                at: dateDir,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]
            ).filter { $0.pathExtension.lowercased() == "wav" }

            for url in wavFiles {
                let fileName = "\(dateDirName)/\(url.lastPathComponent)"
                let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])
                let creationDate = resourceValues.creationDate ?? Date()

                let recording = RecordingModel(fileName: fileName, date: creationDate)

                // 有効なファイルのみ追加
                if recording.fileExists() && recording.fileSize > 0 {
                    recordings.append(recording)
                }
            }
        }

        return recordings
    }

    // MARK: - Private Methods

    private func startMetering() {
        meterTimer?.invalidate()

        // メインスレッドでTimerを作成（RunLoop必須）
        DispatchQueue.main.async { [weak self] in
            self?.meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateMeters()
            }
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func updateMeters() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }

        recorder.updateMeters()

        let averagePower = recorder.averagePower(forChannel: 0)

        // デシベル値を0-1に正規化
        let minDb: Float = -50.0
        let maxDb: Float = -10.0
        let normalizedValue = (averagePower - minDb) / (maxDb - minDb)
        let clampedValue = max(0.0, min(1.0, normalizedValue))

        // パブリッシュ
        audioLevelSubject.send(clampedValue)
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorderService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let url = recorder.url

        if flag {
            // ファイル存在とサイズ確認
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int64 ?? 0

                if fileSize > 0 {
                    // 成功
                    let dateDir = url.deletingLastPathComponent().lastPathComponent
                    let fileName = "\(dateDir)/\(url.lastPathComponent)"

                    let info = RecordingInfo(
                        fileName: fileName,
                        date: Date(),
                        fileURL: url
                    )

                    recordingCompletedSubject.send(.success(info))
                    print("✅ AudioRecorderService: 録音完了通知送信 - \(fileName)")
                } else {
                    // 0バイトファイル
                    try? FileManager.default.removeItem(at: url)
                    recordingCompletedSubject.send(.failure(RecordingError.emptyFile))
                    print("❌ AudioRecorderService: 0バイトファイル")
                }
            } catch {
                recordingCompletedSubject.send(.failure(error))
                print("❌ AudioRecorderService: ファイル確認エラー - \(error)")
            }
        } else {
            recordingCompletedSubject.send(.failure(RecordingError.recordingFailed))
            print("❌ AudioRecorderService: 録音失敗")
        }

        // リセット
        currentRecordingURL = nil
    }
}

// MARK: - Errors
enum RecordingError: LocalizedError {
    case startFailed
    case notRecording
    case noRecordingURL
    case recordingFailed
    case emptyFile

    var errorDescription: String? {
        switch self {
        case .startFailed:
            return "録音の開始に失敗しました"
        case .notRecording:
            return "録音中ではありません"
        case .noRecordingURL:
            return "録音ファイルのURLが見つかりません"
        case .recordingFailed:
            return "録音に失敗しました"
        case .emptyFile:
            return "録音ファイルが空です"
        }
    }
}

// String.matches(_:) extension is already defined in AudioRecorder.swift