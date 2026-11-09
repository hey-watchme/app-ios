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
    @EnvironmentObject var recordingStore: RecordingStore

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

        await MainActor.run {
            onAudioProcessingStarted?()
            ToastManager.shared.showProgressWithPhase(phase: "音声ファイルを読み込み中...", subtitle: nil, progress: 0.0)
        }

        do {
            // Dates come from the original (a copy gets new ones); the copy keeps working
            // after the security-scoped access to the original ends.
            let (copy, dates) = try copyWithDates(from: fileURL)
            defer { try? FileManager.default.removeItem(at: copy) }
            try await recordingStore.importFile(at: copy, originalDates: dates)
        } catch {
            await MainActor.run {
                ToastManager.shared.showError(title: "取り込めませんでした", subtitle: error.localizedDescription)
            }
        }

        await MainActor.run {
            dismiss()
        }
    }

    private func copyWithDates(from sourceURL: URL) throws -> (URL, AudioImporter.FileDates) {
        let accessGranted = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessGranted { sourceURL.stopAccessingSecurityScopedResource() }
        }
        let dates = AudioImporter.FileDates.of(sourceURL)
        let ext = sourceURL.pathExtension.isEmpty ? "audio" : sourceURL.pathExtension
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("selected_audio_\(UUID().uuidString).\(ext)")
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
        } catch {
            try Data(contentsOf: sourceURL).write(to: destination, options: .atomic)
        }
        return (destination, dates)
    }
}
