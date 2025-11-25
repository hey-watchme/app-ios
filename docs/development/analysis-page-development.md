# 分析ページ開発ドキュメント

## 概要

分析ページは、音声メタ情報から推定される認知スタイル・神経機能・知性の形式を視覚化するための新機能です。

**開発ブランチ**: `feature/analysis-page`

---

## 実装内容（Phase 1: UI実装）

### 1. ナビゲーション構造の変更

**フッターナビゲーション**を以下のように変更しました：

- **変更前**: ホーム、マイページ
- **変更後**: レポート、分析、観測対象

**ヘッダー**にマイページボタンを追加：
- 通知ベルの左側に人型アイコンを配置

### 2. 分析ページのUI実装

#### 2.1 認知スタイル表示
- ⚡ **行動系**を最も当てはまるスタイルとして表示
- 大きな絵文字、タイトル、傾向（衝動型/熟考型）、説明文を含むカード形式
- タイトル「認知スタイルモデル」は非表示

#### 2.2 神経機能モデル（レーダーチャート）
- **五角形のレーダーチャート**で視覚化
- 5つの機能を表示：
  - 🎯 注意制御（青）
  - 🧭 実行機能（緑）
  - ⚙️ ワーキングメモリ（オレンジ）
  - ❤️ 感情制御（赤）
  - 🌈 発想流動性（紫）
- インフォメーションアイコンで説明を提供
- カラフルな凡例を追加

#### 2.3 知性の形式モデル（多重知能理論）
- 9つの知性領域を横棒グラフで表示：
  - 言語的知性
  - 論理数学的知性
  - 空間的知性
  - 身体運動的知性
  - 音楽的知性
  - 対人的知性
  - 内省的知性
  - 博物的知性
  - 存在的知性
- インフォメーションアイコンで説明を提供

### 3. 観測対象タブの実装

- デバイスに紐づく観測対象（Subject）の情報を表示
- プロフィール写真、名前、年齢、性別、メモを表示
- 編集ボタンから`SubjectRegistrationView`を開く
- 観測対象未設定時は登録を促すガイドを表示

---

## 今後の開発（Phase 2: データ統合）

### 目標
**現在取得できているデータから、認知モデルの分析結果を実際に表示する**

### 必要な作業

#### 1. データ分析基盤の構築
現在のWatchMeシステムでは以下のデータが利用可能：
- 音声メタ情報（話速、間、声の高さ、音量など）
- 音響イベント検出（SED）データ
- 音声文字起こし（Whisper）データ
- 感情分析データ

これらのデータを統合し、以下のモデルを推定する分析ロジックを構築：

##### 1.1 認知スタイルモデルの推定
音声メタ情報から以下を推定：
- 🎧 **感覚系**: 音量・声の高さの変動から敏感度を推定
- 🧠 **認知系**: 話速・間のパターンから思考スタイルを推定
- 💬 **言語系**: 発話量・間の長さから表出型/内省型を判定
- ⚡ **行動系**: 発話開始の速度・間の短さから衝動型/熟考型を判定
- ❤️ **情動系**: 音声の感情値の変動幅から感情の安定性を推定

##### 1.2 神経機能モデルの推定
音声・行動パターンから以下を推定：
- 🎯 **注意制御**: 発話の一貫性、雑音への反応
- 🧭 **実行機能**: 計画的な発話、話題の展開
- ⚙️ **ワーキングメモリ**: 複雑な文章の使用、情報の保持
- ❤️ **感情制御**: 感情値の変動パターン、衝動的な発話
- 🌈 **発想流動性**: 話題の多様性、連想の豊かさ

##### 1.3 知性の形式モデルの推定
音声・文字起こしデータから以下を推定：
- **言語的知性**: 語彙の豊富さ、文章の複雑さ
- **論理数学的知性**: 論理的な構造、因果関係の説明
- **空間的知性**: 空間に関する表現の使用
- **身体運動的知性**: 身体動作に関する言及
- **音楽的知性**: リズム感、音楽に関する言及
- **対人的知性**: 他者への配慮、共感的な発話
- **内省的知性**: 自己言及、内省的な発話
- **博物的知性**: パターン認識、分類的な思考
- **存在的知性**: 抽象的・哲学的な思考

#### 2. データベース設計

新しいテーブルを作成：

