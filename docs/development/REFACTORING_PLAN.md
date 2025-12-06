# iOS WatchMe リファクタリング実行計画

最終更新: 2025-12-06 12:00

## 📊 進捗状況

### ✅ 完了したフェーズ

#### Phase 0: 準備と分析（完了）
- [x] PERFORMANCE.md作成
- [x] ARCHITECTURE.md作成
- [x] 詳細なコード分析
- [x] ドキュメント整理

#### Phase 1.2: selectedSubject二重管理解消（完了）
- [x] selectedSubjectを計算プロパティ化
- [x] updateSelectedSubject()メソッド削除
- [x] didSetからの呼び出し削除
- [x] View再描画: 3回 → 1回に削減

#### Phase 1.3: NotificationCenter削除（完了）
- [x] SubjectUpdated通知を完全削除
- [x] AvatarUpdated通知を完全削除
- [x] NotificationCenter使用箇所: 5箇所 → 2箇所に削減

#### AvatarViewキャッシュ最適化（完了）
- [x] タイムスタンプによるキャッシュ無効化を削除
- [x] アバター更新時の明示的キャッシュクリア追加
- [x] ImageCacheManager.removeImage()の活用

---

## 🎯 現在の課題と次のステップ

### 🔴 Critical: SimpleDashboardViewのパフォーマンス問題

**症状**: テキストフィールドフォーカス時に30秒のフリーズ

**発見された問題**:
1. **過剰な@State変数（23個）**
2. **複雑なキャッシュロジック**（dataCache、cacheKeys）
3. **頻繁な再描画トリガー**

**調査対象ファイル**:
- `/Users/kaya.matsumoto/ios_watchme_v9/ios_watchme_v9/SimpleDashboardView.swift`

**優先アクション**:
```swift
// 問題の特定
// 1. @State変数の整理（23個 → 10個以下）
// 2. キャッシュロジックの簡素化
// 3. TextField周辺のパフォーマンスプロファイリング
```

---

## 📋 残タスク一覧

### Phase 1: 基盤整備（継続中）

#### 1.1 SimpleDashboardView最適化【🔴 最優先】

**目的**: テキストフィールドフリーズ問題の解決

**タスク**:
- [ ] Instrumentsでパフォーマンスプロファイリング実施
- [ ] 過剰な@State変数の整理（23個 → 10個以下）
- [ ] dataCacheロジックの見直し
- [ ] TextFieldとFocusStateの相互作用調査
- [ ] 不要な再描画の削減

**期待される効果**:
- テキストフィールド応答: 30秒 → <0.5秒
- 画面遷移: 7-18秒 → <1秒

---

#### 1.2 Logger.swift作成【🟡 推奨】

**目的**: デバッグ効率向上、パフォーマンス計測の正確性向上

**新規ファイル**: `Services/Logger.swift`

**実装内容**:
```swift
import Foundation
import os.log

enum LogLevel: Int, Comparable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

final class Logger {
    static let shared = Logger()

    #if DEBUG
    private var currentLevel: LogLevel = .info
    #else
    private var currentLevel: LogLevel = .error
    #endif

    private let osLog = OSLog(subsystem: "com.watchme.ios", category: "general")

    private init() {}

    static func verbose(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .verbose, file: file, function: function, line: line)
    }

    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .debug, file: file, function: function, line: line)
    }

    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .info, file: file, function: function, line: line)
    }

    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .warning, file: file, function: function, line: line)
    }

    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .error, file: file, function: function, line: line)
    }

    private func log(_ message: String, level: LogLevel, file: String, function: String, line: Int) {
        guard level >= currentLevel else { return }

        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(level)] \(fileName):\(line) \(function) - \(message)"

        #if DEBUG
        print(logMessage)
        #endif

        os_log("%{public}@", log: osLog, type: osLogType(for: level), logMessage)
    }

    private func osLogType(for level: LogLevel) -> OSLogType {
        switch level {
        case .verbose, .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }

    static func setLevel(_ level: LogLevel) {
        #if DEBUG
        shared.currentLevel = level
        #endif
    }
}
```

**移行計画**:
- [ ] Logger.swift作成
- [ ] 主要ファイルのprint文をLogger呼び出しに置換（段階的）
- [ ] パフォーマンス計測時にログレベルを調整

---

### Phase 2: データ層刷新（未着手）

**期間**: 3週間（開始予定: SimpleDashboardView最適化完了後）
**リスク**: 🟡 中〜🔴 高

#### 2.1 Repositoryパターンの導入

**新規ファイル**: `Repositories/SubjectRepository.swift`

**目的**: データアクセスの一元化、テスタビリティ向上

