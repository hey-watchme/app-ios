# 録音機能 仕様書

**最終更新**: 2025-10-17
**ステータス**: 🔴 緊急修正待ち（録音開始時の3秒タイムラグ）

---

## 🚨 現在の最優先課題

### 録音開始時の3秒タイムラグ（2025-10-17発生）

**症状:**
- FABボタン（録音ボタン）を押してから実際に録音が開始されるまで約3秒のタイムラグが発生
- 1時間前までは発生していなかった
- 過去に何度も同様の問題が発生し、その都度修正している

**ログ:**
```
🔘 FAB: 録音ボタン押下
✅ 録音シート表示（権限チェックは録音開始時に実行）
🎙️ 録音開始 - 開始スロット: 00-00
...
✅ 録音開始成功
<0x1022912c0> Gesture: System gesture gate timed out.
Hang detected: 3.26s (debugger attached, not reporting)
```

**発生箇所:**
- 録音開始成功直後、メータリング開始前
- 実機（デバッガーなし）でも発生確認済み

**次回セッションで必ず調査・修正すること**

---

## 目次

1. [🚨 現在の最優先課題](#現在の最優先課題)
2. [📝 今回のセッションで実施した修正](#今回のセッションで実施した修正)
3. [概要](#概要)
4. [現在の実装状況](#現在の実装状況)
5. [課題と問題点](#課題と問題点)
6. [修正計画（アーキテクチャ2）](#修正計画アーキテクチャ2)
7. [ファイル構成](#ファイル構成)
8. [データフロー](#データフロー)
9. [UI仕様](#ui仕様)

---

## 📝 今回のセッションで実施した修正

### 2025-10-17セッション

#### 1. ✅ トースト通知機能の追加
**目的:** アップロード完了後、分析中であることをユーザーに通知

**実装内容:**
- `RecordingView.swift`にトーストバナー表示機能を追加
- アップロード完了モーダルが閉じた直後（0.3秒後）にトースト表示
- メッセージ: "ただいま音声を分析中です。しばらくお待ち下さい☕"
- 既存の`ToastBannerView`を再利用（SimpleDashboardViewと同じ実装）

**修正ファイル:**
- `RecordingView.swift:32-34` - 状態管理プロパティ追加
- `RecordingView.swift:43-45` - ToastBannerView追加
- `RecordingView.swift:577-582` - トースト表示ロジック

#### 2. ✅ UserDefaults永続化機能の削除
**問題:** 同じファイル名で上書き録音した際、古い`isUploaded = true`状態が復元され、自動アップロードがスキップされる

**原因:**
- `RecordingModel.swift`が`isUploaded`状態をUserDefaultsに永続化していた
- 同じ30分ブロックで複数回録音すると、同じファイル名で上書きされる
- しかし、UserDefaultsには古い「アップロード済み」状態が残る
- 結果: 新しい録音なのに「既にアップロード済み」と判断される

**修正内容:**
- `loadUploadStatus()` - 削除
- `saveUploadStatus()` - 削除
- `RecordingStatus`構造体 - 削除
- `prepareForceUpload()` - 削除
- `canForceUpload` - 削除
- `isUploaded`はメモリ上の一時的な状態として維持（アップロード成功後の削除前フラグとして必要）

**修正ファイル:**
- `RecordingModel.swift:18-22` - `init()`からloadUploadStatus()呼び出し削除
- `RecordingModel.swift:49-85` - 永続化メソッド削除
- `RecordingModel.swift:60-78` - メソッド簡素化
- `RecordingModel.swift:92-119` - 不要な構造体・プロパティ削除

#### 3. ✅ アップロード条件のシンプル化
**問題:** リストに表示されているのに「アップロード」ボタンが表示されない謎の状態が発生

**原因:**
- アップロードボタンの表示条件: `filter({ !$0.isRecordingFailed && !$0.isUploaded && $0.fileSize > 0 })`
- 自動アップロードの実行条件: `guard recording.canUpload else { ... }`
- 手動アップロードのフィルター: 同様の複雑な条件
- 複雑な条件判定により、リストには表示されるがアップロードできない状態が発生

**新しい設計思想:**
- **リストに表示されている = アップロード対象**
- 複雑な条件判定を一切廃止

**修正内容:**
- アップロードボタン表示条件: `!audioRecorder.recordings.isEmpty`
- 自動アップロード: `canUpload`チェック削除（無条件で実行）
- 手動アップロード: フィルター削除（リスト全体をアップロード対象）

**修正ファイル:**
- `RecordingView.swift:207` - ボタン表示条件シンプル化
- `RecordingView.swift:540-545` - canUploadチェック削除
- `RecordingView.swift:460` - フィルター削除

#### 4. ✅ メッセージ・UIの改善
**修正内容:**
- アップロード完了メッセージ: "すべての一括アップロードが完了しました。" → "アップロードが完了しました。"
- 手動アップロード時の1秒遅延を削除（即座にファイル削除・次の処理へ）

**修正ファイル:**
- `RecordingView.swift:484` - メッセージ簡素化
- `RecordingView.swift:508` - `asyncAfter(deadline: .now() + 1.0)`削除

#### 5. ⚠️ 未解決の問題
**録音開始時の3秒タイムラグ** - 最優先課題として次回セッションで対応

---

## 概要

### 目的
音声録音とAI分析による心理・感情・行動の総合的なモニタリングを提供する。

### 主要機能
- **自動録音**: 30分間隔でバックグラウンド録音
- **自動アップロード**: 録音完了後、自動的にサーバーへアップロード
- **手動アップロード**: 失敗したファイルを手動で再アップロード
- **録音一覧**: 未アップロードのファイル一覧表示

### 期待される動作
1. 録音開始（赤ボタン）→ 録音中（波形表示）→ 録音停止（黒ボタン）
2. 録音完了 → 自動アップロード開始
3. **成功時**: モーダル表示 → ファイル削除 → 一覧に表示されない
4. **失敗時**: モーダル表示 → 一覧に追加 → 「アップロード」ボタン表示
5. 手動アップロード: 「アップロード」ボタン押下 → 成功/失敗を繰り返し可能

---

## 現在の実装状況

### ファイル構成

#### 主要ファイル
- `RecordingView.swift` - UI + アップロード処理
- `AudioRecorder.swift` - 録音管理
- `RecordingModel.swift` - 録音データモデル
- `NetworkManager.swift` - アップロード処理

### 録音フロー（正常動作中）

```
録音開始ボタン（赤）
 ↓
isRecording = true
 ↓
録音中（波形表示）
 ↓
録音停止ボタン（黒）
 ↓
AudioRecorder.stopRecording()
 ↓
audioRecorderDidFinishRecording (AVAudioRecorderDelegate)
 ↓
RecordingModel作成（一覧には追加しない）← 重要な変更点
 ↓
onRecordingCompleted コールバック呼び出し
 ↓
attemptAutoUpload() ← 自動アップロード開始
```

### 自動アップロードフロー（正常動作中）

```
attemptAutoUpload(recording)
 ↓
モーダル表示（送信中...）
 ↓
networkManager.uploadRecording(recording) { success in }
 ↓
├─ 成功
│   ├─ モーダル表示（送信完了）
│   ├─ 2秒後にモーダル消去
│   └─ ファイル削除（一覧に追加されない）✅
│
└─ 失敗
    ├─ モーダル表示（送信失敗）
    ├─ 一覧に追加 ✅
    └─ 2秒後にモーダル消去
```

### 手動アップロードフロー（🔴 バグあり）

```
「アップロード」ボタン押下
 ↓
manualBatchUpload()
 ↓
recordingsToUpload = audioRecorder.recordings.filter { ... } ← コピー作成
 ↓
uploadSequentially(recordings: recordingsToUpload) ← ローカル配列で処理
 ↓
networkManager.uploadRecording(recording) { success in }
 ↓
├─ 成功
│   └─ audioRecorder.deleteRecording(recording) ← 元の配列から削除
│
└─ 失敗
    └─ 何もしない（ログのみ）
 ↓
uploadSequentially(recordings: remainingRecordings) ← 再帰呼び出し
 ↓
remainingRecordings.isEmpty == true
 ↓
「すべての一括アップロードが完了しました」← 🔴 バグ：失敗してもこれが表示される
```

---

## 課題と問題点

### 🔴 バグ1: 手動アップロード失敗時の誤ったメッセージ

**症状**:
- Wi-Fiがない状態で「アップロード」ボタンを押すと、必ず「すべての一括アップロードが完了しました」と表示される
- 実際にはアップロードは失敗している
- ファイルは一覧に残っているが、ユーザーには「完了」と表示される

**原因**:
`uploadSequentially`の設計に根本的な問題がある。

#### 問題のあるコード（RecordingView.swift:449-516）

```swift
private func manualBatchUpload() {
    // ローカル配列にコピー
    let recordingsToUpload = audioRecorder.recordings.filter { ... }
    uploadSequentially(recordings: recordingsToUpload)
}

private func uploadSequentially(recordings: [RecordingModel]) {
    guard let recording = recordings.first else {
        // 配列が空 = 完了？
        alertMessage = "すべての一括アップロードが完了しました。"
        showAlert = true
        return
    }

    var remainingRecordings = recordings
    remainingRecordings.removeFirst() // 必ず減る

    networkManager.uploadRecording(recording) { success in
        if success {
            self.audioRecorder.deleteRecording(recording)
        } else {
            // 何もしない
        }

        // 成功・失敗にかかわらず再帰呼び出し
        self.uploadSequentially(recordings: remainingRecordings)
    }
}
```

#### 問題点の詳細

1. **配列のコピー**: `recordingsToUpload`は元の`audioRecorder.recordings`のコピー
2. **配列の消費**: `remainingRecordings.removeFirst()`で必ず配列が減る
3. **完了判定の誤り**: `recordings.first == nil`（配列が空）= 完了、と判定している
4. **実態との乖離**:
   - 元の`audioRecorder.recordings`には失敗したファイルが残っている
   - しかしローカル配列`recordings`は空になっている
   - 「配列が空」≠「すべて成功」なのに同じ扱い

#### Wi-Fiなしの場合の実際の動作

```
初期状態: audioRecorder.recordings = [File1]

manualBatchUpload()
 ↓
recordingsToUpload = [File1] (コピー)
 ↓
uploadSequentially([File1])
 ↓
recording = File1
remainingRecordings = [] (空)
 ↓
networkManager.uploadRecording(File1) { success = false }
 ↓
失敗 → 何もしない
 ↓
uploadSequentially([]) ← 空配列
 ↓
recordings.first == nil
 ↓
「すべての一括アップロードが完了しました」← 誤ったメッセージ
```

### 🔴 バグ2: 試行回数制限の撤廃による影響

**背景**:
- 元々は`uploadAttempts < 3`という制限があった
- この制限を削除したことで、何度でもリトライ可能になった
- しかし、リトライ可能になったことで、手動アップロードのバグが顕在化した

**現在の状態**:
- 試行回数制限なし（何度でもリトライ可能）✅
- `canUpload`プロパティは簡素化済み ✅
- リセットボタンのUIは削除済み ✅
- NetworkManagerの制限チェックは削除済み ✅

### 設計上の根本的な問題

#### 問題1: Single Source of Truthの欠如
- `audioRecorder.recordings`（元データ）
- `recordingsToUpload`（コピー）
- 2つの配列が存在し、同期が取れていない

#### 問題2: 完了判定のロジックが不適切
- ローカル配列の空チェックで完了判定
- 実際のファイルの状態を反映していない

#### 問題3: 成功/失敗の扱いが曖昧
- 成功 → ファイル削除
- 失敗 → 何もしない
- どちらも配列は減る

---

## 修正計画（アーキテクチャ2）

### 採用する設計: イテレータパターン

#### 設計原則

1. **キューベースの処理**
   - `uploadQueue`という専用のキューを作成
   - キューを消費していく（処理済み = キューから削除）
   - 完了判定はキューが空かどうかで行う

2. **統計情報の管理**
   - `uploadStats = (success: Int, failure: Int)`
   - 成功件数と失敗件数を記録
   - 完了時に適切なメッセージを表示

3. **Single Source of Truth**
   - キューから削除 = 処理済み（成功/失敗問わず）
   - `audioRecorder.recordings`から削除 = 成功のみ
   - 失敗したファイルは`audioRecorder.recordings`に残る

### 新しいフロー

```
「アップロード」ボタン押下
 ↓
manualBatchUpload()
 ↓
uploadQueue = audioRecorder.recordings.filter { ... } ← キュー作成
uploadStats = (success: 0, failure: 0) ← 統計初期化
 ↓
processNextUpload() ← キューベースの処理開始
 ↓
recording = uploadQueue.first
 ↓
networkManager.uploadRecording(recording) { success in }
 ↓
uploadQueue.removeFirst() ← キューから削除（成功/失敗問わず）
 ↓
├─ 成功
│   ├─ uploadStats.success += 1
│   ├─ audioRecorder.deleteRecording(recording) ← 元の配列から削除
│   └─ processNextUpload() ← 次へ
│
└─ 失敗
    ├─ uploadStats.failure += 1
    ├─ 元の配列には残す（削除しない）
    └─ processNextUpload() ← 次へ
 ↓
uploadQueue.isEmpty == true ← 完了判定
 ↓
showUploadResult() ← 統計情報に基づいてメッセージ表示
 ↓
├─ すべて成功: "すべてアップロードしました。(N件)"
├─ 一部失敗: "成功: N件、失敗: M件"
└─ すべて失敗: "アップロードに失敗しました。"
```

### 実装コード（RecordingView.swift）

```swift
// MARK: - プロパティ追加
private var uploadQueue: [RecordingModel] = []
private var uploadStats = (success: 0, failure: 0)

// MARK: - 手動アップロード処理（新規実装）
private func manualBatchUpload() {
    // キューを作成
    uploadQueue = audioRecorder.recordings.filter {
        !$0.isRecordingFailed && !$0.isUploaded && $0.fileExists() && $0.fileSize > 0
    }

    guard !uploadQueue.isEmpty else {
        alertMessage = "アップロード対象のファイルがありません。"
        showAlert = true
        return
    }

    uploadStats = (success: 0, failure: 0)
    print("📤 一括アップロード開始: \(uploadQueue.count)件")

    processNextUpload()
}

private func processNextUpload() {
    // キューが空なら完了
    guard let recording = uploadQueue.first else {
        showUploadResult()
        return
    }

    print("📤 アップロード中: \(recording.fileName)")

    // 1件アップロード
    networkManager.uploadRecording(recording) { success in
        // キューから削除（処理済み）
        self.uploadQueue.removeFirst()

        if success {
            print("✅ アップロード成功: \(recording.fileName)")
            self.uploadStats.success += 1

            // 成功したら一覧から削除
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.audioRecorder.deleteRecording(recording)
                // 次へ
                self.processNextUpload()
            }
        } else {
            print("❌ アップロード失敗: \(recording.fileName)")
            self.uploadStats.failure += 1

            // 失敗したら一覧に残す（次へ）
            self.processNextUpload()
        }
    }
}

private func showUploadResult() {
    let total = uploadStats.success + uploadStats.failure

    if uploadStats.failure == 0 {
        // すべて成功
        alertMessage = "すべてアップロードしました。(\(total)件)"
    } else if uploadStats.success > 0 {
        // 一部失敗
        alertMessage = "アップロード完了\n成功: \(uploadStats.success)件、失敗: \(uploadStats.failure)件"
    } else {
        // すべて失敗
        alertMessage = "アップロードに失敗しました。ネットワーク接続を確認してください。"
    }

    showAlert = true
    print("📊 アップロード結果 - 成功: \(uploadStats.success), 失敗: \(uploadStats.failure)")
}
```

### 修正が必要な箇所

#### RecordingView.swift

1. **プロパティ追加**（20行目付近）
   ```swift
   private var uploadQueue: [RecordingModel] = []
   private var uploadStats = (success: 0, failure: 0)
   ```

2. **manualBatchUpload()の置き換え**（449-473行目）
   - 既存のコードを削除
   - 新しいコードに置き換え

3. **uploadSequentially()の削除**（475-516行目）
   - 完全に削除

4. **processNextUpload()の追加**（新規）
   - 上記のコードを追加

5. **showUploadResult()の追加**（新規）
   - 上記のコードを追加

### 削除する関数

- `uploadSequentially(recordings: [RecordingModel])` - 475-516行目

### 追加する関数

- `processNextUpload()` - キューベースの処理
- `showUploadResult()` - 統計情報に基づく結果表示

---

## ファイル構成

### RecordingView.swift

**役割**: 録音UIとアップロード処理

**主要コンポーネント**:
- 録音開始/停止ボタン
- 録音ファイル一覧
- 「アップロード」ボタン
- 自動アップロードモーダル

**主要メソッド**:
- `attemptAutoUpload(recording:)` - 自動アップロード（正常動作中）
- `manualBatchUpload()` - 手動アップロード（🔴 修正必要）
- `addRecordingToList(_:)` - 一覧に追加
- `deleteRecordingFile(_:)` - ファイル削除

### AudioRecorder.swift

**役割**: 録音管理

**主要機能**:
- 録音開始/停止
- 30分スロット管理
- ファイル保存
- 録音完了コールバック

**重要な変更点**:
- 録音完了時、一覧に追加しない（768-782行目）
- コールバックで`RecordingModel`を渡す

### RecordingModel.swift

**役割**: 録音データモデル

**主要プロパティ**:
- `fileName: String` - ファイル名（"YYYY-MM-DD/HH-MM.wav"）
- `isUploaded: Bool` - アップロード済みフラグ
- `fileSize: Int64` - ファイルサイズ
- `uploadAttempts: Int` - 試行回数（記録用、制限なし）
- `lastUploadError: String?` - 最後のエラーメッセージ

**主要プロパティ（計算型）**:
- `canUpload: Bool` - アップロード可能か（試行回数制限なし）
- `isRecordingFailed: Bool` - 録音失敗（0KB）か

### NetworkManager.swift

**役割**: アップロード処理

**主要メソッド**:
- `uploadRecording(_:completion:)` - ファイルアップロード

**重要な修正点**:
- 試行回数制限を削除（84行目）
- `completion`呼び出し漏れを修正（119, 143行目）

---

## データフロー

### 録音完了からアップロードまで

```
AudioRecorder
 ↓ audioRecorderDidFinishRecording
 ↓ RecordingModel作成（一覧には追加しない）
 ↓ onRecordingCompleted コールバック
 ↓
RecordingView.attemptAutoUpload()
 ↓
NetworkManager.uploadRecording()
 ↓
├─ 成功 → ファイル削除
└─ 失敗 → RecordingView.addRecordingToList()
          ↓
          audioRecorder.recordings.insert(recording, at: 0)
```

### 手動アップロード（修正後）

```
RecordingView.manualBatchUpload()
 ↓
uploadQueue作成
 ↓
RecordingView.processNextUpload()
 ↓
NetworkManager.uploadRecording()
 ↓
uploadQueue.removeFirst() ← 処理済み
 ↓
├─ 成功 → audioRecorder.deleteRecording()
│         ↓
│         processNextUpload() ← 次へ
│
└─ 失敗 → processNextUpload() ← 次へ（一覧に残る）
 ↓
uploadQueue.isEmpty
 ↓
RecordingView.showUploadResult()
```

---

## UI仕様

### 録音ボタン

#### 録音開始ボタン（赤）
- 表示条件: `!audioRecorder.isRecording`
- 色: 赤（`Color.safeColor("RecordingActive")`）
- テキスト: "録音を開始"
- アイコン: `mic.circle.fill`

#### 録音停止ボタン（黒）
- 表示条件: `audioRecorder.isRecording`
- 色: 黒（`Color.black`）
- テキスト: "録音を停止"
- アイコン: `stop.circle.fill`

### アップロードボタン

#### 表示条件
```swift
audioRecorder.recordings.filter {
    !$0.isRecordingFailed && !$0.isUploaded && $0.fileSize > 0
}.count > 0
```

#### デザイン
- 色: `Color.safeColor("AppAccentColor")`（紫）
- テキスト: "アップロード"
- アイコン: `waveform.badge.magnifyingglass`
- 位置: 録音ファイル一覧の下

### 録音ファイル一覧

#### 表示内容
- 日付: "yyyy年M月d日"（小さいフォント）
- 時間帯: "HH:mm-HH:mm"（大きいフォント）
- ファイルサイズ: "XX KB"
- アップロード失敗時: "アップロード失敗"（警告アイコン付き）

#### エラー表示
- アップロード失敗時:
  - アイコン: `exclamationmark.triangle.fill`（警告色）
  - テキスト: "アップロード失敗"
  - 詳細エラー: `lastUploadError`の内容

### モーダル（自動アップロード）

#### 送信中
- タイトル: "送信中..."
- プログレスバー: 0-100%
- サイズ: 320x120（固定）

#### 送信完了
- タイトル: "送信完了"
- プログレスバー: 100%
- 2秒後に自動で閉じる

#### 送信失敗
- タイトル: "送信失敗"（赤）
- サブタイトル: "ファイルはリストに残ります"
- 2秒後に自動で閉じる

### アラート（手動アップロード結果）

#### すべて成功
```
すべてアップロードしました。(N件)
```

#### 一部失敗
```
アップロード完了
成功: N件、失敗: M件
```

#### すべて失敗
```
アップロードに失敗しました。ネットワーク接続を確認してください。
```

---

## テストシナリオ

### シナリオ1: 正常系（Wi-Fi接続あり）

1. 録音開始ボタン（赤）を押す
2. 録音中の波形表示を確認
3. 録音停止ボタン（黒）を押す
4. モーダル「送信中...」が表示される
5. プログレスバーが進む
6. モーダル「送信完了」が表示される
7. 2秒後にモーダルが消える
8. 録音ファイル一覧に何も表示されない ✅

**期待結果**: ファイルは自動的に削除され、一覧には表示されない

### シナリオ2: 自動アップロード失敗（機内モード）

1. 機内モードをONにする
2. 録音開始 → 録音停止
3. モーダル「送信中...」が表示される
4. モーダル「送信失敗」が表示される
5. 2秒後にモーダルが消える
6. 録音ファイル一覧にファイルが表示される ✅
7. 「アップロード」ボタンが表示される ✅
8. ファイル行に「アップロード失敗」と表示される ✅

**期待結果**: ファイルは一覧に残り、手動でアップロード可能

### シナリオ3: 手動アップロード成功（Wi-Fi復活後）

**前提**: シナリオ2の状態（ファイルが一覧に残っている）

1. Wi-Fiを復活させる
2. 「アップロード」ボタンを押す
3. アップロード処理が実行される
4. アラート「すべてアップロードしました。(1件)」が表示される ✅
5. 一覧からファイルが消える ✅

**期待結果**: ファイルが正常にアップロードされ、一覧から削除される

### シナリオ4: 手動アップロード失敗（機内モード）

**前提**: シナリオ2の状態（ファイルが一覧に残っている）

1. 機内モードのまま
2. 「アップロード」ボタンを押す
3. アップロード処理が実行される
4. 🔴 **現在のバグ**: "すべての一括アップロードが完了しました"と表示される
5. ✅ **修正後**: "アップロードに失敗しました。ネットワーク接続を確認してください。"と表示される
6. ファイルは一覧に残る ✅

**期待結果**: エラーメッセージが表示され、ファイルは一覧に残る

### シナリオ5: 複数ファイルの一部失敗

**前提**: 3つのファイルが一覧にある

1. Wi-Fiを不安定な状態にする
2. 「アップロード」ボタンを押す
3. 1件目: 成功 → 一覧から消える
4. 2件目: 失敗 → 一覧に残る
5. 3件目: 成功 → 一覧から消える
6. アラート「アップロード完了\n成功: 2件、失敗: 1件」が表示される ✅

**期待結果**: 成功したファイルは削除され、失敗したファイルのみ残る

---

## 既知の問題

### 🔴 重大なバグ

#### バグ: 手動アップロード失敗時の誤ったメッセージ
- **症状**: Wi-Fiがない状態で「アップロード」ボタンを押すと「すべての一括アップロードが完了しました」と表示される
- **原因**: `uploadSequentially`の設計が配列消費型のため、失敗してもローカル配列は空になる
- **影響**: ユーザーが誤解する（実際は失敗しているのに成功したと思う）
- **修正予定**: アーキテクチャ2（イテレータパターン）で全面的に書き換え

### ✅ 解決済みの問題

#### 試行回数制限の撤廃
- **以前の仕様**: `uploadAttempts < 3`で3回まで
- **現在**: 制限なし（何度でもリトライ可能）
- **理由**: 手動アップロードで何度でも試せるべき

#### completionコールバック呼び出し漏れ
- **問題**: NetworkManagerで一部のエラーケースで`completion`が呼ばれていなかった
- **修正**: 119行目と143行目に`completion(false)`を追加
- **影響**: 一部のエラーケースで処理が止まっていた

#### リセットボタンの削除
- **以前**: 試行回数が3回に達するとリセットボタンが表示されていた
- **現在**: 試行回数制限がないため、リセットボタンは不要になり削除

---

## 次回セッションで実施すること

### タスクリスト

1. ✅ **ボタン名変更**: "分析開始" → "アップロード"（完了済み）

2. 🔴 **アーキテクチャ2の実装**:
   - プロパティ追加: `uploadQueue`, `uploadStats`
   - `manualBatchUpload()`の置き換え
   - `uploadSequentially()`の削除
   - `processNextUpload()`の追加
   - `showUploadResult()`の追加

3. 🔴 **テスト**:
   - シナリオ4の動作確認（機内モードでの手動アップロード失敗）
   - シナリオ5の動作確認（複数ファイルの一部失敗）

4. 🔴 **コンパイルチェック**:
   ```bash
   xcodebuild -scheme ios_watchme_v9 -sdk iphonesimulator build
   ```

### 実装の優先順位

**優先度: 高**
- アーキテクチャ2の実装（手動アップロード処理の書き換え）

**優先度: 中**
- エッジケースのテスト（不安定なネットワーク環境）

**優先度: 低**
- UI/UXの微調整

---

## 参考情報

### 関連ドキュメント
- `README.md` - プロジェクト全体の概要
- `TECHNICAL.md` - アーキテクチャ・データベース設計
- `CHANGELOG.md` - 更新履歴

### 関連Issue・過去の失敗
- **キューベースのアーキテクチャ導入の失敗**: 過去にキューを使った実装を試みて失敗した経緯がある
- **今回の対策**: よりシンプルなイテレータパターンを採用し、Single Source of Truthを徹底する

### コーディング規約
- 日本語コメントを使用
- print文でログを詳細に出力（デバッグ用）
- 絵文字を使ったログ（📤, ✅, ❌など）

---

## 変更履歴

### 2025-10-16
- 録音停止ボタンの色を赤 → 黒に変更
- 自動アップロード失敗時の一覧表示ロジックを実装
- 試行回数制限を撤廃
- リセットボタンを削除
- ボタン名を"分析開始" → "アップロード"に変更
- 手動アップロード処理のバグを発見
- アーキテクチャ2（イテレータパターン）を設計

### 今後の予定
- アーキテクチャ2の実装
- バグ修正の完了
- 包括的なテストの実施
