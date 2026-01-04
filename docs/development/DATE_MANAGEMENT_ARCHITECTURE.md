# 日付管理とスワイプ機能のアーキテクチャ設計

最終更新: 2026-01-05

## 問題の背景

WatchMeアプリのホーム画面において、以下の2つの要件を両立させる必要があります：

1. **スワイプによるページング**: ユーザーが直感的に日付を切り替えられる
2. **正確な日付管理**: 選択された日付のデータを正しく表示する

この2つの要件を同時に満たすことが、技術的に非常に困難である理由を解説し、解決策を提案します。

## なぜスワイプが難しいのか

### SwiftUI TabViewの制約

TabViewは以下の特性を持ちます：

```swift
TabView(selection: $selectedDate) {
    ForEach(dateRange, id: \.self) { date in
        SomeView()
            .tag(date)  // 各ページに一意のタグが必要
    }
}
```

**制約1: ビューとタグの1対1関係**
- 各ページは一意のタグで識別される
- タグが変わるとページが切り替わる

**制約2: ビューの事前生成**
- ForEachで定義されたビューは事前に生成される
- ビューの再利用により、プロパティの更新が複雑

**制約3: ジェスチャー認識の階層**
- TabViewがスワイプジェスチャーを処理
- 子ビューがタッチイベントを処理
- 両者の調整が必要

## 現在までの試行錯誤

### 試行1: 複数ビュー + 固定日付

```swift
SimpleDashboardView(date: date, selectedDate: $selectedDate)
```

**問題**: 各ビューのdateが固定値のため、日付変更が反映されない

### 試行2: 応急処置（すべてのビューを同期）

```swift
.onChange(of: selectedDate) {
    date = selectedDate  // すべてのビューが同じ日付に
}
```

**問題**: 7つのビューが同じデータを表示（無駄）

### 試行3: 単一ビュー構造（ZStack）

```swift
ZStack {
    TabView { Color.clear... }  // スワイプ制御
    SimpleDashboardView(selectedDate: $selectedDate)  // コンテンツ
}
```

**問題**: `.allowsHitTesting(false)`によりスワイプも無効化

## 解決策の提案

### 解決策A: ビュー識別子による再生成【推奨】

```swift
struct ContentView: View {
    @State private var selectedDate = Date()

    var body: some View {
        TabView(selection: $selectedDate) {
            ForEach(dateRange, id: \.self) { date in
                SimpleDashboardView(selectedDate: $selectedDate)
                    .tag(date)
                    .id("\(deviceId)_\(selectedDate)")  // 重要：ビューを強制再生成
            }
        }
    }
}
```

**メリット:**
- スワイプ完全動作
- 日付管理が正確
- 古いビューは自動的に破棄

**デメリット:**
- ビュー再生成のコスト

### 解決策B: アクティブビューの動的切り替え

```swift
struct SmartDashboardView: View {
    let pageDate: Date
    @Binding var selectedDate: Date

    var isActive: Bool {
        Calendar.current.isDate(pageDate, inSameDayAs: selectedDate)
    }

    var body: some View {
        if isActive {
            // アクティブなページは完全なビュー
            FullDashboardView(selectedDate: $selectedDate)
        } else {
            // 非アクティブは軽量プレースホルダー
            EmptyDashboardView()
        }
    }
}
```

**メリット:**
- メモリ効率的
- スワイプ動作保証

**デメリット:**
- 切り替え時の遅延可能性

### 解決策C: ビューモデルの共有

```swift
@StateObject private var dashboardViewModel = DashboardViewModel()

TabView(selection: $selectedDate) {
    ForEach(dateRange, id: \.self) { date in
        DashboardViewWrapper(
            pageDate: date,
            viewModel: dashboardViewModel
        )
        .tag(date)
    }
}
.onChange(of: selectedDate) { newDate in
    dashboardViewModel.loadData(for: newDate)
}
```

