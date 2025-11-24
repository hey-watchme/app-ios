# WatchMe App (iOS)

WatchMeプラットフォームのiOSアプリケーション。
音声録音とAI分析による心理・感情・行動の総合的なモニタリングを提供します。

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

## 🔐 認証とユーザーモード

### 初回起動時のフロー

```
アプリ起動
  ↓
初期画面（ロゴ + 「はじめる」「ログイン」）
  ↓「はじめる」押下
オンボーディング（4ページのスライド）
  ↓「はじめる」またはスキップ押下
アカウント選択画面
  ┃
  ┣━ 🔵 Google でサインイン
  ┣━ 📧 メールアドレスで登録（準備中）
  ┗━ 👤 ゲストとして続行（匿名認証）
```

### 認証方式

#### 1. 匿名認証（Anonymous Authentication）
- **対象**: 初めて使うユーザー、すぐに試したいユーザー
- **特徴**:
  - アカウント登録不要で即座に全機能を利用可能
  - Supabaseの匿名認証機能を使用
  - 後でメールアドレスやGoogle認証にアップグレード可能
- **制限事項**:
  - アプリ削除またはデータクリアでアカウント喪失
  - 複数デバイスでの同期不可
- **推奨**: 後でメールアドレスまたはGoogle認証への移行を促進

#### 2. Google OAuth認証
- **対象**: Googleアカウントを持つユーザー
- **特徴**:
  - ワンタップで簡単ログイン
  - パスワード管理不要
  - 複数デバイスでの同期可能
- **実装**: Supabase OAuth + Google Cloud Console
- **フロー**: アプリ → Safari（Googleログイン）→ アプリに自動復帰

#### 3. メールアドレス/パスワード認証（準備中）
- **対象**: メールアドレスで登録したいユーザー
- **特徴**:
  - 従来型の認証方式
  - 複数デバイスでの同期可能
- **状態**: 現在準備中（モックアップのみ実装済み）

### 権限レベル

#### 閲覧専用モード（Read-Only）
- **対象**: 未認証状態（初回起動時）
- **権限**: サンプルデータの閲覧のみ
- **状態**: `UserAuthState.readOnly(source: .guest)`

#### 全権限モード（Full Access）
- **対象**: 認証済みユーザー（匿名、Google、メールアドレス）
- **権限**: 録音、デバイス管理、コメント投稿など全機能
- **状態**: `UserAuthState.fullAccess(userId: String)`

### ユーザーアカウントの種類

| 種類 | email | 複数デバイス | データ保護 | 実装状況 |
|------|-------|------------|----------|---------|
| 匿名ユーザー | `"anonymous"` | ❌ | ⚠️ 脆弱 | ✅ 実装済み |
| Googleユーザー | Googleアカウント | ✅ | ✅ 安全 | ✅ 実装済み |
| メールユーザー | 登録メール | ✅ | ✅ 安全 | 🚧 準備中 |

### ユーザーとデバイスの関係

- **1ユーザー = 複数の観測対象デバイス + 1台の通知先デバイス**
- 観測対象デバイス: 録音される人を表す論理的なID
- 通知先デバイス: プッシュ通知を受信するユーザーのiPhone

### 匿名ユーザーの判定

```swift
var isAnonymousUser: Bool {
    return currentUser?.email == "anonymous"
}
```

---

## ⚙️ 開発時の重要ルール

### データベース設計

**`auth.users`への直接参照は禁止**。必ず`public.users(user_id)`を使用。

```swift
// ❌ 間違い
let userId = userAccountManager.currentUser?.id

// ✅ 正しい
let userId = userAccountManager.currentUser?.profile?.userId
```

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
| **初期画面** | ウェルカム画面 | `ios_watchme_v9App.swift`（内部のMainAppView） | ロゴと「はじめる」「ログイン」ボタン |
| **オンボーディング画面** | オンボーディング | `OnboardingView.swift` | 4ページのスライド式説明画面 |
| **アカウント選択画面** | アカウント選択 | `AccountSelectionView.swift` | Google/メール/ゲスト選択画面 |
| **ログイン画面** | ログイン | `LoginView.swift` | メールアドレスとパスワードでログイン |
| **会員登録画面** | 会員登録 | `SignUpView.swift` | メールアドレスとパスワードで新規登録 |
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
├── OnboardingView.swift           # オンボーディング画面（4ページスライド）
├── AccountSelectionView.swift     # アカウント選択画面（Google/メール/ゲスト）
├── LoginView.swift                # ログイン画面
├── SignUpView.swift               # 会員登録画面
├── SimpleDashboardView.swift      # ホーム画面 + 分析結果の一覧画面
├── AnalysisView.swift             # レポート画面
├── SubjectTabView.swift           # 観測対象画面
├── HomeView.swift                 # 気分詳細画面
├── BehaviorGraphView.swift        # 行動グラフ詳細
├── EmotionGraphView.swift         # 感情グラフ詳細
├── FullScreenRecordingView.swift  # 録音画面（モーダル）
├── AudioBarVisualizerView.swift   # 音声ビジュアライザー（イコライザー風）
├── UserInfoView.swift             # マイページ
├── RecordingModel.swift           # 録音ファイルモデル
├── NetworkManager.swift           # API通信
├── DeviceManager.swift            # デバイス管理
├── UserAccountManager.swift       # ユーザー認証管理（匿名/Google/メール）
├── SupabaseDataManager.swift      # データ取得管理（ダイレクトアクセス）
├── DashboardSummary.swift         # daily_resultsデータモデル
├── DashboardTimeBlock.swift       # spot_resultsデータモデル
├── Services/
│   ├── RecordingStore.swift       # 録音状態管理
│   ├── AudioRecorderService.swift # 録音実行サービス
│   ├── AudioMonitorService.swift  # 音声レベル監視サービス
│   └── UploaderService.swift      # アップロードサービス
└── Models/                        # その他データモデル
```

---

## 📚 関連ドキュメント

- [TECHNICAL.md](./docs/TECHNICAL.md) - アーキテクチャ・データベース設計・API仕様
- [PUSH_NOTIFICATION_ARCHITECTURE.md](./docs/PUSH_NOTIFICATION_ARCHITECTURE.md) - プッシュ通知の詳細実装
- [ACCOUNT_DELETION.md](./docs/ACCOUNT_DELETION.md) - アカウント削除機能（App Store審査対応）
- [TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md) - トラブルシューティング
- [CHANGELOG.md](./CHANGELOG.md) - 更新履歴

### 外部公開URL

- **プライバシーポリシー**: https://hey-watch.me/privacy
- **利用規約**: https://hey-watch.me/terms
- **サポート**: https://hey-watch.me/

---

## 🛠️ 技術スタック

- **Swift 5.9+** / **SwiftUI**
- **AVFoundation** - 音声録音
- **Supabase** - 認証（匿名認証・Google OAuth）・データベース・ストレージ
- **Google Cloud Platform** - OAuth 2.0クライアント（Google認証）
- **AWS SNS + APNs** - プッシュ通知
- **Combine** - リアクティブプログラミング

---

## ライセンス

プロプライエタリ
