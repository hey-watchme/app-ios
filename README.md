# WatchMe App (iOS)

WatchMeプラットフォームのiOSアプリケーション。
音声録音とAI分析による心理・感情・行動の総合的なモニタリングを提供します。

> **📚 関連ドキュメント**
>
> **機能仕様**:
> - [AUTHENTICATION.md](./docs/features/AUTHENTICATION.md) - 認証システム詳細（アカウント削除含む）
> - [PUSH_NOTIFICATION_ARCHITECTURE.md](./docs/features/PUSH_NOTIFICATION_ARCHITECTURE.md) - プッシュ通知
> - [RECORDING_SPECIFICATION.md](./docs/features/RECORDING_SPECIFICATION.md) - 録音仕様
>
> **技術仕様**:
> - [TECHNICAL.md](./docs/technical/TECHNICAL.md) - アーキテクチャ・データベース設計
> - [ARCHITECTURE.md](./docs/technical/ARCHITECTURE.md) - 現在のアーキテクチャと構造分析
> - [COLOR_SYSTEM.md](./docs/technical/COLOR_SYSTEM.md) - カラーシステム
>
> **セットアップガイド**:
> - [MANTIS.md](./docs/setup/MANTIS.md) - Mantisライブラリのセットアップ
> - [SUPABASE_AUTH.md](./docs/setup/SUPABASE_AUTH.md) - Supabase認証セットアップ
> - [SUPABASE_PACKAGE.md](./docs/setup/SUPABASE_PACKAGE.md) - Supabaseパッケージセットアップ
>
> **開発ガイド**:
> - [TODO.md](./docs/development/TODO.md) - 開発タスク管理
> - [PERFORMANCE.md](./docs/development/PERFORMANCE.md) - パフォーマンス改善計画
> - [REFACTORING_PLAN.md](./docs/development/REFACTORING_PLAN.md) - リファクタリング実行計画
> - [COLOR_GUIDE.md](./docs/development/COLOR_GUIDE.md) - カラー管理ガイド
>
> **運用**:
> - [TROUBLESHOOTING.md](./docs/operations/TROUBLESHOOTING.md) - トラブルシューティング
> - [APP_STORE_METADATA.md](./docs/operations/APP_STORE_METADATA.md) - App Store申請情報
>
> **更新履歴**:
> - [CHANGELOG.md](./CHANGELOG.md) - 変更履歴

---

## 🗺️ ドキュメントガイド

**こんな時は、このドキュメントを参照してください：**

| やりたいこと | 参照先 |
|------------|--------|
| 📱 **アプリの全体像を理解したい** | このREADME |
| 🏗️ **現在のアーキテクチャを理解** | [ARCHITECTURE.md](./docs/technical/ARCHITECTURE.md) |
| 🔐 **認証機能の実装・修正** | [AUTHENTICATION.md](./docs/features/AUTHENTICATION.md) |
| 🗄️ **データベース設計を確認・変更** | [TECHNICAL.md](./docs/technical/TECHNICAL.md)<br>`/Users/kaya.matsumoto/projects/watchme/server-configs/database/` |
| 🔌 **API仕様を確認・変更** | [TECHNICAL.md](./docs/technical/TECHNICAL.md) |
| 📡 **プッシュ通知の仕組みを理解** | [PUSH_NOTIFICATION_ARCHITECTURE.md](./docs/features/PUSH_NOTIFICATION_ARCHITECTURE.md) |
| 🎙️ **録音機能の仕様を確認** | [RECORDING_SPECIFICATION.md](./docs/features/RECORDING_SPECIFICATION.md) |
| ⚡ **パフォーマンス問題を解決** | [PERFORMANCE.md](./docs/development/PERFORMANCE.md) |
| 🔄 **リファクタリング計画を確認** | [REFACTORING_PLAN.md](./docs/development/REFACTORING_PLAN.md) |
| 🎨 **カラーを変更したい** | [COLOR_GUIDE.md](./docs/development/COLOR_GUIDE.md) |
| 🔧 **環境構築・ライブラリセットアップ** | [docs/setup/](./docs/setup/) |
| 📝 **開発タスクを確認** | [TODO.md](./docs/development/TODO.md) |
| 🐛 **トラブルシューティング** | [TROUBLESHOOTING.md](./docs/operations/TROUBLESHOOTING.md) |
| 📦 **App Store申請準備** | [APP_STORE_METADATA.md](./docs/operations/APP_STORE_METADATA.md) |
| 📜 **変更履歴を確認** | [CHANGELOG.md](./CHANGELOG.md) |

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
- **サンプルデバイス**: 初回体験の向上と事例カタログ
- **✅ QRコード共有機能**: デバイスをQRコードで他ユーザーと共有（2025-12-06実装完了）

