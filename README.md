# WatchMe App (iOS)

WatchMeプラットフォームのiOSアプリケーション。
音声録音とAI分析による心理・感情・行動の総合的なモニタリングを提供します。

> **📚 関連ドキュメント**
>
> **機能仕様**:
> - [AUTHENTICATION.md](./docs/features/AUTHENTICATION.md) - 認証システム詳細
> - [PUSH_NOTIFICATION_ARCHITECTURE.md](./docs/features/PUSH_NOTIFICATION_ARCHITECTURE.md) - プッシュ通知
> - [ACCOUNT_DELETION.md](./docs/features/ACCOUNT_DELETION.md) - アカウント削除
> - [RECORDING_SPECIFICATION.md](./docs/features/RECORDING_SPECIFICATION.md) - 録音仕様
>
> **技術仕様**:
> - [TECHNICAL.md](./docs/technical/TECHNICAL.md) - アーキテクチャ・データベース設計
> - [COLOR_SYSTEM.md](./docs/technical/COLOR_SYSTEM.md) - カラーシステム
>
> **セットアップガイド**:
> - [MANTIS.md](./docs/setup/MANTIS.md) - Mantisライブラリのセットアップ
> - [SUPABASE_AUTH.md](./docs/setup/SUPABASE_AUTH.md) - Supabase認証セットアップ
> - [SUPABASE_PACKAGE.md](./docs/setup/SUPABASE_PACKAGE.md) - Supabaseパッケージセットアップ
>
> **開発ガイド**:
> - [TODO.md](./docs/development/TODO.md) - 開発タスク管理
> - [COLOR_GUIDE.md](./docs/development/COLOR_GUIDE.md) - カラー管理ガイド
>
> **運用**:
> - [TROUBLESHOOTING.md](./docs/operations/TROUBLESHOOTING.md) - トラブルシューティング
> - [APP_STORE_METADATA.md](./docs/operations/APP_STORE_METADATA.md) - App Store申請情報
>
> **更新履歴**:
> - [CHANGELOG.md](./CHANGELOG.md) - 変更履歴

---

## 📱 アプリの概要

このアプリは、音声録音とAI分析による心理状態・感情・行動パターンの可視化ツールです。
療育・教育・ケアサポートの現場において、**観測対象の変化を可視化し、適切なサポートを提供する**ことを目的としています。

### 主要機能

- **手動録音**: アプリ内での音声録音（フォアグラウンドのみ）
- **AI分析**: 音声認識、感情分析、行動パターン検出
- **マルチデバイス対応**: 1ユーザーが複数の観測対象デバイス（録音デバイス）を管理可能
- **リアルタイム更新**: プッシュ通知によるデータ自動更新
- **コメント機能**: 観測対象に対する日別コメント投稿

---

## 🏗️ アプリの構成

このアプリは3つの主要ページで構成されています。

### 🏠 ホーム（リアルタイムステータス）

**目的**: 現在の状態をリアルタイムで把握する

- 現時点のステータス表示（今日の気分、行動、感情）
- 1日のサマリー（現時点までの集計）
- プッシュ通知によるリアルタイム更新
- 日別コメント記録

### 📊 レポート（長期的な変化の追跡）

**目的**: 時間軸で変化を可視化し、成長や改善を確認する

- 長期的な時間軸（今週、今月、今年）
- 折れ線グラフ、推移グラフで変化を表現
- エビデンスに基づいたサポート計画の立案

### 👤 観測対象（プロフィールとインサイト）

**目的**: 観測対象の特性と測定結果から得られた知見を統合的に理解する

- 基本情報（名前、写真、年齢、性別、地域）
- 測定から得られたインサイト（認知スタイル、神経機能モデル、知性の形式モデル）
- 課題と傾向の表示

---

## 🗄️ データベース構造

### 主要テーブル

#### Spot分析（録音ごと）
- **`spot_results`**: 録音ごとの分析結果（気分スコア、感情、行動）
- **`spot_features`**: 録音ごとの特徴量（音響特徴、感情特徴、文字起こし）
- **`spot_aggregators`**: Spot集計データ（Daily分析トリガー用）

