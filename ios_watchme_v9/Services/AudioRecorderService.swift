//
//  AudioRecorderService.swift
//  ios_watchme_v9
//
//  Records one session as a series of 5-minute WAV chunks (16 kHz, 16-bit, mono).
//  Recording never stops at a chunk boundary: the next recorder is prepared first,
//  then the current one is stopped and the next started (a gap of milliseconds).
//  A session ends when the person stops it, at 60 minutes, when an interruption
//  cannot be resumed, or when writing fails. Every event is published so the
//  store can journal each chunk the moment it starts. See platform/docs/long-recording.md.
//
//  All methods must be called on the main thread (timers and AVFoundation callbacks are too).
//

import Foundation
import AVFoundation
import Combine

enum RecordingEndReason {
    case stopped          // the person stopped
    case limitReached     // 60 minutes
    case interrupted      // a call / Siri took the microphone and recording could not resume
    case failed(Error)    // writing failed (disk full, audio system reset, ...)
}

final class AudioRecorderService: NSObject {
    static let chunkSeconds: TimeInterval = 300
    static let maxSessionSeconds: TimeInterval = 3600
    /// Enough for a whole session (about 115 MB) with room to spare.
    static let minimumFreeBytes: Int64 = 200 * 1024 * 1024

    private struct ActiveChunk {
        let id: String
        let url: URL
        let sequence: Int
    }

    private struct ActiveSession {
        let id: String
        let deviceId: String
        let timezone: TimeZone
        let startedAt: Date
        var nextSequence = 0
        var interrupted = false
    }

    // MARK: - Publishers

    /// A chunk file was opened and is being written. Journal it now.
    let chunkStarted = PassthroughSubject<ChunkRecord, Never>()
    /// The chunk file is closed and complete (record id). Send it.
    let chunkFinished = PassthroughSubject<String, Never>()
    /// The session is over.
    let sessionEnded = PassthroughSubject<RecordingEndReason, Never>()
    /// true while the microphone is taken by a call etc. and we wait to resume.
    let interruptionChanged = PassthroughSubject<Bool, Never>()

    // MARK: - State

    private let audioSession = AVAudioSession.sharedInstance()
    private var recorder: AVAudioRecorder?
    private var current: ActiveChunk?
    private var session: ActiveSession?
    private var rotationTimer: Timer?
    private var limitTimer: Timer?
    /// Recorder -> chunk, until the recorder's delegate reports the file closed.
    private var closing: [ObjectIdentifier: ActiveChunk] = [:]
    private var observers: [NSObjectProtocol] = []

    var isRecording: Bool { session != nil }
    var currentSessionId: String? { session?.id }
    var currentChunkId: String? { current?.id }

    // MARK: - Init

