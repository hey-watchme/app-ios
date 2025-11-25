# 🎨 WatchMeアプリ カラーシステムガイド

最終更新: 2025-10-16

---

## 📋 概要

WatchMeアプリのデザインは、**Apple風のミニマル・フレンドリーなスタイル**を採用しています。

### デザインの基本方針
- **ベースカラー**: モノクロ（白・黒・グレー）
- **アクセントカラー**: 紫（データポイント、選択状態の強調）
- **状態カラー**: 赤（録音ボタン、エラー、通知）
- **トーン**: シンプルでフレンドリー、Appleライクな洗練されたUI

---

## 🎯 カラーパレット

### 1. **プライマリカラー（モノクロベース）**

| カラー名 | 色 | 用途 | コード |
|---------|---|------|--------|
| **PrimaryText** | 黒 | メインテキスト、アイコン | `.primary` (システムカラー) |
| **SecondaryText** | グレー | サブテキスト、説明文 | `.secondary` (システムカラー) |
| **TertiaryText** | 薄いグレー | さらに薄いテキスト | `.tertiary` (システムカラー) |
| **PrimaryBackground** | 白 | メインの背景 | `Color.white` |
| **SecondaryBackground** | 薄いグレー | カード背景、非アクティブ状態 | `Color.gray.opacity(0.1)` |

---

### 2. **アクションカラー（ボタン）**

| カラー名 | 色 | 用途 | iOS定義 |
|---------|---|------|--------|
| **PrimaryActionBackground** | 黒 | アクションボタン背景、トーストバナー背景 | `Color.safeColor("AppAccentColor")` を黒に設定 |
| **PrimaryActionText** | 白 | アクションボタンのテキスト | `Color.white` |
| **SecondaryActionBackground** | グレー | 副次的なボタン背景 | `Color.gray` |
| **SecondaryActionText** | 黒 | 副次的なボタンのテキスト | `Color.primary` |

---

### 3. **アクセントカラー（強調）**

| カラー名 | 色 | 用途 | iOS定義 |
|---------|---|------|--------|
| **AppAccentColor** | 紫 | データポイント、グラフライン、選択状態の強調（※現在は黒だが紫に変更予定） | `Color.safeColor("AppAccentColor")` |
| **VibeChangeIndicatorColor** | 紫 | グラフのバーストイベントマーカー | `Color.safeColor("VibeChangeIndicatorColor")` |
| **TimelineIndicator** | 紫 | タイムラインの現在位置インジケーター | `Color.safeColor("TimelineIndicator")` |

