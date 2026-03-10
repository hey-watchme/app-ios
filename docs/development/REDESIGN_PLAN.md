# ダッシュボード デザインリニューアル計画

**ブランチ**: `redesign/dashboard`
**ベース**: `main` @ `52b8c27`（STT/SED修正済み）
**作成日**: 2026-03-09
**ステータス**: 実装済み・ビルド修正中

---

## 再開時のコンテキスト（次セッション用）

**ここから再開する場合:**
1. ブランチ `redesign/dashboard` で作業中
2. Oura Ring風ダークテーマの実装は完了済み
3. ビルドエラーが出たため修正を適用済み（下記「実施状況」参照）
4. **次にやること**: ビルド成功確認 → 動作確認 → 必要に応じて追加修正

**関連ファイル**: `ios_watchme_v9/SimpleDashboardView.swift`, `Color+AppColors.swift`, `DashboardMetricsBar.swift`, `ModernVibeCard.swift`, `DetailViews/SpotDetailView.swift`, `UnifiedCard.swift`, `SkeletonView.swift`, `GraphEmptyStateView.swift`, `DateComponents.swift`

**このドキュメント**: `app/ios-watchme/docs/development/REDESIGN_PLAN.md`

---

## 実施状況（2026-03-10）

- [x] Phase 1-5 の実装完了
- [x] ビルドを試行 → エラー発生
- [x] ビルドエラー修正を適用:
  - `.foregroundStyle(.accentTeal)` → `.foregroundStyle(Color.accentTeal)` に5箇所修正
  - `AnalysisListView` の `body` を `filterControls` / `listContent` に分割（type-check タイムアウト解消）
- [ ] ビルド成功確認（未実施）
- [ ] 動作確認（未実施）
- [ ] 引き続き修正（必要に応じて）

---

## 概要

SimpleDashboardView（メイン画面）を起点としたデザインリニューアル。
一番ユーザーの目に触れる画面から段階的に改善していく。

## デザイン方針（2026-03-10 決定）

