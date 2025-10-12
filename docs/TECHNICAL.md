# 技術リファレンス

WatchMe iOSアプリのアーキテクチャ、データベース設計、API仕様に関する技術的な詳細情報。

---

## アーキテクチャ

### 設計思想：ライフログツール

本アプリケーションは**観測対象の時間軸を正確に記録する**ことを最重要視しています。

#### 基本原則

1. **デバイス = 観測対象の時間軸**
   - デバイスは特定の人（観測対象）の生活を記録
   - デバイスが設置されている場所のタイムゾーンが基準
   - 観測対象が東京にいれば、朝7時の活動は「朝7時」として記録

2. **アカウント所有者の位置は無関係**
   - アカウント（ログインユーザー）は観測データを閲覧するだけ
   - アカウント所有者がどこにいても、デバイスのタイムゾーンで表示

3. **タイムゾーンの固定性**
   - デバイスのタイムゾーンは登録時に設定され、基本的に変更されない
   - 引っ越しなど恒久的な変更時のみ設定から変更可能

### アーキテクチャパターン

#### 環境オブジェクトパターン

SwiftUIの`@EnvironmentObject`を使用してSingle Source of Truthを実現：

```swift
@main
struct ios_watchme_v9App: App {
    @StateObject private var dataManager = SupabaseDataManager()
    @StateObject private var deviceManager = DeviceManager()
    @StateObject private var userAccountManager = UserAccountManager()

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(dataManager)
                .environmentObject(deviceManager)
                .environmentObject(userAccountManager)
        }
    }
}
```

#### ダッシュボードアーキテクチャ：完全分離型設計

**設計思想**: ダッシュボードと詳細画面で異なる最適化戦略を採用

##### ダッシュボード（SimpleDashboardView）
- **目的**: 頻繁なアクセスに対応、スワイプ体験の最適化
- **データ管理**: ローカル@Stateで管理
- **キャッシュ**: 5分間有効、最大15日分保持（LRU方式）
- **デバウンス**: スワイプ時300ms待機（連続スワイプ時の無駄なリクエスト防止）
- **トリガー**: `.task(id: LoadDataTrigger(date:deviceId:))`で日付/デバイス変更を検知

```swift
// ダッシュボードのデータ管理例
@State private var behaviorReport: BehaviorReport?
@State private var emotionReport: EmotionReport?
@State private var dashboardSummary: DashboardSummary?

// キャッシュヒット時は即座に表示、ミス時のみAPI呼び出し
if let cached = dataCache[cacheKey], Date().timeIntervalSince(cached.timestamp) < 300 {
    // キャッシュから表示（5分以内）
} else {
    // API呼び出し
}
```

##### 詳細画面（HomeView, BehaviorGraphView, EmotionGraphView）
- **目的**: 常に最新データを表示
- **データ管理**: 各画面が独自に@Stateで管理
- **キャッシュ**: なし（毎回取得）
- **トリガー**: `.task(id: selectedDate)`で画面表示時・日付変更時に取得

```swift
// 詳細画面のデータ取得例
.task(id: selectedDate) {
    await loadBehaviorData()  // 毎回最新データを取得
}

private func loadBehaviorData() async {
    let result = await dataManager.fetchAllReports(
        deviceId: deviceId,
        date: selectedDate,
        timezone: timezone
    )
    behaviorReport = result.behaviorReport
}
```

##### データソースの分離
- **SupabaseDataManager**: データ取得APIのみ提供（@Published削除）
- **各View**: 独自にデータを管理、お互いに依存しない
- **責任の明確化**: ダッシュボード=パフォーマンス、詳細=最新性

**メリット**:
1. ダッシュボードのキャッシュが詳細画面に影響しない
2. 詳細画面は常に最新データを表示
3. シンプルで保守しやすい設計

### 主要コンポーネント

#### 認証・データ管理

1. **UserAccountManager**
   - ユーザー認証とプロフィール管理
   - `public.users`テーブルとの連携

2. **SupabaseAuthManager**
   - Supabase認証の低レベルAPI
   - セッション管理とトークンリフレッシュ

3. **DeviceManager**
   - デバイス選択と管理
   - タイムゾーン情報の提供

