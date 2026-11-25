//
//  AudioRecorderService.swift
//  ios_watchme_v9
//
//  Records one session as a series of 5-minute WAV chunks (16 kHz, 16-bit, mono).
//  Recording never stops at a chunk boundary: the next recorder is prepared first,
//  then the current one is stopped and the next started (a gap of milliseconds).
//  A session ends only when the person stops it, at the time limit, or when writing
//  fails. Nothing else ends it: when the system takes the microphone (a call, Siri,
//  another app) the chunk is closed and sent, and recording resumes as soon as the
//  system lets it: on the end of the interruption (with or without "should resume"),
//  when the app comes back to the foreground, and on a retry timer. A watchdog restarts
//  a recorder that stopped without telling us. Every event is published so the store
//  can journal each chunk the moment it starts, and written to RecordingEventLog for
//  diagnosis. See platform/docs/long-recording.md.
//
//  All methods must be called on the main thread (timers and AVFoundation callbacks are too).
//

import Foundation
import AVFoundation
import Combine
import UIKit

enum RecordingEndReason {
    case stopped          // the person stopped
    case limitReached     // RecordingLimits.maxMinutes (set on the server)
    case interrupted      // no longer used: an interruption waits for the microphone instead of ending
    case failed(Error)    // writing failed (disk full, audio system reset, ...)
}

final class AudioRecorderService: NSObject {
    static let chunkSeconds: TimeInterval = 300
    /// How long one session may run; the value comes from the server (RecordingLimits).
    static var maxSessionSeconds: TimeInterval { RecordingLimits.maxSessionSeconds }
    /// Enough for a whole session (45 minutes is about 115 MB) with room to spare.
    static let minimumFreeBytes: Int64 = 200 * 1024 * 1024

    private struct ActiveChunk {
        let id: String
        let url: URL
        let sequence: Int
    }

    private struct ActiveSession {
        let id: String
        let subjectId: String
        let timezone: TimeZone
        let startedAt: Date
        var nextSequence = 0
        var interrupted = false
        /// Start of chunk 0: the session's one result is keyed by it (sent with every chunk).
        var firstChunkAt: Date?
    }

    // MARK: - Publishers

