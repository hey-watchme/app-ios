# Mantisライブラリのセットアップ手順

## 概要
アバターアップロード機能のトリミングバグを修正するため、専用の画像トリミングライブラリ「Mantis」を導入しました。

## Xcodeでの追加手順

1. **Xcodeでプロジェクトを開く**
   ```bash
   open ios_watchme_v9.xcodeproj
   ```

2. **パッケージの追加**
   - メニューバーから `File` > `Add Package Dependencies...` を選択
   - 検索バーに以下のURLを入力:
     ```
     https://github.com/guoyingtao/Mantis.git
     ```
   - `Add Package` をクリック

3. **バージョン設定**
   - Dependency Rule: `Up to Next Major Version` を選択
   - バージョン: `2.0.0` 以上を選択

4. **ターゲット設定**
   - Product: `Mantis` を選択
   - Target: `ios_watchme_v9` にチェック
   - `Add Package` をクリック

## 実装の変更点

### 追加したファイル
- `MantisCropper.swift` - MantisをSwiftUIで使用するためのラッパー

### 修正したファイル
- `AvatarPickerView.swift` - 自作のImageCropperViewを削除し、Mantisを使用するように変更

### 主な改善点
1. **正確なトリミング**: 選択した領域が正確にトリミングされるようになりました
2. **円形トリミング**: アバター用に最適化された円形トリミングを実装
3. **安定性**: 実績のあるライブラリによる安定したトリミング機能
4. **EXIF対応**: 画像の向きが自動的に補正されます
5. **UX改善**: プロフェッショナルなトリミングUIを提供

## ビルドとテスト

1. **クリーンビルド**
   ```
   Product > Clean Build Folder (Shift+Cmd+K)
   Product > Build (Cmd+B)
   ```

2. **動作確認**
   - アプリを実行
   - マイページからアバター編集をテスト
   - カメラロールから画像を選択
   - トリミング画面で正しい領域が選択できることを確認

## トラブルシューティング

### パッケージが見つからない場合
```bash
# Xcodeを完全に終了してから
File > Packages > Reset Package Caches
File > Packages > Resolve Package Versions
```

### ビルドエラーの場合
```bash
# DerivedDataを削除
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

## 注意事項
- Mantisのバージョンは2.0.0以上を使用してください
- iOS 13.0以上が必要です
- SwiftUI 2.0以上が必要です