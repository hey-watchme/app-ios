# Release Documents

WatchMe iOSアプリのリリース・テスト関連ドキュメント

最終更新: 2025-12-06

---

## 📁 ドキュメント一覧

| ドキュメント | 用途 | 対象者 |
|------------|------|--------|
| [TESTFLIGHT_REVIEW.md](./TESTFLIGHT_REVIEW.md) | TestFlight外部テスト審査前のレビュー結果 | 開発チーム |
| [TESTFLIGHT_WHAT_TO_TEST.md](./TESTFLIGHT_WHAT_TO_TEST.md) | TestFlight外部テスター向けテストガイド | 外部テスター |
| [RELEASE_CHECKLIST.md](./RELEASE_CHECKLIST.md) | リリース前チェックリスト | 開発チーム |

---

## 🚀 リリースプロセス

### 1. TestFlight内部テスト（開発チーム）

1. Xcodeでビルド番号をインクリメント
2. Archive作成
3. App Store Connectにアップロード
4. 内部テスターに配布
5. クリティカルなバグがないか確認

### 2. TestFlight外部テスト（Apple審査）

1. [TESTFLIGHT_REVIEW.md](./TESTFLIGHT_REVIEW.md)のチェックリストを確認
2. [TESTFLIGHT_WHAT_TO_TEST.md](./TESTFLIGHT_WHAT_TO_TEST.md)の内容をTestFlight審査ノートに貼り付け
3. 外部テスター配布申請
4. Apple審査（通常24〜48時間）
5. 承認後、外部テスターに配布

### 3. App Storeリリース（正式版）

1. 外部テストで問題がないことを確認
2. [RELEASE_CHECKLIST.md](./RELEASE_CHECKLIST.md)を完了
3. App Store Connect で審査申請
4. Apple審査（通常24〜48時間）
5. 承認後、リリース

---

## 📝 バージョン管理

### バージョン番号の付け方

- **メジャーバージョン**: `1.0`, `2.0`, `3.0`...
  - 大規模な機能追加・UI刷新
- **マイナーバージョン**: `1.1`, `1.2`, `1.3`...
  - 中規模な機能追加
- **パッチバージョン**: `1.0.1`, `1.0.2`...
  - バグ修正のみ

### ビルド番号

- TestFlight/App Store提出ごとに自動インクリメント
- 例: `1.0 (1)`, `1.0 (2)`, `1.0 (3)`...

---

## 🔗 関連ドキュメント

### プロジェクト全体

- [README.md](../../README.md) - プロジェクト全体の概要
- [CHANGELOG.md](../../CHANGELOG.md) - 変更履歴

### 運用関連

- [APP_STORE_METADATA.md](../operations/APP_STORE_METADATA.md) - App Store申請情報
- [TROUBLESHOOTING.md](../operations/TROUBLESHOOTING.md) - トラブルシューティング

### 技術仕様

- [TECHNICAL.md](../technical/TECHNICAL.md) - 技術仕様
- [AUTHENTICATION.md](../features/AUTHENTICATION.md) - 認証システム
- [RECORDING_SPECIFICATION.md](../features/RECORDING_SPECIFICATION.md) - 録音仕様

---

## 📊 リリース履歴

| バージョン | リリース日 | 種別 | 主な変更 |
|----------|----------|------|---------|
| 1.0 (1) | 2025-12-06 (予定) | TestFlight外部テスト | 初回リリース |

---

## ⚠️ 重要事項

### Apple審査で気をつける点

1. **プライバシーポリシー必須**
   - URL: `https://hey-watch.me/privacy`
   - Info.plistに記載済み

2. **マイク・カメラ権限の説明**
   - 必ず具体的な使用目的を記載
   - Info.plistに記載済み

3. **バックグラウンド録音の扱い**
   - 現在は非対応（フォアグラウンドのみ）
   - 追加する場合は追加審査が必要

4. **サンプルデータの明示**
   - デモデータであることをUI上で明示

---

## 📞 問い合わせ

リリース・テストに関する質問は開発チームまで。

**WatchMe開発チーム**
