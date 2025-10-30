# 録音機能 仕様書

**最終更新**: 2025-10-30
**ステータス**: ✅ **UI刷新完了・安定稼働**

---

## 🎯 概要

WatchMeアプリの録音機能は、30分間隔でユーザーの音声を録音し、AI分析用にクラウドへアップロードする中核機能です。

### 主要な改修履歴

- **2025-10-18**: View-Store-Serviceアーキテクチャへの全面リファクタリング完了
- **2025-10-30**: 全画面録音UI（`FullScreenRecordingView`）への刷新、音声ビジュアライザーの実装

---

## 🎨 現在のUI構成 (2025-10-30)

### FullScreenRecordingView.swift
全画面表示の録音インターフェース（ChatGPT音声モード風）

**特徴:**
- 半透明の黒背景（opacity: 0.8）
- リアルタイム音声ビジュアライザー（`BlobVisualizerView`）
- 録音ボタン（赤い円、完全な白の外周リング）
- 録音時間表示（録音中のみ）
- エラーメッセージ表示
- 右上に閉じるボタン（×）

**状態管理:**
- `RecordingStore`を使用（既存のView-Store-Serviceアーキテクチャを維持）
- `AudioMonitorService`で音声レベルをリアルタイムモニタリング

### BlobVisualizerView.swift
音声に反応する有機的なBlob形状ビジュアライザー

**仕様:**
- サイズ: 160×160
- 色: シアン〜ブルーのグラデーション
- 中心アイコン: `waveform`
- アニメーション: 8つのスパイクが常時回転（phase速度: 0.025）
- 音声反応:
  - 待機中（audioLevel=0）: ほぼ円形（amplitude: 0.01）
  - 音声検知時: スパイクが伸びる（amplitude最大: 0.36）
  - 半径変化: 1.0〜1.22倍
- スパイクのランダム性: 擬似ランダム（0.6〜1.4倍）で有機的な動き

### AudioMonitorService.swift
録音とは独立した音声レベルモニタリング

**役割:**
- `AVAudioEngine`を使用してリアルタイムで音声レベルを取得
- 録音の有無に関わらず動作（ビジュアライザー専用）
- RMS計算で正規化された音声レベル（0.0〜1.0）を提供

**ライフサイクル:**
- `FullScreenRecordingView.onAppear`: モニタリング開始
- `FullScreenRecordingView.onDisappear`: モニタリング停止

---

## ✅ 解決済みの課題 (2025-10-18対応)

### 1. アップロード処理の根本的なバグ

- **問題**: すべてのアップロードが`400 Bad Request`エラーで失敗していた。
- **原因**: `UploaderService`が`URLSession`のAPIを誤って使用し、不正な形式のリクエストを送信していた（二重ラップ問題）。
- **解決策**: `URLSession.shared.upload(for:from:)`メソッドを使用し、手動で作成した`Data`型のボディを直接送信するように修正。これにより、すべてのアップロードが正常に成功するようになった。

### 2. オーディオセッション初期化失敗時の不適切な動作

- **問題**: オーディオセッションの準備に失敗しても、録音処理が続行されてしまい、不安定な状態に陥っていた。
- **原因**: `RecordingStore`に、初期化失敗を検知しても後続処理を中断するガードロジックが欠けていた。
- **解決策**: `startRecording`メソッド内に、オーディオセッションの準備が完了しているかを確認するガード処理を追加。失敗した場合はエラーを表示し、録音処理を安全に中断するように修正。

### 3. 録音開始時の3〜8秒のフリーズ問題

- **問題**: 録音ボタンを押してからUIが反応するまで、最大8秒程度のフリーズが発生していた。
- **原因**: 録音ボタン押下時に、`AVAudioSession`の設定など、重い初期化処理が同期的に実行されていた。
- **解決策**: `RecordingView`の表示時（`.onAppear`）に、`RecordingStore`の`initialize`メソッドを呼び出し、オーディオセッションを事前に非同期で準備する方式に変更。ボタン押下時は軽量な処理のみ実行されるため、ユーザー体感遅延はゼロになった。

### 4. タイムゾーンのバグ（2025-10-18対応）

