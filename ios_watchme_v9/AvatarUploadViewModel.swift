//
//  AvatarUploadViewModel.swift
//  ios_watchme_v9
//
//  アバターアップロード機能の状態管理を一元化するViewModel
//

import SwiftUI
import PhotosUI

@MainActor
class AvatarUploadViewModel: ObservableObject {
    
    // MARK: - Phase Definition
    enum Phase: Equatable {
        case idle                      // 初期状態
        case selectingSource           // 写真源選択中（カメラ/ライブラリ）
        case takingPhoto              // カメラ撮影中
        case loadingImage             // 画像読み込み中
        case cropping(UIImage)        // トリミング中
        case uploading                // アップロード中
        case success(URL)             // 成功
        case error(String)            // エラー
    }
    
    // MARK: - Image Source
    enum ImageSource {
        case camera
        case photoLibrary
    }
    
    // MARK: - Published Properties
    @Published var phase: Phase = .idle
    @Published var showSheet = false
    @Published var showPhotoPicker = false  // フォトピッカー表示用
    @Published var selectedPhotoItem: PhotosPickerItem? = nil
    @Published var progressMessage = ""
    
    // MARK: - Properties
    let avatarType: AvatarType
    var entityId: String?
    var authToken: String?
    var dataManager: SupabaseDataManager?
    var onSuccess: ((URL) -> Void)?
    var onCancel: (() -> Void)?
    
    // MARK: - Initialization
    init(
        avatarType: AvatarType,
        entityId: String?,
        authToken: String? = nil
    ) {
        self.avatarType = avatarType
        self.entityId = entityId
        self.authToken = authToken
    }
    
    // MARK: - Public Methods
    
    /// アバター選択を開始
    func startAvatarSelection() {
        print("🎯 Starting avatar selection")
        phase = .selectingSource
        showSheet = true
    }
    
    /// 画像ソースを選択
    func selectImageSource(_ source: ImageSource) {
        print("📸 Selected image source: \(source)")
        
        switch source {
        case .camera:
            phase = .takingPhoto
            // カメラViewが表示される
            
        case .photoLibrary:
            // フォトピッカーを選択したことを記録し、シートを閉じる
            phase = .idle
            showSheet = false
            // フラグを立てる（親Viewが検知して処理）
            showPhotoPicker = true
        }
    }
    
    /// カメラで撮影した画像を処理
    func processCameraImage(_ image: UIImage) {
        print("📷 Processing camera image: \(image.size)")
        phase = .cropping(image)
    }
    
    /// フォトライブラリから選択した画像を処理
    func processPhotoPickerSelection() {
        guard let item = selectedPhotoItem else { return }
        
        print("🖼️ Processing photo picker selection")
        phase = .loadingImage
        progressMessage = "画像を読み込んでいます..."
        
        Task {
            do {
                // 画像データを読み込む
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    print("✅ Image loaded: \(uiImage.size)")
                    phase = .cropping(uiImage)
                } else {
                    throw NSError(domain: "AvatarUpload", code: -1, 
                                userInfo: [NSLocalizedDescriptionKey: "画像の読み込みに失敗しました"])
                }
            } catch {
                print("❌ Failed to load image: \(error)")
                phase = .error(error.localizedDescription)
            }
        }
    }
    
    /// トリミングされた画像をアップロード
    func uploadCroppedImage(_ image: UIImage) {
        guard let entityId = entityId else {
            print("❌ [AvatarUploadViewModel] entityId is nil")
            phase = .error("IDが指定されていません")
            return
        }

        guard let dataManager = dataManager else {
            print("❌ [AvatarUploadViewModel] dataManager is nil - cannot save to database")
            phase = .error("データマネージャーが設定されていません")
            return
        }

        print("🚀 [AvatarUploadViewModel] Starting upload for \(avatarType.s3Type)/\(entityId)")
        print("   - authToken: \(authToken != nil ? "SET" : "NIL")")
        print("   - dataManager: SET")
        phase = .uploading
        progressMessage = "アバターをアップロードしています..."

        Task {
            do {
                let url: URL

                // Use AvatarService for complete upload flow (S3 + DB + cache)
                switch avatarType {
                case .user:
                    url = try await AvatarService.shared.uploadUserAvatar(
                        image: image,
                        userId: entityId,
                        authToken: authToken,
                        dataManager: dataManager
                    )
                case .subject:
                    url = try await AvatarService.shared.uploadSubjectAvatar(
                        image: image,
                        subjectId: entityId,
                        authToken: authToken,
                        dataManager: dataManager
                    )
                }

                print("✅ Upload successful: \(url)")
                phase = .success(url)
                progressMessage = "アップロードが完了しました"

                // 成功コールバック
                onSuccess?(url)

                // 2秒後にシートを閉じる
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                reset()

            } catch {
                print("❌ Upload failed: \(error)")
                phase = .error(error.localizedDescription)
                progressMessage = ""
            }
        }
    }
    
    /// キャンセル処理
    func cancel() {
        print("🚫 Cancelling avatar upload")
        onCancel?()
        reset()
    }
    
    /// リセット
    func reset() {
        phase = .idle
        showSheet = false
        showPhotoPicker = false
        selectedPhotoItem = nil
        progressMessage = ""
    }
    
    // MARK: - Computed Properties
    
    /// 現在の画面タイトル
    var currentTitle: String {
        switch phase {
        case .idle:
            return "アバターを選択"
        case .selectingSource:
            return "写真を選択"
        case .takingPhoto:
            return "写真を撮影"
        case .loadingImage:
            return "読み込み中"
        case .cropping:
            return "画像をトリミング"
        case .uploading:
            return "アップロード中"
        case .success:
            return "完了"
        case .error:
            return "エラー"
        }
    }
    
    /// エラーメッセージ
    var errorMessage: String? {
        if case .error(let message) = phase {
            return message
        }
        return nil
    }
    
    /// 処理中かどうか
    var isProcessing: Bool {
        switch phase {
        case .loadingImage, .uploading:
            return true
        default:
            return false
        }
    }
}