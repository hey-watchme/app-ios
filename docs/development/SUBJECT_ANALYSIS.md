# 観測対象の分析機能

最終更新: 2025-12-04

---

## 📋 概要

観測対象ページでは、音声メタ情報から推定される認知スタイル・神経機能・知性の形式を視覚化するための分析機能を将来的に追加予定です。

**現在のステータス**: 一旦非表示（データベース構造のみ実装済み）

---

## 🎯 実装済みの内容（非表示中）

### 1. データベース構造

**subjects テーブル:**
- `cognitive_type` カラムを追加（TEXT型）
- 10種類の認知タイプ値を定義

**認知タイプの値一覧:**

| カテゴリ | タイプ | データベース値 |
|---------|--------|---------------|
| 🎧 感覚系 | 敏感型 | `sensory_sensitive` |
| 🎧 感覚系 | 鈍感型 | `sensory_insensitive` |
| 🧠 認知系 | 分析型 | `cognitive_analytical` |
| 🧠 認知系 | 直感型 | `cognitive_intuitive` |
| 💬 言語系 | 表出型 | `verbal_expressive` |
| 💬 言語系 | 内省型 | `verbal_introspective` |
| ⚡ 行動系 | 衝動型 | `behavioral_impulsive` |
| ⚡ 行動系 | 熟考型 | `behavioral_deliberate` |
| ❤️ 情動系 | 安定型 | `emotional_stable` |
| ❤️ 情動系 | 不安定型 | `emotional_unstable` |

### 2. iOSモデル

**Subject.swift:**
- `cognitiveType: String?` プロパティを追加
- `CognitiveTypeOption` Enumで10種類のタイプを定義
- 各タイプに絵文字、カテゴリ名、傾向名、説明文を定義

### 3. UI実装（コメントアウト済み）

**SubjectTabView.swift:**
- カルーセル型タイプ選択UI（左右スワイプで10種類を閲覧）
- タイプ選択ボタン
- 選択後のカード表示

**SubjectRegistrationView.swift:**
- タイプ選択用のプルダウンメニュー

### 4. データ管理

**SupabaseDataManager.swift:**
- `registerSubject`と`updateSubject`にcognitiveTypeパラメータを追加
- データベースへの保存・更新機能を実装

---

## 🔮 将来の実装予定

### Phase 2: データ統合（時期未定）

現在のWatchMeデータから分析結果を生成する方法を検討中：

#### オプション1: LLMによる推定
- Daily/Weeklyデータから認知スタイルをLLMで推定
- メリット: 既存データで実装可能
- デメリット: 科学的根拠が薄い

#### オプション2: 音声メタ情報の拡張
- 話速、間、音量変動などの新しいAPIを追加
- メリット: より正確な分析が可能
- デメリット: 開発期間が長い（数週間〜数ヶ月）

#### オプション3: 自己申告ヒアリング（最も現実的）
- ユーザー（保護者または本人）が選択
- 選択されたタイプをLLM分析のプロンプトに追加
- メリット: すぐに実装可能、ユーザーの直感を活用
- デメリット: 客観性に欠ける

### 将来追加予定の分析セクション

1. **神経機能モデル（レーダーチャート）**
   - 注意制御、実行機能、ワーキングメモリ、感情制御、発想流動性
   - 5つの機能を五角形レーダーチャートで表示

2. **知性の形式モデル（多重知能理論）**
   - 言語的、論理数学的、空間的、身体運動的、音楽的、対人的、内省的、博物的、存在的知性
   - 9つの知性領域を横棒グラフで表示

---

## 📂 関連ファイル

### 実装済み（コメントアウト中）
- `ios_watchme_v9/ios_watchme_v9/Models/Subject.swift` - データモデル、Enum定義
- `ios_watchme_v9/ios_watchme_v9/SubjectTabView.swift` - 観測対象ページUI
- `ios_watchme_v9/ios_watchme_v9/SubjectRegistrationView.swift` - プロフィール編集画面
- `ios_watchme_v9/ios_watchme_v9/SupabaseDataManager.swift` - データ管理

### ドキュメント
- `ios_watchme_v9/docs/development/SUBJECT_ANALYSIS.md` - このファイル

---

## 🔧 開発再開時の手順

### タイプ選択UIを再表示する場合

1. **SubjectTabView.swift の127-130行目をアンコメント**
   ```swift
   // 認知タイプセクション - 一旦非表示
   cognitiveTypeSection  // ← コメント解除
       .padding(.horizontal, 20)
       .padding(.top, 20)
   ```

2. **SubjectRegistrationView.swift の369-405行目をアンコメント**
   ```swift
   // Cognitive Type (optional) - 一旦非表示
   VStack(alignment: .leading, spacing: 8) {  // ← コメント解除
       // ...
   }
   ```

3. **ビルド確認**
   ```bash
   xcodebuild -scheme ios_watchme_v9 -sdk iphonesimulator build
   ```

---

## 📝 開発履歴

### 2025-12-04
- データベースに`cognitive_type`カラムを追加
- iOSモデルに`CognitiveTypeOption` Enumを実装
- カルーセル型タイプ選択UIを実装
- プロフィール編集画面にプルダウンを追加
- 神経機能モデルと知性の形式モデルのセクションを非表示化
- **全ての分析セクションを一旦非表示に変更**

---

## 🎯 今後の方針

1. **まずはプロフィール情報のみでリリース**
   - 名前、年齢、性別、地域、メモのみ表示

2. **分析機能は段階的に追加**
   - データ蓄積と分析設計を並行して進める
   - ユーザーフィードバックを元に優先度を決定

3. **LLM分析への統合**
   - タイプ情報をProfiler APIのプロンプトに追加
   - より個別化された分析を実現
