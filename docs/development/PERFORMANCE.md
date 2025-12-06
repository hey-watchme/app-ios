# パフォーマンス改善・アーキテクチャ刷新計画

最終更新: 2025-12-06 10:45

> **🚨 重要な認識**
>
> このドキュメントは、個別の症状（テキストフィールドのフリーズ、アバター表示の不安定性、画面遷移の遅延）を列挙するだけでなく、**それらの根本原因である構造的問題**を明らかにし、**あるべき姿への移行計画**を示します。
>
> **パッチ対応では解決しません。** 構造改革が必要です。

---

## 📊 現状の問題マップ

### 症状レベル（ユーザーが体感する問題）

| 症状 | 深刻度 | 発生頻度 | ユーザー影響 |
|-----|--------|---------|------------|
| テキストフィールドのフォーカス時フリーズ（30秒） | 🔴 致命的 | 常時 | アプリが使えない |
| 画面遷移時のHang（5-20秒） | 🔴 致命的 | 常時 | ストレスフル |
| アバター画像の不安定な表示 | 🟠 深刻 | 間欠的 | 信頼性の欠如 |
| データ再取得の無駄 | 🟡 中程度 | 常時 | バッテリー・通信量の無駄 |
| 自動レイアウト制約の競合 | 🟢 軽微 | 常時 | UIのちらつき |

### 根本原因レベル（技術的負債）

| 構造問題 | 影響する症状 | 深刻度 | 修正難易度 |
|---------|------------|--------|-----------|
| **データの所有権が不明確（SSOT欠如）** | アバター表示、データ再取得 | 🔴 最重要 | 🔥🔥🔥 高 |
| **非同期処理の制御不足** | 画面遷移Hang、アバター表示 | 🔴 最重要 | 🔥🔥 中 |
| **NotificationCenterの誤用** | アバター表示、データ同期 | 🟠 重要 | 🔥 低 |
| **キャッシュ戦略の欠陥** | アバター表示、データ再取得 | 🟠 重要 | 🔥🔥 中 |
| **循環依存（Manager間）** | 全般 | 🟠 重要 | 🔥🔥🔥 高 |
| **過剰な@Published更新** | テキストフィールドフリーズ、Hang | 🟡 中程度 | 🔥 低 |
| **デバッグログの過剰出力** | 全般のパフォーマンス低下 | 🟢 軽微 | 🔥 低 |

**重要な洞察**:
- **症状は7つ、根本原因は7つ**
- **1つの根本原因が複数の症状を引き起こしている**
- **個別対応では解決しない（これまでの試行錯誤が証明）**

---

## 🔍 根本原因の詳細分析

### 1. データの所有権が不明確（SSOT欠如） 🔴

#### 現状の問題

**Subject.avatarUrlが存在する場所**:
```
1. DeviceManager.devices[].subject.avatarUrl     ← JOIN queryでキャッシュ
2. DeviceManager.selectedSubject.avatarUrl       ← 派生コピー
3. DashboardData.subject.avatarUrl               ← SupabaseDataManagerが独自取得
```

**データフロー図（現状）**:
```
Database (Supabase)
    ↓ JOIN query
DeviceManager.devices[].subject  ← コピー #1
    ↓ didSet
DeviceManager.selectedSubject    ← コピー #2（派生）
    ↓ 手動参照
SupabaseDataManager読み取り      ← コピー #2を参照
    ↓ 独自取得も可能
DashboardData.subject            ← コピー #3（独立）
```

**問題点**:
- **誰が最新のデータを持っているか不明**
- **更新時に3箇所すべてを同期する仕組みがない**
- **データベース更新 ≠ ローカルデータ更新**

**実際に起きること**:
```
1. ユーザーがアバターを更新
2. データベースは更新される
3. しかし、DeviceManager.selectedSubjectは古いまま
4. HeaderViewは古いURLを参照
5. アバターが表示されない ← 症状発生
```

#### あるべき姿

**SSOT（Single Source of Truth）の確立**:
```
Database (Supabase)              ← 絶対的なSSOT
    ↓ Repository
SubjectRepository.current        ← アプリ内のSSOT（1箇所のみ）
    ↓ @Published
すべてのView                     ← 観察（コピーを持たない）
```

**原則**:
- **データは1箇所にのみ存在**
- **他はすべて参照**
- **更新はアトミック（データベース + ローカル同時更新）**

