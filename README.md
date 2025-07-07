# WatchMe - iOS 録音アプリ

## 概要

WatchMe は、デバイス主導型の音声データ収集システムです。音声を30分間隔で自動分割して録音し、デバイスが保存パスを完全制御してAWS EC2上の`watchme-vault-api`サーバーにアップロードします。新しいX-File-Pathヘッダー機能により、バックデート対応とネットワーク復旧時のまとめ送信を実現し、柔軟で堅牢なデータ収集を提供します。

## 主要機能

### 🎙️ 録音機能
- **30分自動分割録音**: 正確な時刻境界（毎時0分・30分）でファイル分割
- **連続録音対応**: 何時間録音しても30分単位のファイルが生成される
- **高品質録音**: リニアPCM 16kHz, 16bit, モノラル形式
- **リアルタイム録音時間表示**: 0.1秒間隔での時間更新
- **自動上書き録音**: 同一時間スロットは確認なしで自動上書き
- **完全クリーンアップ**: 物理ファイル・メタデータ・アップロード状態を完全削除

### ☁️ デバイス主導型クラウド連携機能 **【重要更新】**
- **Supabase認証**: メール・パスワードによるユーザー認証システム
- **デバイス登録**: Supabaseデータベースへの自動デバイス登録・管理
- **🎯 X-File-Pathヘッダー送信（新機能）**: デバイスが保存パス完全制御
  - 形式: `device_id/YYYY-MM-DD/HH-MM.wav`
  - バックデート対応（過去日付のファイル送信可能）
  - まとめ送信対応（ネットワーク復旧時の一括送信）
  - 時系列順序に依存しない柔軟な運用
- **SlotTimeUtilityクラス（新規）**: 時刻スロット生成ロジックの統一化
- **手動アップロード**: ユーザーが手動でサーバーアップロードを制御
- **状態永続化**: アップロード状態をUserDefaultsで永続保存
- **リトライ機能**: 失敗時の自動リトライ（最大3回まで）
- **進捗表示**: アップロード進捗のリアルタイム表示

### 📱 ユーザビリティ
- **統計情報表示**: 総録音数、アップロード済み数、待機数の表示
- **ユーザーアカウント管理**: 左上アイコンからユーザー情報・デバイス情報・ログアウト機能にアクセス
- **ファイル管理**: ファイルサイズ、作成日時、エラー情報の詳細表示
- **開発者向け機能**: フッターエリアにサーバーURL設定・接続テスト機能を配置
- **ファイルクリーンアップ**: 古い形式や破損ファイルの一括削除

## アーキテクチャ設計

### ファイル構成

```
ios_watchme_v9/
├── ios_watchme_v9App.swift          # アプリエントリーポイント
├── MainAppView.swift               # アプリ状態管理・認証分岐
├── LoginView.swift                 # ログイン・サインアップ画面
├── ContentView.swift               # メインUI画面
├── SupabaseAuthManager.swift       # Supabase認証管理
├── DeviceManager.swift             # デバイス登録・管理
├── RecordingModel.swift            # 録音データモデル・永続化
├── AudioRecorder.swift             # 録音制御・ファイル管理
├── NetworkManager.swift            # クラウド通信・アップロード（X-File-Path対応）
├── SlotTimeUtility.swift           # 時刻スロット生成ユーティリティ（新規）
├── UploadManager.swift             # アップロードキュー管理
└── ConnectionStatus.swift          # 接続状態定義
```

### クラス設計

#### SupabaseAuthManager
```swift
class SupabaseAuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: SupabaseUser? = nil
    @Published var authError: String? = nil
    @Published var isLoading: Bool = false
}
```

**主要メソッド**:
- `signIn(email:password:)`: メール・パスワードでログイン
- `signUp(email:password:)`: 新規ユーザー登録
- `signOut()`: ログアウト処理
- `refreshToken()`: JWTトークンのリフレッシュ
- `fetchUserInfo()`: ユーザー情報・確認状態の取得

#### DeviceManager
```swift
class DeviceManager: ObservableObject {
    @Published var isDeviceRegistered: Bool = false
    @Published var currentDeviceID: String? = nil
    @Published var registrationError: String? = nil
    @Published var isLoading: Bool = false
}
```

**主要メソッド**:
- `registerDevice(ownerUserID:)`: Supabaseへのデバイス登録（UPSERT）
- `getDeviceInfo()`: 登録済みデバイス情報の取得
- `resetDeviceRegistration()`: デバイス登録状態のリセット

**デバイス登録フロー**:
1. `UIDevice.current.identifierForVendor`でプラットフォーム識別子取得
2. Supabaseデータベースに`platform_identifier`・`owner_user_id`でUPSERT
3. 既存レコードがあれば再利用、なければ新規作成
4. `device_id`をUserDefaultsにキャッシュして高速アクセス

#### RecordingModel
```swift
class RecordingModel: ObservableObject, Codable {
    @Published var fileName: String          // ファイル名（HH-mm.wav形式）
    @Published var date: Date               // 作成日時
    @Published var isUploaded: Bool         // アップロード完了フラグ
    @Published var fileSize: Int64          // ファイルサイズ（bytes）
    @Published var uploadAttempts: Int      // アップロード試行回数
    @Published var lastUploadError: String? // 最後のエラーメッセージ
}
```

**主要メソッド**:
- `markAsUploaded()`: アップロード成功時の状態更新
- `markAsUploadFailed(error:)`: アップロード失敗時の状態更新
- `resetUploadStatus()`: アップロード状態のリセット
- `fileExists()`: ファイル存在確認
- `canUpload`: アップロード可能性判定

