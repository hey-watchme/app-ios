//
//  AudioFilePickerView.swift
//  ios_watchme_v9
//
//  Files app audio picker for analysis uploads
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct AudioFilePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var userAccountManager: UserAccountManager

    @State private var showFileImporter = false

    var onAudioProcessingStarted: (() -> Void)?

    var body: some View {
        Color.clear
            .onAppear {
                showFileImporter = true
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let selectedURL = urls.first else {
                        dismiss()
                        return
                    }

                    Task {
                        await handleAudioSelection(fileURL: selectedURL)
                    }
                case .failure(let error):
                    ToastManager.shared.showError(
                        title: "読み込み失敗",
                        subtitle: error.localizedDescription
                    )
                    dismiss()
                }
            }
    }

    private func handleAudioSelection(fileURL: URL) async {
        guard !userAccountManager.requireWritePermission() else {
            await MainActor.run {
                ToastManager.shared.showError(
                    title: "ログインが必要です",
                    subtitle: "この機能を使用するにはログインしてください"
                )
                dismiss()
            }
            return
        }

        guard deviceManager.selectedDeviceID != nil else {
            await MainActor.run {
                ToastManager.shared.showError(
                    title: "デバイス連携が必要です",
                    subtitle: "デバイスを連携してください"
                )
                dismiss()
            }
            return
        }

        do {
            await MainActor.run {
                onAudioProcessingStarted?()
                ToastManager.shared.showProgressWithPhase(
                    phase: "音声ファイルを読み込み中...",
                    subtitle: nil,
                    progress: 0.0
                )
            }

            let preparedFileURL = try await prepareAudioFileForUpload(from: fileURL)

            await MainActor.run {
                ToastManager.shared.showProgressWithPhase(
                    phase: "音声をアップロード中...",
                    subtitle: preparedFileURL.lastPathComponent,
                    progress: 0.66
                )
            }

            try await uploadAudioFile(preparedFileURL)

            await MainActor.run {
                ToastManager.shared.showProgressWithPhase(
                    phase: "音声をアップロード中...",
                    subtitle: preparedFileURL.lastPathComponent,
                    progress: 1.0
                )
            }
            try? await Task.sleep(nanoseconds: 300_000_000)

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
            }
        }

        await MainActor.run {
            dismiss()
        }
    }

    private func prepareAudioFileForUpload(from sourceURL: URL) async throws -> URL {
        let accessGranted = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let detectedExtension = try detectExtension(for: sourceURL)
        let copiedFileURL = try copyToTemporaryDirectory(sourceURL: sourceURL, fileExtension: detectedExtension)

        await MainActor.run {
            ToastManager.shared.showProgressWithPhase(
                phase: "音声ファイルを読み込み中...",
                subtitle: copiedFileURL.lastPathComponent,
                progress: 0.33
            )
        }

        if detectedExtension == "wav" || detectedExtension == "m4a" {
            return copiedFileURL
        }

        if detectedExtension == "mp3" {
            let convertedURL = try await convertAudioToM4A(inputURL: copiedFileURL)
            try? FileManager.default.removeItem(at: copiedFileURL)
            return convertedURL
        }

        throw AudioFileProcessingError.unsupportedFormat
    }

    private func copyToTemporaryDirectory(sourceURL: URL, fileExtension: String) throws -> URL {
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("selected_audio_\(UUID().uuidString).\(fileExtension)")

        try? FileManager.default.removeItem(at: destinationURL)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            let data = try Data(contentsOf: sourceURL)
            try data.write(to: destinationURL, options: .atomic)
        }

        return destinationURL
    }

    private func detectExtension(for fileURL: URL) throws -> String {
        let lowerExt = fileURL.pathExtension.lowercased()
        if ["wav", "m4a", "mp3"].contains(lowerExt) {
            return lowerExt
        }

        if let contentType = try fileURL.resourceValues(forKeys: [.contentTypeKey]).contentType {
            if let wavType = UTType(filenameExtension: "wav"), contentType.conforms(to: wavType) {
                return "wav"
            }
            if let m4aType = UTType(filenameExtension: "m4a"), contentType.conforms(to: m4aType) {
                return "m4a"
            }
            if let mp3Type = UTType(filenameExtension: "mp3"), contentType.conforms(to: mp3Type) {
                return "mp3"
            }
        }

        throw AudioFileProcessingError.unsupportedFormat
    }

    private func convertAudioToM4A(inputURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioFileProcessingError.conversionFailed("変換セッションを作成できませんでした")
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("converted_audio_\(UUID().uuidString).m4a")

        try? FileManager.default.removeItem(at: outputURL)

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        if #available(iOS 18.0, *) {
            do {
                try await exportSession.export(to: outputURL, as: .m4a)
            } catch {
                throw AudioFileProcessingError.conversionFailed(
                    error.localizedDescription
                )
            }
        } else {
            await withCheckedContinuation { continuation in
                exportSession.exportAsynchronously {
                    continuation.resume()
                }
            }

            guard exportSession.status == .completed else {
                throw AudioFileProcessingError.conversionFailed(
                    exportSession.error?.localizedDescription ?? "MP3からM4Aへの変換に失敗しました"
                )
            }
        }

        return outputURL
    }

    private func uploadAudioFile(_ audioURL: URL) async throws {
        guard let deviceID = deviceManager.selectedDeviceID,
              let userID = userAccountManager.effectiveUserId else {
            throw AudioFileProcessingError.missingRequiredData
        }

        let uploadRequest = UploadRequest(
            fileURL: audioURL,
            fileName: audioURL.lastPathComponent,
            userID: userID,
            deviceID: deviceID,
            recordedAt: Date(),
            timezone: deviceManager.selectedDeviceTimezone
        )

        let uploaderService = UploaderService()
        try await uploaderService.upload(uploadRequest)

        try? FileManager.default.removeItem(at: audioURL)
    }
}

enum AudioFileProcessingError: LocalizedError {
    case unsupportedFormat
    case conversionFailed(String)
    case missingRequiredData

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "対応している形式は WAV / M4A / MP3 です"
        case .conversionFailed(let message):
            return "音声変換に失敗しました: \(message)"
        case .missingRequiredData:
            return "必要な情報が不足しています"
        }
    }
}