4. **SupabaseDataManager**
   - RPC関数を使用した効率的なデータ取得
   - `get_dashboard_data`で全グラフデータを一括取得
   - **データ取得APIのみ提供**（グローバル状態管理は各Viewに委譲）
   - `@Published var dailyBehaviorReport`等は削除（完全分離型設計）

#### UI/ナビゲーション

1. **ContentView**
   - TabViewによる日付スワイプナビゲーション
   - 過去1年分のデータ表示

2. **SimpleDashboardView**
   - ダッシュボード概要（カード形式）
   - 各グラフカードをタップでモーダル詳細表示
   - ローカル@Stateで高速キャッシュ管理
   - スワイプ体験の最適化（デバウンス + LRUキャッシュ）

3. **HomeView / BehaviorGraphView / EmotionGraphView**
   - 各種グラフの詳細表示
   - 独自にデータ取得（ダッシュボードから独立）
   - 画面表示時に常に最新データを取得

#### 音声録音

1. **AudioRecorder**
   - AVAudioRecorderを使用した録音機能
   - WAVフォーマット（16kHz/16bit/モノラル）
   - 30分間隔での自動録音
   - `spokenAudio`モードで音声会話に最適化

2. **NetworkManager**
   - ストリーミング方式によるメモリ効率的なアップロード
   - multipart/form-dataでのファイルアップロード

---

## データベース設計

### 重要：auth.usersへの直接参照禁止

- `auth.users`はSupabaseの内部テーブル（直接アクセス不可）
- すべての外部キー制約は`public.users(user_id)`を参照
- `public.users.user_id`は`auth.users.id`のコピーとして機能

### 主要テーブル

#### public.users（ユーザー情報）