**方向性**: Oura Ring風のカッティングエッジ・ヘルステック
- **ダークトーン**（ほぼ黒の背景 #0D0D12）で信頼性・機能の高さを表現
- **データが主役** — グラフ、数値、ゲージがデザインのアクセント
- **装飾なし** — 情報密度そのものが質感
- **ティール/シアン (#00D4AB)** をプライマリアクセントに
- **アンバー (#E8A838)** をウォーニング系に
- **コーラル (#FF6B6B)** をエラー/ネガティブ系に

### 参考
- Oura Ring App redesign 2026
- `docs/idea/the-oura-ring-app-is-getting-a-redesign-with-cumulative-stre_r4ue.2496.webp`

---

## 対象画面と優先度

### Phase 1: メインダッシュボード（SimpleDashboardView）✅ 実装済み
**ファイル**: `ios_watchme_v9/SimpleDashboardView.swift`（~1500行）

| セクション | 現状のコンポーネント | 変更内容 |
|-----------|-------------------|---------|
| 日付セクション | `LargeDateSection` / `StickyDateHeader` | ダーク背景化 |
| **メトリクスバー** | **`DashboardMetricsBar` (NEW)** | **Oura風スコアピル（Vibe/Stress/Focus/Activity）** |
| Vibeグラフカード | `ModernVibeCard` | ダーク化、大数値+ミニリングゲージ |
| **ストレスゲージ** | **`StressGaugeCard` (NEW)** | **水平ゲージバー+サブメトリクス** |
| 最新情報 | `SpotAnalysisListSection` + `SpotAnalysisCard` | ダーク化、タグピル化 |
| ハイライト | `SpotAnalysisListSection` + `SpotAnalysisCard` | 同上 |
| コメント | `commentSection` / `commentRow` | ダーク化 |

### Phase 2: スポット分析カード（SpotAnalysisCard）✅ 実装済み
ダッシュボードとAnalysisListViewの両方で使用される共通カード。
- ダークカード背景
- タグピル化（行動=ティール、感情=アンバー）
- 内部ディバイダーで構造化

### Phase 3: 分析詳細画面（SpotDetailView）✅ 実装済み
- リングゲージ+水平バーのVibeスコア表示
- ダークカード
- DisclosureGroupのダーク化

### Phase 4: 分析一覧画面（AnalysisListView）✅ 実装済み
- ダーク背景
- フィルター/ソートUIのダーク化

### Phase 5: その他の共通コンポーネント ✅ 実装済み
- `ModernVibeCard` — ダークテーマ
- `UnifiedCard` — ダークサーフェス
- `SkeletonView` — ダークスケルトン
- `GraphEmptyStateView` — ダークempty state
- `Color+AppColors.swift` — 全カラーパレットのダーク化

---

## 変更ファイル一覧

| ファイル | 変更種別 | 内容 |
|---------|---------|------|
| `Color+AppColors.swift` | 全面書き換え | ダークパレット、safeColor()でfallback直接使用 |
| `DashboardMetricsBar.swift` | 新規→強化 | Oura風メトリクスピル（最適範囲アーク、アイコン）、StressGaugeCard（Vitals風範囲ゾーン）、**DailyActivityOverviewCard**（比較バー、Supported areas ピル） |
| `SimpleDashboardView.swift` | 大幅変更 | 背景ダーク化、メトリクスバー追加、DailyActivityOverviewCard追加、SpotAnalysisCard強化（ミニゲージ、タグアイコン） |
| `ModernVibeCard.swift` | 全面書き換え→強化 | ダーク化、大数値ヒーロー、ミニリングゲージ、**モチベーションメッセージ**、**背景グラデーション** |
| `UnifiedCard.swift` | 全面書き換え | ダークサーフェス |
| `SpotDetailView.swift` | 全面書き換え | ダーク化、リングゲージ、水平バー |
| `SkeletonView.swift` | 全面書き換え | ダークスケルトン |
| `GraphEmptyStateView.swift` | 全面書き換え | ダークempty state |
| `DateComponents.swift` | 部分変更 | 背景色ダーク化 |

---

## 未対応・今後の検討

- [x] InteractiveTimelineView のダーク対応（グラフ線・バースト表示の色調整）
- [x] タブバー（フッター）のダーク化（`ios_watchme_v9App.swift` / `CustomFooterNavigation`）
- [x] 録音画面・設定画面のダーク化
- [x] レポート画面のダーク化
- [x] 初期ログイン画面・オンボーディングのダーク化（`AuthFlowView.swift` / `initialView`）
- [ ] カラーをAssets.xcassetsに移行（現在はfallback直接使用）
- [ ] ダークモードのシステム連動（現在は常にダーク）

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
| 2026-03-10 | Oura Ring風ダークテーマ実装（Phase 1-5 完了） |
| 2026-03-10 | ビルド試行 → エラー発生 → 修正適用（accentTeal型推論、AnalysisListView型チェック） |
| 2026-03-10 | 細部のディテール強化: DashboardMetricsBar（最適範囲アーク、アイコン）、StressGaugeCard（Vitals風範囲ゾーン）、ModernVibeCard（モチベーションメッセージ、背景グラデーション）、DailyActivityOverviewCard（比較バー、Supported areas ピル）、SpotAnalysisCard（ミニゲージ、タグアイコン） |
| 2026-03-10 | 質感強化: ModernVibeCard（多層グラデーション 0.12→0.04、RadialGlow、グラデーション枠線、シャドウ）、全カード（LinearGradient枠線、ドロップシャドウ）、背景（縦方向アンビエントグラデーション）、モチベーションバナー（グラデーション背景） |
| **2026-03-10** | **全面ダークテーマ統一: アプリ内の全白背景コンポーネント（InfoViews, UserInfoView, DeviceSettingsView, NotificationView等）をダーク化** |
| **2026-03-10** | **初期画面・フッター修正: `ios_watchme_v9App.swift` に直書きされていた `initialView` 及び `CustomFooterNavigation` をダーク化、古い `AccountSelectionView` を削除して `AuthFlowView` をダーク化し、全ての画面の統一を完了** |
