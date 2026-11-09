# iOS WatchMe アーキテクチャドキュメント

最終更新: 2025-12-06

## 📊 現在のアーキテクチャ（As-Is）

### システム構成図

```
┌─────────────────────────────────────────────────────────────┐
│                         Views Layer                         │
├─────────────────────────────────────────────────────────────┤
│  ContentView → SimpleDashboardView → AnalysisView          │
│      ↓              ↓                    ↓                  │
│  AvatarView    SubjectTabView      ReportViews             │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                      Managers Layer                         │
├─────────────────────────────────────────────────────────────┤
│  UserAccountManager  ←→  DeviceManager  ←→  SupabaseDataManager │
│       (認証)            (デバイス・Subject)     (データ取得)      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                      Services Layer                         │
├─────────────────────────────────────────────────────────────┤
│  RecordingStore  AudioRecorderService  ChunkUploader  UploadJournal │
│  ImageCacheManager   PushNotificationManager               │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    External Services                        │
├─────────────────────────────────────────────────────────────┤
│              Supabase (Auth, Database, Storage)            │
│                     AWS SNS (Push)                         │
└─────────────────────────────────────────────────────────────┘
```

### データフロー（現状）

```
1. アプリ起動
   └→ UserAccountManager.checkAuthStatus()
      └→ DeviceManager.initializeDevices()
         └→ Supabase: devices + subjects (JOIN)
            └→ DeviceManager.devices = [...]
               └→ DeviceManager.selectedDeviceID = devices[0].id
                  └→ DeviceManager.updateSelectedSubject()  ← 🔴 問題
                     ├→ selectedSubject = device.subject  ← コピー作成
                     └→ NotificationCenter.post("SubjectUpdated")  ← 🔴 問題

2. View描画
   └→ SimpleDashboardView
      ├→ @EnvironmentObject deviceManager
      ├→ deviceManager.selectedSubject  ← 派生データを参照
      └→ .task(id: deviceManager.selectedDeviceID)
         └→ SupabaseDataManager.fetchAllReports()
            └→ deviceManager.selectedSubject  ← 🔴 循環参照
```

### 主要コンポーネントの責務

#### Managers

| クラス | 責務 | @Published数 | 問題点 |
|--------|------|-------------|---------|
| **UserAccountManager** | 認証・ユーザー管理 | 9個 | 過剰な状態管理 |
| **DeviceManager** | デバイス・Subject管理 | 5個 | Subject二重管理、NotificationCenter使用 |
| **SupabaseDataManager** | データ取得・キャッシュ | 5個 | DeviceManagerへの循環依存 |

#### Views

| View | 責務 | 依存Manager | 問題点 |
|------|------|------------|---------|
| **ContentView** | ナビゲーション制御 | UserAccountManager, DeviceManager | - |
| **SimpleDashboardView** | ダッシュボード表示 | DeviceManager, SupabaseDataManager | 過剰な再描画 |
| **AvatarView** | アバター表示 | - | NotificationCenter依存 |
| **SubjectTabView** | プロフィール表示 | DeviceManager | - |

#### Services

| サービス | 責務 | 問題点 |
|----------|------|---------|
| **ImageCacheManager** | 画像キャッシュ | タイムスタンプによるキャッシュ無効化 |
| **RecordingStore** | 録音状態管理 | - |
| **AudioRecorderService** | 5 分ごとの分割録音、60 分の上限、中断からの再開 | - |
| **ChunkUploader** / **UploadJournal** | 断片の記録（ディスク）と、署名付き URL への背景送信・再送 | 設計は platform `docs/long-recording.md` |
| **PushNotificationManager** | プッシュ通知 | - |

## 🔴 構造的問題

### 1. SSOT（Single Source of Truth）違反

```
データの重複箇所:
- DeviceManager.devices[].subject  ← オリジナル
- DeviceManager.selectedSubject    ← コピー（派生）
- SupabaseDataManager内のsubject   ← 別途取得（独立）
```

### 2. 循環依存

```
DeviceManager ←→ SupabaseDataManager
    ↓               ↓
  Subject管理    データ取得
    ↓               ↓
  selectedSubject ← 参照
```

### 3. NotificationCenterの誤用

| 通知名 | 送信元 | 受信側 | 本来の実装 |
|--------|--------|--------|------------|
| SubjectUpdated | DeviceManager | AvatarView | @Published + task(id:) |
| AvatarUpdated | - | AvatarView | @Published + task(id:) |
| APNsTokenReceived | AppDelegate | DeviceManager | async/await |

### 4. 過剰な@Published更新