    /// A chunk file was opened and is being written. Journal it now.
    let chunkStarted = PassthroughSubject<ChunkRecord, Never>()
    /// The chunk file is closed and complete. Send it. `isFinal`: the last chunk of the session.
    let chunkFinished = PassthroughSubject<(id: String, isFinal: Bool), Never>()
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
    /// Chunks closed by the end of their session, until the recorder reports them closed.
    private var finalChunkIds = Set<String>()
    private var observers: [NSObjectProtocol] = []
    /// While interrupted: tries to take the microphone back every few seconds.
    private var resumeTimer: Timer?
    /// While recording: checks that the recorder is really writing.
    private var watchdogTimer: Timer?
    static let resumeRetrySeconds: TimeInterval = 5
    static let watchdogSeconds: TimeInterval = 5

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
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            self?.handleRouteChange(note)
        })
        // Coming back to the app is the surest moment the microphone can be taken back.
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.tryResume(trigger: "app became active")
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Session control

    func configureAudioSession() throws {
        try Self.configureSharedSession()
    }

    /// The one audio session setup of the app (recording and the level meter share it, so
    /// neither changes the session under the other).
    /// - mixWithOthers: another app playing sound (a video, music, a game) does not take the
    ///   microphone from us. Without it, any non-mixable audio of another app interrupts us.
    /// - No Bluetooth input: the phone's own microphone records the room. With HFP allowed,
    ///   earbuds become the microphone, and taking them off interrupts the recording.
    /// - prefersNoInterruptionsFromSystemAlerts: a ringing call (banner style) or an alert
    ///   does not interrupt; only answering the call does.
    /// - prefersInterruptionOnRouteDisconnect = false: unplugging or disconnecting a device
    ///   changes the route instead of interrupting.
    static func configureSharedSession() throws {
        let session = AVAudioSession.sharedInstance()
        let options: AVAudioSession.CategoryOptions = [.mixWithOthers, .defaultToSpeaker]
        if session.category != .playAndRecord || session.mode != .default || session.categoryOptions != options {
            try session.setCategory(.playAndRecord, mode: .default, options: options)
        }
        try? session.setPrefersNoInterruptionsFromSystemAlerts(true)
        try? session.setPrefersInterruptionOnRouteDisconnect(false)
        try session.setActive(true, options: [])
        if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            try? session.setPreferredInput(builtIn)
        }
        if session.isInputGainSettable {
            try? session.setInputGain(0.8)
        }
    }

    /// Start a session. Returns its id. Throws when nothing was recorded.
    /// `limitSeconds` stops the session early (what is left of the month); never beyond the per-recording limit.
    func startSession(subjectId: String, timezone: TimeZone, limitSeconds: TimeInterval? = nil) throws -> String {
        guard session == nil else { throw RecordingError.alreadyRecording }
        try ensureFreeSpace()

        let newSession = ActiveSession(id: UUID().uuidString, subjectId: subjectId, timezone: timezone, startedAt: Date())
        session = newSession
        do {
            try startChunk()
        } catch {
            session = nil
            throw error
        }

        limitTimer?.invalidate()
        // The limit in force when the session starts holds for the whole session.
        let limit = min(Self.maxSessionSeconds, max(limitSeconds ?? .infinity, 1))
        limitTimer = Timer.scheduledTimer(withTimeInterval: limit, repeats: false) { [weak self] _ in
            self?.endSession(.limitReached)
        }
        startWatchdog()
        RecordingEventLog.write("session started \(newSession.id) limit=\(Int(limit))s \(Self.routeSummary())")
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
        next.isMeteringEnabled = true
        guard next.prepareToRecord(), next.record() else {
            throw RecordingError.startFailed
        }

        let chunk = ActiveChunk(id: UUID().uuidString, url: url, sequence: active.nextSequence)
        if active.firstChunkAt == nil {
            active.firstChunkAt = now
        }
        active.nextSequence += 1
        active.interrupted = false
        session = active
        recorder = next
        current = chunk
        closing[ObjectIdentifier(next)] = chunk

        chunkStarted.send(ChunkRecord(
            id: chunk.id, fileName: fileName, subjectId: active.subjectId, recordedAt: now,
            sessionId: active.id, sequence: chunk.sequence, durationSeconds: nil, state: .recording,
            sessionStartedAt: active.firstChunkAt
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
        // The chunk being written is the last one. (After an interruption that could not be
        // resumed nothing is being written; the server closes such a session on its own.)
        if let last = current {
            finalChunkIds.insert(last.id)
        }
        finishCurrentChunk()
        limitTimer?.invalidate()
        limitTimer = nil
        stopResumeTimer()
        watchdogTimer?.invalidate()
        watchdogTimer = nil
        session = nil
        interruptionChanged.send(false)
        sessionEnded.send(reason)
        RecordingEventLog.write("session ended (\(reason))")
        print("⏹️ AudioRecorderService: session ended (\(reason))")
    }

    // MARK: - Things that take the microphone away

    private func handleInterruption(_ notification: Foundation.Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        let reason = (notification.userInfo?[AVAudioSessionInterruptionReasonKey] as? UInt).map(Self.reasonName) ?? "none"
        let options = AVAudioSession.InterruptionOptions(rawValue: notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
        RecordingEventLog.write("interruption \(type == .began ? "began" : "ended") reason=\(reason) shouldResume=\(options.contains(.shouldResume)) recording=\(session != nil) app=\(Self.appState())")
        guard var active = session else { return }

        switch type {
        case .began:
            guard !active.interrupted else { return }
            // Close what we have so it gets sent, then keep trying to take the microphone back.
            finishCurrentChunk()
            active.interrupted = true
            session = active
            interruptionChanged.send(true)
            startResumeTimer()
            print("⚠️ AudioRecorderService: interrupted (\(reason)), chunk closed; waiting to resume")

        case .ended:
            // "shouldResume" is a hint for players. A recorder resumes whenever it can: the
            // person asked for the whole scene, and a missing hint is not a reason to stop.
            tryResume(trigger: "interruption ended")

        @unknown default:
            break
        }
    }

    /// Take the microphone back after an interruption. Fails quietly while the system still
    /// holds it (a call in progress); the retry timer and the next foreground try again.
    private func tryResume(trigger: String) {
        guard let active = session, active.interrupted else { return }
        do {
            try Self.configureSharedSession()
            try startChunk()   // clears `interrupted`
            stopResumeTimer()
            interruptionChanged.send(false)
            RecordingEventLog.write("resumed (\(trigger))")
            print("▶️ AudioRecorderService: resumed after interruption (\(trigger))")
        } catch {
            RecordingEventLog.write("resume failed (\(trigger)): \(error.localizedDescription)")
            print("⏳ AudioRecorderService: could not resume yet (\(trigger)) - \(error)")
        }
    }

    private func startResumeTimer() {
        resumeTimer?.invalidate()
        resumeTimer = Timer.scheduledTimer(withTimeInterval: Self.resumeRetrySeconds, repeats: true) { [weak self] _ in
            self?.tryResume(trigger: "retry")
        }
    }

    private func stopResumeTimer() {
        resumeTimer?.invalidate()
        resumeTimer = nil
    }

    /// A recorder can stop without an interruption or a delegate call (the session was
    /// reconfigured under it, the input route vanished). Every few seconds: if we should
    /// be recording and the recorder is not, close what it wrote and start a new chunk.
    private func startWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: Self.watchdogSeconds, repeats: true) { [weak self] _ in
            self?.checkRecorder()
        }
    }

    private func checkRecorder() {
        guard let active = session, !active.interrupted else { return }
        if let recorder, recorder.isRecording { return }
        RecordingEventLog.write("watchdog: recorder not recording (recorder=\(recorder != nil)); restarting \(Self.routeSummary())")
        finishCurrentChunk()
        do {
            try Self.configureSharedSession()
            try startChunk()
        } catch {
            // Treat it like an interruption: keep the session and keep trying.
            RecordingEventLog.write("watchdog: restart failed: \(error.localizedDescription)")
            if var stuck = session {
                stuck.interrupted = true
                session = stuck
                interruptionChanged.send(true)
                startResumeTimer()
            }
        }
    }

    private func handleRouteChange(_ notification: Foundation.Notification) {
        guard session != nil else { return }
        let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
        RecordingEventLog.write("route change reason=\(raw) \(Self.routeSummary())")
    }

    /// Current input level 0...1 for the meter while recording (nil when not writing).
    func currentLevel() -> Float? {
        guard let recorder, recorder.isRecording else { return nil }
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)   // -160...0
        return max(0, min(1, (db + 50) / 50))
    }

    private static func reasonName(_ raw: UInt) -> String {
        switch AVAudioSession.InterruptionReason(rawValue: raw) {
        case .default: return "default"
        case .builtInMicMuted: return "builtInMicMuted"
        case .routeDisconnected: return "routeDisconnected"
        default: return "raw\(raw)"
        }
    }

    private static func appState() -> String {
        switch UIApplication.shared.applicationState {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
    }

    static func routeSummary() -> String {
        let s = AVAudioSession.sharedInstance()
        let inputs = s.currentRoute.inputs.map { $0.portType.rawValue }.joined(separator: ",")
        let outputs = s.currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ",")
        return "in=[\(inputs)] out=[\(outputs)] category=\(s.category.rawValue) mode=\(s.mode.rawValue) options=\(s.categoryOptions.rawValue)"
    }

    /// The audio system restarted under us. The recorder is dead; keep what was written and go on.
    private func handleMediaServicesReset() {
        RecordingEventLog.write("media services were reset recording=\(session != nil)")
        guard session != nil else { return }
        finishCurrentChunk()
        do {
            try configureAudioSession()
            try startChunk()
            print("▶️ AudioRecorderService: continued after a media services reset")
        } catch {
            // Keep the session and keep trying, like an interruption.
            if var stuck = session {
                stuck.interrupted = true
                session = stuck
                interruptionChanged.send(true)
                startResumeTimer()
            }
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
            RecordingEventLog.write("chunk \(chunk.sequence) did not finish cleanly")
            print("⚠️ AudioRecorderService: chunk \(chunk.sequence) did not finish cleanly")
        }
        chunkFinished.send((id: chunk.id, isFinal: finalChunkIds.remove(chunk.id) != nil))
    }

    /// Writing failed (e.g. the disk is full). The recorder has stopped on its own.
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let failure = error ?? RecordingError.recordingFailed
        RecordingEventLog.write("encode error: \(failure.localizedDescription)")
        print("❌ AudioRecorderService: encode error - \(failure)")
        let wasCurrent = self.recorder === recorder
        if wasCurrent {
            self.recorder = nil
            current = nil
        }
        if let chunk = closing.removeValue(forKey: ObjectIdentifier(recorder)) {
            // The session ends with this chunk.
            finalChunkIds.remove(chunk.id)
            chunkFinished.send((id: chunk.id, isFinal: wasCurrent))
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
            return "空き容量が足りません（残り \(free / 1_048_576) MB。\(Int(AudioRecorderService.maxSessionSeconds / 60))分の録音には約 200 MB 必要です）"
        }
    }
}