#### AudioRecorder
```swift
class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording: Bool         // 録音状態
    @Published var recordings: [RecordingModel] // 録音ファイル一覧
    @Published var recordingTime: TimeInterval  // 録音経過時間
    @Published var currentSlot: String       // 現在のスロット時刻
}
```

**録音制御フロー**:
1. `startRecording()`: 録音開始・初期スロット設定
2. `handleExistingRecording()`: 同一スロット既存ファイルの自動上書き処理
3. `startRecordingForCurrentSlot()`: 現在スロットでの録音開始
4. `setupSlotSwitchTimer()`: 30分境界での切り替えタイマー設定
5. `performSlotSwitch()`: スロット切り替え実行
6. `finishCurrentSlotRecording()`: 現在スロット録音完了・保存
7. `stopRecording()`: 録音停止・最終ファイル保存

**スロット時刻算出**:
```swift
private func getCurrentSlot() -> String {
    let now = Date()
    let calendar = Calendar.current
    let components = calendar.dateComponents([.hour, .minute], from: now)
    
    let hour = components.hour ?? 0
    let minute = components.minute ?? 0
    let adjustedMinute = minute < 30 ? 0 : 30
    
    return String(format: "%02d-%02d", hour, adjustedMinute)
}
```

#### NetworkManager **【X-File-Path対応済み】**
```swift
class NetworkManager: ObservableObject {
    @Published var serverURL: String = "https://api.hey-watch.me"
    @Published var connectionStatus: ConnectionStatus
    @Published var currentUserID: String
    @Published var uploadProgress: Double
    @Published var currentUploadingFile: String?
}
```

**🎯 X-File-Pathヘッダー生成ロジック（新機能）**:
```swift
// NetworkManager.swift - uploadRecording()内で自動生成
if let deviceInfo = deviceManager?.getDeviceInfo() {
    // SlotTimeUtilityを使用してパス生成
    let filePath = SlotTimeUtility.generateFilePath(
        deviceID: deviceInfo.deviceID, 
        date: recording.date
    )
    request.setValue(filePath, forHTTPHeaderField: "X-File-Path")
    // 例: "device123/2025-07-07/13-30.wav"
}
```

#### SlotTimeUtility **【新規クラス】**
```swift
class SlotTimeUtility {
    // 日付から30分スロット名を生成
    static func getSlotName(from date: Date) -> String
    
    // 現在時刻のスロット名を取得
    static func getCurrentSlot() -> String
    
    // 完全なファイルパスを生成
    static func generateFilePath(deviceID: String, date: Date) -> String
    
    // 次のスロット切り替えまでの秒数を計算
    static func getSecondsUntilNextSlot() -> TimeInterval
}
```

**統一化されたロジック**:
- AudioRecorderとNetworkManagerで同じスロット名生成を保証
- JST（日本標準時）ベースの統一処理
- 30分境界での正確な時刻計算

## サーバー連携仕様

### サーバー情報
- **サーバー名**: `watchme-vault-api`
- **プラットフォーム**: AWS EC2
- **エンドポイント**: `https://api.hey-watch.me/upload`
- **プロトコル**: HTTPS
- **メソッド**: POST
- **Content-Type**: multipart/form-data

### リクエスト仕様

#### エンドポイント
```
POST https://api.hey-watch.me/upload
```

#### ヘッダー **【X-File-Path追加】**
```http
Content-Type: multipart/form-data; boundary={UUID}
X-File-Path: device123/2025-07-07/13-30.wav
```

#### ボディ構造
```http
--{boundary}
Content-Disposition: form-data; name="user_id"

{currentUserID}
--{boundary}
Content-Disposition: form-data; name="timestamp"

{ISO8601形式のタイムスタンプ}
--{boundary}
Content-Disposition: form-data; name="device_id"

{Supabase登録済みデバイスID}
--{boundary}
Content-Disposition: form-data; name="file"; filename="{fileName}"
Content-Type: audio/wav

{バイナリ音声データ}
--{boundary}--
```

#### パラメーター詳細 **【X-File-Path追加】**

| パラメーター | 型 | 必須 | 説明 | 例 |
|---|---|---|---|---|
| **X-File-Path** | **Header** | **○** | **デバイス指定の保存パス** | **`device123/2025-07-07/13-30.wav`** |
| user_id | String | ○ | ユーザー識別子（認証済みUser ID） | `164cba5a-dba6-4cbc-9b39-4eea28d98fa5` |
| timestamp | String | ○ | ISO8601形式の録音作成日時 | `2025-06-24T13:00:00Z` |
| device_id | String | ○ | Supabase登録済みデバイスID | `device_uuid_12345` |
| file | Binary | ○ | WAV形式の音声ファイル | バイナリデータ |

**🎯 X-File-Pathヘッダーの重要性**:
- **デバイス主導**: iOSデバイスが保存先を完全制御
- **バックデート対応**: 過去の日付のファイルもアップロード可能
- **まとめ送信**: ネットワーク復旧時の一括送信に対応
- **時系列順序無依存**: ファイル送信順序に関係なく正しく保存

### レスポンス仕様

#### 成功レスポンス **【X-File-Path対応】**
```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "status": "ok",
  "path": "/home/ubuntu/data/data_accounts/device123/2025-07-07/13-30.wav",
  "device_id": "device123",
  "file_path": "device123/2025-07-07/13-30.wav",
  "method": "client_specified"
}
```

