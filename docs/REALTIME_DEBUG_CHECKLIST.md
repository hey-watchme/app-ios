# Supabase Realtime デバッグチェックリスト

**作成日**: 2025-10-12
**ステータス**: 動作せず（調査中）

---

## 🚨 現状

### 問題
手動でdashboard_summaryテーブルを更新しても、iOSアプリに通知が届かない

### 実行済みの対応
- ✅ Supabase Database側のReplication設定完了（4テーブル）
- ✅ iOS側のRealtime購読実装完了
- ✅ `onPostgresChange`と`subscribe()`の順番修正
- ✅ ログで「購読開始」「購読完了」まで確認

### 未解決
- ❌ 実際の更新通知が届かない

---

## 📋 次のエンジニアがやるべきこと

### Step 1: 基本的な確認

#### 1-1. iOSログの詳細確認

**確認するログ:**
```
📡 [Realtime] dashboard_summaryの更新を購読開始: device_id=xxx
✅ [Realtime] 購読完了
```

**このログが出ていない場合:**
- SimpleDashboardViewが表示されていない
- deviceManagerにdevice_idが設定されていない
- subscribeToRealtimeUpdates()が呼ばれていない

**確認方法:**
```swift
// SimpleDashboardView.swift の .onAppear に追加
.onAppear {
    print("🔍 [DEBUG] SimpleDashboardView appeared")
    print("🔍 [DEBUG] Device ID: \(deviceManager.selectedDeviceID ?? "nil")")
    subscribeToRealtimeUpdates()
}
```

#### 1-2. Supabaseクライアントの接続状態確認

**追加するデバッグコード:**
```swift
// SimpleDashboardView.swift の subscribeToRealtimeUpdates() 内
func subscribeToRealtimeUpdates() {
    guard let deviceId = deviceManager.selectedDeviceID else {
        print("⚠️ [Realtime] デバイスIDが未選択のため購読をスキップ")
        return
    }

    unsubscribeFromRealtimeUpdates()

    print("📡 [Realtime] dashboard_summaryの更新を購読開始: device_id=\(deviceId)")

    let supabaseClient = SupabaseClientManager.shared.client

    // ✅ 追加：クライアント情報を確認
    print("🔍 [DEBUG] Supabase URL: \(supabaseClient.supabaseURL)")
    print("🔍 [DEBUG] API Key exists: \(supabaseClient.supabaseKey.isEmpty ? "NO" : "YES")")

    let channel = supabaseClient.channel("dashboard-updates-\(deviceId)")

    // ✅ 追加：チャネル名を確認
    print("🔍 [DEBUG] Channel name: dashboard-updates-\(deviceId)")

    _ = channel.onPostgresChange(
        AnyAction.self,
        schema: "public",
        table: "dashboard_summary",
        filter: "device_id=eq.\(deviceId)"
    ) { payload in
        print("🎉 [DEBUG] Payload received: \(payload)")  // ✅ 追加
        Task { @MainActor in
            self.handleDashboardUpdate(payload)
        }
    }

    realtimeChannel = channel

    Task {
        print("🔍 [DEBUG] Subscribing to channel...")  // ✅ 追加
        await channel.subscribe()
        print("✅ [Realtime] 購読完了")
    }
}
```

### Step 2: Supabase側の設定を再確認

#### 2-1. Replication設定の確認

```sql
-- 1. publicationにテーブルが含まれているか確認
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND schemaname = 'public'
AND tablename = 'dashboard_summary';

-- 期待される結果：
-- schemaname | tablename
-- -----------+------------------
-- public     | dashboard_summary

-- 2. Replica Identityの確認
SELECT
  c.relname as table_name,
  CASE c.relreplident
    WHEN 'd' THEN 'default'
    WHEN 'n' THEN 'nothing'
    WHEN 'f' THEN 'full'
    WHEN 'i' THEN 'index'
  END as replica_identity
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
AND c.relname = 'dashboard_summary';

-- 期待される結果：
-- table_name        | replica_identity
-- ------------------+-----------------
-- dashboard_summary | full
```

#### 2-2. RLSポリシーの確認

```sql
-- RLS有効化されているか確認
SELECT
  schemaname,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'dashboard_summary';

-- もしrls_enabled = true の場合、ポリシーを確認
SELECT * FROM pg_policies WHERE tablename = 'dashboard_summary';
```

