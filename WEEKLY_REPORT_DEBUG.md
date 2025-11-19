# Weekly Report 機能デバッグドキュメント

**作成日**: 2025-11-19
**ステータス**: 🔴 データ疎通不可

---

## 🎯 目的

Reportsタブに「今週のレポート」機能を追加する。

---

## 📊 表示したいデータ

### データソース

**Supabase テーブル**: `weekly_results`

**既存データ** (`/Users/kaya.matsumoto/Desktop/weekly_results_rows (1).csv`):
```
device_id: 9f7d6e27-98c3-4c19-bdfb-f7fda58b9a93
week_start_date: 2025-11-17
summary: 今週は月曜と火曜に、ちょっとした言い間違いから家族への怒り、仕事のデザイン議論、時間管理の混乱まで、さまざまな感情が交錯した会話が目立ちました。特に水筒の蓋問題は印象的で、日常の小さなイライラが大きく語られた瞬間でした。
memorable_events: [5件の印象的な出来事のJSON配列]
processed_count: 84
```

### 表示内容

1. **週の平均気分スコア**: `daily_results`テーブルから計算（2025-11-17〜2025-11-23の平均）
2. **週のサマリー**: `weekly_results.summary`
3. **印象的な出来事5件**: `weekly_results.memorable_events` (JSONB配列)
   - Rank（1〜5）
   - 日付・時刻・曜日
   - イベント要約（日本語）
   - 発話抜粋

---

## 🏗️ 実装済みの構造

### 1. データモデル (`Models/WeeklyResults.swift`)

```swift
struct WeeklyResults: Codable, Identifiable {
    let deviceId: String
    let weekStartDate: String  // YYYY-MM-DD (Monday)
    let summary: String?
    let memorableEvents: [MemorableEvent]?
    let profileResult: [String: AnyCodable]?
    let processedCount: Int?
    let llmModel: String?
    let createdAt: Date?
}

struct MemorableEvent: Codable, Identifiable {
    let rank: Int
    let date: String
    let time: String
    let dayOfWeek: String
    let eventSummary: String
    let transcriptionSnippet: String
}
```

### 2. データ取得メソッド (`SupabaseDataManager.swift`)

**実装済み**:
- `fetchWeeklyResults(deviceId:weekStartDate:timezone:)` → `WeeklyResults?`
- `fetchWeeklyAverageVibeScore(deviceId:weekStartDate:timezone:)` → `Double?`

**エンドポイント**:
```
GET https://qvtlwotzuzbavrzqhyvt.supabase.co/rest/v1/weekly_results?device_id=eq.{deviceId}&week_start_date=eq.{weekStartDate}
```

### 3. UI (`ReportView.swift`)

**位置**: Reportsタブ（下部ナビゲーション）

**構成**:
```
ReportView
├── ヘッダー（「レポート」タイトル + 期間テキスト）
├── 🆕 weeklyReportSection（週タブ選択時のみ表示）
│   ├── ローディング状態
│   ├── データあり → 週の平均気分 + サマリー + 印象的な出来事5件
│   └── データなし → エンプティステート（「今週のデータはまだありません」）
├── 期間選択UI（週/月/年）
├── 気分グラフ（プレースホルダー）
├── 気分ハイライト（プレースホルダー）
├── ダイバージェンス・インデックス（プレースホルダー）
└── ダイバージェンスローライト（プレースホルダー）
```

**データ取得タイミング**:
```swift
.task {
    await loadWeeklyData()
}
```
→ ReportView全体に設定済み（表示時に自動実行）

---

## 🔴 現在の問題

### 症状

1. **ログが一切出ない**
   - `🔍 [ReportView]` のログなし
   - `📅 [fetchWeeklyResults]` のログなし
   - `loadWeeklyData()` 関数が実行されていない

2. **UI表示**
   - 「今週のデータはまだありません」（エンプティステート）
   - プレースホルダーはそのまま表示されている

3. **期待される動作**
   - 今日は 2025-11-19（水）
   - 今週の月曜 = 2025-11-17
   - `weekly_results` テーブルに該当データ存在
   - → データが表示されるはず

### デバッグログの追加箇所

**ReportView.swift (`loadWeeklyData()`):**
```swift
print("🔍 [ReportView] Fetching weekly data for device: \(deviceId)")
print("🔍 [ReportView] Week start date (Monday): \(formatter.string(from: monday))")
print("🔍 [ReportView] Weekly results: \(weeklyResults != nil ? "Found" : "Not found")")
print("🔍 [ReportView] Memorable events count: \(weeklyResults?.memorableEvents?.count ?? 0)")
```