**従来の自動時刻モード（下位互換）**:
```http
{
  "status": "ok",
  "path": "/home/ubuntu/data/data_accounts/device123/2025-07-07/raw/13-30.wav",
  "device_id": "device123",
  "method": "auto_timestamp"
}
```

#### エラーレスポンス **【X-File-Path検証エラー追加】**
```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "detail": "Invalid file path format. Expected: device_id/YYYY-MM-DD/HH-MM.wav"
}
```

**パストラバーサル攻撃検出時**:
```http
{
  "detail": "Invalid path components detected"
}
```

**従来のエラー**:
```http
{
  "status": "error",
  "message": "Invalid file format",
  "error_code": "INVALID_FORMAT"
}
```

### 実装コード例

```swift
func uploadRecording(_ recording: RecordingModel) {
    // アップロード前チェック
    guard recording.canUpload else { return }
    
    // リクエスト設定
    guard let uploadURL = URL(string: "\(serverURL)/upload") else { return }
    var request = URLRequest(url: uploadURL)
    request.httpMethod = "POST"
    request.timeoutInterval = 120.0
    
    // X-File-Pathヘッダー設定（新機能）
    if let deviceInfo = deviceManager?.getDeviceInfo() {
        let filePath = SlotTimeUtility.generateFilePath(
            deviceID: deviceInfo.deviceID, 
            date: recording.date
        )
        request.setValue(filePath, forHTTPHeaderField: "X-File-Path")
    }
    
    // Boundary設定
    let boundary = UUID().uuidString
    request.setValue("multipart/form-data; boundary=\(boundary)", 
                     forHTTPHeaderField: "Content-Type")
    
    // ボディ構築
    var body = Data()
    
    // user_idパラメーター
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
    body.append("\(currentUserID)\r\n".data(using: .utf8)!)
    
    // timestampパラメーター
    let timestampFormatter = ISO8601DateFormatter()
    let timestampString = timestampFormatter.string(from: recording.date)
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"timestamp\"\r\n\r\n".data(using: .utf8)!)
    body.append("\(timestampString)\r\n".data(using: .utf8)!)
    
    // fileパラメーター
    let fileData = try Data(contentsOf: recording.getFileURL())
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(recording.fileName)\"\r\n".data(using: .utf8)!)
    body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
    body.append(fileData)
    body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
    
    request.httpBody = body
    
    // アップロード実行
    URLSession.shared.dataTask(with: request) { data, response, error in
        // レスポンス処理
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 200 {
            recording.markAsUploaded()
        } else {
            recording.markAsUploadFailed(error: "Upload failed")
        }
    }.resume()
}
```

## 音声ファイル仕様

### ファイル形式
- **フォーマット**: WAV (Waveform Audio File Format)
- **コーデック**: リニアPCM
- **サンプルレート**: 16,000 Hz (16kHz)
- **ビット深度**: 16 bit
- **チャンネル数**: 1 (モノラル)

### ファイル命名規則
```
{時刻スロット}.wav

例:
- 13-00.wav (13:00-13:29の録音)
- 13-30.wav (13:30-13:59の録音)
- 14-00.wav (14:00-14:29の録音)
```

### AVAudioRecorder設定
```swift
let settings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatLinearPCM),
    AVSampleRateKey: 16000.0,  // 16kHzに設定
    AVNumberOfChannelsKey: 1,
    AVLinearPCMBitDepthKey: 16,
    AVLinearPCMIsFloatKey: false,
    AVLinearPCMIsBigEndianKey: false,
    AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
]
```

## データ永続化仕様

### UserDefaults構造
```swift
// キー: "recordingUploadStatus"
// 値: [String: RecordingStatus]の辞書

struct RecordingStatus: Codable {
    let isUploaded: Bool
    let uploadAttempts: Int
    let lastUploadError: String?
}
```

### 保存データ例
```json
{
  "13-00.wav": {
    "isUploaded": true,
    "uploadAttempts": 1,
    "lastUploadError": null
  },
  "13-30.wav": {
    "isUploaded": false,
    "uploadAttempts": 2,
    "lastUploadError": "Network timeout"
  }
}
```

### 永続化操作
```swift
// 状態保存
func saveUploadStatus() {
    var statusDict: [String: RecordingStatus] = [:]
    
    // 既存データ読み込み
    if let data = UserDefaults.standard.data(forKey: uploadStatusKey),
       let existingDict = try? JSONDecoder().decode([String: RecordingStatus].self, from: data) {
        statusDict = existingDict
    }
    
    // 現在状態保存
    statusDict[fileName] = RecordingStatus(
        isUploaded: isUploaded,
        uploadAttempts: uploadAttempts,
        lastUploadError: lastUploadError
    )
    
    if let data = try? JSONEncoder().encode(statusDict) {
        UserDefaults.standard.set(data, forKey: uploadStatusKey)
    }
}
```

## UI設計仕様

### メイン画面構成
1. **ナビゲーションバー**: アプリタイトル "WatchMe"、左上にユーザーアイコンメニュー
2. **ステータス部**: 接続状況とアップロード進捗
3. **録音制御部**: 録音開始/停止ボタン
4. **統計部**: 総録音数、アップロード済み数、待機数
5. **ファイル一覧部**: 録音ファイルの詳細一覧
6. **フッター部**: 開発・テスト用機能（サーバーURL設定、接続テスト）