### QRコード共有機能（2025-12-06実装完了）

デバイスの共有をQRコードで簡単に行える機能です。

**機能詳細**:
- デバイス詳細画面から「QRコードを表示」ボタンでQRコード生成
- 自動的にS3にアップロードされ、永続的な公開URLを取得
- QRコード画像の共有・保存が可能
- API: `https://api.hey-watch.me/qrcode/v1/devices/{device_id}/qrcode`

**実装ファイル**:
- `QRCodeService.swift` - QRコード生成APIクライアント
- `DeviceEditView.swift` - QRコード表示UI

**技術スタック**:
- QR Code Generator API（FastAPI）
- S3バケット: `watchme-qrcodes`（公開アクセス可）
- 画像形式: PNG（512x512px）

**詳細**: [QR Code Generator API仕様](../projects/watchme/api/qr-code-generator/README.md)

### サンプルデバイス機能

新規ユーザーが登録すると、自動的に**デフォルトサンプルデバイス**（5歳男児のデモデータ）が追加されます。
これにより、ユーザーはすぐにアプリの機能を体験できます。

また、QRコードスキャンで追加のサンプルデバイス（30代会社員、70代高齢者など）を追加し、様々な年齢層の事例を閲覧できます。

**詳細**: [Demo Generator API仕様](../projects/watchme/api/demo-generator/README.md#サンプルデバイスとiosアプリの連携)

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

- **期間選択**: 週次・月次の切り替えが可能
- **今週のレポート**:
  - 気分グラフ（日別のVibeスコア推移）
  - 週のサマリー（平均スコアと総括）
  - 印象的な出来事（ランキング形式）
- **今月のレポート**: 近日公開予定（週次と同様の構成）
- **ダイバージェンスインデックス**（開発予定）:
  - 認知・感情・行動の3軸からの総合的な偏差指標
  - Typical（通常範囲）からExtreme（極度の偏差）までの5段階で可視化
  - 観測対象の状態変化を早期に検知

### 👤 観測対象（プロフィールとインサイト）

**目的**: 観測対象の特性と測定結果から得られた知見を統合的に理解する

- 基本情報（名前、写真、年齢、性別、地域）
- 測定から得られたインサイト（認知スタイル、神経機能モデル、知性の形式モデル）
- 課題と傾向の表示

---

## 🗄️ データベース

WatchMeは録音データを分析し、気分・感情・行動パターンを可視化します。

### データ階層
- **Spot分析**: 録音ごとの即時分析（気分スコア、感情、行動）
- **Daily分析**: 1日分の累積分析（トレンド、サマリー、急激な変化イベント）
- **プロフィール**: 観測対象の基本情報とインサイト

### 重要な設計原則
- **タイムゾーン**: すべてのデータは`local_date`/`local_time`で管理（UTC時刻は使用しない）
- **ユーザー認証**: `auth.users`への直接参照は禁止。必ず`public.users`を使用

**詳細**: [技術仕様ドキュメント](./docs/technical/TECHNICAL.md)

**データベーススキーマ管理**: `/Users/kaya.matsumoto/projects/watchme/server-configs/database/`

---

## 🔌 API通信

iOSアプリはSupabaseを通じてデータを取得・更新します。

**現在のアプローチ**: Supabaseテーブルへの直接アクセス（開発スピード優先）
**将来の最適化**: パフォーマンスチューニング時にRPC関数を導入予定

**詳細**: [技術仕様ドキュメント](./docs/technical/TECHNICAL.md)

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

## ⚙️ 開発時の重要原則

### データベース
- **ユーザー認証**: `auth.users`への直接参照は禁止。必ず`public.users`を使用
- **タイムゾーン**: `local_date`/`local_time`のみ使用（UTC時刻は使用しない）

### ビルド
```bash
xcodebuild -scheme ios_watchme_v9 -sdk iphonesimulator build
```

### Git
ブランチベースの開発フロー（`main` → `feature/機能名` → PR → `main`）

**詳細**:
- 認証: [AUTHENTICATION.md](./docs/features/AUTHENTICATION.md)
- 技術仕様: [TECHNICAL.md](./docs/technical/TECHNICAL.md)
- セットアップ: [docs/setup/](./docs/setup/)

---

## 📡 プッシュ通知

観測対象デバイスで録音・分析が完了すると、自動的に最新データが反映されます。

**仕組み**: AWS Lambda → SNS → APNs → トーストバナー表示 → データ自動再取得

**詳細**: [プッシュ通知アーキテクチャ](./docs/features/PUSH_NOTIFICATION_ARCHITECTURE.md)

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