**SupabaseDataManager.swift (`fetchWeeklyResults()`):**
```swift
print("📅 [fetchWeeklyResults] Fetching weekly results for \(weekStartString)")
print("✅ [fetchWeeklyResults] Fetched weekly result: \(weeklyResult.memorableEvents?.count ?? 0) events")
print("⚠️ [fetchWeeklyResults] No weekly results found for \(weekStartString)")
```

### 仮説

#### 仮説1: `.task` が実行されていない
- **可能性**: ReportViewの初期化タイミングの問題
- **確認方法**: `loadWeeklyData()` の先頭に `print("🚀 loadWeeklyData() started")` を追加

#### 仮説2: デバイスIDがnilまたは不一致
- **可能性**: `deviceManager.selectedDeviceID` が取得できていない
- **確認方法**: `guard let deviceId` で早期リターンしている

#### 仮説3: 週の計算ロジックエラー
- **可能性**: 月曜日の計算が間違っている
- **期待値**: 2025-11-17
- **確認方法**: ログで実際の計算結果を確認

#### 仮説4: Supabaseリクエストエラー
- **可能性**: ネットワークエラー、認証エラー
- **確認方法**: HTTPレスポンスのログ確認

---

## 🔧 次のステップ

### Step 1: ログ出力の確認

最も基本的なログを追加：

```swift
// ReportView.swift の body 先頭
var body: some View {
    let _ = print("🎨 [ReportView] body rendered")

    ScrollView {
        // ...
    }
    .task {
        print("🚀 [ReportView] .task triggered")
        await loadWeeklyData()
    }
}

// loadWeeklyData() の先頭
private func loadWeeklyData() async {
    print("🚀 [loadWeeklyData] Function started")

    guard let deviceId = deviceManager.selectedDeviceID else {
        print("❌ [loadWeeklyData] No device selected")
        return
    }

    print("✅ [loadWeeklyData] Device ID: \(deviceId)")
    // ...
}
```

### Step 2: デバイスID確認

```swift
print("🔍 Device Manager state:")
print("  - Selected Device ID: \(deviceManager.selectedDeviceID ?? "nil")")
print("  - Devices count: \(deviceManager.devices.count)")
```

### Step 3: 週計算の検証

```swift
let calendar = Calendar.current
let now = Date()
let weekday = calendar.component(.weekday, from: now)
print("📅 Current weekday: \(weekday) (1=Sunday, 2=Monday)")

let daysFromMonday = (weekday == 1) ? 6 : weekday - 2
print("📅 Days from Monday: \(daysFromMonday)")

guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: now) else {
    print("❌ Failed to calculate Monday")
    return
}

let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd"
print("📅 Calculated Monday: \(formatter.string(from: monday))")
```

### Step 4: Supabaseリクエストの直接テスト

curl でテスト:
```bash
curl -s -X GET \
  "https://qvtlwotzuzbavrzqhyvt.supabase.co/rest/v1/weekly_results?device_id=eq.9f7d6e27-98c3-4c19-bdfb-f7fda58b9a93&week_start_date=eq.2025-11-17" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dGx3b3R6dXpiYXZyenFoeXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzODAzMzAsImV4cCI6MjA2Njk1NjMzMH0.g5rqrbxHPw1dKlaGqJ8miIl9gCXyamPajinGCauEI3k" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dGx3b3R6dXpiYXZyenFoeXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzODAzMzAsImV4cCI6MjA2Njk1NjMzMH0.g5rqrbxHPw1dKlaGqJ8miIl9gCXyamPajinGCauEI3k" \
  | jq
```

---

## 📝 チェックリスト

- [ ] `🎨 [ReportView] body rendered` ログが出る
- [ ] `🚀 [ReportView] .task triggered` ログが出る
- [ ] `🚀 [loadWeeklyData] Function started` ログが出る
- [ ] デバイスIDが正しく取得できている
- [ ] 週の計算が `2025-11-17` になっている
- [ ] Supabaseリクエストが送信されている
- [ ] Supabaseからデータが返ってきている
- [ ] JSONデコードが成功している
- [ ] `weeklyResults` に値が入っている

---

## 🔗 関連ファイル

- `/Users/kaya.matsumoto/ios_watchme_v9/ios_watchme_v9/ReportView.swift`
- `/Users/kaya.matsumoto/ios_watchme_v9/ios_watchme_v9/SupabaseDataManager.swift`
- `/Users/kaya.matsumoto/ios_watchme_v9/ios_watchme_v9/Models/WeeklyResults.swift`
- `/Users/kaya.matsumoto/Desktop/weekly_results_rows (1).csv` (テストデータ)

---

## 💡 備考

- プレースホルダーのグラフ・ハイライトはそのまま残す（別機能）
- Weekly Report は独立したセクションとして追加
- 今週のデータ（月曜始まり、ISO 8601準拠）のみを表示
