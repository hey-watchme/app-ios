# ダッシュボード デザインリニューアル計画

**ブランチ**: `redesign/dashboard`
**ベース**: `main` @ `52b8c27`（STT/SED修正済み）
**作成日**: 2026-03-09
**ステータス**: 計画段階

---

## 概要

SimpleDashboardView（メイン画面）を起点としたデザインリニューアル。
一番ユーザーの目に触れる画面から段階的に改善していく。

---

## 対象画面と優先度

### Phase 1: メインダッシュボード（SimpleDashboardView）
**ファイル**: `ios_watchme_v9/SimpleDashboardView.swift`（~1500行）

| セクション | 現状のコンポーネント | 備考 |
|-----------|-------------------|------|
| 日付セクション | `LargeDateSection` / `StickyDateHeader` | 外部コンポーネント |
| Vibeグラフカード | `ModernVibeCard` | 外部コンポーネント |
| 最新情報 | `SpotAnalysisListSection` + `SpotAnalysisCard` | 同一ファイル内 |
| ハイライト | `SpotAnalysisListSection` + `SpotAnalysisCard` | 同一ファイル内 |
| コメント | `commentSection` / `commentRow` | 同一ファイル内 |

### Phase 2: スポット分析カード（SpotAnalysisCard）
**ファイル**: `ios_watchme_v9/SimpleDashboardView.swift`内（L1137-1247）

ダッシュボードとAnalysisListViewの両方で使用される共通カード。
ここのデザインを変えるとダッシュボードと分析一覧の両方に反映される。

### Phase 3: 分析詳細画面（SpotDetailView）
**ファイル**: `ios_watchme_v9/DetailViews/SpotDetailView.swift`（~317行）

| セクション | 内容 |
|-----------|------|
| Vibeスコア | 数値表示 |
| シーンマッピング | 5カテゴリ（participants等） |
| 概要 | summary テキスト |
| 分析 | analysis テキスト |
| 行動 / 感情 | behavior / emotion テキスト |
| DATA | STT / SED / SER 折りたたみ |

### Phase 4: 分析一覧画面（AnalysisListView）
**ファイル**: `ios_watchme_v9/SimpleDashboardView.swift`内（L1250-1447）

フィルター/ソートUI + SpotAnalysisCardのリスト表示。

### Phase 5: その他の共通コンポーネント
- `ModernVibeCard` — Vibeグラフ
- `LargeDateSection` / `StickyDateHeader` — 日付表示
- `UnifiedCard` — 汎用カードラッパー
- `SkeletonView` — ローディング表示
- カラー定義（`Color.safeColor()`）

---

## 未決定事項（次セッションで決める）

- [ ] 全体の雰囲気・トーン（ミニマル / カードリッチ / やわらかい / モダンダーク）
- [ ] カラースキーム（現在の紫維持 / 変更）
- [ ] 一番目立たせたいセクション
- [ ] 現状で一番気になるポイント
- [ ] 参考にしたいアプリやデザイン

---

## 切り戻し方法

```bash
# リニューアルが不要になった場合
git checkout main

# 一部だけ取り込みたい場合
git checkout main
git cherry-pick <commit-hash>

# リニューアルを採用する場合
git checkout main
git merge redesign/dashboard
```

---

## 変更ログ

| 日付 | 内容 |
|------|------|
| 2026-03-09 | 計画作成、ブランチ `redesign/dashboard` 作成 |