### 録音中UI
```swift
VStack(spacing: 8) {
    Text("🔴 録音中...")
        .font(.headline)
        .foregroundColor(.red)
    
    Text(audioRecorder.formatTime(audioRecorder.recordingTime))
        .font(.title2)
        .fontWeight(.bold)
        .foregroundColor(.red)
    
    Text(audioRecorder.getCurrentSlotInfo())
        .font(.caption)
        .foregroundColor(.secondary)
}
```

### ファイル一覧項目
```swift
HStack {
    VStack(alignment: .leading) {
        Text(recording.fileName)           // ファイル名
        Text(recording.fileSizeFormatted) // ファイルサイズ
        Text("アップロード: \(recording.isUploaded ? "✅" : "❌")") // 状態
        if recording.uploadAttempts > 0 {
            Text("試行: \(recording.uploadAttempts)/3") // 試行回数
        }
    }
    
    Spacer()
    
    // アップロードボタン or リセットボタン
    if recording.canUpload {
        Button("📤") { networkManager.uploadRecording(recording) }
    } else if !recording.isUploaded {
        Button("🔄") { recording.resetUploadStatus() }
    }
    
    // 削除ボタン
    Button("🗑️") { audioRecorder.deleteRecording(recording) }
}
```

## セットアップ手順

### 1. 開発環境要件
- **Xcode**: 15.0以上
- **iOS SDK**: 18.0以上
- **Swift**: 5.9以上
- **対象iOS**: 18.5以上

### 2. プロジェクト作成
```bash
# 新規プロジェクト作成
# Xcode > File > New > Project
# iOS > App > SwiftUI
```

### 3. 依存関係追加
**Supabase Swift ライブラリ**をプロジェクトに追加：
```
1. Xcode > File > Add Package Dependencies
2. URL: https://github.com/supabase/supabase-swift
3. Version: 2.5.1以上
4. Target: ios_watchme_v9に追加
```

### 4. ファイル構成
以下のファイルを作成・配置：
- `ios_watchme_v9App.swift`
- `MainAppView.swift`
- `LoginView.swift`
- `ContentView.swift`
- `SupabaseAuthManager.swift`
- `DeviceManager.swift`
- `RecordingModel.swift`
- `AudioRecorder.swift`
- `NetworkManager.swift`
- `ConnectionStatus.swift`

### 5. Info.plist設定
```xml
<key>NSMicrophoneUsageDescription</key>
<string>このアプリは音声録音のためにマイクロフォンアクセスが必要です</string>
```

### 6. サーバー設定
NetworkManager.swiftの`serverURL`を適切なエンドポイントに設定：
```swift
@Published var serverURL: String = "https://api.hey-watch.me"
```

### 7. ビルド・実行
```bash
xcodebuild -project ios_watchme_v9.xcodeproj \
           -scheme ios_watchme_v9 \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           build
```

## トラブルシューティング

### よくある問題と解決策

#### 1. マイクアクセス拒否
**症状**: 録音が開始されない
**解決**: 設定 > プライバシー > マイクロフォンでアプリを許可

#### 2. ネットワークエラー
**症状**: アップロードが失敗する
**解決**: 
- ネットワーク接続確認
- サーバーURL設定確認
- ファイアウォール設定確認

#### 3. ファイル分割されない
**症状**: 長時間録音で1ファイルのまま
**解決**:
- タイマー機能の動作確認
- スロット切り替えログ確認
- アプリのバックグラウンド実行制限確認

#### 4. アップロード状態がリセットされる
**症状**: アプリ再起動でアップロード済みが未処理になる
**解決**:
- UserDefaults読み込み処理確認
- JSON エンコード/デコード確認

#### 5. 同一スロット録音の重複問題
**症状**: 既存録音が残り、重複ファイルが発生
**解決**:
- `handleExistingRecording()`メソッドの動作確認
- 物理ファイル削除権限の確認
- UserDefaults状態クリア処理の確認
- ログ出力で上書き処理の実行状況を確認

### デバッグログ確認
```swift
// 録音関連ログ
print("🎙️ 録音開始 - スロット: \(currentSlot)")
print("🔄 スロット切り替え: \(oldSlot) → \(newSlot)")
print("💾 スロット録音完了: \(fileName)")

// 同一スロット上書きログ
print("🔄 同一スロット録音の自動上書き: \(fileName)")
print("📁 既存物理ファイル削除: \(fileURL.path)")
print("✅ 上書き準備完了 - 新録音を開始します")

// アップロード関連ログ
print("🚀 アップロード開始: \(recording.fileName)")
print("✅ アップロード成功: \(recording.fileName)")
print("❌ アップロード失敗: \(error)")

// ファイル管理ログ
print("📋 読み込み完了: \(recordings.count)個のファイル")
print("🗑️ ファイル削除: \(recording.fileName)")
```

## ファイル上書き仕様

### 同一スロット録音の処理
WatchMeアプリでは、同じ時間スロット（例：13-00.wav）で録音が開始された場合、**自動的に上書き**されます。

#### 上書き処理の流れ
1. **既存ファイル検出**: 同一ファイル名の録音データを検出
2. **物理ファイル削除**: 既存のWAVファイルを完全削除
3. **メタデータクリア**: アップロード状態をUserDefaultsから削除
4. **リスト更新**: 録音リストから既存データを除去
5. **新録音開始**: クリーンな状態で新しい録音を開始