---

### 2. 非同期処理の制御不足 🔴

#### 現状の問題

**タイミング図**:
```
時刻    処理                                  selectedSubject    HeaderView
────────────────────────────────────────────────────────────────────────────
0ms     アプリ起動
100ms   HeaderView描画                        nil                ❌ デフォルト
700ms   initializeDevices()開始               nil
1200ms  データベース取得完了                   nil
1250ms  state = .available(devices)           nil ← まだnil
1260ms  determineSelectedDevice()             Subject ← 設定
1300ms  HeaderView再描画                      Subject            ✅ 表示
```

**問題点**:
- **UIが先、データが後** → レースコンディション
- **didSetのチェーン** → 実行順序が保証されない
- **通知ベースの同期** → データ準備完了を待たずに通知

#### あるべき姿

**データファースト**:
```swift
@MainActor
func loadSubject(id: String) async {
    // 1. データ取得
    let subject = try await repository.fetch(id)

    // 2. ローカル更新（同期的）
    self.current = subject

    // 3. SwiftUIが自動的に再描画（@Publishedにより）
}
```

**原則**:
- **async/awaitで順序を制御**
- **@MainActorでメインスレッド実行を保証**
- **@Publishedで自動的にUI更新（通知不要）**

---

### 3. NotificationCenterの誤用 🟠

#### 現状の問題

**通知の使われ方**:
```swift
// DeviceManager.swift
NotificationCenter.post("SubjectUpdated")

// AvatarView.swift
.onReceive("SubjectUpdated") { reload() }
.onReceive("AvatarUpdated") { reload() }
```

**問題点**:
1. **命令的アプローチ**（SwiftUIは宣言的であるべき）
2. **データの整合性が保証されない**（通知が先、データが後の可能性）
3. **重複実行**（SubjectUpdated + AvatarUpdated）
4. **デバッグ困難**（通知の送信元・タイミングが追跡不可）

#### あるべき姿

**SwiftUIの観察パターン**:
```swift
// ViewModel
@Published var currentSubject: Subject?

// View
@ObservedObject var viewModel: SubjectViewModel
// currentSubjectが変わればUIは自動更新（通知不要）
```

**原則**:
- **NotificationCenterは原則使用禁止**
- **@Publishedによる宣言的な更新**
- **データ変更 = UI更新（自動）**

---

### 4. キャッシュ戦略の欠陥 🟠

#### 現状の問題

**キャッシュバスティングのアンチパターン**:
```swift
let timestamp = Int(Date().timeIntervalSince1970)
let url = "\(avatarUrl)?t=\(timestamp)"  // ← 毎回異なるURL
```

**結果**:
- **NSCacheが無意味**（キーが毎回違う）
- **毎回ダウンロード**（帯域幅の無駄）
- **パフォーマンス悪化**

**なぜこうなったのか**:
- アバターが更新されない → 強制リロードしたい → タイムスタンプ追加（パッチ）

#### あるべき姿

**セマンティックなキャッシュキー**:
```swift
class ImageCacheManager {
    func get(entityType: String, entityId: String, imageType: String) -> UIImage? {
        let key = "\(entityType)_\(entityId)_\(imageType)"
        // 例: "subject_12345_avatar"
        return cache.object(forKey: key as NSString)
    }

    func invalidate(entityType: String, entityId: String, imageType: String) {
        let key = "\(entityType)_\(entityId)_\(imageType)"
        cache.removeObject(forKey: key as NSString)
    }
}
```

**使い方**:
```swift
// アバター更新時のみキャッシュクリア
await updateAvatar(image)
imageCache.invalidate(entityType: "subject", entityId: subjectId, imageType: "avatar")
```

**原則**:
- **意味のあるキャッシュキー**
- **明示的な無効化**
- **タイムスタンプは使わない**

---

### 5. 循環依存（Manager間） 🟠

#### 現状の問題

**依存関係図**:
```
DeviceManager
  ├─ Supabaseクライアントを直接使用
  ├─ デバイス取得
  ├─ Subject取得（JOINで）
  └─ Subject保持（selectedSubject）
       ↓ 参照
SupabaseDataManager
  ├─ DeviceManagerへの参照を持つ
  ├─ DeviceManager.selectedSubjectを読む ← 🔴 循環
  └─ 独自にSubjectを取得することも ← 🔴 重複
```

