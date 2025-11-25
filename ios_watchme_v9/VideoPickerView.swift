//
//  VideoPickerView.swift
//  ios_watchme_v9
//
//  Video to Audio Extraction Feature (Experimental)
//  MVP implementation for extracting audio from camera roll videos
//

import SwiftUI
import PhotosUI
import AVFoundation

struct VideoPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var recordingStore: RecordingStore

    @State private var selectedVideoURL: URL? = nil
    @State private var showPicker = false

    var body: some View {
        Color.clear
            .onAppear {
                showPicker = true
            }
            .sheet(isPresented: $showPicker, onDismiss: {
                dismiss()
            }) {
                VideoPicker(
                    selectedVideoURL: $selectedVideoURL,
                    onConfirm: { videoURL in
                        Task {
                            await handleVideoSelection(videoURL: videoURL)
                        }
                    },
                    onCancel: {
                        dismiss()
                    }
                )
                .ignoresSafeArea()
            }
    }

    // MARK: - Video Processing

    private func handleVideoSelection(videoURL: URL) async {
        // Permission check
        guard !userAccountManager.requireWritePermission() else {
            await MainActor.run {
                ToastManager.shared.showError(
                    title: "ログインが必要です",
                    subtitle: "この機能を使用するにはログインしてください"
                )
            }
            return
        }

        // Device check
        guard deviceManager.selectedDeviceID != nil else {
            await MainActor.run {
                ToastManager.shared.showError(
                    title: "デバイス連携が必要です",
                    subtitle: "デバイスを連携してください"
                )
            }
            return
        }

        do {
            // Phase 2: Audio extraction (33% - 66%)
            await MainActor.run {
                ToastManager.shared.showProgressWithPhase(
                    phase: "音声を抽出中...",
                    subtitle: nil,
                    progress: 0.33  // Start of phase 2
                )
            }

            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

            await MainActor.run {
                ToastManager.shared.showProgressWithPhase(
                    phase: "音声を抽出中...",
                    subtitle: nil,
                    progress: 0.44  // Midpoint of phase 2
                )
            }

            let audioURL = try await extractAudio(from: videoURL)

            await MainActor.run {
                ToastManager.shared.showProgressWithPhase(
                    phase: "音声を抽出中...",
                    subtitle: nil,
                    progress: 0.66  // End of phase 2
                )
            }

            // Phase 3: Upload (66% - 100%)
            await MainActor.run {
                ToastManager.shared.showProgressWithPhase(
                    phase: "音声をアップロード中...",
                    subtitle: audioURL.lastPathComponent,
                    progress: 0.66  // Start of phase 3
                )
            }

            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

            await MainActor.run {
                ToastManager.shared.showProgressWithPhase(
                    phase: "音声をアップロード中...",
                    subtitle: audioURL.lastPathComponent,
                    progress: 0.83  // Midpoint of phase 3
                )
            }

            try await uploadExtractedAudio(audioURL)

            await MainActor.run {
                ToastManager.shared.showProgressWithPhase(
                    phase: "音声をアップロード中...",
                    subtitle: audioURL.lastPathComponent,
                    progress: 1.0  // End of phase 3 (100%)
                )
            }
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3s

            // Success
            await MainActor.run {
                ToastManager.shared.showSuccess(
                    title: "送信完了",
                    subtitle: "分析結果をお待ちください"
                )
            }

        } catch {
            await MainActor.run {
                ToastManager.shared.showError(
                    title: "送信失敗",
                    subtitle: error.localizedDescription
                )
                print("❌ Video processing error: \(error)")
            }
        }
    }

    private func extractAudio(from videoURL: URL) async throws -> URL {
        // Create AVURLAsset from video URL (iOS 18+ compatible)
        let asset = AVURLAsset(url: videoURL)

        // Check if the asset has audio tracks
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard audioTracks.first != nil else {
            throw VideoProcessingError.noAudioTrack
        }

        // Extract as M4A and let server convert to WAV
        let DEBUG_M4A_ONLY = true

        if DEBUG_M4A_ONLY {
            // M4A extraction (previously working)
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("extracted_\(UUID().uuidString).m4a")

            try? FileManager.default.removeItem(at: outputURL)

            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                throw VideoProcessingError.failedToCreateExportSession
            }

            exportSession.outputURL = outputURL
            exportSession.outputFileType = .m4a

            await withCheckedContinuation { continuation in
                exportSession.exportAsynchronously {
                    continuation.resume()
                }
            }

            guard exportSession.status == .completed else {
                throw VideoProcessingError.exportFailed(exportSession.error?.localizedDescription ?? "Export failed")
            }

            print("✅ M4A extraction completed: \(outputURL)")

            // NOTE: Server won't process M4A, but we can verify extraction works
            return outputURL

        } else {
            // WAV extraction (having issues)
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("extracted_\(UUID().uuidString).wav")

            try? FileManager.default.removeItem(at: outputURL)

            // Try simpler WAV extraction
            let firstAudioTrack = audioTracks.first!
            try await extractAudioAsWAV(from: asset, audioTrack: firstAudioTrack, to: outputURL)

            print("✅ WAV extraction completed: \(outputURL)")
            return outputURL
        }
    }

    private func extractAudioAsWAV(from asset: AVAsset, audioTrack: AVAssetTrack, to outputURL: URL) async throws {
        // SIMPLER APPROACH: First extract as M4A, then convert to WAV in a separate step

        // Step 1: Extract to M4A (we know this works)
        let tempM4AURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("temp_\(UUID().uuidString).m4a")

        try? FileManager.default.removeItem(at: tempM4AURL)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw VideoProcessingError.failedToCreateExportSession
        }

        exportSession.outputURL = tempM4AURL
        exportSession.outputFileType = .m4a

        await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }

        guard exportSession.status == .completed else {
            throw VideoProcessingError.exportFailed(exportSession.error?.localizedDescription ?? "M4A export failed")
        }

        print("✅ Step 1: M4A extraction done")

        // Step 2: Convert M4A to WAV using simpler approach
        let m4aAsset = AVURLAsset(url: tempM4AURL)
        let m4aTrack = try await m4aAsset.loadTracks(withMediaType: .audio).first!

        let reader = try AVAssetReader(asset: m4aAsset)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .wav)

        // Simple reader output (no format conversion in reader)
        let readerOutput = AVAssetReaderTrackOutput(track: m4aTrack, outputSettings: nil)
        reader.add(readerOutput)

        // Writer settings for WAV
        let writerSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false  // Required for Linear PCM
        ]

        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: writerSettings)
        writer.add(writerInput)

        // Start
        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        // Simple synchronous copy loop
        let group = DispatchGroup()
        group.enter()

        let queue = DispatchQueue(label: "wav.conversion")
        queue.async {
            while reader.status == .reading {
                if let buffer = readerOutput.copyNextSampleBuffer() {
                    while !writerInput.isReadyForMoreMediaData {
                        usleep(10000) // 10ms
                    }
                    writerInput.append(buffer)
                } else {
                    break
                }
            }

            writerInput.markAsFinished()
            writer.finishWriting {
                group.leave()
            }
        }

        // Wait for completion
        await withCheckedContinuation { continuation in
            group.notify(queue: .main) {
                continuation.resume()
            }
        }

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempM4AURL)

        print("✅ Step 2: WAV conversion done")

        if writer.status == .failed {
            throw VideoProcessingError.exportFailed(writer.error?.localizedDescription ?? "WAV conversion failed")
        }
    }

    private func uploadExtractedAudio(_ audioURL: URL) async throws {
        guard let deviceID = deviceManager.selectedDeviceID,
              let userID = userAccountManager.currentUser?.profile?.userId else {
            print("❌ Missing device ID or user ID")
            throw VideoProcessingError.missingRequiredData
        }

        // Create upload request using the same structure as recording uploads
        let uploadRequest = UploadRequest(
            fileURL: audioURL,
            fileName: audioURL.lastPathComponent,
            userID: userID,
            deviceID: deviceID,
            recordedAt: Date(),
            timezone: deviceManager.selectedDeviceTimezone
        )

        // Use the uploader service directly
        let uploaderService = UploaderService()

        do {
            try await uploaderService.upload(uploadRequest)
            print("✅ Audio upload successful")

            // Clean up temporary file
            try? FileManager.default.removeItem(at: audioURL)

        } catch {
            print("❌ Upload failed: \(error)")
            throw error
        }
    }

}

// MARK: - Error Types

enum VideoProcessingError: LocalizedError {
    case failedToLoadVideo
    case noAudioTrack
    case failedToCreateExportSession
    case exportFailed(String)
    case exportCancelled
    case unexpectedExportStatus
    case missingRequiredData

    var errorDescription: String? {
        switch self {
        case .failedToLoadVideo:
            return "動画の読み込みに失敗しました"
        case .noAudioTrack:
            return "この動画には音声が含まれていません"
        case .failedToCreateExportSession:
            return "音声抽出の準備に失敗しました"
        case .exportFailed(let message):
            return "音声抽出に失敗しました: \(message)"
        case .exportCancelled:
            return "処理がキャンセルされました"
        case .unexpectedExportStatus:
            return "予期しないエラーが発生しました"
        case .missingRequiredData:
            return "必要な情報が不足しています"
        }
    }
}