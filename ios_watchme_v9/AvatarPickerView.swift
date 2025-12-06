//
//  AvatarPickerView.swift
//  ios_watchme_v9
//
//  アバター選択・アップロード機能を提供するビュー
//  シートの二重表示問題を解決した実装
//

import SwiftUI
import Mantis

struct AvatarPickerView: View {
    @ObservedObject var viewModel: AvatarUploadViewModel
    let currentAvatarURL: URL?
    @Environment(\.dismiss) private var dismiss

    // 写真選択
    @State private var selectedImage: UIImage? = nil
    @State private var showingPhotoLibrary = false

    // カメラ
    @State private var showingCamera = false
    @State private var cameraImage: UIImage? = nil

    // トリミング（Mantis用）
    @State private var imageToEdit: ImageWrapper? = nil

    // UI状態
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // 現在のアバター表示
            avatarPreviewSection
                .padding(.top, 20)
                .padding(.bottom, 30)
            
            // 選択オプション
            VStack(spacing: 16) {
                // カメラボタン
                Button(action: {
                    showingCamera = true
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .frame(width: 30)
                        Text("写真を撮る")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                // Photo Library Button
                Button(action: {
                    showingPhotoLibrary = true
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .frame(width: 30)
                        Text("写真を選択")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // エラーメッセージ
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(Color.safeColor("ErrorColor"))
                    .padding()
                    .multilineTextAlignment(.center)
            }
            
            // アップロード状態表示
            if viewModel.phase != .idle {
                uploadStateView
                    .padding()
            }
        }
        .disabled(isProcessing || viewModel.phase == .uploading)
        .overlay {
            // Loading overlay when processing image from PhotosPicker
            if isProcessing {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))

                        Text("画像を読み込んでいます...")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(16)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            ImagePickerController(selectedImage: $cameraImage, sourceType: .camera)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingPhotoLibrary) {
            ImagePickerController(selectedImage: Binding(
                get: { selectedImage },
                set: { newImage in
                    if let newImage = newImage {
                        selectedImage = newImage
                        imageToEdit = ImageWrapper(image: newImage)
                        showingPhotoLibrary = false
                    }
                }
            ), sourceType: .photoLibrary)
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $imageToEdit) { wrapper in
            MantisCropper(
                image: wrapper.image,
                onComplete: { croppedImage in
                    Task {
                        await uploadImage(croppedImage)
                    }
                    imageToEdit = nil
                },
                onCancel: {
                    imageToEdit = nil
                }
            )
            .ignoresSafeArea()
        }
        .onChange(of: cameraImage) { newImage in
            if let newImage = newImage {
                imageToEdit = ImageWrapper(image: newImage)
                cameraImage = nil
            }
        }
        .onChange(of: viewModel.phase) { newPhase in
            if case .success = newPhase {
                // アップロード成功時は自動的に閉じる
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Avatar Preview Section
    private var avatarPreviewSection: some View {
        VStack(spacing: 12) {
            // 現在のアバターまたは選択した画像を表示
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.safeColor("PrimaryActionColor"), lineWidth: 3)
                    )
            } else if let url = currentAvatarURL {
                // Use ImageCacheManager for consistent caching behavior
                AvatarImageView(url: url)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(Color.safeColor("BorderLight"))
                    .frame(width: 120, height: 120)
            }

            Text(currentAvatarURL != nil ? "現在のアバター" : "アバター未設定")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // Simple avatar image view using ImageCacheManager
    private struct AvatarImageView: View {
        let url: URL
        @State private var image: UIImage?

        var body: some View {
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(Color.safeColor("BorderLight"))
                }
            }
            .task {
                self.image = await ImageCacheManager.shared.getImage(for: url)
            }
        }
    }
    
    // MARK: - Upload State View
    private var uploadStateView: some View {
        VStack(spacing: 12) {
            switch viewModel.phase {
            case .uploading:
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("アップロード中...")
                        .font(.subheadline)
                }
                .padding()
                .background(Color.safeColor("PrimaryActionColor").opacity(0.1))
                .cornerRadius(10)
                
            case .success:
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.safeColor("SuccessColor"))
                        .font(.title2)
                    Text("アップロード完了!")
                        .font(.subheadline)
                        .foregroundColor(Color.safeColor("SuccessColor"))
                }
                .padding()
                .background(Color.safeColor("SuccessColor").opacity(0.1))
                .cornerRadius(10)
                
            case .error(let message):
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color.safeColor("ErrorColor"))
                        .font(.title2)
                    Text("エラー")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(message)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.safeColor("ErrorColor").opacity(0.1))
                .cornerRadius(10)
                
            case .idle, .selectingSource, .takingPhoto, .loadingImage, .cropping:
                EmptyView()
            }
        }
    }
    
    // MARK: - Helper Functions
    private func uploadImage(_ image: UIImage) async {
        selectedImage = image
        errorMessage = nil
        viewModel.uploadCroppedImage(image)
    }
}

// MARK: - UIImagePickerController Wrapper
struct ImagePickerController: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerController

        init(_ parent: ImagePickerController) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}