# WatchMe - iOS 録音アプリ

## 概要

WatchMe は、音声を30分間隔で自動分割して録音し、AWS EC2上の`watchme-vault-api`サーバーに自動アップロードするiOSアプリケーションです。長時間の録音でも確実にファイル分割され、ネットワーク環境に関係なく安定したデータ保存を実現します。

## 主要機能

### 🎙️ 録音機能
- **30分自動分割録音**: 正確な時刻境界（毎時0分・30分）でファイル分割
- **連続録音対応**: 何時間録音しても30分単位のファイルが生成される
- **高品質録音**: リニアPCM 16kHz, 16bit, モノラル形式
- **リアルタイム録音時間表示**: 0.1秒間隔での時間更新
- **自動上書き録音**: 同一時間スロットは確認なしで自動上書き
- **完全クリーンアップ**: 物理ファイル・メタデータ・アップロード状態を完全削除

### ☁️ クラウド連携機能
- **Supabase認証**: メール・パスワードによるユーザー認証システム
- **デバイス登録**: Supabaseデータベースへの自動デバイス登録・管理
- **自動アップロード**: 録音完了時に自動的にサーバーアップロード
- **状態永続化**: アップロード状態をUserDefaultsで永続保存
- **リトライ機能**: 失敗時の自動リトライ（最大3回まで）
- **進捗表示**: アップロード進捗のリアルタイム表示

### 📱 ユーザビリティ
- **統計情報表示**: 総録音数、アップロード済み数、待機数の表示
- **ファイル管理**: ファイルサイズ、作成日時、エラー情報の詳細表示
- **ユーザーID管理**: カスタマイズ可能なユーザー識別子
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
├── NetworkManager.swift            # クラウド通信・アップロード
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

#### NetworkManager
```swift
class NetworkManager: ObservableObject {
    @Published var serverURL: String = "https://api.hey-watch.me"
    @Published var connectionStatus: ConnectionStatus
    @Published var currentUserID: String
    @Published var uploadProgress: Double
    @Published var currentUploadingFile: String?
}
```

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

#### ヘッダー
```http
Content-Type: multipart/form-data; boundary={UUID}
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

#### パラメーター詳細

| パラメーター | 型 | 必須 | 説明 | 例 |
|---|---|---|---|---|
| user_id | String | ○ | ユーザー識別子（認証済みUser ID） | `164cba5a-dba6-4cbc-9b39-4eea28d98fa5` |
| timestamp | String | ○ | ISO8601形式の録音作成日時 | `2025-06-24T13:00:00Z` |
| device_id | String | ○ | Supabase登録済みデバイスID | `device_uuid_12345` |
| file | Binary | ○ | WAV形式の音声ファイル | バイナリデータ |

### レスポンス仕様

#### 成功レスポンス
```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "status": "success",
  "message": "File uploaded successfully",
  "file_id": "recording_20250624_1300_user12345",
  "uploaded_at": "2025-06-24T13:01:23Z"
}
```

#### エラーレスポンス
```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

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
1. **ヘッダー部**: アプリタイトル "WatchMe"
2. **ステータス部**: 接続状況とアップロード進捗
3. **設定部**: サーバーURL・ユーザーID表示・変更
4. **録音制御部**: 録音開始/停止ボタン、現在スロット情報
5. **統計部**: 総録音数、アップロード済み数、待機数
6. **ファイル一覧部**: 録音ファイルの詳細一覧

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
- **最終更新**: 2025年7月5日
- **バージョン**: v9.1 - Supabase認証・デバイス登録機能追加

---

このREADMEは、WatchMe アプリの完全な技術仕様書として、同等のアプリケーション開発に必要なすべての情報を含んでいます。