**メリット:**
- データの一元管理
- ビューは軽量

**デメリット:**
- 複雑な状態管理

## 推奨実装パターン

### 最適解: ハイブリッドアプローチ

```swift
struct ContentView: View {
    @State private var selectedDate = Date()
    @StateObject private var dataCache = DataCacheManager()

    var body: some View {
        TabView(selection: $selectedDate) {
            ForEach(dateRange, id: \.self) { date in
                OptimizedDashboardView(
                    pageDate: date,
                    selectedDate: $selectedDate,
                    dataCache: dataCache
                )
                .tag(date)
            }
        }
        .tabViewStyle(.page)
    }
}

struct OptimizedDashboardView: View {
    let pageDate: Date
    @Binding var selectedDate: Date
    @ObservedObject var dataCache: DataCacheManager

    private var isCurrentPage: Bool {
        Calendar.current.isDate(pageDate, inSameDayAs: selectedDate)
    }

    private var isNearbyPage: Bool {
        abs(pageDate.timeIntervalSince(selectedDate)) < 86400 * 2  // 前後2日
    }

    var body: some View {
        Group {
            if isCurrentPage {
                // 現在のページ：完全なビュー
                ActiveDashboardView(date: selectedDate, dataCache: dataCache)
            } else if isNearbyPage {
                // 近隣ページ：プリロード
                PreloadDashboardView(date: pageDate, dataCache: dataCache)
            } else {
                // 遠いページ：空ビュー
                Color.clear
            }
        }
    }
}
```

## パフォーマンス最適化

### 1. 遅延評価

```swift
LazyVStack {
    // コンテンツは必要時のみ生成
}
```

### 2. キャッシュ戦略

```swift
class DataCacheManager: ObservableObject {
    private var cache: [String: CachedData] = [:]
    private let maxCacheSize = 7  // 1週間分

    func getData(for date: Date) -> DashboardData? {
        let key = cacheKey(for: date)
        return cache[key]?.data
    }
}
```

### 3. プリフェッチ

```swift
.onAppear {
    // 前後の日付のデータをプリフェッチ
    prefetchAdjacentDates()
}
```

## 根本的な問題：構造の不自然さ

### なぜTabViewを使うと無理が生じるのか

**TabViewの本来の用途：**
- 固定的なタブ切り替え（「ホーム」「設定」「プロフィール」など）
- 各タブは独立したコンテンツ

**日付スワイプの本来の構造：**
- 動的なページリスト（日付は無限に存在）
- 各ページは同じテンプレート、データだけが異なる

**現在の構造が不自然な理由：**

1. **SimpleDashboardViewが巨大すぎる（1300行）**
   - データ取得、キャッシュ、UI、すべてが詰まっている
   - これを7つも生成するのは非効率

2. **TabViewのページング用途への転用**
   - TabViewは元々そういう用途ではない
   - 無理やり使うことで複雑化

3. **データとUIの密結合**
   - 各ビューが独自にAPIを叩く
   - 状態管理が複雑

### 一般的なアプリの構造（カレンダー、ニュース等）

```swift
// 1. データ層の分離
@StateObject var dataStore = DashboardDataStore()

// 2. 軽量なページビュー
PageView(selectedDate: $selectedDate) { date in
    DayView(date: date, data: dataStore.data(for: date))
}

// データストアの例
class DashboardDataStore: ObservableObject {
    @Published private var cache: [Date: DashboardData] = [:]

    func data(for date: Date) -> DashboardData? {
        if let cached = cache[date] { return cached }
        Task { await loadData(for: date) }
        return nil
    }

    private func loadData(for date: Date) async {
        // API呼び出し
        let data = await fetchFromAPI(date: date)
        await MainActor.run {
            cache[date] = data
        }
    }
}
```

## 正しい構造への再設計（UIPageViewController使用）

### 1. データストアの分離

