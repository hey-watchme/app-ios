# Supabase Realtime 調査クイックスタート

**次のエンジニアへ：このファイルから開始してください**

---

## 🎯 現在の状況（30秒で理解）

- ✅ iOS側のコード実装完了
- ✅ Supabase Database側のReplication設定完了
- ✅ コンパイルエラーなし
- ❌ **実際の通知が届かない**

**やるべきこと：** なぜ通知が届かないのか原因特定

---

## 🚀 最初にやること（5分）

### 1. iOSアプリを起動してログ確認

Xcodeでアプリを実行し、以下のログが出ているか確認：

```
📡 [Realtime] dashboard_summaryの更新を購読開始: device_id=xxx
✅ [Realtime] 購読完了
```

**このログが出ていない場合：**
→ `SimpleDashboardView`が表示されていない
→ `REALTIME_DEBUG_CHECKLIST.md` の Step 1-1 へ

**ログが出ている場合：**
→ 次のステップへ

---

### 2. 手動でテーブルを更新

**SQL実行（Supabaseダッシュボード → SQL Editor）:**

```sql
-- iOSログから取得したdevice_idを使用
UPDATE public.dashboard_summary
SET updated_at = NOW()
WHERE device_id = '1cf67321-f1aa-4c51-b642-cbd7837c45d5'  -- ← iOSログから取得
AND date = CURRENT_DATE;
```

**iOSログに以下が出るか確認：**
```
✅ [Realtime] dashboard_summaryが更新されました
```

**出ない場合：**
→ **原因調査が必要**
→ `REALTIME_DEBUG_CHECKLIST.md` の Step 2 へ

---

## 🔍 主要な調査項目（優先順）

### 優先度 1: Supabase設定の確認

```sql
-- Replication設定を確認
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND tablename = 'dashboard_summary';

-- 結果が返ってこない場合、設定されていない
```

**修正SQL（結果が返ってこない場合）:**
```sql
ALTER TABLE public.dashboard_summary REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.dashboard_summary;
```

---

### 優先度 2: RLS（Row Level Security）の確認

```sql
-- RLS有効か確認
SELECT rowsecurity FROM pg_tables WHERE tablename = 'dashboard_summary';

-- trueの場合、一時的に無効化してテスト
ALTER TABLE public.dashboard_summary DISABLE ROW LEVEL SECURITY;
```

**再度手動UPDATE → iOSログ確認**

---

### 優先度 3: デバッグコードの追加

**SimpleDashboardView.swift の subscribeToRealtimeUpdates() を修正:**

```swift
_ = channel.onPostgresChange(
    AnyAction.self,
    schema: "public",
    table: "dashboard_summary",
    filter: "device_id=eq.\(deviceId)"
) { payload in
    print("🎉🎉🎉 [DEBUG] PAYLOAD RECEIVED: \(payload)")  // ← 追加
    Task { @MainActor in
        self.handleDashboardUpdate(payload)
    }
}
```

**この`PAYLOAD RECEIVED`ログが出るか確認**

---

## 📂 重要なファイル

### すぐに確認すべきファイル

1. **`docs/REALTIME_DEBUG_CHECKLIST.md`** ← 詳細な調査手順
2. **`docs/REALTIME_HANDOFF.md`** ← 実装の全体像
3. **`SimpleDashboardView.swift:945-1033`** ← 実装コード

### データベースSQL

```sql
-- device_id確認（iOSログと一致するか）
SELECT device_id, device_name FROM public.devices;

-- dashboard_summaryのデータ確認
SELECT * FROM public.dashboard_summary
ORDER BY updated_at DESC LIMIT 5;
```

---

## 🆘 困ったら

### パターン1: ログに何も出ない
→ `REALTIME_DEBUG_CHECKLIST.md` Step 1

### パターン2: 「購読完了」は出るが通知が来ない
→ `REALTIME_DEBUG_CHECKLIST.md` Step 2

### パターン3: エラーログが出る
→ エラー内容をGoogleで検索 or Supabase Discord

---

## ⏱️ 推定作業時間

- **ベストケース:** 30分（設定ミスの修正）
- **通常ケース:** 2-3時間（原因特定 + 修正）
- **ワーストケース:** 1日（SDKのバグ or アーキテクチャ見直し）

---

## 📞 サポート

- Supabase Discord: https://discord.supabase.com
- GitHub Issues: https://github.com/supabase/supabase/issues
- Stack Overflow: `[supabase] [realtime]` タグ

---

**作成日**: 2025-10-12
**最終更新**: 2025-10-12
**次のアクション**: 上記の「最初にやること」から開始
