# リリース前チェックリスト

最終更新: 2025-12-06

---

## 📋 チェックリスト

リリース前に以下の項目をすべて確認してください。

---

## 🔧 ビルド設定

### Xcode設定

- [ ] **Bundle Identifier**: `com.watchme.watchme`
- [ ] **Team**: WatchMe開発チーム
- [ ] **Signing**: Automatic（Distribution証明書）
- [ ] **Deployment Target**: iOS 17.0以上
- [ ] **Supported Devices**: iPhone only（iPadは未対応）

### バージョン情報

- [ ] **Version**: `1.0`（メジャー.マイナー.パッチ）
- [ ] **Build**: 前回より大きい番号（例: `1`, `2`, `3`...）
- [ ] **Display Name**: `WatchMe`

### Info.plist確認

- [ ] **NSMicrophoneUsageDescription**: ✅ 記載済み
- [ ] **NSCameraUsageDescription**: ✅ 記載済み
- [ ] **NSPhotoLibraryUsageDescription**: ✅ 記載済み
- [ ] **CFBundleURLTypes**: ✅ OAuth用URL Scheme設定済み
- [ ] **UIBackgroundModes**: ✅ `remote-notification`のみ

---

## 🧪 機能テスト

### 認証機能

- [ ] 匿名認証が動作する
- [ ] Google OAuth認証が動作する
- [ ] メール/パスワード認証が動作する（準備中の場合はスキップ）
- [ ] ログアウトが正常に動作する
- [ ] 再ログインが正常に動作する

### 録音機能

- [ ] マイク権限リクエストが表示される
- [ ] 録音開始が正常に動作する
- [ ] 録音中に音声レベルが表示される
- [ ] 録音停止が正常に動作する
- [ ] S3へのアップロードが成功する
- [ ] アップロード完了バナーが表示される

### データ表示

- [ ] ホーム画面でダッシュボードが表示される
- [ ] 最新の分析結果が表示される（AI分析完了後）
- [ ] レポート画面で週次グラフが表示される
- [ ] 観測対象画面でプロフィールが表示される
- [ ] QRコード表示機能が動作する（新機能）

### プッシュ通知

- [ ] APNsデバイストークンが取得される
- [ ] フォアグラウンド通知が受信できる
- [ ] 通知受信時にデータが自動更新される

---

## 🎨 UI/UX確認

### デザイン

- [ ] ロゴが正しく表示される
- [ ] カラーが統一されている
- [ ] フォントサイズが適切
- [ ] ボタンのタップ領域が十分

### レイアウト

- [ ] iPhone SE（小画面）で崩れていない
- [ ] iPhone 15 Pro Max（大画面）で崩れていない
- [ ] セーフエリアが適切に設定されている
- [ ] キーボード表示時にUIが隠れない

### エラーハンドリング

- [ ] エラーメッセージが日本語で表示される
- [ ] ネットワークエラー時に適切なメッセージが表示される
- [ ] エラー時にアプリがクラッシュしない

---

## 📱 App Store Connect

### アプリ情報

- [ ] **アプリ名**: WatchMe
- [ ] **サブタイトル**: 音声分析で心理状態を可視化（30文字以内）
- [ ] **カテゴリ**: メディカル / ヘルスケア&フィットネス
- [ ] **年齢制限**: 4+（全年齢対象）

### 説明文

- [ ] **アプリ説明**: 簡潔で魅力的な説明（4000文字以内）
- [ ] **新機能**: バージョンごとの変更点
- [ ] **キーワード**: 関連キーワード（100文字以内）

### スクリーンショット

- [ ] **6.7"（iPhone 15 Pro Max）**: 最低3枚
- [ ] **6.5"（iPhone 14 Plus）**: 最低3枚（または6.7"を流用）
- [ ] **5.5"（iPhone 8 Plus）**: 最低3枚（または6.7"を流用）

推奨スクリーンショット:
1. ホーム画面（ダッシュボード）
2. 録音画面
3. レポート画面（グラフ）
4. 観測対象画面
5. QRコード表示画面

### URLリンク

- [ ] **プライバシーポリシー**: https://hey-watch.me/privacy
- [ ] **サポートURL**: https://hey-watch.me/
- [ ] **利用規約**: https://hey-watch.me/terms（任意）

---

## 🔐 セキュリティ・プライバシー

### データ収集

- [ ] **収集データ**: 音声、ユーザーID、デバイスID
- [ ] **利用目的**: AI分析、サービス提供
- [ ] **第三者共有**: なし（明示）

### 暗号化

- [ ] **App Transport Security (ATS)**: HTTPS通信のみ
- [ ] **ITSAppUsesNonExemptEncryption**: `false`（暗号化なし）

---

## 📝 ドキュメント

### TestFlight（外部テスト）

- [ ] [TESTFLIGHT_REVIEW.md](./TESTFLIGHT_REVIEW.md)を確認
- [ ] [TESTFLIGHT_WHAT_TO_TEST.md](./TESTFLIGHT_WHAT_TO_TEST.md)を審査ノートに貼り付け
- [ ] テスターのApple IDリストを準備

### リリースノート

- [ ] [CHANGELOG.md](../../CHANGELOG.md)を更新
- [ ] 新機能・バグ修正を記載
- [ ] 既知の問題を記載（あれば）

---

## 🚀 提出前の最終確認

### ビルド

- [ ] **Release Configuration**でArchive作成
- [ ] **Debug Symbolsアップロード**（クラッシュレポート用）
- [ ] **BitCode**: 無効（Xcode 14以降不要）

### テスト

- [ ] 実機でクラッシュしないか最終確認
- [ ] ネットワークエラー時の動作確認
- [ ] ログイン → 録音 → 分析 → ログアウトの一連の流れ確認

### 審査ノート

- [ ] TestFlight審査ノートを記載
- [ ] テストアカウント情報（不要であれば明記）
- [ ] デモ動画URL（任意）

---

## ✅ 提出

すべてのチェック項目が完了したら、以下の手順で提出:

1. XcodeからArchive作成
2. App Store Connectにアップロード
3. TestFlight外部テスト申請 または App Store審査申請
4. 審査ノートを記載
5. 提出ボタンをクリック

---

## 📊 提出後の対応

### 審査中

- [ ] 審査ステータスを定期的に確認
- [ ] App Store Connectからの通知を確認
- [ ] 追加情報リクエストに迅速に対応

### 承認後

- [ ] リリースノートを更新
- [ ] ユーザーへの告知（SNS、メールなど）
- [ ] 初日のクラッシュレポートを確認

### リジェクト時

- [ ] リジェクト理由を確認
- [ ] 修正方法を検討
- [ ] 修正後、再提出

---

## 🔗 関連ドキュメント

- [TESTFLIGHT_REVIEW.md](./TESTFLIGHT_REVIEW.md) - TestFlight審査前レビュー
- [TESTFLIGHT_WHAT_TO_TEST.md](./TESTFLIGHT_WHAT_TO_TEST.md) - テスターガイド
- [APP_STORE_METADATA.md](../operations/APP_STORE_METADATA.md) - App Store申請情報