```swift
// Services/DashboardDataStore.swift
@MainActor
class DashboardDataStore: ObservableObject {
    @Published private var cache: [String: CachedDashboardData] = [:]
    private let maxCacheSize = 30  // 30日分

    private let supabase: SupabaseDataManager

    func getData(for date: Date, deviceId: String) -> DashboardData? {
        let key = cacheKey(for: date, deviceId: deviceId)

        // キャッシュヒット
        if let cached = cache[key], !isExpired(cached) {
            return cached.data
        }

        // バックグラウンドで取得
        Task {
            await loadData(for: date, deviceId: deviceId)
        }

        return nil
    }

    private func loadData(for date: Date, deviceId: String) async {
        let key = cacheKey(for: date, deviceId: deviceId)

        // 既に読み込み中なら重複を避ける
        guard !loadingKeys.contains(key) else { return }
        loadingKeys.insert(key)

        do {
            let data = try await supabase.fetchAllReports(
                deviceId: deviceId,
                date: date
            )

            cache[key] = CachedDashboardData(
                data: data,
                timestamp: Date()
            )

            // LRU管理
            if cache.count > maxCacheSize {
                removeOldestCache()
            }
        } catch {
            print("Error loading data: \(error)")
        }

        loadingKeys.remove(key)
    }
}
```

### 2. UIPageViewControllerベースのページビュー

```swift
// Views/DatePageViewController.swift
struct DatePageView: UIViewControllerRepresentable {
    @Binding var currentDate: Date
    @ObservedObject var dataStore: DashboardDataStore
    @EnvironmentObject var deviceManager: DeviceManager

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageVC = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )

        pageVC.dataSource = context.coordinator
        pageVC.delegate = context.coordinator

        // 初期ページを設定
        if let initialVC = context.coordinator.viewController(for: currentDate) {
            pageVC.setViewControllers(
                [initialVC],
                direction: .forward,
                animated: false
            )
        }

        return pageVC
    }

    func updateUIViewController(_ pageVC: UIPageViewController, context: Context) {
        // 外部からの日付変更に対応
        context.coordinator.updateCurrentDate(currentDate, in: pageVC)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            parent: self,
            dataStore: dataStore,
            deviceManager: deviceManager
        )
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        let parent: DatePageView
        let dataStore: DashboardDataStore
        let deviceManager: DeviceManager

        func viewController(for date: Date) -> UIHostingController<DayContentView>? {
            guard let deviceId = deviceManager.selectedDeviceID else { return nil }

            let data = dataStore.getData(for: date, deviceId: deviceId)
            let view = DayContentView(date: date, data: data)
                .environmentObject(deviceManager)

            let hosting = UIHostingController(rootView: view)
            hosting.view.tag = dateToTag(date)

            return hosting
        }

        // UIPageViewControllerDataSource
        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            let currentDate = tagToDate(viewController.view.tag)
            let previousDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
            return self.viewController(for: previousDate)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            let currentDate = tagToDate(viewController.view.tag)
            let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
            return self.viewController(for: nextDate)
        }

        // UIPageViewControllerDelegate
        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard completed,
                  let currentVC = pageViewController.viewControllers?.first else { return }

            let newDate = tagToDate(currentVC.view.tag)
            parent.currentDate = newDate
        }
    }
}
```

### 3. 軽量な日付ビュー

```swift
// Views/DayContentView.swift
struct DayContentView: View {
    let date: Date
    let data: DashboardData?

    @EnvironmentObject var deviceManager: DeviceManager

    var body: some View {
        ScrollView {
            if let data = data {
                VStack(spacing: 20) {
                    // ヘッダー
                    DateHeader(date: date)

                    // 気分グラフ
                    VibeGraph(data: data.vibeData)

                    // 感情チャート
                    EmotionChart(data: data.emotionData)

                    // 行動グラフ
                    BehaviorChart(data: data.behaviorData)

                    // コメント
                    CommentSection(date: date, comments: data.comments)
                }
                .padding()
            } else {
                // ローディング
                VStack {
                    ProgressView()
                    Text("読み込み中...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
```