**RGB値**: `Color(red: 0.384, green: 0, blue: 1)` (#6200ff)

---

### 4. **状態カラー（意味を持つ色）**

| カラー名 | 色 | 用途 | iOS定義 |
|---------|---|------|--------|
| **SuccessColor** | 緑 | 成功メッセージ、選択中の状態（チェックマーク） | `Color.safeColor("SuccessColor")` |
| **ErrorColor** | 赤 | エラー表示、録音ボタン、重要な通知 | `Color.safeColor("ErrorColor")` |
| **WarningColor** | オレンジ | 警告メッセージ | `Color.safeColor("WarningColor")` |
| **InfoColor** | 青 | 情報メッセージ | `Color.safeColor("InfoColor")` |

---

## 🖼️ コンポーネント別カラールール

### デバイス選択・設定画面（DeviceCard）

#### **選択中のデバイスカード**
- **背景**: 白 (`Color.white`)
- **トグルボタン**: 緑のチェックマーク (`Color.safeColor("SuccessColor")`)
- **テキスト**: 黒 (`.primary`)
- **アイコン**: 黒
- **枠線**: なし

#### **非選択のデバイスカード**
- **背景**: うっすらグレー (`Color.gray.opacity(0.1)`)
- **トグルボタン**: グレーの丸 (`Color.gray.opacity(0.3)`)
- **テキスト**: 黒 (`.primary`)
- **アイコン**: 黒
- **枠線**: 薄いグレー

---

### トーストバナー（通知）

- **背景**: 黒 (`Color.safeColor("AppAccentColor")` ※現在は黒）
- **テキスト**: 白 (`Color.white`)
- **シャドウ**: `Color.black.opacity(0.1)`

---

### グラフ（心理グラフ、気分カード）

#### **メインライン**
- **色**: 黒 (`Color.safeColor("BehaviorTextPrimary")`)
- **太さ**: 2pt

#### **未来のライン（グレーアウト）**
- **色**: グレー (`Color.gray.opacity(0.3)`)
- **太さ**: 1pt

#### **バーストイベントマーカー**
- **色**: 紫 (`Color.safeColor("VibeChangeIndicatorColor")`)
- **サイズ**: 8pt (Circle)

#### **タイムインジケーター**
- **線の色**: グレー (`Color.gray.opacity(0.5)`)
- **丸の色**: 紫（グラデーション） (`Color.safeColor("TimelineIndicator")`)

---

### ボタン

#### **プライマリボタン（主要アクション）**
- **背景**: 黒
- **テキスト**: 白
- **角丸**: 10-12pt

#### **セカンダリボタン（副次的アクション）**
- **背景**: グレー
- **テキスト**: 黒
- **角丸**: 10-12pt

#### **録音ボタン**
- **アクティブ**: 赤 (`Color.safeColor("ErrorColor")`)
- **非アクティブ**: グレー (`Color.gray`)

---

## 🎨 ダークモード対応

### システムカラーの挙動

| カラー | ライトモード | ダークモード |
|-------|------------|------------|
| `.primary` | 黒 | 白 |
| `.secondary` | グレー | 薄いグレー |
| `.white` | 白 | 白（変わらない） |
| `.black` | 黒 | 黒（変わらない） |

### カスタムカラーのダークモード対応

**現状**: `AppAccentColor`などのカスタムカラーは**ダークモード未対応**

**対応方法**（将来的に実装）:
1. `Assets.xcassets`に`AppAccentColor.colorset`を作成
2. **Light Appearance**: 黒 or 紫
3. **Dark Appearance**: 白 or 薄い紫

---

## 📝 実装ガイドライン

### ✅ 正しい使い方

#### **テキストカラー**
```swift
// ✅ 正しい（システムカラーを使用 → ダークモード自動対応）
.foregroundColor(.primary)
.foregroundColor(.secondary)

// ❌ 間違い（ハードコード）
.foregroundColor(.black)
.foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
```

#### **背景カラー**
```swift
// ✅ 正しい
.background(Color.white)
.background(Color.gray.opacity(0.1))

// ❌ 間違い（意味のない条件分岐）
.background(isSelected ? Color.white : Color.white)
```

#### **アクセントカラー**
```swift
// ✅ 正しい（定義済みカラーを使用）
.foregroundColor(Color.safeColor("AppAccentColor"))
.foregroundColor(Color.safeColor("SuccessColor"))

// ❌ 間違い（直接指定）
.foregroundColor(Color(red: 0.384, green: 0, blue: 1))
```

---

### ❌ 避けるべき使い方

1. **AppAccentColorを黒にする**
   - アクセントカラーは「目立つ色」であるべき（紫を推奨）

2. **トーストバナーにAppAccentColorを使う（黒背景として）**
   - トーストはアクションなので`PrimaryActionBackground`を使うべき

3. **選択状態の強調に黒を使う**
   - 選択状態は目立たせるため、アクセントカラー（紫）またはSuccessColor（緑）を使うべき

4. **条件分岐で同じ色を返す**
   ```swift
   // ❌ 無駄な条件分岐
   .foregroundColor(isSelected ? .primary : .primary)

   // ✅ シンプルに
   .foregroundColor(.primary)
   ```

---

## 🔧 カラー変更手順

### 方法1: Color+AppColors.swiftを編集（簡単）

**ファイル**: `/ios_watchme_v9/ios_watchme_v9/Color+AppColors.swift`

```swift
// 132行目付近
case "AppAccentColor":
    return Color.black  // ← ここを変更

// 例: 紫に変更する場合
case "AppAccentColor":
    return Color(red: 0.384, green: 0, blue: 1)  // 紫
```

### 方法2: Assets.xcassetsでカラーセットを作成（推奨）

1. Xcodeで`Assets.xcassets`を開く
2. 右クリック → **New Color Set**
3. カラー名を入力（例: `AppAccentColor`）
4. **Any Appearance**: ライトモード用の色を設定
5. **Dark Appearance**: ダークモード用の色を設定
6. ビルド

---

## 🎯 今後の改善計画

### Phase 1: 現在 ✅
- モノクロベース + アクセントカラー（紫）のデザイン確立
- 主要コンポーネントのカラー統一

### Phase 2: 近日中
- `AppAccentColor`を紫に変更
- Assets.xcassetsへのカラーセット追加
- ダークモード対応

### Phase 3: 将来
- カラーテーマ機能の実装
- ユーザーによるカスタマイズ機能

---

## 📚 参考資料

### 関連ドキュメント
- `/ios_watchme_v9/COLOR_GUIDE.md` - iOSアプリの詳細なカラーガイド
- `/ios_watchme_v9/Color+AppColors.swift` - カラー定義ファイル

### Apple Human Interface Guidelines
- [Color - Apple Design Resources](https://developer.apple.com/design/human-interface-guidelines/color)
- [Dark Mode - Apple Design Resources](https://developer.apple.com/design/human-interface-guidelines/dark-mode)

---

## 🆘 トラブルシューティング

### Q: 色を変更したのに反映されない
**A**: 以下を試してください：
1. **Product → Clean Build Folder** (`Shift + Cmd + K`)
2. DerivedDataを削除: `rm -rf ~/Library/Developer/Xcode/DerivedData/*`
3. アプリを完全に終了（バックグラウンドからも削除）
4. 再ビルド: **Product → Build** (`Cmd + B`)
5. 再実行: `Cmd + R`

### Q: ダークモードで色がおかしい
**A**: システムカラー（`.primary`, `.secondary`）を使用しているか確認してください。ハードコード（`.black`, `.white`）はダークモード非対応です。

---

**作成日**: 2025-10-16
**作成者**: Claude Code
**バージョン**: 1.0