**RLS有効でポリシーがない場合、一時的に無効化してテスト:**
```sql
ALTER TABLE public.dashboard_summary DISABLE ROW LEVEL SECURITY;
```

#### 2-3. Supabaseダッシュボードで確認

1. https://supabase.com/dashboard にアクセス
2. プロジェクト選択
3. **Database → Replication**
   - `dashboard_summary`が**Enabled**になっているか確認
4. **Logs → Realtime**
   - 接続ログがあるか確認
   - エラーログがないか確認

### Step 3: テーブル構造の確認

#### 3-1. device_idカラムの存在確認

```sql
-- dashboard_summaryテーブルのカラム一覧
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'dashboard_summary'
ORDER BY ordinal_position;

-- device_idカラムが存在するか確認
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'dashboard_summary'
AND column_name = 'device_id';
```

**もしdevice_idカラムが存在しない場合:**
- 別のカラム名（deviceId, device, device_uuid等）の可能性
- iOS側のフィルター条件を修正する必要あり

#### 3-2. 実際のデータ確認

```sql
-- dashboard_summaryテーブルのデータ確認
SELECT
  device_id,
  date,
  created_at,
  updated_at,
  overall_vibe_score
FROM public.dashboard_summary
WHERE device_id = '1cf67321-f1aa-4c51-b642-cbd7837c45d5'  -- iOSログから取得したdevice_id
ORDER BY updated_at DESC
LIMIT 5;
```

### Step 4: 別の監視方法をテスト

#### 4-1. フィルターなしでテスト

**SimpleDashboardView.swiftを一時的に修正:**
```swift
// フィルター条件を削除してテスト
_ = channel.onPostgresChange(
    AnyAction.self,
    schema: "public",
    table: "dashboard_summary"
    // filter: "device_id=eq.\(deviceId)"  // ← コメントアウト
) { payload in
    print("🎉 [DEBUG] Payload received (no filter): \(payload)")
    Task { @MainActor in
        self.handleDashboardUpdate(payload)
    }
}
```

**テスト:**
```sql
-- どのdevice_idでも更新してみる
UPDATE public.dashboard_summary
SET updated_at = NOW()
WHERE date = CURRENT_DATE
LIMIT 1;
```

#### 4-2. INSERTでテスト

UPDATEではなくINSERTで試す

```sql
-- 新しいレコードを挿入
INSERT INTO public.dashboard_summary (
  device_id,
  date,
  created_at,
  updated_at
) VALUES (
  '1cf67321-f1aa-4c51-b642-cbd7837c45d5',
  CURRENT_DATE,
  NOW(),
  NOW()
)
ON CONFLICT (device_id, date)
DO UPDATE SET updated_at = NOW();
```

### Step 5: Supabase Swift SDKのバージョン確認

#### 5-1. パッケージバージョン確認

```bash
# プロジェクトディレクトリで実行
cat Package.resolved | grep -A 5 "supabase-swift"
```

または

Xcode → File → Packages → Resolve Package Versions

#### 5-2. 最新版へのアップデート

もし古いバージョンの場合、最新版にアップデート：

Xcode → File → Packages → Update to Latest Package Versions

**推奨バージョン:** supabase-swift 2.5.0 以降

### Step 6: Realtime接続のデバッグ

#### 6-1. チャネルステータスの監視

```swift
// SimpleDashboardView.swift に追加
func subscribeToRealtimeUpdates() {
    // ... 既存のコード ...

    Task {
        print("🔍 [DEBUG] Subscribing to channel...")
        await channel.subscribe()
        print("✅ [Realtime] 購読完了")

        // ✅ 追加：チャネルステータスを監視
        Task {
            for await status in channel.status {
                print("📊 [Realtime] Channel status: \(status)")
            }
        }
    }
}
```

#### 6-2. ネットワークログの確認

Xcodeで：
1. Product → Scheme → Edit Scheme
2. Run → Arguments
3. Environment Variables に追加：
   - Name: `OS_ACTIVITY_MODE`
   - Value: `disable`（パフォーマンス向上）

または詳細ログを有効化：
   - Name: `SUPABASE_DEBUG`
   - Value: `1`

---

## 🔍 考えられる原因

