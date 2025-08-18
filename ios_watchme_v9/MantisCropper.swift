//
//  MantisCropper.swift
//  ios_watchme_v9
//
//  Mantisライブラリを使用した画像トリミング機能のSwiftUIラッパー
//

import SwiftUI
import Mantis

// UIImageをIdentifiableにするためのラッパー
struct ImageWrapper: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct MantisCropper: UIViewControllerRepresentable {
    let image: UIImage
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        // Mantisの設定
        var config = Mantis.Config()
        
        // 円形トリミング設定（新しいAPI）
        config.cropViewConfig.cropShapeType = .circle()
        
        // その他の推奨設定
        config.presetFixedRatioType = .alwaysUsingOnePresetFixedRatio(ratio: 1.0) // 正方形固定
        config.cropViewConfig.showAttachedRotationControlView = false // 回転コントロールを非表示
        config.ratioOptions = [.custom] // カスタム比率のみ
        config.addCustomRatio(byHorizontalWidth: 1, andHorizontalHeight: 1) // 1:1比率
        
        // 日本語ローカライゼーション
        config.localizationConfig.bundle = Bundle.main
        config.localizationConfig.tableName = "MantisLocalizable"
        
        // CropViewControllerを作成
        let cropViewController = Mantis.cropViewController(image: image, config: config)
        cropViewController.delegate = context.coordinator
        
        // モーダル表示のスタイル設定
        cropViewController.modalPresentationStyle = .fullScreen
        
        return cropViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // 更新処理は不要
    }
    
    class Coordinator: NSObject, CropViewControllerDelegate {
        let parent: MantisCropper
        
        init(_ parent: MantisCropper) {
            self.parent = parent
        }
        
        // トリミングが完了したときに呼ばれる
        func cropViewControllerDidCrop(_ cropViewController: CropViewController, 
                                      cropped: UIImage, 
                                      transformation: Transformation,
                                      cropInfo: CropInfo) {
            // トリミングされた画像を返す
            parent.onComplete(cropped)
        }
        
        // キャンセルされたときに呼ばれる
        func cropViewControllerDidCancel(_ cropViewController: CropViewController, 
                                        original: UIImage) {
            parent.onCancel()
        }
        
        // 画像の回転が終了したときに呼ばれる（オプション）
        func cropViewControllerDidImageTransformed(_ cropViewController: CropViewController) {
            // 必要に応じて処理を追加
        }
        
        // 失敗したときに呼ばれる（オプション）
        func cropViewControllerDidFailToCrop(_ cropViewController: CropViewController, 
                                           original: UIImage) {
            // エラー処理が必要な場合はここに追加
            parent.onCancel()
        }
    }
}

// MARK: - SwiftUI View Extension for easier usage
extension View {
    func mantisImageCropper(image: ImageWrapper?,
                           onComplete: @escaping (UIImage) -> Void,
                           onCancel: @escaping () -> Void) -> some View {
        self.fullScreenCover(item: .constant(image)) { wrapper in
            MantisCropper(image: wrapper.image,
                         onComplete: onComplete,
                         onCancel: onCancel)
                .ignoresSafeArea()
        }
    }
}