##### `cognitive_analysis` テーブル
```sql
CREATE TABLE cognitive_analysis (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT REFERENCES devices(device_id) ON DELETE CASCADE,
    analysis_date DATE NOT NULL,

    -- 認知スタイル（主要）
    primary_cognitive_style TEXT, -- 'sensory', 'cognitive', 'verbal', 'behavioral', 'emotional'
    cognitive_style_label TEXT, -- '衝動型', '熟考型' など
    cognitive_style_description TEXT,

    -- 認知スタイル詳細（0.0-1.0）
    sensory_sensitivity NUMERIC(3,2),
    cognitive_style NUMERIC(3,2),
    verbal_expression NUMERIC(3,2),
    behavioral_tempo NUMERIC(3,2),
    emotional_stability NUMERIC(3,2),

    -- 神経機能（0.0-1.0）
    attention_control NUMERIC(3,2),
    executive_function NUMERIC(3,2),
    working_memory NUMERIC(3,2),
    emotion_regulation NUMERIC(3,2),
    creative_fluidity NUMERIC(3,2),

    -- 知性の形式（0.0-1.0）
    linguistic_intelligence NUMERIC(3,2),
    logical_mathematical_intelligence NUMERIC(3,2),
    spatial_intelligence NUMERIC(3,2),
    bodily_kinesthetic_intelligence NUMERIC(3,2),
    musical_intelligence NUMERIC(3,2),
    interpersonal_intelligence NUMERIC(3,2),
    intrapersonal_intelligence NUMERIC(3,2),
    naturalistic_intelligence NUMERIC(3,2),
    existential_intelligence NUMERIC(3,2),

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(device_id, analysis_date)
);

-- インデックス
CREATE INDEX idx_cognitive_analysis_device_date ON cognitive_analysis(device_id, analysis_date DESC);
```

##### RPC関数の作成
```sql
-- 最新の分析結果を取得
CREATE OR REPLACE FUNCTION get_latest_cognitive_analysis(p_device_id TEXT)
RETURNS TABLE (
    -- 全カラムを返す
) AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM cognitive_analysis
    WHERE device_id = p_device_id
    ORDER BY analysis_date DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### 3. バックエンド分析処理の実装

新しいマイクロサービスまたは既存サービスの拡張：

##### 3.1 分析エンドポイントの追加
`/api/analysis/cognitive-profile` エンドポイントを作成し、以下を実行：
1. 指定期間の音声データを取得
2. 特徴量を抽出
3. 機械学習モデルまたはルールベースで分析
4. `cognitive_analysis`テーブルに保存

##### 3.2 定期実行
Lambda関数またはcronで日次バッチ処理：
- 各デバイスの前日データを分析
- 分析結果をデータベースに保存

#### 4. iOS側の実装

##### 4.1 DataManagerの拡張
```swift
// SupabaseDataManager.swift に追加
func fetchCognitiveAnalysis(deviceId: String) async -> CognitiveAnalysis? {
    // Supabase RPC関数を呼び出し
    // 最新の分析結果を取得
}
```

##### 4.2 AnalysisViewの更新
- 静的データをAPIから取得したデータに置き換え
- ローディング状態の追加
- エラーハンドリングの追加

---

## 開発の優先順位

### 必須（価値提供のための最低限）
1. ✅ **Phase 1**: UI実装（完了）
2. ⏳ **Phase 2**: データ統合
   - データベース設計
   - 分析ロジックの実装
   - iOS側のデータ取得実装

### 将来的な拡張
- 時系列での変化のグラフ表示
- 他の観測対象との比較
- AIによる推奨アクション

---

## 技術スタック

### フロントエンド（iOS）
- SwiftUI
- カスタムレーダーチャート実装
- Supabase Swift SDK

### バックエンド
- Python (FastAPI) - 分析処理
- PostgreSQL (Supabase) - データ保存
- AWS Lambda - バッチ処理

### 分析手法
- 音声特徴量抽出（既存のWhisper/SED APIを活用）
- ルールベース分析（初期実装）
- 機械学習モデル（将来的な拡張）

---

## 関連ファイル

### 新規作成
- `ios_watchme_v9/AnalysisView.swift` - 分析ページUI
- `ios_watchme_v9/SubjectTabView.swift` - 観測対象タブ
- `ios_watchme_v9/docs/analysis-page-development.md` - このドキュメント

### 変更ファイル
- `ios_watchme_v9App.swift` - フッターナビゲーション変更
- `HeaderView.swift` - マイページボタン追加
- `ContentView.swift` - マイページ表示制御追加

---

## 注意事項

### データプライバシー
- 認知スタイルの分析結果は機密性が高い
- 本人のみが閲覧可能なように権限制御を徹底
- データの保存期間・削除ポリシーを明確化

### 倫理的配慮
- 分析結果はあくまで「推定」であり、決定的なものではないことを明示
- ラベリングによる偏見を助長しないよう、説明文に配慮
- 「弱み」ではなく「特性」として中立的に表現

---

## 開発者向けメモ

### ブランチ運用
- **feature/analysis-page**: 分析ページ機能の開発
- **main**: 安定版
- Phase 2完了後にmainにマージ

### デプロイ戦略
1. Phase 1: UIのみ（静的データ）→ TestFlightでテスト
2. Phase 2: データ統合 → 段階的ロールアウト
3. フィードバック収集 → 改善イテレーション

---

最終更新: 2025-10-26
開発者: Claude (AI Assistant)
