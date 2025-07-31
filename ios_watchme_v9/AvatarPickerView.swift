//
//  AvatarPickerView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/31.
//

import SwiftUI
import PhotosUI

// MARK: - Avatar Picker View
/// 共通のアバター選択・編集コンポーネント
struct AvatarPickerView: View {
    // MARK: - Properties
    let currentAvatarURL: URL?
    let onImageSelected: (UIImage) -> Void
    let onDelete: (() -> Void)?
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showingImageCropper = false
    @State private var showingActionSheet = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var isProcessing = false
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 20) {
            // 現在のアバター表示
            avatarDisplay
                .onTapGesture {
                    showingActionSheet = true
                }
            
            // 選択ボタン
            Button(action: {
                showingActionSheet = true
            }) {
                Label("アバターを変更", systemImage: "camera.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(20)
            }
        }
        .confirmationDialog("アバターの選択", isPresented: $showingActionSheet, titleVisibility: .visible) {
            // 写真ライブラリから選択
            Button("写真を選択") {
                showingPhotoPicker = true
            }
            
            // カメラが利用可能な場合のみ表示
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("カメラで撮影") {
                    showingCamera = true
                }
            }
            
            if currentAvatarURL != nil && onDelete != nil {
                Button("アバターを削除", role: .destructive) {
                    onDelete?()
                }
            }
            
            Button("キャンセル", role: .cancel) {}
        }
        message: {
            Text("プロフィール写真を選択してください")
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                await loadImage(from: newValue)
            }
        }
        .sheet(isPresented: $showingImageCropper) {
            if let image = selectedImage {
                ImageCropperView(image: image) { croppedImage in
                    onImageSelected(croppedImage)
                    showingImageCropper = false
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView { image in
                DispatchQueue.main.async {
                    self.selectedImage = image
                    self.showingCamera = false
                    // 少し遅延させてからトリミング画面を表示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.showingImageCropper = true
                    }
                }
            }
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedItem,
            matching: .images,
            photoLibrary: .shared()
        )
    }
    
    // MARK: - Avatar Display
    private var avatarDisplay: some View {
        ZStack {
            if let url = currentAvatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                    case .failure(_), .empty:
                        defaultAvatar
                    @unknown default:
                        defaultAvatar
                    }
                }
            } else {
                defaultAvatar
            }
            
            // カメラアイコンオーバーレイ
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "camera.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }
            .frame(width: 150, height: 150)
        }
    }
    
    private var defaultAvatar: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 150))
            .foregroundColor(.gray.opacity(0.5))
    }
    
    // MARK: - Helper Methods
    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        await MainActor.run {
            isProcessing = true
        }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.selectedImage = uiImage
                    self.isProcessing = false
                    self.showingPhotoPicker = false
                    // 少し遅延させてからトリミング画面を表示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.showingImageCropper = true
                    }
                }
            } else {
                await MainActor.run {
                    isProcessing = false
                    print("⚠️ 画像データを取得できませんでした")
                }
            }
        } catch {
            await MainActor.run {
                print("❌ 画像の読み込みに失敗: \(error)")
                isProcessing = false
            }
        }
    }
}

// MARK: - Image Cropper View
/// 画像を正方形にトリミングするビュー
struct ImageCropperView: View {
    let image: UIImage
    let onComplete: (UIImage) -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    VStack {
                        Spacer()
                        
                        // トリミングエリア
                        ZStack {
                            // 画像
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(
                                    SimultaneousGesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                scale = lastScale * value
                                            }
                                            .onEnded { value in
                                                lastScale = scale
                                            },
                                        DragGesture()
                                            .onChanged { value in
                                                offset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                            }
                                            .onEnded { value in
                                                lastOffset = offset
                                            }
                                    )
                                )
                            