### 4. メインビューの構造

```swift
// ContentView.swift
struct ContentView: View {
    @StateObject private var dataStore = DashboardDataStore()
    @State private var selectedDate = Date()

    @EnvironmentObject var deviceManager: DeviceManager

    var body: some View {
        ZStack(alignment: .top) {
            // ページビュー
            DatePageView(
                currentDate: $selectedDate,
                dataStore: dataStore
            )
            .environmentObject(deviceManager)

            // 固定ヘッダー（日付選択、カレンダーボタンなど）
            StickyDateHeader(selectedDate: $selectedDate)
        }
    }
}
```

## 再設計の作業規模

### 必要な作業

| タスク | 推定時間 | 難易度 |
|-------|---------|--------|
| DashboardDataStore作成 | 2-3時間 | 中 |
| UIPageViewController実装 | 3-4時間 | 高 |
| SimpleDashboardViewの分割 | 4-6時間 | 高 |
| DayContentViewの作成 | 2-3時間 | 中 |
| テストと調整 | 4-6時間 | 中 |
| **合計** | **15-22時間** | **2-3日** |

### 段階的な移行戦略

**Phase 1: データ層の分離（1日）**
1. DashboardDataStoreを作成
2. 既存のデータ取得ロジックを移行
3. SimpleDashboardViewから段階的に切り替え

**Phase 2: UIPageViewController導入（1日）**
1. DatePageViewの実装
2. 基本的なスワイプ動作の確認
3. 既存のContentViewと並行運用

**Phase 3: ビュー層の再構築（1日）**
1. SimpleDashboardViewを複数のコンポーネントに分割
2. DayContentViewに移行
3. 旧ビューを削除

## 現在の応急処置の限界

**試行3（ZStack + Color.clear）の問題：**
- `.allowsHitTesting(false)`がスワイプも無効化
- 根本的な解決にならない

**応急処置の状態（試行2）：**
```swift
.onChange(of: selectedDate) {
    date = selectedDate  // すべてのビューが同じ日付に
}
```
- 動作はするが、7つのビューが無駄
- メモリ効率が悪い
- 構造的に不自然

## 結論と推奨事項

### 短期対策（現在）
1. 試行2の応急処置を維持
2. 動作は保証されるが、構造的な問題は残る

### 中期対策（推奨）
1. 新しいブランチで根本的な再設計
2. UIPageViewControllerベースの実装
3. データ層とUI層の完全分離

### 長期的な利点
- **保守性の向上**: 責任の明確な分離
- **パフォーマンス向上**: 必要なビューのみ生成
- **拡張性**: 新機能の追加が容易

### 実装の優先順位

| 優先度 | タスク | 理由 |
|-------|--------|------|
| 🔴 最優先 | 応急処置のマージ | 動作する状態を確保 |
| 🟡 高 | DashboardDataStoreの設計 | データ層の分離は独立して実施可能 |
| 🟢 中 | UIPageViewControllerの実装 | 時間のある時に段階的に |

## 実装チェックリスト

### Phase 1: データ層分離
- [ ] DashboardDataStore設計書作成
- [ ] DashboardDataStore実装
- [ ] 既存コードとの互換性確認
- [ ] テスト作成

### Phase 2: UIPageViewController導入
- [ ] DatePageView実装
- [ ] Coordinator実装
- [ ] スワイプ動作確認
- [ ] パフォーマンステスト

### Phase 3: ビュー層再構築
- [ ] SimpleDashboardView分割計画
- [ ] DayContentView実装
- [ ] コンポーネント分離
- [ ] 旧コード削除

---

**作成者**: Claude AI Assistant
**作成日**: 2026-01-05
**最終更新**: 2026-01-05
**ステータス**: 検討中（応急処置でリバート予定）