#### 実装コード
```swift
// AudioRecorder.swift: handleExistingRecording()
private func handleExistingRecording(fileName: String) {
    if let existingIndex = recordings.firstIndex(where: { $0.fileName == fileName }) {
        let existingRecording = recordings[existingIndex]
        print("🔄 同一スロット録音の自動上書き: \(fileName)")
        
        // 既存ファイルの物理削除
        let fileURL = existingRecording.getFileURL()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
            print("📁 既存物理ファイル削除: \(fileURL.path)")
        }
        
        // アップロード状態クリア（UserDefaultsからも削除）
        clearUploadStatus(fileName: fileName)
        
        // リストから削除
        recordings.remove(at: existingIndex)
        pendingRecordings.removeAll { $0.fileName == fileName }
        
        print("✅ 上書き準備完了 - 新録音を開始します")
    }
}
```

#### 処理例とログ出力
```
シナリオ: 同一スロット（13-00.wav）での録音重複

ログ出力例:
🔄 同一スロット録音の自動上書き: 13-00.wav
   - 既存ファイル作成日時: 2025-06-23 13:00:00
   - 既存ファイルサイズ: 1.2 MB
   - 既存アップロード状態: 済み
📁 既存物理ファイル削除: /Documents/13-00.wav
✅ 上書き準備完了 - 新録音を開始します
🔍 新規スロット録音開始:
   - スロット: 13-00
   - ファイル名: 13-00.wav
   - 保存パス: /Documents/13-00.wav
```

#### 重要な特徴
- **確認プロンプトなし**: ユーザーへの確認なしで自動実行
- **完全クリーンアップ**: 物理ファイル・メタデータ・永続化状態をすべて削除
- **システム要件**: ファイル名が時間スロットの重要な位置要素のため上書きが必須
- **データ整合性**: 新録音開始前にすべての既存データを完全削除

#### サーバー側処理
- **クラウド側の重複処理**: EC2サーバー（watchme-vault-api）の仕様に完全委任
- **iOS側の責任範囲**: ローカルファイルの上書き処理のみ
- **サーバー実装**: 同一ファイル名での上書き・履歴管理はサーバー側で制御

## Supabase認証・デバイス登録仕様

### 認証フロー
```
1. アプリ起動
   ↓
2. 保存された認証状態確認（UserDefaults）
   ↓ 認証済み
3. MainAppView → ContentView（メイン画面）
   ↓ 未認証
4. LoginView（ログイン画面）
   ↓ ログイン成功
5. デバイス登録処理
   ↓
6. ContentView（メイン画面）
```

### デバイス登録データベース構造
```sql
CREATE TABLE devices (
    device_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform_identifier TEXT NOT NULL,
    device_type TEXT,
    platform_type TEXT NOT NULL,
    owner_user_id UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    
    CONSTRAINT unique_platform_owner 
        UNIQUE (platform_identifier, owner_user_id)
);
```

### Supabase設定例
```swift
// SupabaseAuthManager.swift / DeviceManager.swift
private let supabaseURL = "https://your-project.supabase.co"
private let supabaseAnonKey = "your-anon-key"

private let supabase = SupabaseClient(
    supabaseURL: URL(string: supabaseURL)!,
    supabaseKey: supabaseAnonKey
)
```

### デバイス登録UPSERT実装
```swift
func registerDeviceToSupabase(platformIdentifier: String, ownerUserID: String?) {
    Task { @MainActor in
        do {
            let deviceData = DeviceInsert(
                platform_identifier: platformIdentifier,
                device_type: "ios",
                platform_type: "iOS",
                owner_user_id: ownerUserID
            )
            
            // UPSERT: 既存レコードがあれば更新、なければ作成
            let response: [Device] = try await supabase
                .from("devices")
                .upsert(deviceData)
                .select()
                .execute()
                .value
                
            if let device = response.first {
                saveSupabaseDeviceRegistration(
                    deviceID: device.device_id,
                    platformIdentifier: platformIdentifier
                )
                print("✅ デバイス情報を取得/登録完了: \(device.device_id)")
            }
        } catch {
            print("❌ デバイス情報取得エラー: \(error)")
        }
    }
}
```

### 認証状態永続化
```swift
// UserDefaults保存キー
private let userKey = "supabase_user"
private let deviceIDKey = "watchme_device_id"
private let isRegisteredKey = "watchme_supabase_registered"

// 認証情報保存
func saveUserToDefaults(_ user: SupabaseUser) {
    let data = try JSONEncoder().encode(user)
    UserDefaults.standard.set(data, forKey: userKey)
}

// デバイス情報保存
func saveSupabaseDeviceRegistration(deviceID: String, platformIdentifier: String) {
    UserDefaults.standard.set(deviceID, forKey: deviceIDKey)
    UserDefaults.standard.set(true, forKey: "watchme_supabase_registered")
}
```

## v9.4アップデート（最新）

### UI・UX改善
- **自動アップロード機能削除**: 安定性向上のため手動アップロードのみに変更
- **左上ユーザーアイコンメニュー**: ユーザー情報・デバイス情報・ログアウト機能を統合
- **フッターエリア新設**: 開発・テスト用機能（サーバーURL設定・接続テスト）を最下部に移動
- **アップロード成功時の自動ファイル削除**: ストレージ容量節約のため実装
- **「次のスロット」表示削除**: UI簡素化のため削除

### 改善された操作フロー
1. **録音**: 従来通り30分単位で自動分割
2. **手動アップロード**: 個別ファイルまたは一括アップロードをユーザーが選択
3. **自動削除**: アップロード成功後にファイルが自動削除されストレージを節約
4. **ユーザー管理**: 左上アイコンからアカウント情報に簡単アクセス

## 拡張可能性

