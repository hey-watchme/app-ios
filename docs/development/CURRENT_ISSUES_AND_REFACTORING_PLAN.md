# 現状の課題と修正計画

最終更新: 2025-12-29

## 🚨 重大な課題: ハイライトセクションのデータ不整合問題

### 問題の概要

ホーム画面の「ハイライト」セクションおよび分析結果の一覧画面の「会話あり」フィルターが、正しく機能していない。実際には会話データが存在するにも関わらず、表示されない。

### 根本原因: Computed Propertyとデータフローの設計問題

#### 1. 非同期データ取得とComputed Propertyのタイミング問題

**現状の問題のある実装:**

```swift
// SimpleDashboardView.swift
@State private var timeBlocks: [DashboardTimeBlock] = []

private var highlightSection: some View {
    // ❌ 問題: アクセスされるたびに再計算される
    let conversationBlocks = timeBlocks.filter { block in
        guard let transcription = block.vibeTranscriberResult else {
            return false
        }
        return transcription != "発話なし"
    }
    // ...
}
```

**問題点:**
- `timeBlocks`が非同期で更新される
- ビューの再描画タイミングで、古いデータで計算される可能性
- SwiftUIの更新サイクルと非同期データ更新のタイミングがズレる
- 同じ計算を何度も繰り返すパフォーマンスの問題

#### 2. データフローの一貫性が保証されていない

**現在のデータフロー:**

```
1. SupabaseDataManager.fetchDashboardTimeBlocks() [非同期]
   ↓
2. timeBlocks @State変数に代入 [メインスレッド]
   ↓
3. ビュー再描画トリガー
   ↓
4. highlightSection computed property評価 [タイミング不定]
   ↓
5. 古いデータまたは空データで計算される可能性 ❌
```

#### 3. フィルタ結果を保持しない設計

現在の実装では、フィルタリング結果を保持せず、アクセスのたびに再計算している。これにより：
- 計算結果の一貫性が保証されない
- パフォーマンスが低下
- デバッグが困難

## 📋 技術的分析

### SwiftUIのビューライフサイクルとの不整合

1. **ビュー初期化時**
   - `timeBlocks = []` （空配列）
   - `highlightSection`がアクセスされると空データで計算

2. **データ取得中**
   - 非同期でデータ取得
   - ビューは何度も再描画される可能性

3. **データ取得完了後**
   - `timeBlocks`更新
   - しかし、computed propertyの再評価タイミングは保証されない

### 実際のログ分析結果

```
# 同じ時間のデータが異なる内容で複数回表示される
1246行目: Block 09:31: transcription='発話なし', hasConversation=false
1488行目: Block 09:31: transcription='な景色だし...', hasConversation=true

# フィルタ結果が安定しない
244〜1275行目: Conversation blocks count: 0
1517行目: Conversation blocks count: 9  ← 実際は9件存在
```

## 🎯 修正計画

### Phase 1: 即座の修正（暫定対応）

#### 1.1 ハイライトセクションの表示ロジック修正

**変更内容:**
- 会話がない場合はフォールバックではなく、セクション自体を非表示にする
- computed propertyで会話ブロックを共有して重複計算を避ける

**実装済み:**
```swift
// 会話ブロックを一度だけ計算
private var conversationBlocks: [DashboardTimeBlock] {
    timeBlocks.filter { block in
        guard let transcription = block.vibeTranscriberResult else {
            return false
        }
        return transcription != "発話なし"
    }
}

// セクション表示判定
private var shouldShowHighlightSection: Bool {
    !timeBlocks.isEmpty && conversationBlocks.count > 0
}
```

### Phase 2: 根本的な設計改善（推奨）

#### 2.1 @State変数でフィルタ結果を保持

**設計方針:**
- フィルタ結果を@State変数として保持
- データ更新時に明示的に再計算
- onChangeを使用して自動更新

**実装案:**
```swift
struct SimpleDashboardView: View {
    @State private var timeBlocks: [DashboardTimeBlock] = []
    @State private var conversationBlocks: [DashboardTimeBlock] = []
    @State private var highlightBlocks: [DashboardTimeBlock] = []

    var body: some View {
        // ...
    }
    .task {
        await loadData()
    }
    .onChange(of: timeBlocks) { newBlocks in
        updateFilteredData(newBlocks)
    }

    private func loadData() async {
        let blocks = await dataManager.fetchDashboardTimeBlocks(...)

        // メインスレッドで確実に更新
        await MainActor.run {
            self.timeBlocks = blocks
            self.updateFilteredData(blocks)
        }
    }

    private func updateFilteredData(_ blocks: [DashboardTimeBlock]) {
        // 一度だけ計算して結果を保存
        conversationBlocks = blocks.filter { block in
            guard let transcription = block.vibeTranscriberResult else { return false }
            return transcription != "発話なし"
        }

        // ハイライト表示用データを決定
        if !conversationBlocks.isEmpty {
            highlightBlocks = conversationBlocks.reversed()
        }
        // フォールバックは使用しない（セクション非表示）
    }
}
```

### Phase 3: ViewModelパターンへの移行（長期的）

#### 3.1 ViewModelクラスの導入

**利点:**
- ビューロジックとビジネスロジックの分離
- テスト容易性の向上
- データフローの明確化
- 状態管理の一元化