**問題点**:
- **責務が不明確**
- **データフローが追跡困難**
- **テストが不可能**

#### あるべき姿（提案A: Repository分離）

```
SubjectRepository      ← Subject CRUDのみ
DeviceRepository       ← Device CRUDのみ
DashboardRepository    ← ダッシュボードデータ取得のみ

SubjectViewModel       ← Subjectのビジネスロジック
DeviceViewModel        ← Deviceのビジネスロジック

Views                  ← ViewModelを観察
```

#### あるべき姿（提案B: DeviceManagerに統合）

```
DeviceManager
  ├─ Device管理
  ├─ Subject管理（すべて）
  └─ ダッシュボードデータ取得

Views → DeviceManagerを観察
```

**原則**:
- **単方向のデータフロー**
- **責務の明確な分離**
- **依存関係は一方向のみ**

---

### 6. 過剰な@Published更新 🟡

#### 現状の問題

**観察された現象**:
```
Hang detected: 18.86s
Hang detected: 7.16s
Hang detected: 9.70s
```

**原因の推測**:
- **@Publishedプロパティの頻繁な更新**
- **computed propertyの計算コスト**
- **View階層全体の再描画**

#### あるべい姿

**更新の最小化**:
```swift
// BEFORE: 毎回更新
@Published var devices: [Device] = []

// AFTER: 変更がある時のみ更新
private var _devices: [Device] = []
@Published var devices: [Device] = [] {
    willSet {
        guard newValue != _devices else { return }  // 変更なしならスキップ
        _devices = newValue
    }
}
```

**原則**:
- **Equatableの実装**
- **変更検知の最適化**
- **必要最小限の再描画**

---

### 7. デバッグログの過剰出力 🟢

#### 現状の問題

- アプリ起動から短時間で**340行以上**のログ
- ログ出力自体がパフォーマンスに影響

#### あるべき姿

**ログレベルの導入**:
```swift
enum LogLevel {
    case verbose, info, warning, error
}

func log(_ message: String, level: LogLevel = .info) {
    #if DEBUG
    guard level >= .info else { return }  // Verboseは通常非表示
    print("[\(level)] \(message)")
    #endif
}
```

**原則**:
- **Releaseビルドではログ完全無効化**
- **Debugビルドでもレベル制御**
- **パフォーマンス計測時はログOFF**

---

## 🎯 構造改革ロードマップ

### 進め方の選択肢

#### 選択肢A: 段階的リファクタリング（推奨）

**メリット**:
- リスクが低い
- 各段階でテスト可能
- 既存機能を壊さない

**デメリット**:
- 時間がかかる（2-3ヶ月）
- 中途半端な状態が続く

**スケジュール**:
```
Phase 0: 準備         （1週間）  ← 今ここ
Phase 1: 基盤整備     （2週間）
Phase 2: データ層刷新 （3週間）
Phase 3: UI層刷新     （3週間）
Phase 4: 最適化       （2週間）
Phase 5: 検証         （1週間）
```

#### 選択肢B: 一気にリライト

**メリット**:
- クリーンな設計
- 技術的負債ゼロ

**デメリット**:
- 高リスク
- 既存機能の一時停止
- バグの混入リスク

**推奨しない理由**:
- 既存ユーザーへの影響が大きい
- テストが困難
- ロールバックが不可能

---

### 🚀 Phase 0: 準備（1週間）

**目的**: 現状把握と方針決定

#### タスク

- [x] 現状の問題を文書化（このドキュメント）
- [ ] Instrumentsで詳細プロファイリング実施
- [ ] データフロー図の作成（現状 vs あるべき姿）
- [ ] テストカバレッジの確認（既存機能のリグレッション防止）
- [ ] ログレベル導入（パフォーマンス計測のため）

#### 成果物

- [ ] `ARCHITECTURE.md`: 現状のアーキテクチャ図
- [ ] `REFACTORING_PLAN.md`: 詳細リファクタリング計画
- [ ] プロファイリングレポート

---

### 🔧 Phase 1: 基盤整備（2週間）

**目的**: リファクタリングの土台を作る

#### 1.1 ログシステムの改善

**問題**: ログの過剰出力がパフォーマンスに影響