```sql
CREATE TABLE public.users (
    user_id UUID PRIMARY KEY,  -- auth.users.idのコピー
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    avatar_url TEXT,
    newsletter_subscription BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### devices（デバイス情報）

```sql
CREATE TABLE devices (
    device_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_type TEXT NOT NULL,
    timezone TEXT NOT NULL,  -- IANAタイムゾーン識別子（例: Asia/Tokyo）
    subject_id UUID REFERENCES subjects(subject_id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### user_devices（ユーザーとデバイスの関連）

```sql
CREATE TABLE user_devices (
    user_id UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(device_id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('owner', 'viewer')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, device_id)
);
```

**RLSポリシー（必須）**:
```sql
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own device associations" ON user_devices
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own device associations" ON user_devices
    FOR INSERT WITH CHECK (auth.uid() = user_id);
```

#### subjects（観測対象情報）

```sql
CREATE TABLE subjects (
    subject_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    age INTEGER,
    gender TEXT,
    avatar_url TEXT,
    notes TEXT,
    created_by_user_id UUID REFERENCES public.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### subject_comments（観測対象へのコメント）

```sql
CREATE TABLE subject_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_id UUID NOT NULL REFERENCES subjects(subject_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    comment_text TEXT NOT NULL,
    date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### dashboard_summary（統合ダッシュボードデータ）

```sql
CREATE TABLE dashboard_summary (
    device_id UUID NOT NULL,
    date DATE NOT NULL,
    average_vibe REAL,                    -- 1日の平均気分スコア
    vibe_scores JSONB,                    -- 48個の時系列スコア配列（30分ごと）
    burst_events JSONB,                   -- バーストイベント配列（感情の急変点）
    insights TEXT,                        -- 1日のサマリーインサイト
    analysis_result JSONB,                -- 詳細な分析結果
    processed_count INTEGER,              -- 処理済みブロック数
    last_time_block TEXT,                 -- 最後に処理した時間ブロック
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (device_id, date)
);
```

#### notifications（通知）

```sql
CREATE TABLE notifications (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    user_id UUID NULL REFERENCES public.users(user_id) ON DELETE CASCADE,  -- NULLの場合はグローバル通知
    type TEXT NOT NULL,  -- 'global', 'personal', 'event'
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN NULL DEFAULT false,  -- パーソナル/イベント通知の既読フラグ
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT NOW(),
    triggered_by TEXT NULL,
    metadata JSONB NULL,
    PRIMARY KEY (id)
);
```

#### notification_reads（グローバル通知の既読管理）

```sql
CREATE TABLE notification_reads (
    user_id UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    notification_id UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
    read_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, notification_id)
);
```

---

## API仕様

### Vault API（録音アップロード）

**エンドポイント**: `https://api.hey-watch.me/upload`

```
POST /upload
Content-Type: multipart/form-data

Parameters:
- file: 音声ファイル (WAV形式)
- user_id: ユーザーID
- timestamp: 録音時刻 (ISO 8601形式、タイムゾーン情報付き)
  例: 2025-07-19T14:15:00+09:00
- metadata: デバイス情報とタイムスタンプを含むJSON
  {
    "device_id": "device_xxxxx",
    "recorded_at": "2025-07-19T14:15:00+09:00"
  }
```

**file_pathの構造**:
```
files/{device_id}/{YYYY-MM-DD}/{HH-MM}/audio.wav
```

- `device_id`: デバイスの識別子
- `YYYY-MM-DD`: デバイスのローカル日付
- `HH-MM`: 30分スロット（00-00, 00-30, ..., 23-30）

### Avatar Uploader API

**エンドポイント**: `http://3.24.16.82:8014`

```
POST /upload/user
POST /upload/subject

Headers:
- Authorization: Bearer {supabase_access_token}

Body (multipart/form-data):
- file: 画像ファイル（JPEG/PNG）
- user_id or subject_id: 対象のID

Response:
{
  "avatar_url": "https://watchme-avatars.s3.ap-southeast-2.amazonaws.com/..."
}
```

### Supabase RPC関数

#### get_dashboard_data

**重要**: このアプリケーションはRPC関数を使用して複数テーブルからデータを一括取得します。

```sql
CREATE OR REPLACE FUNCTION get_dashboard_data(
    p_device_id TEXT,
    p_date TEXT
)
RETURNS TABLE (
    dashboard_summary JSONB,
    behavior_report JSONB,
    emotion_report JSONB,
    subject_info JSONB,
    subject_comments JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT to_jsonb(t) FROM dashboard_summary t
         WHERE t.device_id = p_device_id::uuid AND t.date = p_date::date
         LIMIT 1) AS dashboard_summary,

        (SELECT to_jsonb(t) FROM behavior_summary t
         WHERE t.device_id = p_device_id::uuid AND t.date = p_date::date
         LIMIT 1) AS behavior_report,

        (SELECT to_jsonb(t) FROM emotion_opensmile_summary t
         WHERE t.device_id = p_device_id::uuid AND t.date = p_date::date
         LIMIT 1) AS emotion_report,

        (SELECT to_jsonb(s) FROM subjects s
         JOIN devices d ON s.subject_id = d.subject_id
         WHERE d.device_id = p_device_id::uuid
         LIMIT 1) AS subject_info,

        (SELECT jsonb_agg(to_jsonb(c.*)) FROM (
            SELECT sc.*, u.name, u.avatar_url
            FROM subject_comments sc
            JOIN subjects s ON sc.subject_id = s.subject_id
            JOIN devices d ON s.subject_id = d.subject_id
            JOIN public.users u ON sc.user_id = u.user_id
            WHERE d.device_id = p_device_id::uuid AND sc.date = p_date::date
            ORDER BY sc.created_at DESC
            LIMIT 50
        ) c) AS subject_comments;
END;
$$;
```

**iOS側での呼び出し**:
```swift
func fetchAllReports(deviceId: String, date: Date, timezone: TimeZone) async -> DashboardData {
    let dateString = formatDate(date, timezone: timezone)  // "YYYY-MM-DD"
    let params = ["p_device_id": deviceId, "p_date": dateString]

    let response: [RPCDashboardResponse] = try await supabase
        .rpc("get_dashboard_data", params: params)
        .execute()
        .value

    // DashboardDataに変換して返却
}
```

---

## データ処理パイプライン

```
[iOS App]
  ↓ 録音（30分ごと、デバイスのローカル時間）
  ↓
[Vault API]
  ↓ file_path生成: files/{device_id}/{date}/{time_slot}/audio.wav
  ↓
[S3 Storage]
  ↓
[Lambda Function] ← S3イベントで即座に起動
  ↓ すべてのデバイスのオーディオファイルを自動処理
  ↓
[Whisper API / AST API / SUPERB API]
  ↓ 並列処理で音声分析
  ↓ file_pathから日付とtime_blockを抽出
  ↓ 各APIが結果をデータベースに保存
  ↓
[ChatGPT API]
  ↓ 感情分析とスコア生成
  ↓
[dashboard_summary]
  ↓ 日次集計データ（48スロット）
  ↓
[iOS App]
  グラフ表示（デバイスのタイムゾーンで）
```

---

## タイムゾーン処理

### DeviceManagerの役割

```swift
class DeviceManager {
    // 選択中デバイスのタイムゾーン取得
    var selectedDeviceTimezone: TimeZone {
        // devicesテーブルのtimezoneカラムから取得
        // フォールバック: TimeZone.current
    }

    // デバイス用のCalendar生成
    var deviceCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = selectedDeviceTimezone
        return calendar
    }
}
```

### 実装ルール

1. **UTC変換の完全廃止**: データはデバイスのローカル時間で保存・処理
2. **Calendar.currentの使用禁止**: 常にデバイスのCalendarを使用
3. **タイムゾーンの明示的な管理**: 暗黙的なタイムゾーン使用を避ける

---

## 認証とセキュリティ

### Supabase認証の重要事項

#### ✅ 正しい実装

```swift
// 認証: Supabase SDKの標準メソッドを使用
let session = try await supabase.auth.signIn(email: email, password: password)

// データ取得: SDKのクエリビルダーを使用
let data: [MyModel] = try await supabase
    .from("table_name")
    .select()
    .eq("column", value: "value")
    .execute()
    .value
```

#### ❌ やってはいけないこと

```swift
// 手動でAPIを呼び出さない
URLSession.shared.dataTask(with: "supabaseURL/auth/v1/token") { ... }
URLSession.shared.dataTask(with: "supabaseURL/rest/v1/table") { ... }
```

### グローバルSupabaseクライアント

```swift
// SupabaseClientManager.swiftで定義
class SupabaseClientManager {
    static let shared = SupabaseClientManager()
    private(set) lazy var client: SupabaseClient = {
        SupabaseClient(
            supabaseURL: URL(string: "https://xxx.supabase.co")!,
            supabaseKey: "xxx"
        )
    }()
}

// 各クラスで使用
let supabase = SupabaseClientManager.shared.client
```

### RLS（Row Level Security）

新しいテーブルを作成する際は、必ずRLSポリシーを設定：

1. RLSを有効化
2. 適切なポリシーを設定（認証ユーザーのみアクセス可能など）
3. テストユーザーでアクセス確認

---

## パフォーマンス最適化

### アプリ起動時間

**実機での起動時間**: 約5秒（業界標準レベル）

- システム処理（dyldリンカー + ライブラリロード）: 約5秒
- アプリ初期化処理: 0.04秒
- 認証チェック処理: 0.01秒

### 実施した最適化

1. **Supabaseクライアントの遅延初期化**
   - Singleton + lazy初期化に変更
   - 初回API呼び出し時のみ初期化

2. **RPC関数による一括データ取得**
   - ネットワークリクエストが5回以上から1回に削減

3. **ストリーミングアップロード**
   - ファイル全体をメモリに読み込まない
   - 64KB単位のチャンクで読み込み

---

## 依存ライブラリ

1. **Supabase Swift** - 認証・データベース
2. **Mantis** - 画像トリミング
3. **Swift Crypto** - 暗号化処理
4. **Swift HTTP Types** - HTTP通信

---

## 開発ガイドライン

### NavigationViewの適切な使用

#### ✅ 推奨パターン

```swift
// モーダル内でのNavigationView使用
.sheet(isPresented: $showSheet) {
    NavigationView {
        ContentView()
            .navigationTitle("タイトル")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
    }
}
```

#### ❌ 避けるべきパターン

```swift
// NavigationViewの入れ子（ネスト）
NavigationView {
    NavigationLink(destination: NavigationView { ... })
}
```

### ストリーミングアップロード仕様

```swift
// 一時ファイルへの書き込み
let tempFileURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("\(UUID().uuidString).tmp")

// 64KBごとにストリーミングコピー
let bufferSize = 65536
while true {
    let chunk = audioFileHandle.readData(ofLength: bufferSize)
    if chunk.isEmpty { break }
    fileHandle.write(chunk)
}

// URLSessionUploadTaskでアップロード
let uploadTask = URLSession.shared.uploadTask(with: request, fromFile: tempFileURL)
```