### 追加機能候補
1. **音声品質設定**: サンプルレート・ビット深度の変更
2. **バックアップ機能**: 複数サーバーへの同時アップロード
3. **音声再生機能**: アプリ内での録音再生
4. **音声解析**: 音量レベル・無音検出
5. **クラウド同期**: 複数デバイス間でのファイル同期

### API拡張
```swift
// 音声メタデータ送信
struct AudioMetadata: Codable {
    let duration: TimeInterval
    let averageVolume: Double
    let peakVolume: Double
    let silencePercentage: Double
}
```

## セキュリティ考慮事項

### データ保護
- **通信暗号化**: HTTPS通信でデータ暗号化
- **ローカル暗号化**: 機密データのKeychain保存検討
- **ユーザーID管理**: UUID使用による匿名化

### プライバシー
- **マイク許可**: 明示的な許可取得
- **データ最小化**: 必要最小限のデータ収集
- **削除機能**: ユーザーによるデータ削除権限

## ライセンス

このプロジェクトは [ライセンス名] の下でライセンスされています。

## 開発者情報

- **作成者**: Kaya Matsumoto
- **作成日**: 2025年6月11日
- **最終更新**: 2025年7月7日
- **バージョン**: v9.3 - デバイス主導型アーキテクチャへの重要変更

## 更新履歴

### v9.3 (2025年7月7日) **【重要アップデート - 手動アップロード化】**
- **🎯 デバイス主導型アーキテクチャへの変更**:
  - X-File-Pathヘッダー機能を実装
  - デバイスが保存パスを完全制御する新方式
  - 形式: `device_id/YYYY-MM-DD/HH-MM.wav`
  - サーバー側はクライアント指定パスで無条件保存

- **🔄 バックデート・まとめ送信対応**:
  - 過去日付のファイルアップロード可能
  - ネットワーク復旧時の一括送信対応
  - 時系列順序に依存しない柔軟な運用

- **⚙️ SlotTimeUtilityクラス新規追加**:
  - 時刻スロット生成ロジックの統一化
  - AudioRecorderとNetworkManagerで共通利用
  - JST（日本標準時）ベースの一元管理

- **🔒 セキュリティ強化**:
  - パストラバーサル攻撃防御
  - 正規表現による厳密なパス形式検証
  - サーバー側での包括的なエラーハンドリング

- **✂️ 自動アップロード機能の削除**:
  - 安定性重視のため自動アップロード機能を完全削除
  - 手動アップロードのみに変更（個別・一括対応）
  - ユーザーが明示的にアップロードタイミングを制御
  - UI表示とメッセージを手動アップロード用に更新

- **📊 システム位置づけの明確化**:
  - WatchMeプロジェクトの中核データ収集システムとして位置づけ
  - デバイス → Vault API → 解析エンジン → ダッシュボードの流れを確立

### v9.2 (2025年7月6日)
- **新機能**: UploadManagerクラスを追加し、アップロードキューシステムを実装
  - Time blockをまたいだ録音時のリアルタイムアップロード対応
  - スロット切り替え時に完了したファイルを即座にバックグラウンドアップロード
  - アップロードタスクの順次処理により競合を回避
  - 自動リトライ機能（最大3回）とタイムアウト処理（120秒）
  - アップロード進捗とキュー状態のリアルタイム表示

- **改善点**: NetworkManagerのエラーハンドリング強化
  - HTTPステータスコード別の詳細なエラーメッセージ
  - ネットワークエラーの種類別判定（タイムアウト、接続不可など）
  - サーバーレスポンスのJSON解析とログ出力
  - アップロード時間の計測と表示

- **不具合修正**:
  - アップロード成功時に「失敗」と表示される問題を修正
  - 複数ファイルの同時アップロードによる状態競合を解消
  - アップロード状態の永続化とUI表示の同期を改善

- **既知の問題（要修正）**:
  - **UploadManagerキューシステムが正常に動作しない**: ファイルがキューに追加されても実際のアップロード処理が実行されない
  - **自動アップロード機能が不安定**: 録音停止時の自動アップロードが期待通りに動作しない
  - **手動アップロードは正常動作**: 個別ファイルの手動アップロードボタンは正常に機能する

## サーバー側挙動調査結果（2025年7月6日）

### watchme-vault-api サーバー仕様

**検証済みエンドポイント**:
- **アップロードURL**: `https://api.hey-watch.me/upload`
- **メソッド**: POST (multipart/form-data)
- **正常レスポンス**: HTTP 200 + JSON形式レスポンス
- **ファイル上書き**: 同一ファイル名での再アップロード対応済み

#### サーバー挙動の詳細

1. **正常アップロード**:
   ```
   HTTP/1.1 200 OK
   Content-Type: application/json
   
   {
     "status": "success",
     "message": "File uploaded successfully",
     "file_id": "recording_20250706_1400_user12345",
     "uploaded_at": "2025-07-06T14:01:23Z"
   }
   ```

2. **重複ファイル処理**: 
   - サーバー側で同一ファイル名の上書き処理を実装済み
   - クライアント側の重複チェックは不要
   - 既存ファイルでも常に200レスポンスを返す

3. **エラーレスポンス例**:
   - **400 Bad Request**: パラメータ不足・形式不正
   - **401 Unauthorized**: 認証情報無効（現在は未実装）
   - **403 Forbidden**: 権限不足（現在は未実装）
   - **413 Payload Too Large**: ファイルサイズ制限超過

#### 必須パラメータ検証結果

