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
    @State private var videoConfirmed = false  // 動画選択確認フラグ

    var onVideoProcessingStarted: (() -> Void)?

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
                    },
                    onVideoConfirmed: {
                        // 動画選択が確認された瞬間にコールバックを呼ぶ（「はい」を押した瞬間）
                        onVideoProcessingStarted?()
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
            // The copy from the photo library has new file dates; the shooting time embedded in
            // the video is what AudioImporter uses (no original dates to pass).
            defer { try? FileManager.default.removeItem(at: videoURL) }
            try await recordingStore.importFile(at: videoURL, originalDates: nil)
        } catch {
            await MainActor.run {
                ToastManager.shared.showError(title: "取り込めませんでした", subtitle: error.localizedDescription)
                print("❌ Video import error: \(error)")
            }
        }
    }
}
