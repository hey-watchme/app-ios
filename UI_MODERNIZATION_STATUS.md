# 🎨 UI モダナイゼーション実装状況（2025年1月14日更新）

## 📌 現在の実装状況

### ✅ 完了した実装（Phase 1-6）

#### **Phase 1-5: 初期実装**（2025/1/13完了）
- ダークテーマ実装 → ライトテーマへ変更
- InteractiveTimelineView（1回再生、ドラッグ可能）
- ParticleEffectView（バーストイベント時のみ）
- 統一カードコンポーネント実装

#### **Phase 6: ライトテーマへの移行**（2025/1/14実施）
- **カラースキーム変更**
  - 背景: #efefef（薄グレー）
  - カード: #ffffff（白）
  - テキスト: #1a1a1a（濃グレー）
  - サブテキスト: #666666（グレー）

- **統一カードシステム**
  - UnifiedCard.swift: 汎用カードコンポーネント
  - ObservationTargetCard.swift: 観測対象専用（紫背景 #6200ff）
  - ModernVibeCard.swift: 気分グラフ用

- **改善実装**
  - 行動カードで「その他」カテゴリを除外
  - バーストパーティクルを中心から放射状に変更（透明度0.4）
  - 感情カードに顔文字表示（😆 😢 😨 など）

### 🚧 現在作業中の内容

#### **新ダッシュボード実装**（feature/unified-designブランチ）
- **NewHomeView.swift作成**
  - 旧DashboardViewと並行運用可能
  - フィーチャーフラグで切り替え（useNewDesign = true）
  - DashboardViewModelを共有

- **日付管理の改善**
  - onChange監視追加
  - forceRefreshData実装
  - キャッシュクリア機能

### ⚠️ 未解決の問題

#### **グラフ同期問題**（部分的に改善）
1. **症状**
   - 日付を切り替えて戻ると、前のグラフが残る場合がある
   - インジケーターとグラフデータがずれる

2. **根本原因（特定済み）**
   - View IDの重複によるView再利用
   - ModernVibeCardのID: `deviceId_date`（同じ日付で同じID）
   - InteractiveTimelineViewの状態が保持される
   - キャッシュヒット時の高速処理でView更新がスキップ

3. **改善済み**
   - resetAndStartPlayback()追加
   - onChange監視実装
   - View IDによる強制再生成

4. **残課題**
   - 完全な解決には追加対策が必要
   - View IDの生成ロジック見直し
   - 明示的なリセットAPI実装

## 🔧 技術仕様

### ファイル構成
```
ios_watchme_v9/
├── NewHomeView.swift            # 新ダッシュボード
├── ModernVibeCard.swift         # ライトテーマの気分カード
├── UnifiedCard.swift            # 統一カードコンポーネント
├── ObservationTargetCard.swift  # 観測対象専用カード
├── InteractiveTimelineView.swift # タイムライン（改善済み）
├── ParticleEffectView.swift     # パーティクル（最適化済み）
├── RippleEffectView.swift       # 波紋・バーストエフェクト
└── HapticManager.swift          # 振動管理
```

### 主要パラメータ（最新）
- **自動再生**: 1回のみ（ループなし）
- **再生速度**: 0.5秒/スロット
- **パーティクル**: バーストイベント時のみ、中心から放射状
- **振動強度**: 0.6（イベント時）
- **バーストパーティクル**: 30個、透明度0.4
- **グラフ透明度**: 0.3（グレー系）

## 🎯 次のステップ

### 優先度高
1. **グラフ同期問題の完全解決**
   - View ID生成ロジックの改善
   - データ変更検知の強化
   - 明示的リセットメソッド

2. **各グラフViewの移行**
   - HomeView → VibeGraphView
   - BehaviorGraphView（統一デザイン適用）
   - EmotionGraphView（統一デザイン適用）

### 優先度中
3. **スワイプ機能追加**
   - ダッシュボードでの日付スワイプ
   - 他Viewと同様の操作性

4. **パフォーマンス最適化**
   - 不要な再レンダリング削減
   - メモリ使用量改善

## 💡 重要な設計決定

### 採用した方針
- **並行運用方式（Plan A）**: 新旧を切り替え可能
- **ライトテーマ基調**: Apple風のクリーンなデザイン
- **統一カードシステム**: コンポーネント再利用
- **最小限のインタラクション**: シンプルな操作性

### コード規約
- 「その他」カテゴリ除外時はコメント必須
- View ID使用時は目的を明記
- キャッシュ処理には動作説明を記載

## 📞 引き継ぎ事項

### 現在のブランチ
- `feature/unified-design`: 作業中
- `feature/behavior-emotion-graphs`: マージ済み

### 環境設定
```swift
// ContentView.swift
private let useNewDesign = true  // 新デザイン有効
```

### 次回作業時の確認事項
1. NewHomeViewでの日付切り替え動作確認
2. グラフ同期問題の再現テスト
3. View ID戦略の見直し

### 未解決の技術的課題
```swift
// 問題のあるコード箇所
// ModernVibeCard.swift line 84
.id("\(vibeReport.deviceId)_\(vibeReport.date)")  // 同じ日付で同じID

// NewHomeView.swift line 112  
.id("\(vibeReport.deviceId)_\(vibeReport.date)_\(Date().timeIntervalSince1970)")  // 常に新しいが効果不完全
```

### 推奨される修正案
1. 日付変更カウンターを導入
2. 明示的なリセットメソッド追加
3. データのハッシュ値でID生成

---
最終更新: 2025年1月14日
コンテキスト切り替えポイント