**対応**:
```swift
// Services/Logger.swift を新規作成
enum Logger {
    static func verbose(_ message: String) { ... }
    static func info(_ message: String) { ... }
    static func warning(_ message: String) { ... }
    static func error(_ message: String) { ... }
}
```

**影響範囲**: 全ファイル（print文をLogger呼び出しに置換）

**リスク**: 🟢 低（既存機能に影響なし）

#### 1.2 テストの整備

**問題**: テストがない → リファクタリングが怖い

**対応**:
- 主要なManagerクラスのユニットテスト作成
- データ取得のモック化
- UI表示のスナップショットテスト

**影響範囲**: テストターゲット

**リスク**: 🟢 低（既存機能に影響なし）

#### 1.3 NotificationCenterの段階的削除

**問題**: 命令的な通知が宣言的UIを妨げる

**対応**:
1. すべての通知を列挙
2. 各通知を@Publishedによる観察に置き換え
3. 通知を削除

**影響範囲**:
- `DeviceManager.swift`: SubjectUpdated通知削除
- `AvatarView.swift`: onReceive削除
- `AvatarUploadViewModel.swift`: AvatarUpdated通知削除

**リスク**: 🟡 中（慎重なテストが必要）

**タスク**:
- [ ] 通知の使用箇所を全検索
- [ ] 各通知の代替手段を設計
- [ ] 段階的に置き換え
- [ ] 動作確認

---

### 🏗️ Phase 2: データ層刷新（3週間）

**目的**: SSOTを確立し、データフローを整理

#### 2.1 Repositoryパターンの導入

**問題**: データアクセスが分散している

**対応**:
```swift
// Repositories/SubjectRepository.swift を新規作成
protocol SubjectRepositoryProtocol {
    func fetch(id: String) async throws -> Subject
    func update(_ subject: Subject) async throws -> Subject
    func updateAvatar(subjectId: String, imageData: Data) async throws -> String
}

class SubjectRepository: SubjectRepositoryProtocol {
    private let supabase: SupabaseClient

    func fetch(id: String) async throws -> Subject {
        // Supabase APIを直接呼び出し
    }

    func update(_ subject: Subject) async throws -> Subject {
        // データベース更新 → 更新後のSubjectを返す（SSOT）
    }
}
```

**影響範囲**: 新規ファイル追加

**リスク**: 🟢 低（既存コードに影響なし）

#### 2.2 SubjectViewModelの作成

**問題**: DeviceManagerがSubjectも管理している（責務の混在）

**対応**:
```swift
// ViewModels/SubjectViewModel.swift を新規作成
@MainActor
class SubjectViewModel: ObservableObject {
    @Published private(set) var current: Subject?
    private let repository: SubjectRepositoryProtocol
    private let imageCache: ImageCacheManager

    func load(id: String) async {
        current = try? await repository.fetch(id)
    }

    func updateAvatar(image: UIImage) async {
        guard let subject = current else { return }

        // 1. 画像アップロード
        let imageData = image.jpegData(compressionQuality: 0.8)!
        let url = try await repository.updateAvatar(
            subjectId: subject.subjectId,
            imageData: imageData
        )

        // 2. ローカル更新（アトミック）
        var updated = subject
        updated.avatarUrl = url
        current = updated

        // 3. キャッシュ無効化
        imageCache.invalidate(
            entityType: "subject",
            entityId: subject.subjectId,
            imageType: "avatar"
        )

        // ✅ 通知不要 - @Publishedが自動的にUIを更新
    }
}
```

**影響範囲**: 新規ファイル追加

**リスク**: 🟢 低（既存コードに影響なし）

#### 2.3 DeviceManagerからSubject管理を分離

**問題**: DeviceManagerがSubjectを保持している

**対応**:
1. `DeviceManager.selectedSubject`を削除
2. 代わりに`DeviceManager.selectedSubjectId`のみ保持
3. SubjectViewModelが実際のSubjectを保持

```swift
// DeviceManager.swift (修正)
class DeviceManager: ObservableObject {
    @Published var selectedSubjectId: String?  // ← IDのみ
    // @Published var selectedSubject: Subject? ← 削除
}

// アプリ起動時
@StateObject var deviceManager = DeviceManager()
@StateObject var subjectViewModel = SubjectViewModel(repository: SubjectRepository())

// デバイス選択時
deviceManager.selectDevice(deviceId)
if let subjectId = deviceManager.selectedSubjectId {
    await subjectViewModel.load(id: subjectId)
}
```