```swift
// 1つのアクションで連鎖的に更新される例
selectedDeviceID変更
  ↓ didSet
updateSelectedSubject()
  ↓
selectedSubject変更
  ↓ @Published
View再描画（1回目）
  ↓
NotificationCenter("SubjectUpdated")
  ↓
AvatarView再描画（2回目）
```

## 📈 パフォーマンスへの影響

### 測定結果（Instruments）

| 操作 | 発生する更新 | 所要時間 | 期待値 |
|------|------------|----------|--------|
| デバイス選択 | View再描画×3回 | 7-18秒 | <1秒 |
| テキストフィールドフォーカス | 不明（要調査） | 30秒 | <0.5秒 |
| アバター更新 | 通知×2、再描画×2 | 不定 | <1秒 |

### メモリ使用状況

- **Subject重複**: 約100KB × デバイス数 × 3箇所
- **キャッシュミス**: タイムスタンプ付きURLによりキャッシュが機能しない
- **ログ出力**: 起動時340行以上（パフォーマンスへの影響）

## 🎯 改善すべき優先順位

### Critical（即座に対応）
1. ✅ selectedSubjectの二重管理を解消（SSOT確立）
2. ✅ NotificationCenter使用を全廃止
3. ✅ テキストフィールドフリーズの原因特定と修正

### High（Phase 1-2で対応）
4. ✅ SupabaseDataManagerの循環依存解消
5. ✅ キャッシュ戦略の見直し
6. ✅ ログシステムの改善

### Medium（Phase 3-4で対応）
7. ✅ @Published過剰更新の最適化
8. ✅ View再描画の最小化
9. ✅ 非同期処理の最適化

## 📐 あるべき姿（To-Be）

### 理想的なアーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                         Views Layer                         │
├─────────────────────────────────────────────────────────────┤
│  ContentView → SimpleDashboardView → AnalysisView          │
│  (@StateObject: SubjectViewModel, DeviceViewModel)         │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    ViewModels Layer                         │
├─────────────────────────────────────────────────────────────┤
│  SubjectViewModel    DeviceViewModel    DashboardViewModel │
│  (@Published current) (@Published selected)  (@Published data) │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                   Repositories Layer                        │
├─────────────────────────────────────────────────────────────┤
│  SubjectRepository   DeviceRepository   DashboardRepository│
│     (CRUD)              (CRUD)           (Read-only)       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                      Services Layer                         │
├─────────────────────────────────────────────────────────────┤
│  ImageCacheService   RecordingService   UploadService      │
│  (Semantic keys)     (AVFoundation)     (Supabase Storage) │
└─────────────────────────────────────────────────────────────┘
```

### 理想的なデータフロー

```
1. デバイス選択
   └→ DeviceViewModel.selectDevice(id)
      └→ @Published selectedDeviceId = id
         └→ SubjectViewModel.task(id: deviceId)
            └→ SubjectRepository.fetch(deviceId)
               └→ @Published current = subject
                  └→ View自動更新（1回のみ）

2. アバター更新
   └→ SubjectViewModel.updateAvatar(image)
      ├→ SubjectRepository.uploadAvatar(image)
      ├→ @Published current.avatarUrl = newUrl
      └→ ImageCache.invalidate(key)
         └→ AvatarView自動更新（@Published経由）
```

### 主要な改善点

1. **SSOT確立**: データは1箇所のみに存在
2. **単方向データフロー**: View → ViewModel → Repository → Service
3. **宣言的UI**: NotificationCenter廃止、@Published + Combineのみ
4. **責務の明確化**: 各層が単一責務を持つ
5. **テスタビリティ**: Repositoryパターンでモック化が容易

## 📊 期待される効果

### パフォーマンス改善

| 指標 | 現在 | 目標 | 改善率 |
|------|------|------|--------|
| デバイス選択時のView再描画 | 3回 | 1回 | -67% |
| テキストフィールド応答 | 30秒 | <0.5秒 | -98% |
| 画面遷移 | 7-18秒 | <1秒 | -90% |
| アバター表示（キャッシュヒット） | 不定 | 0秒 | 100% |

### コード品質改善

| 指標 | 現在 | 目標 |
|------|------|------|
| @Published数（全体） | 19個 | 8個以下 |
| NotificationCenter使用 | 5箇所 | 0箇所 |
| 循環依存 | 2組 | 0組 |
| コード行数 | 約10,000行 | 約8,000行 |

## 🔗 関連ドキュメント

- [PERFORMANCE.md](../development/PERFORMANCE.md) - パフォーマンス改善計画
- [REFACTORING_PLAN.md](../development/REFACTORING_PLAN.md) - 詳細なリファクタリング手順
- [README.md](../../README.md) - アプリ概要

---

**作成日**: 2025-12-06
**作成者**: Claude (AI Assistant)
**レビュー**: 未実施