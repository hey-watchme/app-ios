//
//  VideoPicker.swift
//  ios_watchme_v9
//
//  Custom video picker using PHPickerViewController
//

import SwiftUI
import PhotosUI

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var selectedVideoURL: URL?
    @Environment(\.dismiss) private var dismiss
    var onConfirm: (URL) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .videos
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker

        init(_ parent: VideoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                // User cancelled
                parent.onCancel()
                return
            }

            // Validate video
            let itemProvider = result.itemProvider
            guard itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
                parent.onCancel()
                return
            }

            // Show confirmation dialog IMMEDIATELY before loading
            showConfirmationAlert(on: picker, itemProvider: itemProvider)
        }

        private func showConfirmationAlert(on picker: PHPickerViewController, itemProvider: NSItemProvider) {
            let alert = UIAlertController(
                title: "この動画を分析しますか？",
                message: nil,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "はい", style: .default) { _ in
                // Dismiss picker IMMEDIATELY
                picker.dismiss(animated: true) {
                    // Start loading video in background
                    self.loadVideo(itemProvider: itemProvider)
                }
            })

            alert.addAction(UIAlertAction(title: "いいえ", style: .cancel) { _ in
                // Picker remains open for another selection
                self.parent.selectedVideoURL = nil
            })

            picker.present(alert, animated: true)
        }

        private func loadVideo(itemProvider: NSItemProvider) {
            // Phase 1: Video loading (0% - 33%)
            DispatchQueue.main.async {
                ToastManager.shared.showProgressWithPhase(
                    phase: "動画を読み込み中...",
                    subtitle: nil,
                    progress: 0.0
                )
            }

            // Load the video
            itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                guard let url = url, error == nil else {
                    DispatchQueue.main.async {
                        ToastManager.shared.showError(
                            title: "読み込み失敗",
                            subtitle: "動画の読み込みに失敗しました"
                        )
                        self.parent.onCancel()
                    }
                    return
                }

                DispatchQueue.main.async {
                    ToastManager.shared.showProgressWithPhase(
                        phase: "動画を読み込み中...",
                        subtitle: nil,
                        progress: 0.16  // 16% (halfway in phase 1)
                    )
                }

                // Copy to temp directory
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("selected_video_\(UUID().uuidString).mov")

                do {
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try FileManager.default.removeItem(at: tempURL)
                    }
                    try FileManager.default.copyItem(at: url, to: tempURL)

                    DispatchQueue.main.async {
                        ToastManager.shared.showProgressWithPhase(
                            phase: "動画を読み込み中...",
                            subtitle: nil,
                            progress: 0.33  // 33% (phase 1 complete)
                        )

                        self.parent.selectedVideoURL = tempURL

                        // Immediately proceed to next phase (no delay needed)
                        self.parent.onConfirm(tempURL)
                    }
                } catch {
                    print("❌ Error copying video: \(error)")
                    DispatchQueue.main.async {
                        ToastManager.shared.showError(
                            title: "読み込み失敗",
                            subtitle: error.localizedDescription
                        )
                        self.parent.onCancel()
                    }
                }
            }
        }
    }
}
