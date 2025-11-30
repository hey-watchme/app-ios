# 分析画面アーキテクチャ改革

最終更新: 2025-11-30（用語統一版）

## 📋 目的

分析結果の表示構造を整理し、以下を実現する：

1. **各分析レベルごとの詳細ページを統一的に実装**
2. **レポート画面で3つのタブ（日次/週次/月次）を提供**
3. **アプリ内のどこからでも詳細ページにアクセス可能**
4. **廃止予定の旧ビューを特定し、段階的に削除**

---

## 🎯 分析レベルの定義（用語統一）

すべて「分析」で統一：

| 分析レベル | 単位 | データソース | 詳細ページ |
|----------|------|------------|-----------|
| **Spot分析** | 録音1件 | spot_results | SpotDetailView |
| **Daily分析** | 1日 | daily_results | DailyDetailView |
| **Weekly分析** | 1週間 | weekly_results | WeeklyDetailView |
| **Monthly分析** | 1ヶ月 | monthly_results | MonthlyDetailView |

---

## 📱 レポートタブの構造（3タブ構成）

レポートタブでは、以下の3つのタブを提供：

### タブ構成

```
┌─────────────────────────────────────┐
│ 📊 レポート                          │
├─────────────────────────────────────┤
│                                     │
│ [日次] [週次] [月次]  ← タブ切り替え │
│  ^^^^                               │
│  デフォルト選択                      │
└─────────────────────────────────────┘
```

### 1️⃣ 日次タブ（デフォルト）

```
┌─────────────────────────────────────┐
│ [日次] [週次] [月次]                 │
│  ^^^^                               │
│                                     │
│ [1週間] [1ヶ月] [3ヶ月]  ← 期間選択 │
│                                     │
│ 2025年11月24日 〜 11月30日  ← 期間表示│
│                                     │
│ 📈 グラフ（7日分のvibe_score推移）   │
│                                     │
│ 11/30 (土) 23.6  [詳細]             │
│ この日、朝から...                    │
│                                     │
│ 11/29 (金) 22.1  [詳細]             │
│ ...                                 │
└─────────────────────────────────────┘
```

**データソース**: `daily_results` テーブル
**一覧→詳細**: 各行をタップ → `DailyDetailView.sheet()`

### 2️⃣ 週次タブ

```
┌─────────────────────────────────────┐
│ [日次] [週次] [月次]                 │
│        ^^^^                         │
│                                     │
│ 11月第4週（11/24〜11/30）            │
│ 週の総括: 今週は...                  │
│ 印象的イベント: 5件                  │
│ [詳細を見る]                         │
│                                     │
│ 11月第3週（11/17〜11/23）            │
│ 週の総括: 先週は...                  │
│ [詳細を見る]                         │
└─────────────────────────────────────┘
```

**データソース**: `weekly_results` テーブル
**一覧→詳細**: 各行をタップ → `WeeklyDetailView.sheet()`

### 3️⃣ 月次タブ

```
┌─────────────────────────────────────┐
│ [日次] [週次] [月次]                 │
│              ^^^^                   │
│                                     │
│ 2025年11月                          │
│ 月の総括: 今月は...                  │
│ 印象的イベント: 5件                  │
│ [詳細を見る]                         │
│                                     │
│ 2025年10月                          │
│ 月の総括: 先月は...                  │
│ [詳細を見る]                         │
└─────────────────────────────────────┘
```

**データソース**: `monthly_results` テーブル
**一覧→詳細**: 各行をタップ → `MonthlyDetailView.sheet()`

---

## 📱 必要なビューコンポーネント

### 1. 詳細ページ（Detail Views）

#### SpotDetailView.swift ✅
```swift
// 引数: device_id, recorded_at
// 表示内容:
// - 録音時刻
// - vibe_score
// - summary（Spot分析のサマリー）
// - behavior（検出された行動）
// - transcription（文字起こし）
```

#### DailyDetailView.swift ✅
```swift
// 引数: device_id, local_date
// 表示内容:
// - 日付ヘッダー
// - vibe_score（日次平均）
// - summary（日次サマリー）
// - vibe_scores配列のグラフ（時系列、30分刻み）
// - burst_events一覧（感情変化イベント）
// - その日のSpot一覧（タップでSpotDetailViewへ）
```

#### WeeklyDetailView.swift ✅
```swift
// 引数: device_id, week_start_date
// 表示内容:
// - 週の期間（2025年11月18日〜24日）
// - 週の総括（weekly_results.summary）
// - 印象的な出来事5件（memorable_events）
```

#### MonthlyDetailView.swift ✅
```swift
// 引数: device_id, month_start_date
// 表示内容:
// - 月の期間（2025年11月）
// - 月の総括（monthly_results.summary）
// - 印象的な出来事5件（monthly版）
```

### 2. レポート一覧ページ（Report List Views）

