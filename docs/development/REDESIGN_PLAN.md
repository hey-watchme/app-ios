# ダッシュボード デザインリニューアル計画

**ブランチ**: `redesign/dashboard`
**ベース**: `main` @ `52b8c27`（STT/SED修正済み）
**作成日**: 2026-03-09
**ステータス**: 実装継続中（ダーク統一・動画背景・トースト調整まで反映済み）

---

## 再開時のコンテキスト（次セッション用）

**ここから再開する場合:**
1. ブランチ `redesign/dashboard` で作業中
2. Oura Ring風ダークテーマの実装は完了済み
3. ビルドエラー修正後の再ビルドは成功済み（`xcodebuild -scheme ios_watchme_v9 -sdk iphonesimulator build`）
4. **次にやること**: 主要フローの実機/シミュレータ確認（動画復帰、トースト表示、シート可読性）→ 必要に応じて微調整

**関連ファイル**: `ios_watchme_v9/SimpleDashboardView.swift`, `ios_watchme_v9/Color+AppColors.swift`, `ios_watchme_v9/DashboardMetricsBar.swift`, `ios_watchme_v9/ModernVibeCard.swift`, `ios_watchme_v9/DetailViews/SpotDetailView.swift`, `ios_watchme_v9/UnifiedCard.swift`, `ios_watchme_v9/SkeletonView.swift`, `ios_watchme_v9/GraphEmptyStateView.swift`, `ios_watchme_v9/DateComponents.swift`, `ios_watchme_v9/AuthFlowView.swift`, `ios_watchme_v9/ios_watchme_v9App.swift`, `ios_watchme_v9/Components/LoopingVideoBackgroundView.swift`, `ios_watchme_v9/Services/ToastManager.swift`, `ios_watchme_v9/AccountSettingsView.swift`, `ios_watchme_v9/UserInfoView.swift`, `ios_watchme_v9/AboutAppView.swift`, `ios_watchme_v9/TermsOfServiceView.swift`, `ios_watchme_v9/PrivacyPolicyView.swift`, `ios_watchme_v9/FeedbackFormView.swift`, `ios_watchme_v9/UpgradeAccountView.swift`

**このドキュメント**: `app/ios-watchme/docs/development/REDESIGN_PLAN.md`

---

## 実施状況（2026-03-11 更新）

- [x] Phase 1-5 の実装完了
- [x] ビルドを試行 → エラー発生
- [x] ビルドエラー修正を適用:
  - `.foregroundStyle(.accentTeal)` → `.foregroundStyle(Color.accentTeal)` に5箇所修正
  - `AnalysisListView` の `body` を `filterControls` / `listContent` に分割（type-check タイムアウト解消）
- [x] ビルド成功確認（`xcodebuild -scheme ios_watchme_v9 -sdk iphonesimulator build`）
- [x] 初期画面（「始める」「ログイン」）の背景動画対応（ミュート・ループ）
- [x] 動画再表示時の停止対策（画面再オープン時の再生復帰処理）
- [x] アカウント関連シートの可読性改善（ダーク背景に対する文字コントラスト統一）
- [x] トーストのデザイン統一（白背景からダークガラス調カードへ）
- [ ] 実機での最終動作確認（動画の初回表示タイミング・操作遷移時の体感）

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
| `ios_watchme_v9/AuthFlowView.swift` | 部分変更 | 初期画面背景を動画化（ミュート・ループ） |
| `ios_watchme_v9/Components/LoopingVideoBackgroundView.swift` | 新規追加 | 再利用可能なループ動画背景コンポーネント |
| `ios_watchme_v9/Resources/Videos/Zooming_out_rotating_camera_59a4c0497a.mp4` | 新規追加 | 初期画面用の背景動画素材 |
| `ios_watchme_v9/Services/ToastManager.swift` | 部分変更 | トーストの配色/背景/進捗バーをダークトーンへ統一 |
| `ios_watchme_v9/AccountSettingsView.swift` | 部分変更 | アカウント設定のリスト/シートのダーク統一 |
| `ios_watchme_v9/AboutAppView.swift` / `ios_watchme_v9/TermsOfServiceView.swift` / `ios_watchme_v9/PrivacyPolicyView.swift` / `ios_watchme_v9/FeedbackFormView.swift` / `ios_watchme_v9/UpgradeAccountView.swift` | 部分変更 | アカウント配下シートの可読性改善・ダーク統一 |

---

## 未対応・今後の検討

- [x] InteractiveTimelineView のダーク対応（グラフ線・バースト表示の色調整）
- [x] タブバー（フッター）のダーク化（`ios_watchme_v9App.swift` / `CustomFooterNavigation`）
- [x] 録音画面・設定画面のダーク化
- [x] レポート画面のダーク化
- [x] 初期ログイン画面・オンボーディングのダーク化（`AuthFlowView.swift` / `initialView`）
- [x] 初期画面（`AuthFlowView`）の背景動画化（ループ・ミュート）
- [x] アカウント関連シート（about/terms/privacy/feedback/upgrade）のダーク可読性調整
- [x] トースト（分析完了/送信中/完了）のダークトーン統一
- [ ] カラーをAssets.xcassetsに移行（現在はfallback直接使用）
- [ ] ダークモードのシステム連動（現在は常にダーク）
- [ ] 動画の初回表示タイミング最適化（必要であればプリウォームを検討）

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
| **2026-03-11** | **初期画面背景を動画化（`LoopingVideoBackgroundView` + mp4追加）、再表示時の再生復帰を改善** |
| **2026-03-11** | **アカウント配下シート（about/terms/privacy/feedback/upgrade）と設定画面の文字コントラストを調整し、全体をダークトーンに統一** |
| **2026-03-11** | **トースト（分析完了/送信中/完了）を白背景からダークガラス調へ変更し、アクセント色を統一** |
| **2026-03-11** | **`xcodebuild -scheme ios_watchme_v9 -sdk iphonesimulator build` でビルド成功を確認** |