### 原因1: Supabaseプロジェクトの設定
- Realtimeが有効化されていない（プランの問題）
- APIキーの権限不足

**確認方法:**
Supabaseダッシュボード → Settings → API
- 「Realtime enabled」がtrueか確認

### 原因2: ネットワークの問題
- WebSocket接続がブロックされている
- ファイアウォール/プロキシの問題

**確認方法:**
Safari/Chromeで以下にアクセス：
```
wss://qvtlwotzuzbavrzqhyvt.supabase.co/realtime/v1/websocket
```

WebSocket接続エラーが出る場合、ネットワーク問題

### 原因3: iOS側の実装ミス
- `@MainActor`の問題
- チャネル名の衝突
- メモリリーク（channelが解放されている）

**確認方法:**
```swift
// SimpleDashboardView.swift
deinit {
    print("⚠️ [DEBUG] SimpleDashboardView deinitialized")
    unsubscribeFromRealtimeUpdates()
}
```

### 原因4: データベーストリガーの問題
- Lambda関数がdashboard_summaryを更新していない
- 更新されているがタイムスタンプが変わっていない

**確認方法:**
```sql
-- Lambdaが最近データを書き込んだか確認
SELECT
  device_id,
  date,
  created_at,
  updated_at,
  NOW() - updated_at as time_since_update
FROM public.dashboard_summary
WHERE device_id = '1cf67321-f1aa-4c51-b642-cbd7837c45d5'
ORDER BY updated_at DESC
LIMIT 5;
```

---

## 🧪 最終デバッグテスト

すべてのチェックが完了したら、以下の完全なテストを実行：

### テスト1: 最小構成でテスト

**新しいテーブルを作成してテスト:**
```sql
-- テスト用テーブル作成
CREATE TABLE public.realtime_test (
  id SERIAL PRIMARY KEY,
  message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Replication設定
ALTER TABLE public.realtime_test REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.realtime_test;
```

**iOS側で監視:**
```swift
let channel = supabaseClient.channel("test-channel")

_ = channel.onPostgresChange(
    AnyAction.self,
    schema: "public",
    table: "realtime_test"
) { payload in
    print("🎉 TEST: Received payload: \(payload)")
}

Task {
    await channel.subscribe()
    print("✅ TEST: Subscribed")
}
```

**SQLでINSERT:**
```sql
INSERT INTO public.realtime_test (message) VALUES ('Hello Realtime!');
```

### テスト2: Supabase公式サンプルと比較

公式ドキュメントのサンプルコードと比較：
https://github.com/supabase-community/supabase-swift/blob/main/Examples/Examples/Realtime/RealtimeExample.swift

---

## 📚 参考資料

### 公式ドキュメント
- Supabase Realtime: https://supabase.com/docs/guides/realtime
- Supabase Swift SDK: https://github.com/supabase-community/supabase-swift
- Realtime V2 Migration: https://github.com/supabase-community/supabase-swift/blob/main/docs/migrations/RealtimeV2%20Migration%20Guide.md

### トラブルシューティング
- Supabase Community: https://github.com/supabase/supabase/discussions
- Discord: https://discord.supabase.com

---

## 📝 実装済みファイル

### iOS
- `SimpleDashboardView.swift:945-1033` - Realtime実装
- `UserAccountManager.swift:16-38` - SupabaseClientManager

### ドキュメント
- `docs/REALTIME_HANDOFF.md` - 引き継ぎドキュメント
- `docs/TECHNICAL.md:623-731` - 技術仕様

### Supabase Database
- dashboard_summary: Replication有効
- dashboard: Replication有効
- behavior_summary: Replication有効
- emotion_opensmile_summary: Replication有効

---

## ✅ 成功の判断基準

以下のログが出れば成功：

```
📡 [Realtime] dashboard_summaryの更新を購読開始: device_id=1cf67321-f1aa-4c51-b642-cbd7837c45d5
✅ [Realtime] 購読完了
✅ [Realtime] dashboard_summaryが更新されました
🗑️ [Realtime] 今日のキャッシュをクリア: 2025-10-12
🔄 [Realtime] 今日のデータを再取得
```

---

**最終更新**: 2025-10-12
**ステータス**: デバッグ中
**次のアクション**: Step 1から順番に確認
