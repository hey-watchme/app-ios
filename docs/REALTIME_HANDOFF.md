# Supabase Realtime実装 引き継ぎドキュメント

**作成日**: 2025-10-12
**最終更新**: 2025-10-12

---

## 📊 実装概要

### 目的
Lambda処理完了後、iOSアプリに自動的にデータ更新を通知し、5分キャッシュ問題を解決する

### アーキテクチャ
```
録音完了 → Lambda処理（1-3分） → dashboard_summary更新
  ↓ (Supabase Realtime)
iOS App → 今日のキャッシュクリア → 最新データ取得
```

---

## ✅ 完了した作業

### 1. iOS側の実装（SimpleDashboardView.swift）
- Supabase Realtime V2 APIを使用
- dashboard_summaryテーブルの更新を監視
- 更新検知時に今日のキャッシュをクリア
- デバイス切り替え時の再購読対応

**主要コード（SimpleDashboardView.swift:949-991）:**
```swift
@State private var realtimeChannel: RealtimeChannelV2?

func subscribeToRealtimeUpdates() {
    let channel = supabaseClient.channel("dashboard-updates-\(deviceId)")

    _ = channel.onPostgresChange(
        AnyAction.self,
        schema: "public",
        table: "dashboard_summary",
        filter: "device_id=eq.\(deviceId)"
    ) { payload in
        Task { @MainActor in
            self.handleDashboardUpdate(payload)
        }
    }

    realtimeChannel = channel

    Task {
        await channel.subscribe()
        print("✅ [Realtime] 購読完了")
    }
}
```

### 2. Supabase Database側の設定
**設定済み：**
- dashboard_summary: ✅
- dashboard: ✅
- behavior_summary: ✅
- emotion_opensmile_summary: ✅

**実行済みSQL:**
```sql
ALTER TABLE public.dashboard_summary REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.dashboard_summary;

ALTER TABLE public.dashboard REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.dashboard;

ALTER TABLE public.behavior_summary REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.behavior_summary;

ALTER TABLE public.emotion_opensmile_summary REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.emotion_opensmile_summary;
```

### 3. TabViewの実装ミス修正
**問題:** 全SimpleDashboardViewが同じ`$selectedDate`を共有

**解決:** 各ビューに固有の`date: Date`プロパティを追加

---

## 🐛 発見した問題と修正

### 問題: "You cannot call postgresChange after joining the channel"

**原因:**
`subscribe()`を呼んだ後に`onPostgresChange`を設定していた

**修正（2025-10-12）:**
`onPostgresChange`を`subscribe()`の**前**に呼ぶように順番を変更

**修正前:**
```swift
_ = channel.onPostgresChange(...)
realtimeChannel = channel
Task { await channel.subscribe() }  // ❌ 順番が間違い
```

**修正後:**
```swift
_ = channel.onPostgresChange(...)  // ✅ subscribeの前
realtimeChannel = channel
Task { await channel.subscribe() }
```

---

## 🧪 テスト方法

### 1. 手動テスト（即座に確認）

**SQL実行:**
```sql
UPDATE public.dashboard_summary
SET updated_at = NOW()
WHERE device_id = '1cf67321-f1aa-4c51-b642-cbd7837c45d5'  -- 実際のdevice_idに置き換え
AND date = CURRENT_DATE;
```

**期待されるiOSログ:**
```
📡 [Realtime] dashboard_summaryの更新を購読開始: device_id=xxx
✅ [Realtime] 購読完了
✅ [Realtime] dashboard_summaryが更新されました
🗑️ [Realtime] 今日のキャッシュをクリア: 2025-10-12
🔄 [Realtime] 今日のデータを再取得
```

### 2. 実際の録音テスト

1. iOSアプリで録音実行
2. **2-4分待つ**（Lambda処理完了まで）
3. 自動的にダッシュボードが更新されることを確認

---

## 🔍 トラブルシューティング