#### Daily分析（1日分の累積）
- **`daily_results`**: 1日分の累積分析結果
  - `vibe_score`: 平均気分スコア
  - `summary`: LLMによる1日のサマリー文章
  - `vibe_scores`: 時系列スコアデータ `[{time: "HH:MM", score: N}]`
  - `burst_events`: 急激な変化イベント
  - `profile_result`: 心理分析結果（daily_trend, key_moments, emotional_stability）
- **`daily_aggregators`**: Daily集計データ（Profiler API用）

#### その他
- **`audio_files`**: 音声ファイルメタデータ（S3パス、録音時刻、タイムゾーン）
- **`devices`**: デバイス情報（観測対象デバイス）
- **`subjects`**: 観測対象のプロフィール情報
- **`public.users`**: ユーザー情報（認証・APNsトークン）

### タイムゾーン対応

すべての主要テーブルに `local_date` と `local_time` カラムがあります。

- **UTC時刻**: `recorded_at`, `created_at`, `updated_at` ← **アップロード時のみ使用、アプリでは参照しない**
- **ローカル時刻**: `local_date`, `local_time` ← **✅ アプリではこれのみ使用**
  - `local_date`: 日付のみ（YYYY-MM-DD）
  - `local_time`: 日付+時間（YYYY-MM-DD HH:MM:SS） ← ユニークキー

**重要原則**:
- アプリ内では`recorded_at`（UTC）を一切参照しない
- すべてのデータフィルタリング・表示は`local_date`と`local_time`のみ使用
- タイムゾーン変換は不要（データベースに既にローカルタイムが格納されている）

---

## 🔌 API通信

### データアクセス方式

**開発中はダイレクトアクセス方式を採用**

現在、iOSアプリはSupabaseの各テーブルに直接アクセスしています。

**主要なデータ取得メソッド**:
- `fetchDailyResults()` → `daily_results`テーブルから気分データを取得
- `fetchSubjectInfo()` → `devices` → `subjects`テーブルからプロフィール情報を取得
- `fetchDashboardTimeBlocks()` → `spot_results` + `spot_features`を並列取得
- `fetchComments()` → `subject_comments`テーブルからコメントを取得

**メリット**:
- デバッグが容易（SQLログが明示的に見える）
- カラム指定が明確（`notes`などの取得漏れを防げる）
- 開発スピードが速い（RPC関数の修正・デプロイサイクルが不要）

**今後の方針**:
- **最終的なパフォーマンスチューニング時にRPC関数を導入**
- 複数のテーブルを1回のAPIコールで取得する最適化を実施
- 開発段階では柔軟性を優先し、ダイレクトアクセスを継続

---

## 💻 セットアップ

### 必要な環境

- Xcode 15.0以上
- iOS 17.0以上
- Swift 5.9以上

### プロジェクトを開く

```bash
cd /Users/kaya.matsumoto/ios_watchme_v9
open ios_watchme_v9.xcodeproj
```

### パッケージ依存関係

Swift Package Managerが自動的に以下を解決します：
- Supabase Swift SDK
- Mantis（画像トリミング）

### ビルドと実行

```bash
# コンパイルチェック
xcodebuild -scheme ios_watchme_v9 -sdk iphonesimulator build

# または Xcode で Cmd + R
```

---

## 🔐 認証

WatchMeでは3つの認証方式をサポートしています：

- **匿名認証**: アカウント登録不要で即座に利用開始（後でアップグレード可能）
- **Google OAuth**: Googleアカウントでワンタップログイン
- **メール/パスワード**: 従来型の認証（準備中）

認証後は全機能にアクセス可能です。未認証状態ではサンプルデータの閲覧のみ可能です。

**詳細**: [認証システム詳細ドキュメント](./docs/features/AUTHENTICATION.md)

---

## ⚙️ 開発時の重要ルール

### データベース設計

#### ユーザー認証テーブルの設計

**重要原則**: `auth.users`への直接参照は禁止。必ず`public.users(user_id)`を使用。

**主要テーブル**:
- **`auth.users`**: Supabase認証専用（直接アクセス不可）
- **`public.users`**: アプリケーション用ユーザープロファイル（✅ 推奨）

**詳細**: [認証システム詳細ドキュメント](./docs/features/AUTHENTICATION.md)

### ビルド検証

```bash
# ✅ 正しい：シンプルにコンパイルチェック
xcodebuild -scheme ios_watchme_v9 -sdk iphonesimulator build

# ❌ 間違い：-destination指定は不要
xcodebuild -scheme ios_watchme_v9 -destination '...' build
```