**実装案:**
```swift
@MainActor
class DashboardViewModel: ObservableObject {
    @Published var timeBlocks: [DashboardTimeBlock] = []
    @Published var conversationBlocks: [DashboardTimeBlock] = []
    @Published var highlightBlocks: [DashboardTimeBlock] = []
    @Published var showHighlightSection = false

    private let dataManager: SupabaseDataManager

    func loadData(deviceId: String, date: Date) async {
        let blocks = await dataManager.fetchDashboardTimeBlocks(deviceId: deviceId, date: date)

        // すべての更新をメインスレッドで実行
        await MainActor.run {
            self.timeBlocks = blocks
            self.updateFilteredData()
        }
    }

    private func updateFilteredData() {
        // 会話ブロックのフィルタリング
        conversationBlocks = timeBlocks.filter { block in
            guard let transcription = block.vibeTranscriberResult else { return false }
            return transcription != "発話なし"
        }

        // ハイライト表示の判定
        showHighlightSection = !conversationBlocks.isEmpty

        // 表示用データの準備
        if showHighlightSection {
            highlightBlocks = conversationBlocks.reversed()
        } else {
            highlightBlocks = []
        }
    }
}

struct SimpleDashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        // シンプルなビュー実装
        ScrollView {
            if viewModel.showHighlightSection {
                SpotAnalysisListSection(
                    title: "ハイライト",
                    spotResults: viewModel.highlightBlocks,
                    // ...
                )
            }
        }
        .task {
            await viewModel.loadData(...)
        }
    }
}
```

## 🔧 パフォーマンス最適化

### 問題点

1. **重複計算**
   - 同じフィルタリング処理を複数回実行
   - computed propertyが何度も評価される

2. **メモリ使用**
   - 大量のデータを複数の配列にコピー

### 改善策

1. **遅延評価とキャッシング**
```swift
private lazy var conversationBlocksCache = [DashboardTimeBlock]()
private var cacheVersion = 0
private var dataVersion = 0

private var conversationBlocks: [DashboardTimeBlock] {
    if cacheVersion != dataVersion {
        conversationBlocksCache = timeBlocks.filter { /* ... */ }
        cacheVersion = dataVersion
    }
    return conversationBlocksCache
}
```

2. **Combineを使用した反応的更新**
```swift
import Combine

class DashboardViewModel: ObservableObject {
    @Published var timeBlocks: [DashboardTimeBlock] = []
    @Published var highlightBlocks: [DashboardTimeBlock] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        $timeBlocks
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .map { blocks in
                blocks.filter { block in
                    guard let transcription = block.vibeTranscriberResult else { return false }
                    return transcription != "発話なし"
                }.reversed()
            }
            .assign(to: &$highlightBlocks)
    }
}
```

## 📊 テスト計画

### Unit Tests

1. **フィルタリングロジックのテスト**
   - 「発話なし」のフィルタリング
   - nilデータの処理
   - 空配列の処理

2. **データ更新のテスト**
   - 非同期データ取得後の状態確認
   - 複数回更新時の一貫性

### Integration Tests

1. **ビュー更新のテスト**
   - データ取得からUI表示までの一連の流れ
   - フィルター適用後の表示確認

2. **パフォーマンステスト**
   - 大量データでのフィルタリング速度
   - メモリ使用量の監視

## 📅 実装スケジュール

| フェーズ | タスク | 優先度 | 推定時間 |
|---------|--------|--------|----------|
| Phase 1 | ハイライトセクションの表示ロジック修正 | 高 | 完了 |
| Phase 2 | @State変数によるフィルタ結果保持 | 高 | 2時間 |
| Phase 2 | onChangeによる自動更新実装 | 高 | 1時間 |
| Phase 3 | ViewModelクラスの設計・実装 | 中 | 4時間 |
| Phase 3 | 既存ビューのリファクタリング | 中 | 3時間 |
| Phase 3 | テストの実装 | 低 | 2時間 |

## 🎯 成功基準

1. **機能要件**
   - 会話があるデータが正しくフィルタリングされる
   - ハイライトセクションに会話データが表示される
   - 会話がない場合はセクションが非表示になる

2. **非機能要件**
   - データ更新後100ms以内にUIが更新される
   - フィルタリング処理が50ms以内に完了する
   - メモリ使用量が増加しない

## 🚀 次のステップ

1. **即座に実施**
   - Phase 1の修正をテスト
   - 動作確認とログ分析

2. **短期（1週間以内）**
   - Phase 2の実装
   - 既存のcomputed propertyを@Stateに移行

3. **中期（1ヶ月以内）**
   - ViewModelパターンへの完全移行
   - 包括的なテストの追加

## 📝 学んだ教訓

1. **SwiftUIのデータフロー設計の重要性**
   - computed propertyは単純な計算にのみ使用
   - 非同期データには@Stateまたは@PublishedでIを明示的に管理

2. **デバッグの落とし穴**
   - print文自体がビューの再評価を引き起こす可能性
   - ログだけでなく、設計レベルでの問題分析が必要

3. **段階的リファクタリングの必要性**
   - 一度にすべてを修正しようとせず、段階的に改善
   - 各段階でテストを実施し、動作を確認

---

**作成者:** Claude
**レビュー:** 未実施
**承認:** 未実施