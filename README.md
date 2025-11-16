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

- **UTC時刻**: `recorded_at`, `created_at`, `updated_at`
- **ローカル時刻**: `local_date`, `local_time`（デバイスのタイムゾーン）

---

## 🔌 API通信

### Supabase RPC関数

iOSアプリは Supabase RPC関数 `get_dashboard_data` を使用して、1回のAPIコールで全データを取得します。

**呼び出し**:
```swift
let response: [RPCDashboardResponse] = try await supabase
    .rpc("get_dashboard_data", params: [
        "p_device_id": deviceId,
        "p_date": dateString  // "YYYY-MM-DD"
    ])
    .execute()
    .value
```

**レスポンス構造**:
```swift
struct RPCDashboardResponse: Codable {
    let behavior_report: BehaviorReport?       // behavior_summaryテーブル
    let emotion_report: EmotionReport?         // emotion_opensmile_summaryテーブル
    let subject_info: Subject?                 // subjectsテーブル
    let dashboard_summary: DashboardSummary?   // daily_resultsテーブル ← 重要
    let subject_comments: [SubjectComment]?    // subject_commentsテーブル
}
```

**重要**: `dashboard_summary` は `daily_results` テーブルから取得されます。

### RPC関数の定義（Supabase側）

```sql
CREATE OR REPLACE FUNCTION get_dashboard_data(p_device_id text, p_date text)
RETURNS TABLE (
    behavior_report jsonb,
    emotion_report jsonb,
    subject_info jsonb,
    dashboard_summary jsonb,  -- daily_resultsテーブルを参照
    subject_comments jsonb
)
```

**参照先テーブル**:
- `behavior_summary` → `behavior_report`
- `emotion_opensmile_summary` → `emotion_report`
- `subjects` → `subject_info`
- **`daily_results`** → `dashboard_summary` ← 気分データのメインソース
- `subject_comments` → `subject_comments`

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

### 権限レベル

#### 1. 閲覧専用モード（Read-Only）
- 対象: ゲストユーザー
- 権限: サンプルデータの閲覧のみ

#### 2. 全権限モード（Full Access）
- 対象: 認証済みユーザー
- 権限: 録音、デバイス管理、コメント投稿など全機能

### ユーザーとデバイスの関係

- **1ユーザー = 複数の観測対象デバイス + 1台の通知先デバイス**
- 観測対象デバイス: 録音される人を表す論理的なID
- 通知先デバイス: プッシュ通知を受信するユーザーのiPhone

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

## 📂 プロジェクト構造

```
ios_watchme_v9/
├── ios_watchme_v9App.swift        # アプリエントリーポイント
├── ContentView.swift              # メインビュー（ホームタブ）
├── SimpleDashboardView.swift      # 日別ダッシュボード
├── AnalysisView.swift             # レポートページ
├── SubjectTabView.swift           # 観測対象ページ
├── HomeView.swift                 # 気分詳細ビュー
├── BehaviorGraphView.swift        # 行動グラフ詳細
├── EmotionGraphView.swift         # 感情グラフ詳細
├── RecordingView.swift            # 録音機能
├── LoginView.swift                # ログイン画面
├── SignUpView.swift               # 会員登録画面
├── UserInfoView.swift             # マイページ
├── AudioRecorder.swift            # 録音管理
├── NetworkManager.swift           # API通信
├── DeviceManager.swift            # デバイス管理
├── UserAccountManager.swift       # ユーザー認証管理
├── SupabaseAuthManager.swift      # Supabase認証
├── SupabaseDataManager.swift      # データ取得管理（RPC呼び出し）
├── DashboardSummary.swift         # daily_resultsデータモデル
├── DashboardTimeBlock.swift       # spot_resultsデータモデル
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
- **Supabase** - 認証・データベース・ストレージ
- **AWS SNS + APNs** - プッシュ通知
- **Combine** - リアクティブプログラミング

---

## ライセンス

プロプライエタリ