### Git運用

ブランチベースの開発フロー：

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

## 📡 プッシュ通知（リアルタイム更新）

### アーキテクチャ

```
観測対象デバイス（録音） → Lambda処理 → daily_results更新
  ↓ (AWS SNS → APNs)
通知先デバイス（iPhone） → トーストバナー表示 → 最新データ取得
```

### 通知の動作

- **フォアグラウンド**: トーストバナー表示 → 自動データ再取得
- **バックグラウンド**: サイレント通知（次回起動時にデータ取得）
- **完全終了**: 何も起きない

---

## 📱 画面とファイルの対応表

実装時に参照する画面名とファイル名の対応表です。

| 通称 | 正式名称 | ファイル名 | 説明 |
|------|---------|-----------|------|
| **初期画面** | ウェルカム画面 | `ios_watchme_v9App.swift`（MainAppView） | ロゴと「はじめる」「ログイン」ボタン |
| **認証フロー** | 統合認証フロー | `AuthFlowView.swift` | オンボーディングとアカウント選択 |
| **ログイン画面** | ログイン | `LoginView.swift` | メール/パスワードでログイン |
| **ホーム画面** | ホーム（リアルタイムステータス） | `SimpleDashboardView.swift` | 日別のダッシュボード。気分グラフ、最新のスポット分析（最大3件）、コメント機能を表示 |
| **分析結果の一覧画面** | 分析結果の一覧 | `SimpleDashboardView.swift`（内部の`AnalysisListView`） | 1日分の全スポット分析を時系列順に表示 |
| **気分詳細画面** | 気分詳細 | `HomeView.swift` | 気分グラフの詳細と時間ごとの詳細リスト |
| **レポート画面** | レポート（長期的な変化の追跡） | `AnalysisView.swift` | 週次・月次の長期トレンド表示 |
| **観測対象画面** | 観測対象（プロフィールとインサイト） | `SubjectTabView.swift` | プロフィール情報とインサイト表示 |

---

## 📂 プロジェクト構造

```
ios_watchme_v9/
├── ios_watchme_v9App.swift        # アプリエントリーポイント
├── ContentView.swift              # メインビュー（ホームタブ）
├── SimpleDashboardView.swift      # ホーム画面 + 分析結果の一覧画面
├── AnalysisView.swift             # レポート画面
├── SubjectTabView.swift           # 観測対象画面
├── HomeView.swift                 # 気分詳細画面
├── BehaviorGraphView.swift        # 行動グラフ詳細
├── EmotionGraphView.swift         # 感情グラフ詳細
├── FullScreenRecordingView.swift  # 録音画面（モーダル）
├── AudioBarVisualizerView.swift   # 音声ビジュアライザー
├── UserInfoView.swift             # マイページ
├── AuthFlowView.swift             # 統合認証フロー
├── LoginView.swift                # ログイン画面
├── UpgradeAccountView.swift       # アカウントアップグレード画面
├── RecordingModel.swift           # 録音ファイルモデル
├── NetworkManager.swift           # API通信
├── DeviceManager.swift            # デバイス管理
├── UserAccountManager.swift       # ユーザー認証管理
├── SupabaseDataManager.swift      # データ取得管理
├── DashboardSummary.swift         # daily_resultsデータモデル
├── DashboardTimeBlock.swift       # spot_resultsデータモデル
├── Services/
│   ├── RecordingStore.swift       # 録音状態管理
│   ├── AudioRecorderService.swift # 録音実行サービス
│   ├── AudioMonitorService.swift  # 音声レベル監視サービス
│   ├── UploaderService.swift      # アップロードサービス
│   └── ToastManager.swift         # グローバルトースト通知システム
└── Models/                        # その他データモデル
```

---

## 🔗 外部公開URL

- **プライバシーポリシー**: https://hey-watch.me/privacy
- **利用規約**: https://hey-watch.me/terms
- **サポート**: https://hey-watch.me/

---

## 🛠️ 技術スタック

- **Swift 5.9+** / **SwiftUI**
- **AVFoundation** - 音声録音
- **Supabase** - 認証・データベース・ストレージ
- **AWS SNS + APNs** - プッシュ通知
- **Combine** - リアクティブプログラミング

---

## ライセンス

プロプライエタリ