#### DailyReportView.swift ✅
```swift
// 日次タブの内容
// 期間選択: 1週間（デフォルト）/ 1ヶ月 / 3ヶ月
// 表示内容:
// - 期間表示（2025年11月24日 〜 11月30日）
// - Daily vibe_scoreのグラフ（期間に応じて7/30/90点）
// - 日次サマリー一覧（各行から DailyDetailView へ）
```

#### WeeklyReportView.swift（新規作成）
```swift
// 週次タブの内容
// 表示内容:
// - 週次分析一覧（新しい順）
// - 各週の期間、総括の要約、印象的イベント件数
// - 各行から WeeklyDetailView へ
```

#### MonthlyReportView.swift（新規作成）
```swift
// 月次タブの内容
// 表示内容:
// - 月次分析一覧（新しい順）
// - 各月の期間、総括の要約、印象的イベント件数
// - 各行から MonthlyDetailView へ
```

### 3. レポートタブ統括（Report Container）

#### ReportView.swift（大幅修正）
```swift
// タブ切り替え: [日次] [週次] [月次]
// デフォルト: 日次タブ
// 各タブの内容:
//   - 日次: DailyReportView
//   - 週次: WeeklyReportView
//   - 月次: MonthlyReportView
```

---

## 🔄 導線（Navigation）

### ホーム画面（SimpleDashboardView）から

```
┌─────────────────────────────────┐
│ ホーム（今日の日付）             │
│                                 │
│ 📊 今日のサマリーカード          │
│   vibe_score: 23.6              │
│   summary: この日、朝から...     │
│   ────────────────────           │
│   [詳細を見る] ← タップ          │
│         ↓                       │
│   DailyDetailView.sheet()       │
│                                 │
│ 🎙️ Spotカード（録音1件）        │
│   recorded_at: 14:30            │
│   summary: 家族との会話で...    │
│   ────────────────────           │
│   [タップ]                      │
│         ↓                       │
│   SpotDetailView.sheet()        │
└─────────────────────────────────┘
```

### レポート画面（ReportView）から

```
┌─────────────────────────────────────┐
│ 📊 レポート                          │
├─────────────────────────────────────┤
│                                     │
│ [日次] [週次] [月次]  ← タブ         │
│  ^^^^                               │
│                                     │
│ ┌─ 日次タブ ─────────────────┐      │
│ │                             │      │
│ │ [1週間] [1ヶ月] [3ヶ月]     │      │
│ │                             │      │
│ │ 2025年11月24日〜11月30日    │      │
│ │                             │      │
│ │ 📈 グラフ（7日分）           │      │
│ │                             │      │
│ │ 11/30 (土) 23.6  [詳細]     │      │
│ │         ↓                   │      │
│ │   DailyDetailView.sheet()   │      │
│ │                             │      │
│ │ 11/29 (金) 22.1  [詳細]     │      │
│ │ ...                         │      │
│ └─────────────────────────────┘      │
│                                     │
│ ┌─ 週次タブ ─────────────────┐      │
│ │                             │      │
│ │ 11月第4週（11/24〜11/30）   │      │
│ │ 週の総括: 今週は...          │      │
│ │ 印象的イベント: 5件          │      │
│ │ [詳細を見る]                │      │
│ │         ↓                   │      │
│ │   WeeklyDetailView.sheet()  │      │
│ │                             │      │
│ │ 11月第3週（11/17〜11/23）   │      │
│ │ ...                         │      │
│ └─────────────────────────────┘      │
│                                     │
│ ┌─ 月次タブ ─────────────────┐      │
│ │                             │      │
│ │ 2025年11月                  │      │
│ │ 月の総括: 今月は...          │      │
│ │ 印象的イベント: 5件          │      │
│ │ [詳細を見る]                │      │
│ │         ↓                   │      │
│ │   MonthlyDetailView.sheet() │      │
│ │                             │      │
│ │ 2025年10月                  │      │
│ │ ...                         │      │
│ └─────────────────────────────┘      │
└─────────────────────────────────────┘
```

---

## 🗑️ 廃止予定のビュー

### 現在アクセスできていない旧ビュー

| ファイル名 | 内容 | 状態 | 廃止予定 |
|----------|------|------|---------|
| `DailyVibeReport.swift` | 気分の詳細（Daily） | 未使用 | ✅ 削除候補 |
| `BehaviorGraphView.swift` | 行動の詳細（Daily） | 未使用 | ✅ 削除候補 |
| `EmotionGraphView.swift` | 感情の詳細（Daily） | 未使用 | ✅ 削除候補 |

**理由**:
- 分析軸ごと（気分/行動/感情）に分けた詳細ページは複雑
- 新しい `DailyDetailView` で統合的に表示する方が分かりやすい

### バックアップ済みのビュー

| ファイル名 | 内容 | 状態 | 廃止予定 |
|----------|------|------|---------|
| `ReportView_backup_20251130.swift` | 旧ReportView | バックアップ | ⚠️ 保留 |