### ログに「購読開始」が出ない場合

**確認項目:**
- [ ] SimpleDashboardViewが表示されているか
- [ ] deviceManagerにdevice_idが設定されているか
- [ ] `.onAppear`が呼ばれているか

**デバッグSQL:**
```sql
-- デバイスIDを確認
SELECT device_id, device_name FROM public.devices
WHERE user_id = '976decef-5e04-42b9-9e22-b8964fc908ce';
```

### ログに「購読完了」が出ない場合

**確認項目:**
- [ ] Supabase APIキーが正しいか（anon key）
- [ ] ネットワーク接続があるか
- [ ] Supabase Realtimeサービスが稼働しているか

**Supabaseダッシュボードで確認:**
1. Settings → API
2. 「anon public」キーを使用しているか確認

### 更新が届かない場合

**確認項目:**
- [ ] Replication設定が有効か
- [ ] dashboard_summaryテーブルにデータが実際に追加/更新されたか
- [ ] device_idのフィルター条件が正しいか

**確認SQL:**
```sql
-- Replication設定を確認
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND schemaname = 'public'
ORDER BY tablename;

-- 最新データを確認
SELECT device_id, date, updated_at
FROM dashboard_summary
ORDER BY updated_at DESC
LIMIT 5;
```

---

## 🚀 次のステップ（未実装）

### Phase 1: Row Level Security (RLS)の追加

**現状:** RLS無効（テスト中）

**本番環境で実装すべきポリシー:**
```sql
-- RLS有効化
ALTER TABLE public.dashboard_summary ENABLE ROW LEVEL SECURITY;

-- ユーザーが自分のデバイスデータのみ閲覧可能
CREATE POLICY "Users can view their own device data"
ON public.dashboard_summary
FOR SELECT
USING (
  device_id IN (
    SELECT device_id FROM public.devices WHERE user_id = auth.uid()
  )
);

-- Lambda用（service_roleは制限なし）
CREATE POLICY "Service role full access"
ON public.dashboard_summary
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
```

### Phase 2: 他のテーブルへの横展開

現在`dashboard_summary`のみ監視していますが、以下のテーブルも同様に実装可能：

**SimpleDashboardView.swiftに追加:**
```swift
// dashboardテーブルも監視（30分単位データ）
_ = channel.onPostgresChange(
    AnyAction.self,
    schema: "public",
    table: "dashboard",
    filter: "device_id=eq.\(deviceId)"
) { payload in
    Task { @MainActor in
        self.handleDashboardUpdate(payload)
    }
}
```

### Phase 3: エラーハンドリングの強化

**実装例:**
```swift
Task {
    do {
        await channel.subscribe()
        print("✅ [Realtime] 購読完了")
    } catch {
        print("❌ [Realtime] 購読失敗: \(error)")
        // リトライロジック
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        subscribeToRealtimeUpdates()
    }
}
```

---

## 📚 参考資料

- Supabase Realtime V2 Migration Guide: https://github.com/supabase-community/supabase-swift/blob/main/docs/migrations/RealtimeV2%20Migration%20Guide.md
- Supabase Realtime Docs: https://supabase.com/docs/guides/realtime
- PostgreSQL Logical Replication: https://www.postgresql.org/docs/current/logical-replication.html

---

## 📝 関連ファイル

### iOS
- `SimpleDashboardView.swift:945-1033` - Realtime購読実装
- `ContentView.swift:67-68` - TabView修正
- `UserAccountManager.swift:16-38` - SupabaseClientManager

### ドキュメント
- `docs/TECHNICAL.md:623-731` - リアルタイム更新システムの技術詳細

### サーバー
- `/projects/watchme/server-configs/PROCESSING_ARCHITECTURE.md` - Lambda処理フロー
- `/projects/watchme/server-configs/lambda-functions/watchme-audio-worker/` - Lambda関数

---

**最終更新者:** Claude
**ステータス:** 修正完了・テスト待ち