**実装概要**:
```swift
protocol SubjectRepositoryProtocol {
    func fetch(subjectId: String) async throws -> Subject
    func fetchByDeviceId(_ deviceId: String) async throws -> Subject?
    func update(_ subject: Subject) async throws -> Subject
    func updateAvatar(subjectId: String, imageData: Data) async throws -> String
}

@MainActor
final class SubjectRepository: SubjectRepositoryProtocol {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient = SupabaseManager.shared.client) {
        self.supabase = supabase
    }

    // 実装詳細は省略
}
```

**タスク**:
- [ ] SubjectRepository作成
- [ ] DeviceRepository作成
- [ ] DashboardRepository作成
- [ ] 既存のSupabaseDataManagerから移行

---

#### 2.2 SubjectViewModelの作成

**新規ファイル**: `ViewModels/SubjectViewModel.swift`

**目的**: DeviceManagerからSubject管理を分離

**実装概要**:
```swift
@MainActor
final class SubjectViewModel: ObservableObject {
    @Published private(set) var current: Subject?
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    private let repository: SubjectRepositoryProtocol
    private let imageCache: ImageCacheManager

    func load(subjectId: String?) async { ... }
    func updateAvatar(_ image: UIImage) async { ... }
}
```

**タスク**:
- [ ] SubjectViewModel実装
- [ ] DeviceManagerからSubject管理を分離
- [ ] すべてのViewでSubjectViewModelを使用

---

### Phase 3: UI層刷新（未着手）

**期間**: 3週間
**リスク**: 🟡 中

#### 3.1 SimpleDashboardViewの構造改善

**目的**: 状態管理の簡素化、再描画の最小化

**タスク**:
- [ ] @State変数の削減（23個 → 8個以下）
- [ ] キャッシュロジックをViewModelに移動
- [ ] コメント機能を独立したViewに分離

---

#### 3.2 AvatarViewの最終最適化

**タスク**:
- [ ] CachedAsyncImageコンポーネントの作成
- [ ] ImageCacheManagerとの統合強化

---

### Phase 4: 最適化（未着手）

**期間**: 2週間
**リスク**: 🟡 中

#### 4.1 ImageCacheManagerの拡張

**タスク**:
- [ ] ディスクキャッシュの追加
- [ ] セマンティックなキャッシュキー（entity_id_type形式）

---

#### 4.2 Supabase RPC関数の活用

**目的**: API呼び出しのバッチ化

**タスク**:
- [ ] get_dashboard_data RPC関数の作成
- [ ] iOS側の実装

---

### Phase 5: 検証とリリース（未着手）

**期間**: 1週間
**リスク**: 🟢 低

**タスク**:
- [ ] パフォーマンス計測（Before/After比較）
- [ ] 全機能の動作確認
- [ ] ストレステスト
- [ ] メモリリーク確認

---

## 📊 改善効果（現時点）

### パフォーマンス指標

| 操作 | 改善前 | 現在 | 最終目標 |
|------|--------|------|----------|
| デバイス選択時のView再描画 | 3回 | **1回** ✅ | 1回 |
| アバター表示（キャッシュヒット） | 不定 | **0秒** ✅ | 0秒 |
| テキストフィールド応答 | 30秒 | 未改善 | <0.5秒 |
| 画面遷移 | 7-18秒 | 未改善 | <1秒 |

### コード品質指標

| 指標 | 改善前 | 現在 | 最終目標 |
|------|--------|------|----------|
| データのコピー（Subject） | 3箇所 | **1箇所** ✅ | 1箇所 |
| NotificationCenter使用 | 5箇所 | **2箇所** ✅ | 0箇所 |
| @Published数（全体） | 19個 | 19個 | 8個以下 |
| テストカバレッジ | 0% | 0% | 70% |

---

## 🔗 関連ドキュメント

- [PERFORMANCE.md](./PERFORMANCE.md) - パフォーマンス問題の詳細分析
- [ARCHITECTURE.md](../technical/ARCHITECTURE.md) - 現在のアーキテクチャ
- [README.md](../../README.md) - アプリ概要

---

## 📝 変更履歴

### 2025-12-06 12:00
- Phase 0完了（ドキュメント整備）
- Phase 1.2完了（selectedSubject二重管理解消）
- Phase 1.3完了（NotificationCenter削除）
- AvatarViewキャッシュ最適化完了
- 次の最優先タスク: SimpleDashboardView最適化

### 2025-12-06 10:45（初版作成）
- リファクタリング計画の策定
- Phase 0-5の詳細計画作成

---

**作成日**: 2025-12-06
**作成者**: Claude (AI Assistant)
**承認**: 未実施
**開始日**: 2025-12-06
**現在のPhase**: Phase 1（基盤整備）継続中