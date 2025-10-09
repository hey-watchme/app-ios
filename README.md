# WatchMe App (iOS)

WatchMeプラットフォームのiOSアプリケーション。
音声録音とAI分析による心理・感情・行動の総合的なモニタリングを提供します。

---

## 概要

このアプリは、観測対象（デバイスを装着している人）の音声を30分間隔で自動録音し、クラウド上でAI分析を行うことで、心理状態・感情・行動パターンをライフログとして可視化するツールです。

### 主要機能

- **自動録音**: 30分間隔でバックグラウンド録音
- **AI分析**: 音声認識、感情分析、行動パターン検出
- **ダッシュボード**: 日別の心理グラフ、行動グラフ、感情グラフ
- **マルチデバイス対応**: 1ユーザーが複数のデバイス（観測対象）を管理可能
- **コメント機能**: 観測対象に対する日別コメント投稿
- **通知機能**: グローバル通知、パーソナル通知、イベント通知

---

## セットアップ

### 1. 必要な環境

- Xcode 15.0以上
- iOS 17.0以上
- Swift 5.9以上

### 2. プロジェクトを開く

```bash
cd /Users/kaya.matsumoto/ios_watchme_v9
open ios_watchme_v9.xcodeproj
```

### 3. パッケージ依存関係の解決

Xcodeが自動的にSwift Package Managerの依存関係を解決します。

- Supabase Swift SDK
- Mantis（画像トリミング）

### 4. ビルドと実行

- ターゲットデバイス/シミュレーターを選択
- `Cmd + R` でビルド・実行

---

## 開発時の重要ルール

### データベース設計の絶対ルール

- **`auth.users`テーブルへの直接参照は禁止**
- **すべてのユーザー参照は`public.users(user_id)`を使用**
- 新規テーブル作成時の外部キー：`REFERENCES public.users(user_id) ON DELETE CASCADE`

```swift
// ❌ 間違い
let userId = userAccountManager.currentUser?.id

// ✅ 正しい
let userId = userAccountManager.currentUser?.profile?.userId
```

### iOS開発時のビルド検証ルール

- **コンパイルチェックのみ**：シミュレーター指定は不要
- **実際の動作確認はユーザー側で実施**

```bash
# ✅ 正しい：シンプルにコンパイルチェックのみ
xcodebuild -scheme ios_watchme_v9 -sdk iphonesimulator build
```

### コミット前の確認事項

- 必ず動作確認を実施
- エラーがない状態でコミット
- `.gitignore`の確認（秘密情報を含むファイルは除外）

---

## プロジェクト構造

```
ios_watchme_v9/
├── README.md                       # このファイル
├── CHANGELOG.md                    # 更新履歴
├── docs/
│   ├── TECHNICAL.md               # アーキテクチャ・データベース・API仕様
│   └── TROUBLESHOOTING.md         # トラブルシューティング
├── ios_watchme_v9App.swift        # アプリエントリーポイント
├── ContentView.swift              # メインビュー
├── SimpleDashboardView.swift      # ダッシュボード
├── HomeView.swift                 # 心理グラフ
├── BehaviorGraphView.swift        # 行動グラフ
├── EmotionGraphView.swift         # 感情グラフ
├── RecordingView.swift            # 録音機能
├── LoginView.swift                # ログイン画面
├── SignUpView.swift               # 会員登録画面
├── UserInfoView.swift             # マイページ
├── AudioRecorder.swift            # 録音管理
├── NetworkManager.swift           # API通信
├── DeviceManager.swift            # デバイス管理
├── UserAccountManager.swift       # ユーザー認証管理
├── SupabaseAuthManager.swift      # Supabase認証
├── SupabaseDataManager.swift      # データ取得管理
└── Models/                        # データモデル
```

---

## 技術スタック

- **Swift 5.9+** / **SwiftUI**
- **AVFoundation** - 音声録音
- **Supabase** - 認証・データベース
- **Combine** - リアクティブプログラミング

---

## ユーザーモード（権限レベル）

このアプリは**Permission-Based Architecture（権限ベース設計）**を採用しており、ユーザーの権限レベルに応じて利用できる機能が段階的に変化します。

### 権限レベルの種類

#### 1. 閲覧専用モード（Read-Only Mode）
- **対象**: ゲストユーザー、ログアウトしたユーザー
- **できること**:
  - サンプルデバイスのデータ閲覧
  - ダッシュボード、グラフの表示
  - アプリの操作感を体験
- **できないこと**:
  - 録音機能の使用
  - デバイスの追加・編集
  - コメントの投稿
  - その他の能動的なアクション

#### 2. 全権限モード（Full Access Mode）
- **対象**: 認証済みユーザー（メール・パスワードでログイン/サインアップ）
- **できること**:
  - すべての機能の利用
  - 録音機能の使用
  - デバイスの追加・編集・削除
  - コメントの投稿
  - データのエクスポート
  - 通知の受信

#### 3. プレミアムモード（Premium Mode）*将来実装予定*
- **対象**: 課金済みプレミアムユーザー
- **できること**（予定）:
  - 全権限モードのすべての機能
  - より詳細な分析レポート
  - データ保存期間の延長
  - 高度なエクスポート機能
  - 優先サポート

### アップグレードの流れ

```
閲覧専用モード (ゲスト)
    ↓ 会員登録・ログイン
全権限モード (認証済み)
    ↓ 課金 (将来実装予定)
プレミアムモード (課金済み)
```

### 設計思想

従来の「ゲスト/認証ユーザー」という二分法ではなく、**段階的な権限レベル**として設計されています。

- ゲストユーザーは「不完全なユーザー」ではなく「閲覧専用モードで試用中のユーザー」
- 会員登録は「アカウント作成」ではなく「権限のアップグレード」
- 将来的な有料プランの追加が容易

---

## ユーザーとデバイスの関係

### 基本概念

1. **ユーザー**: アプリにログインするアカウント（メール・パスワード認証）
2. **デバイス**: 観測対象（録音される人）を表す論理的なID
3. **1ユーザー = 複数デバイス**: 1人のユーザーが複数の観測対象を管理可能

### デバイス選択方式

- デバイスIDは物理的なiPhoneに紐付かない
- ユーザーがアプリ内でデバイスを選択
- どのiPhoneからでも、同じデバイスIDを選択すれば同じデータにアクセス可能
- QRコードスキャンで新しいデバイスを追加可能（全権限モードのみ）

---

## 関連ドキュメント

- [TECHNICAL.md](./docs/TECHNICAL.md) - アーキテクチャ・データベース設計・API仕様
- [TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md) - よくある問題と解決策
- [CHANGELOG.md](./CHANGELOG.md) - 更新履歴

---

## Git運用ルール

このプロジェクトは**ブランチベースの開発フロー**を採用しています。

1. `main`ブランチは常に安定した状態を保つ
2. 開発作業はすべて`feature/xxx`ブランチで実施
3. 作業完了後、Pull Requestを作成して`main`にマージ

```bash
# 作業ブランチを作成
git checkout main
git pull origin main
git checkout -b feature/機能名

# 作業内容をコミット
git add .
git commit -m "変更内容の説明"

# リモートにプッシュしてPR作成
git push origin feature/機能名
```

---

## ライセンス

プロプライエタリ