| パラメータ | 要求度 | 検証結果 | 備考 |
|---|---|---|---|
| user_id | 必須 | ✅ 正常動作 | Supabase認証済みユーザーID使用推奨 |
| device_id | 必須 | ✅ 正常動作 | Supabaseデバイス登録必須 |
| timestamp | 必須 | ✅ 正常動作 | ISO8601形式タイムスタンプ |
| file | 必須 | ✅ 正常動作 | WAV形式、最大サイズ未確認 |

#### タイムアウト・接続テスト結果

- **接続テスト**: `/health` エンドポイント無し、`/upload` で代替確認
- **レスポンス時間**: 平均2-5秒（ファイルサイズにより変動）
- **タイムアウト設定**: 120秒で適切
- **リトライ上限**: 3回で適切

## 現時点でのアップロードシステム仕様（v9.2）

### 🟢 正常動作する機能

#### 1. 手動個別アップロード
```swift
// RecordingRowView.swift内の個別アップロードボタン
Button(action: {
    networkManager?.uploadRecording(recording)
}) {
    // アップロードボタンUI
}
```

**動作確認済み**:
- ✅ 新規ファイルのアップロード
- ✅ アップロード済みファイルの再送信（サーバー側で上書き処理）
- ✅ エラー時のリトライ機能（最大3回）
- ✅ アップロード状態の永続化（UserDefaults）
- ✅ 詳細なログ出力とエラーハンドリング

#### 2. NetworkManager基本機能
```swift
// NetworkManager.swift - アップロード制御
func uploadRecording(_ recording: RecordingModel) {
    // 基本チェックのみ実行
    guard recording.fileExists() else { return }
    guard recording.uploadAttempts < 3 else { return }
    // アップロード済みでも実行可能（サーバー側で上書き）
}
```

**検証済み動作**:
- ✅ multipart/form-data形式のリクエスト構築
- ✅ HTTPステータスコード別エラーハンドリング（200-599）
- ✅ ネットワークエラーの詳細分析（タイムアウト、接続不可等）
- ✅ アップロード進捗表示とタイムアウト処理（120秒）
- ✅ JSON/テキストレスポンスの解析と詳細ログ出力

#### 3. 認証・デバイス登録システム
- ✅ Supabase認証によるユーザー管理
- ✅ デバイス自動登録（UPSERT方式）
- ✅ 認証状態の永続化（UserDefaults）

### 🔴 問題のある機能

#### 1. UploadManagerキューシステム

**実装済みだが機能しない部分**:
```swift
// UploadManager.swift - 期待される動作
func addToQueue(_ recording: RecordingModel) {
    let task = UploadTask(recording: recording)
    uploadQueue.append(task)  // ✅ キューへの追加は成功
    startProcessing()         // ❌ 処理が実際には実行されない
}
```

**問題の詳細**:
- **キュー追加**: ファイルは正常にキューに追加される
- **処理開始**: `startProcessing()` は呼ばれるが実際のアップロードが開始されない
- **ステータス監視**: NetworkManagerのステータス変化が正しく検知されない
- **タスク進行**: ペンディング状態から変化しない

**推定原因**:
1. **非同期処理の競合**: メインスレッドとバックグラウンドキューでの処理競合
2. **監視ロジックの複雑さ**: 複数のObservableObjectの状態同期問題
3. **Combineフレームワークの使用**: 複雑なリアクティブプログラミングによる予期しない動作

#### 2. 自動アップロード機能

**実装箇所**:
```swift
// ContentView.swift - 録音停止時の自動アップロード
Button(action: {
    audioRecorder.stopRecording()
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        autoUploadAllPendingRecordingsWithUploadManager()  // ❌ 不安定
    }
})
```

**問題の症状**:
- 録音停止後に呼び出されるがアップロードが開始されない
- UploadManagerキューの根本問題に起因
- 手動での一括アップロードボタンも同様の問題

#### 3. リアルタイムスロット切り替えアップロード

**実装箇所**:
```swift
// AudioRecorder.swift - スロット切り替え時の自動アップロード
private func performSlotSwitch() {
    if let completedRecording = finishCurrentSlotRecordingWithReturn() {
        UploadManager.shared.addToQueue(completedRecording)  // ❌ キューに追加されるが処理されない
    }
}
```

**期待される動作**: 30分境界でスロットが切り替わった際に完了したファイルを即座にバックグラウンドアップロード
**実際の動作**: ファイルはキューに追加されるが、アップロード処理が実行されない

### 📋 現時点での推奨使用方法

#### 推奨ワークフロー
1. **録音実行**: 正常に30分単位でファイル分割される
2. **手動アップロード**: 個別ファイルのアップロードボタンを使用
3. **状態確認**: アップロード済み（✅）マークで確認
4. **エラー時**: リセットボタン（🔄）でリトライ

#### 一時的な回避策
```swift
// UploadManagerを使わず、従来のNetworkManagerのみを使用
for recording in audioRecorder.recordings {
    if recording.canUpload {
        networkManager?.uploadRecording(recording)
        // 手動で0.5秒間隔をあけて順次実行
        Thread.sleep(forTimeInterval: 0.5)
    }
}
```

### 🔧 修正が必要な具体的項目

#### 1. UploadManagerキューシステムの根本的見直し

**現在の複雑な実装**:
- 複数のDispatchQueue使用
- Combineフレームワークでの状態監視
- 非同期処理の多重化

**推奨する簡素化案**:
- シンプルなfor-loop + DispatchQueue.asyncAfter
- NetworkManagerの完了コールバック使用
- 状態監視の単純化