**理由**:
- 新しい構造で作り直すためバックアップ
- 問題があれば元に戻せる

---

## 📊 データ構造の確認

### daily_results テーブル（既存）

**カラム構成**（CSV確認済み）:
```
device_id, local_date, vibe_score, summary, behavior,
profile_result, vibe_scores, burst_events, processed_count,
last_time_block, llm_model, created_at, updated_at
```

**含まれているデータ**:
- ✅ vibe_score: 平均スコア（23.5882）
- ✅ summary: 日次サマリー文章
- ✅ vibe_scores: 時系列スコア配列（30分刻み）
- ✅ burst_events: 感情変化イベント

### weekly_results テーブル（既存）

**含まれているデータ**:
- ✅ summary: 週の総括（LLM生成）
- ✅ memorable_events: 印象的なイベント5件（JSONB配列）

**重要**: これは **Weekly Summary（週次総括）** のデータ。Daily Reportとは別物。

### monthly_results テーブル（未作成）

**必要なカラム**（weekly_resultsと同様）:
- monthly_aggregators テーブル
- monthly_results テーブル

---

## 🎯 実装フェーズ

### ✅ Phase 1: 日次レポートの完成（2025-11-30完了）

**実装完了項目**:

1. **UI構造の改革**
   - [x] 期間選択をプルダウンメニュー形式に変更（過去7日間/30日間/90日間）
   - [x] グラフデザインをModernVibeCardと統一（白背景 + グラデーション）
   - [x] 日次サマリー一覧の実装

2. **データ取得の実装**
   - [x] `SupabaseDataManager.fetchDailyResultsRange()` メソッド追加
   - [x] DailyReportViewで実データ取得・表示
   - [x] 期間選択に応じた動的データ取得

3. **詳細ページのモックアップ作成**
   - [x] SpotDetailView.swift（プレースホルダー）
   - [x] DailyDetailView.swift（プレースホルダー）
   - [x] WeeklyDetailView.swift（プレースホルダー）
   - [x] MonthlyDetailView.swift（プレースホルダー）

4. **レポート一覧ページ**
   - [x] DailyReportView.swift（実データ表示完了）
   - [x] WeeklyReportView.swift（モックアップのみ）
   - [x] MonthlyReportView.swift（モックアップのみ）

5. **ReportView.swiftの調整**
   - [x] 3タブ構造を実装
   - [x] 日次タブのみ表示（週次・月次は一旦非表示）

**現在の状態**:
- ✅ 日次レポート完全動作（`daily_results`テーブルから実データ取得）
- ⏸️ 週次・月次レポートは保留（タブUIはコメントアウト）

### 📋 Phase 2: 詳細ページの実装（次のステップ）

**実装予定**:

1. **DailyDetailView にリアルデータを表示**
   - [ ] daily_resultsから1日分のデータ取得
   - [ ] vibe_scoresグラフの表示
   - [ ] burst_events一覧の表示
   - [ ] その日のSpot一覧（タップでSpotDetailViewへ）

2. **SpotDetailView にリアルデータを表示**
   - [ ] spot_resultsから1件取得
   - [ ] summary、behavior、transcriptionの表示

### 🔜 Phase 3: Weekly/Monthly分析の実装（将来）

**バックエンド準備が必要**:
1. [ ] /aggregator/monthly エンドポイント作成
2. [ ] /profiler/monthly-profiler エンドポイント作成
3. [ ] monthly_results テーブル作成

**iOS側の実装**:
1. [ ] WeeklyDetailView にリアルデータを表示
2. [ ] MonthlyDetailView にリアルデータを表示
3. [ ] ReportViewのタブUIを復活（日次/週次/月次）

### 🗑️ Phase 4: 旧ビューの削除（最終段階）

1. **廃止予定ビューの削除**
   - [ ] DailyVibeReport.swift
   - [ ] BehaviorGraphView.swift
   - [ ] EmotionGraphView.swift
   - [ ] ReportView_backup_20251130.swift（確認後）

---

## 📝 重要な用語の整理

| 用語 | 説明 | データソース |
|------|------|------------|
| **Spot分析** | 録音1件ごとの即時分析 | spot_results |
| **Daily分析** | 1日単位の累積分析 | daily_results |
| **Weekly分析** | 1週間単位の総括分析 | weekly_results |
| **Monthly分析** | 1ヶ月単位の総括分析 | monthly_results |

**日次タブとWeekly分析は別物**:
- 日次タブ（1週間表示） ≠ Weekly分析
- 日次タブ: 7日分のdaily_resultsを並べたもの（一覧）
- Weekly分析: 1週間全体をLLMで総括したもの（1データブロック）

---

## 🔗 関連ドキュメント

- [分析ページ開発](./analysis-page-development.md)
- [技術仕様](../technical/TECHNICAL.md)
