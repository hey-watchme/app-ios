# TestFlight外部テスト審査前レビュー

最終更新: 2025-12-06

---

## 📋 レビューサマリー

| チェック項目 | 状態 | 詳細 |
|------------|------|------|
| **起動時クラッシュリスク** | ✅ 問題なし | 非同期初期化、適切なエラーハンドリング実装済み |
| **認証フロー** | ✅ 問題なし | 匿名認証・Google OAuth・メール認証の3方式をサポート |
| **主要機能フロー** | ✅ 問題なし | 録音 → アップロード → 分析 → 表示のフロー実装済み |
| **権限リクエスト** | ✅ 問題なし | マイク・カメラ・フォトライブラリの説明文あり |
| **UI** | ✅ 問題なし | ビルド成功、主要画面実装済み |

---

## 🎯 Apple審査基準での評価

| Apple審査基準 | 状態 | コメント |
|-------------|------|----------|
| **2.1 App Completeness** | ✅ 合格 | 主要機能が完全に実装済み |
| **2.3 Accurate Metadata** | ✅ 合格 | Info.plistに必要な権限説明あり |
| **4.0 Design** | ✅ 合格 | ビルド成功、UI実装済み |
| **5.1.1 Data Collection** | ✅ 合格 | マイク・カメラの使用目的を明記 |

---

## ✅ 実装確認済み項目

### 1. 起動フロー

**実装ファイル**: `ios_watchme_v9App.swift`

- ✅ 非同期Supabaseクライアント初期化（UIブロック回避）
- ✅ 適切な初期化順序（DeviceManager → UserAccountManager → SupabaseDataManager → RecordingStore）
- ✅ 認証状態確認中のローディング画面
- ✅ 認証済み/未認証での画面切り替え

**クラッシュリスク**: なし

---

### 2. 権限リクエスト

**実装ファイル**: `Info.plist`

```xml
<key>NSMicrophoneUsageDescription</key>
<string>このアプリは音声を録音してサーバーにアップロードするためにマイクへのアクセスが必要です。</string>

<key>NSCameraUsageDescription</key>
<string>QRコードをスキャンしてデバイスを追加するため、およびアバター写真を撮影するためにカメラを使用します</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>アバター画像を選択するためにフォトライブラリへのアクセスが必要です</string>
```

- ✅ マイク権限説明あり
- ✅ カメラ権限説明あり
- ✅ フォトライブラリ権限説明あり

**Apple審査での懸念事項**: なし

---

### 3. 認証フロー

**実装ファイル**: `UserAccountManager.swift`

**サポートする認証方式**:
- ✅ 匿名認証（`signInAnonymously()`）
- ✅ Google OAuth（`signInWithGoogle()`）
- ✅ メール/パスワード（`signIn(email:password:)`、`signUp(email:password:displayName:newsletter:)`）

**エラーハンドリング**:
- ✅ 認証エラーをToastで表示
- ✅ 適切なエラーメッセージ

**懸念事項**: なし

---

### 4. 録音機能（コア機能）

**実装ファイル**:
- `RecordingStore.swift` - 状態管理
- `AudioRecorderService.swift` - 録音実行
- `AudioMonitorService.swift` - 音声レベル監視
- `UploaderService.swift` - アップロード

**フロー**:
1. ✅ マイク権限リクエスト
2. ✅ 録音開始（AVAudioRecorder）
3. ✅ 音声レベル可視化
4. ✅ 録音停止
5. ✅ S3アップロード
6. ✅ アップロード完了バナー表示

**懸念事項**: なし

---

### 5. AI分析結果表示

**実装ファイル**:
- `SimpleDashboardView.swift` - ダッシュボード表示
- `SupabaseDataManager.swift` - データ取得

**フロー**:
1. ✅ 録音アップロード完了
2. ✅ Lambda（AWS）でAI分析実行
3. ✅ 分析結果をSupabaseに保存
4. ✅ プッシュ通知でアプリに通知
5. ✅ アプリで自動更新・表示

**懸念事項**: なし

---

## ⚠️ 既知の制限事項（審査対応済み）

### 1. フォアグラウンド録音のみ

- **制限**: バックグラウンド録音には対応していない
- **理由**: Apple審査ガイドライン遵守（バックグラウンド録音は追加審査が必要）
- **対応**: 仕様として明記

### 2. AI分析に時間がかかる

- **現象**: 録音後、分析結果が表示されるまで2〜3分かかる
- **理由**: Lambda（AWS）でのAI分析処理
- **対応**: ユーザーガイドに明記

### 3. サンプルデバイス

- **現象**: 初回登録時に「5歳男児」のデモデータが追加される
- **理由**: 初回体験向上のため
- **対応**: サンプルデータであることをUI上で明示

---

## 🚀 TestFlight提出チェックリスト

### App Store Connect情報

- [ ] **スクリーンショット**: 最低5枚（6.7", 6.5", 5.5"対応）
- [ ] **アプリ説明文**: 簡潔な説明（最大4000文字）
- [ ] **プライバシーポリシーURL**: `https://hey-watch.me/privacy`
- [ ] **サポートURL**: `https://hey-watch.me/`
- [ ] **カテゴリ**: メディカル / ヘルスケア&フィットネス

### ビルド情報

- [ ] **バージョン**: `1.0`
- [ ] **ビルド番号**: `1`
- [ ] **最小iOSバージョン**: `17.0`
- [ ] **対応デバイス**: iPhone（iPadは未対応）

### TestFlight審査ノート

- [ ] **What to Test**: [TESTFLIGHT_WHAT_TO_TEST.md](./TESTFLIGHT_WHAT_TO_TEST.md)の内容を貼り付け
- [ ] **テストアカウント**: 必要なし（匿名認証サポート）
- [ ] **審査用デモ動画**: 任意（推奨）

### テスター情報

- [ ] **内部テスター**: App Store Connect Users
- [ ] **外部テスター**: Apple IDリスト準備

---

## 📝 次回リリース時の注意事項

### ビルド番号の更新

```bash
# Xcodeでビルド番号を自動インクリメント
# Project Settings > Build Settings > Versioning
CURRENT_PROJECT_VERSION = 2  # 次回は 2, 3, 4...
```

### 変更履歴の記録

`CHANGELOG.md`に変更内容を記載:
- 新機能
- バグ修正
- 既知の問題

---

## 🔗 関連ドキュメント

- [TestFlight What to Test](./TESTFLIGHT_WHAT_TO_TEST.md) - 外部テスター向けテストガイド
- [App Store Metadata](../operations/APP_STORE_METADATA.md) - App Store申請情報
- [Troubleshooting](../operations/TROUBLESHOOTING.md) - トラブルシューティング

---

## 📊 レビュー履歴

| 日付 | バージョン | レビュアー | 結果 |
|------|-----------|----------|------|
| 2025-12-06 | 1.0 (1) | Claude | ✅ 合格 |