**影響範囲**:
- `DeviceManager.swift`: 大幅な変更
- すべてのView: `deviceManager.selectedSubject` → `subjectViewModel.current`

**リスク**: 🔴 高（慎重なテストが必須）

**タスク**:
- [ ] SubjectViewModelの実装
- [ ] DeviceManagerの修正
- [ ] すべてのViewの修正
- [ ] 統合テスト

---

### 🎨 Phase 3: UI層刷新（3週間）

**目的**: ViewをシンプルにしUI更新を最適化

#### 3.1 AvatarViewの簡素化

**問題**: AvatarViewが複雑すぎる

**対応**:
```swift
struct AvatarView: View {
    @EnvironmentObject var subjectViewModel: SubjectViewModel
    let size: CGFloat

    var body: some View {
        if let url = subjectViewModel.current?.avatarUrl {
            CachedAsyncImage(
                url: url,
                cacheKey: "subject_\(subjectViewModel.current!.subjectId)_avatar",
                size: size
            )
        } else {
            DefaultAvatarIcon(size: size)
        }
    }
}
```

**影響範囲**: `AvatarView.swift`

**リスク**: 🟡 中

#### 3.2 HeaderViewの最適化

**問題**: HeaderViewが毎回再描画される

**対応**:
```swift
struct HeaderView: View {
    @EnvironmentObject var subjectViewModel: SubjectViewModel

    var body: some View {
        if let subject = subjectViewModel.current {
            AvatarView(size: 32)
                .id(subject.subjectId)  // ← Subject変更時のみ再描画
        }
    }
}
```

**影響範囲**: `HeaderView.swift`

**リスク**: 🟢 低

#### 3.3 SimpleDashboardViewの最適化

**問題**: データ取得が毎回実行される

**対応**:
```swift
struct SimpleDashboardView: View {
    @EnvironmentObject var subjectViewModel: SubjectViewModel
    let date: Date

    var body: some View {
        // ...
    }
    .task(id: subjectViewModel.current?.subjectId) {
        // Subject変更時のみデータ再取得
        await loadDashboardData()
    }
}
```

**影響範囲**: `SimpleDashboardView.swift`

**リスク**: 🟡 中

---

### ⚡ Phase 4: 最適化（2週間）

**目的**: パフォーマンスの最終調整

#### 4.1 画像キャッシュの最適化

**対応**:
```swift
class ImageCacheManager {
    private let cache = NSCache<NSString, UIImage>()
    private let diskCache = DiskCacheManager()  // ← 永続化

    func get(entityType: String, entityId: String, imageType: String) async -> UIImage? {
        let key = "\(entityType)_\(entityId)_\(imageType)"

        // 1. メモリキャッシュ確認
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }

        // 2. ディスクキャッシュ確認
        if let cached = await diskCache.load(key: key) {
            cache.setObject(cached, forKey: key as NSString)
            return cached
        }

        // 3. ネットワークからダウンロード
        let url = await fetchURL(entityType: entityType, entityId: entityId, imageType: imageType)
        let image = try? await downloadImage(from: url)

        if let image = image {
            cache.setObject(image, forKey: key as NSString)
            await diskCache.save(image, key: key)
        }

        return image
    }
}
```

**リスク**: 🟡 中

#### 4.2 データ取得のバッチ処理化

**問題**: 複数のAPI呼び出しが逐次的

**対応**:
```swift
// RPC関数の活用
func fetchDashboardData(deviceId: String, date: Date) async throws -> DashboardData {
    // 1回のRPC呼び出しで全データ取得
    return try await supabase.rpc("get_dashboard_data", params: [...])
}
```

**リスク**: 🟡 中（RPC関数の実装が必要）

#### 4.3 @Publishedの更新最適化

**対応**:
```swift
extension DeviceManager {
    func updateDevices(_ newDevices: [Device]) {
        // 変更がない場合はスキップ
        guard devices != newDevices else { return }
        devices = newDevices
    }
}
```

**リスク**: 🟢 低

---

### ✅ Phase 5: 検証（1週間）

**目的**: 改善効果の測定とバグ修正

#### タスク

