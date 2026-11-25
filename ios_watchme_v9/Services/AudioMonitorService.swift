//
//  AudioMonitorService.swift
//  ios_watchme_v9
//
//  録音なしで音声レベルをリアルタイムモニタリング
//  AVAudioEngineを使用（録音の有無に関わらず動作）
//

import Foundation
import AVFoundation
import Combine

final class AudioMonitorService: ObservableObject {
    // MARK: - Properties
    @Published var audioLevel: Float = 0.0  // 0.0 〜 1.0

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var isMonitoring = false
    /// While recording the meter reads the recorder instead of opening the microphone a
    /// second time (two inputs on one session is one more way for the recorder to stop).
    private var followTimer: Timer?

    /// Show the recorder's level instead of running our own engine.
    func follow(_ level: @escaping () -> Float?) {
        stopMonitoring()
        followTimer?.invalidate()
        followTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.audioLevel = level() ?? 0
        }
    }

    /// Back to our own engine (recording stopped).
    func stopFollowing() {
        followTimer?.invalidate()
        followTimer = nil
        audioLevel = 0
    }

    // MARK: - Public Methods

    /// 音声モニタリング開始
    func startMonitoring() {
        guard !isMonitoring else { return }

        do {
            // The same session setup as recording, so starting to record changes nothing under the engine
            try AudioRecorderService.configureSharedSession()

            // AVAudioEngine設定
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else { return }

            inputNode = audioEngine.inputNode
            guard let inputNode = inputNode else { return }

            let recordingFormat = inputNode.outputFormat(forBus: 0)

            // 音声レベルをリアルタイム取得
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                guard let self = self else { return }

                let level = self.calculateAudioLevel(from: buffer)

                DispatchQueue.main.async {
                    self.audioLevel = level
                }
            }

            try audioEngine.start()
            isMonitoring = true

            print("✅ [AudioMonitorService] 音声モニタリング開始")

        } catch {
            print("❌ [AudioMonitorService] 音声モニタリング開始失敗: \(error)")
        }
    }

    /// 音声モニタリング停止
    func stopMonitoring() {
        guard isMonitoring else { return }

        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        isMonitoring = false
        audioLevel = 0.0

        print("⏹️ [AudioMonitorService] 音声モニタリング停止")
    }

    // MARK: - Private Methods

    /// バッファから音声レベルを計算
    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0.0 }

        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0.0

        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))

        // 0.0 〜 1.0 に正規化（録音中と同じ感度になるよう調整）
        // RMS値は通常非常に小さいため、大きく増幅する必要がある
        let normalizedLevel = min(max(rms * 50.0, 0.0), 1.0)

        return normalizedLevel
    }
}
