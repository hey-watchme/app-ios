# Behavior Event Translation Guide

行動イベントラベルの日本語翻訳ガイド

最終更新: 2025-12-02

---

## 📋 概要

APIから取得した英語のイベントラベル（"Speech", "Music"など）を、アプリ内で日本語表示するための仕組みです。

### 設計方針

- **シンプル**: Enum + computed property（感情分析と同じ方式）
- **疎結合**: モデル変更時は新しいEnumを追加するだけ
- **自動翻訳**: データ取得後、追加コード不要で自動的に日本語化

---

## 🎯 使い方

### UI側での使用

```swift
// ❌ 英語のまま表示
Text(event.event)  // "Speech"

// ✅ 日本語で表示
Text(event.displayName)  // "会話"
```

**それだけです。** 他に何もする必要はありません。

---

## 🔧 実装の仕組み

### 1. Enum定義（`BehaviorReport.swift`）

```swift
enum BehaviorEventType: String {
    case speech = "Speech"
    case music = "Music"
    case laughter = "Laughter"
    // ...

    var displayName: String {
        switch self {
        case .speech: return "会話"
        case .music: return "音楽"
        case .laughter: return "笑い声"
        // ...
        }
    }
}
```

### 2. BehaviorEvent に computed property

```swift
struct BehaviorEvent: Codable {
    let event: String  // API from: "Speech"

    var displayName: String {
        BehaviorEventType(rawValue: event)?.displayName ?? event
    }
}
```

### 3. 未定義ラベルは英語のまま表示

翻訳リストにないラベルは自動的に英語で表示されます（fallback）。

---

## 📝 翻訳リストのメンテナンス

### 新しいラベルを追加する手順

#### 1. `BehaviorReport.swift` を開く

```
ios_watchme_v9/Models/BehaviorReport.swift
```

#### 2. `BehaviorEventType` に case を追加

```swift
enum BehaviorEventType: String {
    // 既存のcase...
    case newEvent = "NewEventName"  // ← 追加
}
```

#### 3. `displayName` に翻訳を追加

```swift
var displayName: String {
    switch self {
    // 既存のcase...
    case .newEvent: return "新しいイベント"  // ← 追加
    }
}
```

#### 4. ビルドして確認

Xcodeでビルド（Cmd+B）→ 実行して動作確認

---

## 🔄 モデル変更時の対応

### 新しいモデル（例：YamNet）に対応

#### オプション1: 同じEnumに追加（推奨）

ラベル名が同じなら、何もしなくてOK：

```swift
// AST: "Speech" → "会話"
// YamNet: "Speech" → "会話" (そのまま使える)
```

#### オプション2: 新しいEnumを作成

ラベル名が大きく異なる場合：

```swift
// BehaviorReport.swift に追加

enum YamNetEventType: String {
    case voice = "Voice"  // YamNet固有のラベル
    // ...

    var displayName: String {
        switch self {
        case .voice: return "声"
        // ...
        }
    }
}

// BehaviorEvent で切り替え
var displayName: String {
    // モデルバージョンに応じて切り替え
    if isYamNetModel {
        return YamNetEventType(rawValue: event)?.displayName ?? event
    } else {
        return BehaviorEventType(rawValue: event)?.displayName ?? event
    }
}
```

---

## 📊 現在の翻訳リスト（AST v2.1対応）

### よく検出されるイベント

| 英語 | 日本語 |
|------|--------|
| Speech | 会話 |
| Music | 音楽 |
| Laughter | 笑い声 |
| Crying | 泣き声 |
| Dog | 犬 |
| Cat | 猫 |
| Water | 水の音 |
| Cutlery and kitchenware | 食器・調理音 |
| Child speech | 子供の声 |
| Vehicle | 車両 |
| Engine | エンジン音 |
| Machine | 機械音 |

### 身体音

| 英語 | 日本語 |
|------|--------|
| Cough | 咳 |
| Sneeze | くしゃみ |
| Snoring | いびき |
| Breathing | 呼吸音 |

### その他

| 英語 | 日本語 |
|------|--------|
| Walk, footsteps | 足音 |
| Clapping | 拍手 |
| Tick-tock | 時計の音 |
| Silence | 静寂 |
| Door | ドア |

**全23種類のよく使われるラベルを実装済み**

詳細は `Models/BehaviorReport.swift` の `BehaviorEventType` を参照。

---

## 🎨 感情分析との比較

### 感情分析（`EmotionReport.swift`）

```swift
enum EmotionType: String {
    case joy = "Joy"

    var displayName: String {
        switch self {
        case .joy: return "喜び"
        }
    }
}
```

### 行動分析（`BehaviorReport.swift`）

```swift
enum BehaviorEventType: String {
    case speech = "Speech"

    var displayName: String {
        switch self {
        case .speech: return "会話"
        }
    }
}
```

**完全に独立** - 感情分析のコードには一切影響しません。

---

## 🔍 トラブルシューティング

### 問題1: 英語のまま表示される

**原因**: 翻訳リストにラベルが登録されていない

**解決策**:
1. `BehaviorReport.swift` を開く
2. `BehaviorEventType` に該当ラベルを追加
3. ビルドして確認

### 問題2: 新しいラベルが増えすぎる

**対応**:
- よく使われる20-30種類だけ登録すればOK
- 未登録ラベルは英語のまま表示（問題なし）
- 必要に応じて徐々に追加

### 問題3: モデル変更後に翻訳がおかしい

**対応**:
- 新しいモデル用のEnumを追加
- 古いEnumは削除せず残す（互換性維持）
- モデルバージョンで切り替える仕組みを追加

---

## ✅ 次のステップ

1. **UI側を修正**
   - `event.event` → `event.displayName` に変更
   - `BehaviorGraphView.swift`
   - `SimpleDashboardView.swift`

2. **動作確認**
   - アプリをビルド
   - Behavior Report画面で日本語表示を確認

3. **新しいラベルの追加**（必要に応じて）
   - よく検出されるラベルを徐々に追加

---

## 📚 関連ファイル

- `Models/BehaviorReport.swift` - 翻訳Enum定義
- `BehaviorGraphView.swift` - 表示部分
- `SimpleDashboardView.swift` - 表示部分
- API側: `event_filter_config.py` - フィルタリング・統合設定

---

## 💡 設計の利点

### ✅ シンプル

- Enum + computed property だけ
- データ取得時の追加コード不要
- Factory, Protocol, Cache 不要

### ✅ 疎結合

- 翻訳ロジックはモデル内に完結
- UI側は `displayName` を使うだけ
- モデル変更時は新しいEnumを追加

### ✅ 保守性

- 翻訳リストは1箇所に集約
- コンパイル時にチェック（タイポ防止）
- 未登録ラベルは英語で表示（クラッシュしない）

---

## 📞 メンテナンスチェックリスト

### 新しいラベル追加時

- [ ] `BehaviorEventType` に case を追加
- [ ] `displayName` に翻訳を追加
- [ ] ビルド確認
- [ ] 動作確認

### モデル変更時

- [ ] 新しいモデル用のEnumを作成
- [ ] 古いEnumは残す（削除しない）
- [ ] モデルバージョンで切り替える仕組みを検討
- [ ] 動作確認

### 定期メンテナンス

- [ ] よく検出されるラベルをログで確認
- [ ] 未登録ラベルで頻出するものを追加
- [ ] 不要なラベルを削除（API側でフィルタリング済み）