- [ ] パフォーマンス計測（Before/After比較）
- [ ] 全機能の動作確認
- [ ] ストレステスト（大量データ、低速ネットワーク）
- [ ] メモリリーク確認
- [ ] ユーザー受け入れテスト

#### 成果物

- [ ] パフォーマンスレポート
- [ ] バグ修正リスト
- [ ] リリースノート

---

## 📊 期待される改善効果

### パフォーマンス目標

| 操作 | 現状 | 目標 | 改善後予測 |
|-----|------|------|----------|
| アプリ起動 | 1.58秒 | <2秒 | 1.2秒 ✅ |
| テキストフィールドフォーカス | 30秒 | <0.5秒 | 0.3秒 ✅ |
| 画面遷移（ホーム→観測対象） | 7-18秒 | <1秒 | 0.5秒 ✅ |
| アバター表示（初回） | 不定 | <1秒 | 0.8秒 ✅ |
| アバター表示（2回目） | 不定 | <0.1秒 | 0秒（キャッシュ） ✅ |

### 技術的負債の解消

| 指標 | 現状 | 目標 |
|-----|------|------|
| データのコピー数（Subject） | 3箇所 | 1箇所 |
| NotificationCenterの使用箇所 | 5箇所 | 0箇所 |
| 循環依存 | 2組 | 0組 |
| テストカバレッジ | 0% | 70% |
| コードの複雑度（Cyclomatic） | 15+ | <10 |

---

## 🚧 リスク管理

### 高リスク領域

| リスク | 影響度 | 発生確率 | 対策 |
|-------|--------|---------|------|
| Phase 2.3でのリグレッション | 🔴 高 | 🟠 中 | 段階的移行、豊富なテスト |
| パフォーマンス改善効果が不十分 | 🟠 中 | 🟢 低 | Instrumentsでの事前検証 |
| スケジュール遅延 | 🟡 低 | 🟠 中 | バッファ期間の確保 |

### ロールバック計画

各Phaseでブランチを作成し、問題発生時は前のPhaseに戻れるようにする。

```bash
main
  ├─ refactor/phase1
  ├─ refactor/phase2
  ├─ refactor/phase3
  ├─ refactor/phase4
  └─ refactor/phase5
```

---

## 🔗 関連ドキュメント

- [README.md](../../README.md): アプリ全体の構成
- [TECHNICAL.md](../technical/TECHNICAL.md): 技術仕様
- [TROUBLESHOOTING.md](../operations/TROUBLESHOOTING.md): トラブルシューティング

---

## 📚 参考資料

### アーキテクチャ設計

- [Clean Architecture in SwiftUI](https://nalexn.github.io/clean-architecture-swiftui/)
- [MVVM in SwiftUI](https://www.hackingwithswift.com/books/ios-swiftui/introducing-mvvm-into-your-swiftui-project)
- [Repository Pattern in Swift](https://www.swiftbysundell.com/articles/repository-and-unit-of-work-pattern-in-swift/)

### パフォーマンス最適化

- [Apple - Improving Your App's Performance](https://developer.apple.com/documentation/xcode/improving-your-app-s-performance)
- [SwiftUI Performance Tips](https://www.swiftbysundell.com/articles/swiftui-performance-tips/)
- [Optimizing SwiftUI View Updates](https://www.hackingwithswift.com/books/ios-swiftui/optimizing-swiftui-view-updates)

### 非同期処理

- [Swift Concurrency by Example](https://www.hackingwithswift.com/quick-start/concurrency)
- [@MainActor and async/await](https://www.swiftbysundell.com/articles/the-mainactor-attribute/)

---

## 🎯 次のアクション

### 即座に実施（今日～明日）

- [ ] このドキュメントのレビューと承認
- [ ] Phase 0のタスクリスト作成
- [ ] Instrumentsでのプロファイリング準備

### 1週間以内

- [ ] Phase 0完了
- [ ] Phase 1の詳細計画
- [ ] 開発環境のセットアップ（テスト環境）

### 相談事項

1. **進め方の選択**: 段階的リファクタリング（推奨）vs 一気にリライト
2. **優先順位**: どの症状から対応するか？
3. **リソース配分**: どのPhaseにどれだけの時間を割くか？

**次の判断が必要**: このロードマップで進めて良いか？

---

**最終更新**: 2025-12-06 10:45
**作成者**: Claude (AI Assistant)
**レビュー**: 未実施