#### 2. canUploadプロパティの見直し

**現在の制限**:
```swift
var canUpload: Bool {
    return !isUploaded && fileExists() && uploadAttempts < 3
}
```

**問題**: `!isUploaded` によりアップロード済みファイルの再送信を制限

**推奨修正**:
```swift
var canUpload: Bool {
    return fileExists() && uploadAttempts < 3  // isUploadedチェックを削除
}
```

#### 3. 自動削除機能の無効化

**現在の状態**: UploadManager内で自動削除が一時的に無効化済み
**理由**: ファイル管理の複雑化とデバッグの困難化を避けるため
**推奨**: 手動削除のみ対応し、自動削除は将来的な実装とする

### 🎯 今後の開発方針

#### 短期的修正（優先度: 高）
1. UploadManagerキューシステムの完全無効化
2. 従来のNetworkManager直接呼び出しへの復帰
3. 順次アップロード機能の再実装（シンプルなロジック）

#### 中期的改善（優先度: 中）
1. キューシステムの再設計（非Combineアプローチ）
2. バックグラウンドアップロード対応
3. アップロード進捗の精度向上

#### 長期的拡張（優先度: 低）
1. 音声品質設定対応
2. 複数サーバーバックアップ
3. クラウド同期機能

### 🚨 UI表示の混乱問題（2025年7月6日現在）

#### アップロード状態表示の不整合

**問題の症状**:
1. **アプリ再起動後の状態不整合**: 
   - アップロード成功済みファイルに赤い❌マークが表示される
   - 実際はサーバーに正常アップロード済みなのに「失敗」と表示

2. **ボタン表示の混乱**:
   - アップロード成功済み（✅緑チェックマーク）なのに「再送信」ボタンが表示される
   - アップロード失敗（❌赤マーク）なのにアップロードボタンが表示されない場合がある

3. **情報とアクションの不一致**:
   - 表示されている状態情報と実行可能なアクション（ボタン）が一致しない
   - ユーザーが何をすべきかが分からない状態

#### 具体的な表示例

```
ファイル: 14-00.wav
状態: アップロード: ❌  <-- 実際は成功済みなのに失敗表示
ボタン: [📤 アップロード] <-- 成功済みなら「再送信」であるべき
```

```
ファイル: 14-30.wav  
状態: アップロード: ✅  <-- 成功表示は正しい
ボタン: [🔄 再送信]     <-- 成功済みなら再送信ボタンは適切だが表示が紛らわしい
```

#### 根本原因の推定

1. **永続化状態の同期問題**:
   ```swift
   // RecordingModel.swift - loadUploadStatus()
   private func loadUploadStatus() {
       // UserDefaultsからの状態復元が正しく動作していない可能性
   }
   ```

2. **アップロード完了時の状態更新タイミング**:
   ```swift
   // NetworkManager.swift - アップロード成功時
   recording.markAsUploaded()  // この更新がUserDefaultsに正しく保存されていない可能性
   ```

3. **UI更新ロジックの複雑さ**:
   ```swift
   // RecordingRowView.swift - ボタン表示ロジック
   if recording.fileExists() && recording.uploadAttempts < 3 {
       // 複雑な条件分岐によりボタン表示が不正確
   }
   ```

#### 修正が必要な具体的項目

**優先度: 高（次回修正必須）**

1. **状態永続化の確実性向上**:
   - `RecordingModel.saveUploadStatus()` の動作確認
   - UserDefaultsへの保存が確実に実行されているかの検証
   - アプリ再起動時の状態復元ロジックの見直し

2. **UI表示ロジックの統一**:
   ```swift
   // 推奨する統一ロジック
   var displayStatus: String {
       if isUploaded {
           return "✅ アップロード済み"
       } else if uploadAttempts > 0 {
           return "❌ 失敗（試行: \(uploadAttempts)/3）"
       } else {
           return "⏳ 未処理"
       }
   }
   
   var availableAction: String {
       if isUploaded {
           return "再送信"
       } else if uploadAttempts >= 3 {
           return "リセット"
       } else {
           return "アップロード"
       }
   }
   ```

3. **状態とアクションの整合性確保**:
   - 表示されている状態と実行可能なアクションを必ず一致させる
   - アップロード済みファイルは明確に「再送信」として扱う
   - 失敗ファイルは明確に「リトライ」として扱う

4. **デバッグ用状態確認機能**:
   ```swift
   // デバッグ用：現在の状態を詳細表示
   func debugCurrentState() -> String {
       return """
       ファイル: \(fileName)
       isUploaded: \(isUploaded)
       uploadAttempts: \(uploadAttempts)
       UserDefaults状態: \(getUserDefaultsStatus())
       ファイル存在: \(fileExists())
       """
   }
   ```

#### ユーザー体験への影響

- **混乱**: 何が成功で何が失敗かが分からない
- **不信**: アプリの表示が信頼できない
- **操作ミス**: 不要な再アップロードや操作の実行
- **効率低下**: 状態確認に余計な時間がかかる

**次回修正時の必須チェック項目**:
- [ ] アップロード成功後のUserDefaults保存確認
- [ ] アプリ再起動後の状態復元確認
- [ ] UI表示とボタンアクションの整合性確認
- [ ] 各状態での表示メッセージの統一

### v9.1 (2025年7月5日)
- Supabase認証・デバイス登録機能追加

---

このREADMEは、WatchMe アプリの完全な技術仕様書として、同等のアプリケーション開発に必要なすべての情報を含んでいます。