    override init() {
        super.init()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            self?.handleInterruption(note)
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleMediaServicesReset()
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Session control

    func configureAudioSession() throws {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: [])
        } catch {
            // Fall back to plain recording
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
        }
        if audioSession.isInputGainSettable {
            try? audioSession.setInputGain(0.8)
        }
    }

    /// Start a session. Returns its id. Throws when nothing was recorded.
    func startSession(deviceId: String, timezone: TimeZone) throws -> String {
        guard session == nil else { throw RecordingError.alreadyRecording }
        try ensureFreeSpace()

        let newSession = ActiveSession(id: UUID().uuidString, deviceId: deviceId, timezone: timezone, startedAt: Date())
        session = newSession
        do {
            try startChunk()
        } catch {
            session = nil
            throw error
        }

        limitTimer?.invalidate()
        limitTimer = Timer.scheduledTimer(withTimeInterval: Self.maxSessionSeconds, repeats: false) { [weak self] _ in
            self?.endSession(.limitReached)
        }
        print("🎙️ AudioRecorderService: session started \(newSession.id)")
        return newSession.id
    }

    /// The person stopped. The last chunk is closed and reported through chunkFinished.
    func stopSession() {
        endSession(.stopped)
    }

    // MARK: - Chunks

    private func startChunk() throws {
        guard var active = session else { return }
        let now = Date()
        let fileName = ChunkUploader.fileName(for: now, timezone: active.timezone)
        let url = UploadJournal.documentsDirectory.appendingPathComponent(fileName)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let next = try AVAudioRecorder(url: url, settings: settings)
        next.delegate = self
        guard next.prepareToRecord(), next.record() else {
            throw RecordingError.startFailed
        }

        let chunk = ActiveChunk(id: UUID().uuidString, url: url, sequence: active.nextSequence)
        active.nextSequence += 1
        active.interrupted = false
        session = active
        recorder = next
        current = chunk
        closing[ObjectIdentifier(next)] = chunk

        chunkStarted.send(ChunkRecord(
            id: chunk.id, fileName: fileName, deviceId: active.deviceId, recordedAt: now,
            sessionId: active.id, sequence: chunk.sequence, durationSeconds: nil, state: .recording
        ))
        scheduleRotation()
        print("🎙️ AudioRecorderService: chunk \(chunk.sequence) started - \(fileName)")
    }

    private func scheduleRotation() {
        rotationTimer?.invalidate()
        rotationTimer = Timer.scheduledTimer(withTimeInterval: Self.chunkSeconds, repeats: false) { [weak self] _ in
            self?.rotate()
        }
    }

    /// Close the current chunk and immediately open the next one.
    private func rotate() {
        guard session != nil else { return }
        finishCurrentChunk()
        do {
            try startChunk()
        } catch {
            print("❌ AudioRecorderService: could not start the next chunk - \(error)")
            endSession(.failed(error))
        }
    }

    private func finishCurrentChunk() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        guard let active = recorder else { return }
        recorder = nil
        current = nil
        active.stop()   // the delegate reports the closed file -> chunkFinished
    }

    private func endSession(_ reason: RecordingEndReason) {
        guard session != nil else { return }
        finishCurrentChunk()
        limitTimer?.invalidate()
        limitTimer = nil
        session = nil
        interruptionChanged.send(false)
        sessionEnded.send(reason)
        print("⏹️ AudioRecorderService: session ended (\(reason))")
    }

    // MARK: - Things that take the microphone away

    private func handleInterruption(_ notification: Foundation.Notification) {
        guard var active = session,
              let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

        switch type {
        case .began:
            // Close what we have so it gets sent; wait for the end of the interruption to resume.
            finishCurrentChunk()
            active.interrupted = true
            session = active
            interruptionChanged.send(true)
            print("⚠️ AudioRecorderService: interrupted, chunk closed; waiting to resume")

        case .ended:
            guard active.interrupted else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            guard options.contains(.shouldResume) else {
                endSession(.interrupted)
                return
            }
            do {
                try audioSession.setActive(true, options: [])
                try startChunk()
                interruptionChanged.send(false)
                print("▶️ AudioRecorderService: resumed after interruption")
            } catch {
                print("❌ AudioRecorderService: could not resume after interruption - \(error)")
                endSession(.interrupted)
            }

        @unknown default:
            break
        }
    }

    /// The audio system restarted under us. The recorder is dead; keep what was written and go on.
    private func handleMediaServicesReset() {
        guard session != nil else { return }
        finishCurrentChunk()
        do {
            try configureAudioSession()
            try startChunk()
            print("▶️ AudioRecorderService: continued after a media services reset")
        } catch {
            endSession(.failed(error))
        }
    }

    // MARK: - Checks

    private func ensureFreeSpace() throws {
        let values = try? UploadJournal.documentsDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let free = values?.volumeAvailableCapacityForImportantUsage, free < Self.minimumFreeBytes {
            throw RecordingError.notEnoughSpace(freeBytes: free)
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorderService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard let chunk = closing.removeValue(forKey: ObjectIdentifier(recorder)) else { return }
        if !flag {
            // The file may still hold audio; the uploader repairs or drops it.
            print("⚠️ AudioRecorderService: chunk \(chunk.sequence) did not finish cleanly")
        }
        chunkFinished.send(chunk.id)
    }

    /// Writing failed (e.g. the disk is full). The recorder has stopped on its own.
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let failure = error ?? RecordingError.recordingFailed
        print("❌ AudioRecorderService: encode error - \(failure)")
        if self.recorder === recorder {
            self.recorder = nil
            current = nil
        }
        if let chunk = closing.removeValue(forKey: ObjectIdentifier(recorder)) {
            chunkFinished.send(chunk.id)
        }
        endSession(.failed(failure))
    }
}

// MARK: - Errors

enum RecordingError: LocalizedError {
    case startFailed
    case alreadyRecording
    case recordingFailed
    case notEnoughSpace(freeBytes: Int64)

    var errorDescription: String? {
        switch self {
        case .startFailed:
            return "録音の開始に失敗しました"
        case .alreadyRecording:
            return "すでに録音中です"
        case .recordingFailed:
            return "録音に失敗しました"
        case .notEnoughSpace(let free):
            return "空き容量が足りません（残り \(free / 1_048_576) MB。60分の録音には約 200 MB 必要です）"
        }
    }
}