                            // トリミング枠
                            Rectangle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: min(geometry.size.width - 40, 300),
                                       height: min(geometry.size.width - 40, 300))
                                .overlay(
                                    // グリッド線
                                    GeometryReader { geo in
                                        Path { path in
                                            let width = geo.size.width
                                            let height = geo.size.height
                                            
                                            // 縦線
                                            path.move(to: CGPoint(x: width / 3, y: 0))
                                            path.addLine(to: CGPoint(x: width / 3, y: height))
                                            path.move(to: CGPoint(x: width * 2 / 3, y: 0))
                                            path.addLine(to: CGPoint(x: width * 2 / 3, y: height))
                                            
                                            // 横線
                                            path.move(to: CGPoint(x: 0, y: height / 3))
                                            path.addLine(to: CGPoint(x: width, y: height / 3))
                                            path.move(to: CGPoint(x: 0, y: height * 2 / 3))
                                            path.addLine(to: CGPoint(x: width, y: height * 2 / 3))
                                        }
                                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                                    }
                                )
                        }
                        .frame(width: min(geometry.size.width - 40, 300),
                               height: min(geometry.size.width - 40, 300))
                        .clipped()
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("画像をトリミング")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        if let croppedImage = cropImage() {
                            onComplete(croppedImage)
                        }
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func cropImage() -> UIImage? {
        let targetSize: CGFloat = 300
        let scale = UIScreen.main.scale
        
        // 画像の実際のサイズを取得
        let imageSize = image.size
        
        // スケールを考慮した最小倍率を計算（画像が300x300の枠を完全に覆うように）
        let minScale = max(targetSize / imageSize.width, targetSize / imageSize.height)
        let finalScale = max(self.scale, minScale)
        
        // スケール後の画像サイズ
        let scaledWidth = imageSize.width * finalScale
        let scaledHeight = imageSize.height * finalScale
        
        // オフセットを考慮したトリミング領域の計算
        let cropX = (scaledWidth - targetSize) / 2 - offset.width
        let cropY = (scaledHeight - targetSize) / 2 - offset.height
        
        // トリミング領域が画像の範囲内に収まるように調整
        let finalCropX = max(0, min(cropX, scaledWidth - targetSize))
        let finalCropY = max(0, min(cropY, scaledHeight - targetSize))
        
        // UIGraphicsで高品質な画像処理
        UIGraphicsBeginImageContextWithOptions(CGSize(width: targetSize, height: targetSize), true, scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // 背景を白で塗りつぶす
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: targetSize, height: targetSize))
        
        // 画像を描画
        let drawRect = CGRect(
            x: -finalCropX,
            y: -finalCropY,
            width: scaledWidth,
            height: scaledHeight
        )
        image.draw(in: drawRect)
        
        // トリミングされた画像を取得
        let croppedImage = UIGraphicsGetImageFromCurrentImageContext()
        
        return croppedImage
    }
}

// MARK: - Camera View
/// カメラ撮影用のビュー
struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        
        // カメラが利用可能かチェック
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            print("❌ Camera is not available on this device")
            picker.sourceType = .photoLibrary
            picker.allowsEditing = false
            picker.delegate = context.coordinator
            return picker
        }
        
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        
        // カメラ設定
        picker.cameraCaptureMode = .photo
        
        // 利用可能なカメラデバイスをチェック
        if UIImagePickerController.isCameraDeviceAvailable(.rear) {
            picker.cameraDevice = .rear
        } else if UIImagePickerController.isCameraDeviceAvailable(.front) {
            picker.cameraDevice = .front
        }
        
        // フラッシュモードの設定
        if UIImagePickerController.isFlashAvailable(for: picker.cameraDevice) {
            picker.cameraFlashMode = .off
        }
        
        // iPadでのポップオーバー対応
        picker.modalPresentationStyle = .fullScreen
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController,
                                 didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // メインスレッドで処理
            DispatchQueue.main.async {
                if let image = info[.originalImage] as? UIImage {
                    self.parent.onImageCaptured(image)
                }
                self.parent.dismiss()
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            DispatchQueue.main.async {
                self.parent.dismiss()
            }
        }
    }
}