- **問題**: 録音データのタイムスタンプとタイムブロックが、デバイスのタイムゾーンではなくUTCで保存されていた。例：日本時間22:00の録音が、UTC 13:00（`time_block: 13-00`）として保存される。
- **原因**: `UploaderService.swift`の`createMultipartBody`メソッドで、`ISO8601DateFormatter()`がデフォルトでUTCに変換していたため、デバイスのタイムゾーン情報（`Asia/Tokyo`）が失われていた。
- **解決策**:
  1. `UploadRequest`構造体に`timezone: TimeZone`フィールドを追加
  2. `RecordingStore.createUploadRequest`でデバイスのタイムゾーン（`deviceManager.selectedDeviceTimezone`）を設定
  3. `UploaderService.createMultipartBody`で、`ISO8601DateFormatter`にデバイスのタイムゾーンを設定してフォーマット
- **結果**: `recorded_at`がデバイスのタイムゾーン情報を含む形式（例：`2025-10-17T22:12:12+09:00`）で送信され、API側で正しいタイムブロック（`22-00`）が生成されるようになった。

---

## 🏗️ 新アーキテクチャ：View-Store-Service

今回のリファクタリングで全面的に導入された、責務の分離と単一方向のデータフローを徹底した設計です。

### 設計原則

1.  **単一の信頼できる状態 (Single Source of Truth):** 録音機能に関する全ての状態は、`RecordingStore`内の単一の`State`構造体に集約され、状態の矛盾を設計上不可能にしています。
2.  **単一方向のデータフロー:** データの流れを「UI操作 → Storeのアクション呼び出し → Stateの更新 → UIの再描画」という一方向に限定し、予測可能な動作を保証します。
3.  **明確な責務分離:** 各コンポーネントは、単一の責務に特化しています。

### コンポーネントの役割

#### 1. View層 (`FullScreenRecordingView.swift`) - 表示装置
- **責務:** UIの表示と、ユーザー操作の受付のみ。
- **役割:** `RecordingStore`から最新の`State`を受け取り、画面を忠実に描画します。ビジネスロジックは一切持ちません。
- **補助View:**
  - `BlobVisualizerView`: 音声ビジュアライザー
  - `RecordingButton`: 録音制御ボタン
  - `ErrorMessageView`: エラー表示

#### 2. Store層 (`RecordingStore.swift`) - 司令塔・頭脳
- **責務:** 状態管理とビジネスロジックのすべて。
- **役割:** 唯一の状態である`RecordingState`を保持・公開し、UIからの指示に基づき`Service`層を呼び出して、その結果に応じて`State`を更新します。

#### 3. Service層 (`AudioRecorderService.swift`, `UploaderService.swift`, `AudioMonitorService.swift`) - 実行部隊
- **責務:** 特定の技術的タスク（録音、アップロード、音声モニタリング）の実行。
- **役割:** `AVFoundation`やネットワーク通信など、具体的な処理に特化します。状態を持たず、`Store`や`View`の存在を知りません。
- **AudioMonitorService**: 録音とは独立して音声レベルをモニタリング（ビジュアライザー用）

### このアーキテクチャの価値

この設計により、以前の「ツギハギ感」の根本原因であった「責務の混在」と「状態の分散」が解消され、バグが起きにくく、将来の変更にも強い、クリーンなコードベースが実現しました。

---

## 📈 最終的な成果指標

### コード品質の改善

| 項目 | 旧実装 (2025-10-17以前) | リファクタリング後 (2025-10-18) | UI刷新後 (2025-10-30) |
|------|--------|-------|-------|
| View | RecordingView.swift (879行、混在) | RecordingView.swift (501行、UI層のみ) | FullScreenRecordingView.swift (236行、シンプル) |
| Recorder | AudioRecorder.swift (928行、複雑) | AudioRecorderService (295行) | 変更なし（既存Service使用） |
| ビジュアライザー | なし | なし | BlobVisualizerView (132行) + AudioMonitorService (99行) |
| 責務 | 混在・密結合 | 分離・疎結合 | 分離・疎結合（維持） |
| UX | 標準UI | 標準UI | 全画面・モダンUI |

### パフォーマンスと信頼性

| 項目 | Before | After |
|------|--------|-------|
| 録音開始遅延 | 3～8秒 | **即座（0秒）** |
| アップロード | 100%失敗 | **正常に成功** |
| エラーハンドリング | 不完全 | **堅牢** |

