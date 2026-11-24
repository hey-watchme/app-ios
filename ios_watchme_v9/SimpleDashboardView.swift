//
//  SimpleDashboardView.swift
//  ios_watchme_v9
//
//  シンプルなダッシュボード実装（日付バグ修正版）
//

import SwiftUI
import UIKit

// データ取得のトリガーを管理する構造体
struct LoadDataTrigger: Equatable {
    let localDate: String
    let subjectId: String?
    let refreshTrigger: Int  // Pull-to-Refresh用
}

// 📊 パフォーマンス最適化: キャッシュデータ構造（Phase 1-A）
struct CachedDashboardData {
    let dashboardSummary: DashboardSummary?
    let behaviorReport: BehaviorReport?
    let emotionReport: EmotionReport?
    let subject: Subject?
    let timeBlocks: [DashboardTimeBlock]  // グラフ用データ
    let cachedEmotionPercentages: [(String, Double, String, Color)]
    let timestamp: Date
}

struct SimpleDashboardView: View {
    let localDate: String
    @Binding var selectedLocalDate: String
    @EnvironmentObject var subjectManager: SubjectManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var recordingStore: RecordingStore

    init(localDate: String, selectedLocalDate: Binding<String>) {
        self.localDate = localDate
        self._selectedLocalDate = selectedLocalDate
    }

    private var currentTimezone: TimeZone {
        if let subjectId = subjectManager.selectedSubjectID {
            return subjectManager.getTimezone(for: subjectId)
        }
        return subjectManager.selectedTimezone
    }

    private var displayDate: Date {
        LocalDate.date(from: localDate, timezone: currentTimezone) ?? Date()
    }

    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: { displayDate },
            set: { newValue in
                let normalizedLocalDate = LocalDate.string(from: newValue, timezone: currentTimezone)
                let today = LocalDate.today(timezone: currentTimezone)
                selectedLocalDate = min(normalizedLocalDate, today)
            }
        )
    }

    // Push notification manager (centralized)
    @StateObject private var pushManager = PushNotificationManager.shared

    // スティッキーヘッダーの表示状態を内部で管理
    @State private var showStickyHeader = false
    
    // 各データを個別に管理（シンプルに）
    @State private var behaviorReport: BehaviorReport?
    @State private var emotionReport: EmotionReport?
    @State private var subject: Subject?
    @State private var dashboardSummary: DashboardSummary?  // メインデータソース
    @State private var timeBlocks: [DashboardTimeBlock] = []  // グラフ用データ（spot_results）
    @State private var otherDayBlocks: [DashboardTimeBlock] = []  // received this day, recorded on another (imports)
    // Starts as loading: the cache is empty when the page is created, so the first frame
    // is the skeleton rather than an empty day that then turns into the skeleton.
    @State private var isLoading = true
    @State private var lastLoadedSubjectID: String? = nil  // 最後に読み込んだ分析対象のID

    // Phase 2: フィルタ結果を@State変数で明示的に管理
    @State private var conversationBlocks: [DashboardTimeBlock] = []  // 会話があるブロック
    @State private var highlightBlocks: [DashboardTimeBlock] = []  // ハイライト表示用
    @State private var showHighlightSection = false  // ハイライトセクション表示判定

    // 📊 パフォーマンス最適化: 計算結果のキャッシュ
    @State private var cachedEmotionPercentages: [(String, Double, String, Color)] = []

    // 📊 パフォーマンス最適化: データキャッシュ（Phase 1-A）
    @State private var dataCache: [String: CachedDashboardData] = [:]
    @State private var cacheKeys: [String] = []  // LRU管理用
    private let maxCacheSize = 30  // 最近30日分をキャッシュ（スワイプ体験向上＆メモリ効率改善）
    private let currentDayCacheTTL: TimeInterval = 60
    private let historicalCacheTTL: TimeInterval = 1800

    // 📊 パフォーマンス最適化: デバイス選択直後フラグ（Phase 5-A）
    @State private var isInitialLoad = false

    // Pull-to-Refresh trigger (simple approach)
    @State private var refreshTrigger = 0
    @State private var timelineReplayToken = 0  // pull to refresh replays the vibe timeline animation
    @StateObject private var realtime = RealtimeWatcher()  // reload the day as analysis stages finish
    @State private var lastHandledPushTimestamp: Date?

    // モーダル表示管理
    @State private var showBehaviorSheet = false
    @State private var showEmotionSheet = false
    @State private var selectedSpotForDetail: DashboardTimeBlock?
    /// Finished results the person has looked at (the activity card does not repeat them).
    @State private var activitySeen = ActivitySeen.load()
    private let floatingHeaderContentInset: CGFloat = 40

    // MARK: - Activity card and recordings (docs/product/screens.md「ホーム」)

    private var activityBanner: ActivityBanner? {
        let unsent = recordingStore.state.isRecording ? 0 : recordingStore.state.pending.filter { $0.state != .blocked }.count
        return ActivityBanner.current(blocks: timeBlocks + otherDayBlocks, unsentChunks: unsent,
                                      viewingDate: localDate, seen: activitySeen)
    }

    private func openActivity(_ banner: ActivityBanner) {
        if let key = banner.seenKey {
            ActivitySeen.add(key)
            activitySeen.insert(key)
        }
        switch banner {
        case .analysing(let id, _, _), .recordingDone(let id, _), .recordingFailed(let id, _):
            selectedSpotForDetail = (timeBlocks + otherDayBlocks).first { $0.id == id }
        case .dayUpdated, .sending:
            // The day's analysis is this screen
            break
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    // 大きい日付セクション（スクロール可能）
                    LargeDateSection(selectedDate: selectedDateBinding)
                        .environmentObject(subjectManager)
                        .environmentObject(dataManager)
                        .padding(.top, floatingHeaderContentInset)
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: geometry.frame(in: .named("scroll")).minY
                                    )
                            }
                        )
                    
                    // Dashboard content
                    LazyVStack(spacing: 16) {
                        if isLoading {
                            SkeletonView()
                        } else {
                            // 1. Activity: one slim card that follows the latest recording through sending
                            // and analysis, then says it is done until looked at (docs/product/screens.md)
                            if let banner = activityBanner {
                                ActivityBannerView(
                                    banner: banner,
                                    onTap: { openActivity(banner) }
                                )
                                .padding(.horizontal, 20)
                                .transition(.opacity)
                            }

                            // 2. The day itself: the same content the report opens (DayContentView)
                            DayContentView(subjectId: subjectManager.selectedSubjectID, localDate: localDate,
                                           summary: dashboardSummary, blocks: timeBlocks,
                                           onOpenSpot: { selectedSpotForDetail = $0 }) {
                                // Questions the analysis could not settle (hidden when none are open)
                                QuestionsEntry(subjectId: subjectManager.selectedSubjectID, place: .dashboard)
                            }
                            .padding(.horizontal, 20)
                            .transition(.opacity)

                            Spacer(minLength: 100)
                        }
                    }
                    .padding(.top, 8)
                    .animation(.easeInOut(duration: 0.3), value: isLoading)
                    .animation(.easeInOut(duration: 0.3), value: dashboardSummary?.date)
                    .animation(.easeInOut(duration: 0.3), value: timeBlocks.count)
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                // 📊 パフォーマンス最適化: ログ出力を削減
                // LargeDateSectionが画面外に出そうになったら固定ヘッダーを表示
                let shouldShowStickyHeader = value < -150
                if shouldShowStickyHeader != showStickyHeader {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showStickyHeader = shouldShowStickyHeader
                    }
                }
            }
            .refreshable {
                // Pull-to-Refresh: Simple trigger approach to avoid Task cancellation
                refreshTrigger += 1
                timelineReplayToken += 1
            }
            .background(
                ZStack {
                    Color.darkBase
                    // Subtle ambient gradient for depth (Oura-style)
                    LinearGradient(
                        colors: [
                            Color(white: 0.07).opacity(0.6),
                            Color.clear,
                            Color(white: 0.04).opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()
            )
            
            // 固定日付ヘッダー（条件付き表示）
            if showStickyHeader {
                StickyDateHeader(selectedDate: selectedDateBinding)
                    .environmentObject(subjectManager)
                    .environmentObject(dataManager)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task(id: LoadDataTrigger(localDate: localDate, subjectId: subjectManager.selectedSubjectID, refreshTrigger: refreshTrigger)) {
            // 📊 パフォーマンス最適化: データ取得を一元化（Phase 1-A: デバウンス + キャッシュ）
            guard subjectManager.isReady else {
                #if DEBUG
                print("⏸️ [SimpleDashboardView] SubjectManager not ready, skipping data load")
                #endif
                await MainActor.run {
                    clearAllData()
                    isLoading = false
                }
                return
            }

            // キャッシュキーの生成
            guard let subjectId = subjectManager.selectedSubjectID else {
                await MainActor.run {
                    clearAllData()
                    isLoading = false
                }
                return
            }

            let dateString = localDate
            let cacheKey = "\(subjectId)_\(dateString)"

            // Pull-to-Refresh: Clear cache if triggered
            if refreshTrigger > 0 {
                dataCache.removeValue(forKey: cacheKey)
                cacheKeys.removeAll { $0 == cacheKey }
                print("🔄 [Pull-to-Refresh] Cache cleared for \(dateString)")
            }

            // ✅ キャッシュヒット → 即座に表示（スワイプ超高速）
            if let cached = dataCache[cacheKey] {
                if shouldUseCachedData(cached, for: localDate, timezone: currentTimezone) {
                    await MainActor.run {
                        self.dashboardSummary = cached.dashboardSummary
                        self.behaviorReport = cached.behaviorReport
                        self.emotionReport = cached.emotionReport
                        self.subject = cached.subject
                        self.timeBlocks = cached.timeBlocks  // グラフ用データ
                        self.cachedEmotionPercentages = cached.cachedEmotionPercentages

                        // Phase 2: キャッシュ復元時もフィルタリング実行
                        self.updateFilteredData()
                        self.isLoading = false
                    }
                    print("✅ [Cache HIT] Data loaded from cache for \(dateString)")
                    return
                } else {
                    print("⚠️ [Cache BYPASS] Refreshing cached data for \(dateString)")
                }
            }

            // 📊 Phase 5-B: 即座にローディング表示を開始
            await MainActor.run {
                isLoading = true
            }

            // ✅ キャッシュミス → デバウンス処理を最適化
            if !isInitialLoad {
                // デバウンス時間を動的に決定
                let debounceTime: UInt64
                if dataCache[cacheKey] != nil {
                    // キャッシュ存在時（期限切れ）: 100ms
                    debounceTime = 100
                } else {
                    // 完全に新規データ: 200ms（300msから短縮）
                    debounceTime = 200
                }

                #if DEBUG
                print("⏳ [Debounce] Waiting \(debounceTime)ms before loading data for \(dateString)...")
                #endif
                try? await Task.sleep(for: .milliseconds(debounceTime))

                // スワイプ継続中ならキャンセルされている
                guard !Task.isCancelled else {
                    print("🚫 [Cancelled] Data loading cancelled for \(dateString)")
                    await MainActor.run {
                        isLoading = false
                    }
                    return
                }
            } else {
                print("⚡️ [Initial Load] Skipping debounce for immediate data loading")
                // 初回フラグをリセット
                await MainActor.run {
                    isInitialLoad = false
                }
            }

            // ✅ スワイプ停止後のみデータ取得
            #if DEBUG
            print("📡 [API Request] Loading data for \(dateString)...")
            #endif
            await loadAllData()

            // ✅ キャッシュに保存
            await MainActor.run {
                let cached = CachedDashboardData(
                    dashboardSummary: self.dashboardSummary,
                    behaviorReport: self.behaviorReport,
                    emotionReport: self.emotionReport,
                    subject: self.subject,
                    timeBlocks: self.timeBlocks,  // グラフ用データ
                    cachedEmotionPercentages: self.cachedEmotionPercentages,
                    timestamp: Date()
                )

                guard shouldPersistCache(for: localDate, timezone: currentTimezone) else {
                    dataCache.removeValue(forKey: cacheKey)
                    cacheKeys.removeAll { $0 == cacheKey }
                    print("⚠️ [Cache SKIP] Empty current-day data was not cached for \(dateString)")
                    return
                }

                dataCache[cacheKey] = cached

                // LRU管理: 既存のキーを削除してから追加
                if let existingIndex = cacheKeys.firstIndex(of: cacheKey) {
                    cacheKeys.remove(at: existingIndex)
                }
                cacheKeys.append(cacheKey)

                // 古いキャッシュを削除
                if cacheKeys.count > maxCacheSize {
                    let oldKey = cacheKeys.removeFirst()
                    dataCache.removeValue(forKey: oldKey)
                }
            }
        }
        .task(id: LoadDataTrigger(localDate: localDate, subjectId: subjectManager.selectedSubjectID, refreshTrigger: refreshTrigger)) {
            await loadOtherDayBlocks()
        }
        .task(id: subjectManager.selectedSubjectID) {
            guard let subjectId = subjectManager.selectedSubjectID else { await realtime.stop(); return }
            realtime.onChange = { Task { await silentRefreshCurrentDay() } }
            await realtime.watch(subjectId: subjectId)
        }
        .onChange(of: subjectManager.selectedSubjectID) { oldSubjectId, newSubjectId in
            // デバイスが切り替わったときにデータとキャッシュをクリア（Phase 1-A）
            if oldSubjectId != nil && newSubjectId != nil && oldSubjectId != newSubjectId {
                clearAllData()
                // キャッシュもクリア
                dataCache.removeAll()
                cacheKeys.removeAll()

                // 📊 Phase 5-A: 初回読み込みフラグを設定（デバウンススキップ）
                isInitialLoad = true
            }
        }
        .onChange(of: timeBlocks) { oldValue, newValue in
            // Phase 2: timeBlocksが更新されたら自動的にフィルタリング実行
            updateFilteredData()
        }
        .onChange(of: pushManager.latestUpdate) { oldValue, newValue in
            guard let update = newValue else { return }
            processPushUpdateIfNeeded(update)
        }
        .onAppear {
            // Handle pending update when app is opened from notification tap
            if let update = pushManager.latestUpdate {
                processPushUpdateIfNeeded(update)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refreshCurrentDayIfNeeded(reason: "foreground")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshCurrentDayIfNeeded(reason: "significantTimeChange")
        }
        .sheet(isPresented: $showBehaviorSheet) {
            NavigationView {
                BehaviorGraphView(selectedDate: displayDate)
                    .environmentObject(subjectManager)
                    .environmentObject(dataManager)
                    .navigationBarTitleDisplayMode(.large)
                    .navigationTitle("行動グラフ")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            CloseButton {
                                showBehaviorSheet = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showEmotionSheet) {
            NavigationView {
                EmotionGraphView(selectedDate: displayDate)
                    .environmentObject(subjectManager)
                    .environmentObject(dataManager)
                    .navigationBarTitleDisplayMode(.large)
                    .navigationTitle("感情グラフ")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            CloseButton {
                                showEmotionSheet = false
                            }
                        }
                    }
            }
        }
        .sheet(item: $selectedSpotForDetail) { spot in
            if let subjectId = subjectManager.selectedSubjectID {
                SpotDetailView(subjectId: subjectId, spotData: spot)
                    .environmentObject(dataManager)
            }
        }
    }

    private func processPushUpdateIfNeeded(_ update: PushNotificationManager.PushNotificationUpdate) {
        // Avoid duplicate handling when onChange and onAppear fire for the same payload
        if lastHandledPushTimestamp == update.timestamp {
            return
        }

        // Only process dashboard refresh notifications
        guard update.type == .refreshDashboard else { return }

        // Filter: only when the push is for the subject on screen
        guard update.subjectId == subjectManager.selectedSubjectID else {
            print("⚠️ [PUSH] Update ignored (different device)")
            return
        }

        let viewDateString = localDate

        // Filter: only this view's date
        guard viewDateString == update.date else {
            print("⚠️ [PUSH] Update ignored (different date: view=\(viewDateString), update=\(update.date))")
            return
        }

        lastHandledPushTimestamp = update.timestamp
        print("🔄 [PUSH] Dashboard update received: \(update.subjectId) - \(update.date)")

        let cacheKey = "\(update.subjectId)_\(update.date)"
        dataCache.removeValue(forKey: cacheKey)
        cacheKeys.removeAll { $0 == cacheKey }
        print("🗑️ [PUSH] Cache cleared: \(cacheKey)")

        Task {
            await loadAllData()
            await MainActor.run {
                ToastManager.shared.showInfo(title: update.message)
                print("🍞 [PUSH] Toast displayed: \(update.message)")
            }
            PushNotificationManager.shared.clearUpdate()
        }
    }

    private func isToday(_ targetLocalDate: String, timezone: TimeZone) -> Bool {
        targetLocalDate == LocalDate.today(timezone: timezone)
    }

    private func shouldUseCachedData(_ cached: CachedDashboardData, for targetLocalDate: String, timezone: TimeZone) -> Bool {
        let isCurrentDay = isToday(targetLocalDate, timezone: timezone)
        let cacheTTL = isCurrentDay ? currentDayCacheTTL : historicalCacheTTL

        if isCurrentDay && cached.dashboardSummary == nil && cached.timeBlocks.isEmpty {
            return false
        }

        return Date().timeIntervalSince(cached.timestamp) < cacheTTL
    }

    private func shouldPersistCache(for targetLocalDate: String, timezone: TimeZone) -> Bool {
        if !isToday(targetLocalDate, timezone: timezone) {
            return true
        }

        return dashboardSummary != nil || !timeBlocks.isEmpty
    }

    /// Realtime: reload today's data without the skeleton, so only the changed parts redraw.
    private func silentRefreshCurrentDay() async {
        guard let subjectId = subjectManager.selectedSubjectID else { return }
        guard isToday(localDate, timezone: subjectManager.getTimezone(for: subjectId)) else { return }
        guard !isLoading else { return }
        await loadAllData(showLoading: false)
        await loadOtherDayBlocks()
        // The cached copy of today is now stale; drop it so the next visit reloads.
        let cacheKey = "\(subjectId)_\(localDate)"
        dataCache.removeValue(forKey: cacheKey)
        cacheKeys.removeAll { $0 == cacheKey }
        #if DEBUG
        print("🔄 [Dashboard Refresh] silent (realtime)")
        #endif
    }

    /// Recordings that arrived on this day but belong to another (imported files), for the activity strip and log.
    private func loadOtherDayBlocks() async {
        guard let subjectId = subjectManager.selectedSubjectID else {
            await MainActor.run { otherDayBlocks = [] }
            return
        }
        let blocks = await dataManager.fetchReceivedFromOtherDays(
            subjectId: subjectId, localDate: localDate, timezone: subjectManager.getTimezone(for: subjectId)
        )
        await MainActor.run { otherDayBlocks = blocks }
    }

    private func refreshCurrentDayIfNeeded(reason: String) {
        guard let subjectId = subjectManager.selectedSubjectID else { return }
        let timezone = subjectManager.getTimezone(for: subjectId)

        guard isToday(localDate, timezone: timezone) else { return }

        refreshTrigger += 1
        print("🔄 [Dashboard Refresh] Triggered for current day (\(reason))")
    }
    
    // MARK: - View Components
    
    private var vibeGraphCard: some View {
        Group {
            if dashboardSummary != nil || !timeBlocks.isEmpty {
                ModernVibeCard(
                    dashboardSummary: dashboardSummary,
                    timeBlocks: timeBlocks,  // spot_resultsから取得したグラフデータ
                    onNavigateToDetail: { },
                    showTitle: false,
                    showHeaderSection: false,
                    showInsightSection: false,
                    showFooterLink: false,
                    timelineTitle: "Daily vibe timeline",
                    replayToken: timelineReplayToken
                )
            } else {
                // エンプティーステート：ナビゲーションボタンを非表示
                if subjectManager.selectedSubjectID == nil {
                    SubjectNotSelectedView(graphType: .vibe, isCompact: true)
                } else {
                    GraphEmptyStateView(graphType: .vibe, isCompact: true)
                }
            }
        }
    }

    // Phase 2: フィルタリングロジック（明示的な更新）
    private func updateFilteredData() {
        // rating > 0 のブロックをフィルタリング（rating == 0 または nil を除外）
        conversationBlocks = timeBlocks.filter { block in
            #if DEBUG
            print("📊 [FILTER DEBUG] block time: \(block.displayTime), rating: \(block.rating?.description ?? "nil"), summary: \(block.summary?.prefix(30) ?? "nil")")
            #endif

            guard let rating = block.rating else {
                // rating が nil の場合は除外（古いデータ）
                #if DEBUG
                print("   → EXCLUDED (rating is nil)")
                #endif
                return false
            }

            let shouldInclude = rating > 0
            #if DEBUG
            print("   → \(shouldInclude ? "INCLUDED" : "EXCLUDED") (rating: \(rating))")
            #endif
            return shouldInclude
        }

        #if DEBUG
        print("✅ [FILTER RESULT] conversationBlocks count: \(conversationBlocks.count)")
        print("✅ [FILTER RESULT] highlightBlocks count (after reverse): \(conversationBlocks.count)")
        #endif

        // ハイライト表示の判定
        showHighlightSection = !conversationBlocks.isEmpty

        // ハイライト表示用データの準備（新しい順）
        highlightBlocks = conversationBlocks.reversed()
    }

    // Highlight section (conversation-focused, no fallback)
    private var behaviorGraphCard: some View {
        UnifiedCard(
            title: "行動",
            navigationLabel: "行動詳細",
            onNavigate: { }
        ) {
            if let behaviorReport = behaviorReport {
                VStack(spacing: 8) {
                    let filteredRanking = behaviorReport.summaryRanking.filter { 
                        $0.event.lowercased() != "other" && $0.event.lowercased() != "その他" 
                    }
                    
                    if let topBehavior = filteredRanking.first {
                        VStack(spacing: 8) {
                            Text("🚶")
                                .font(.system(size: 108))  // 1.5倍に拡大（72 * 1.5 = 108）

                            HStack(spacing: 8) {
                                Text(topBehavior.event)
                                    .font(.caption)
                                    .foregroundStyle(Color.safeColor("BehaviorTextPrimary"))
                                    .textCase(.uppercase)
                                    .tracking(1.0)

                                Text("\(topBehavior.count)回")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.safeColor("BehaviorTextPrimary"))
                            }
                        }
                        .padding(.bottom, 30)  // 下に30px余白
                    }
                    
                    behaviorReportContent(behaviorReport)
                }
            } else {
                if subjectManager.selectedSubjectID == nil {
                    SubjectNotSelectedView(graphType: .behavior, isCompact: true)
                } else {
                    GraphEmptyStateView(graphType: .behavior, isCompact: true)
                }
            }
        }
        .onTapGesture {
            showBehaviorSheet = true
        }
    }
    
    private var emotionGraphCard: some View {
        UnifiedCard(
            title: "感情",
            navigationLabel: "感情詳細",
            onNavigate: { }
        ) {
            if let emotionReport = emotionReport {
                emotionReportContent(emotionReport)
            } else {
                if subjectManager.selectedSubjectID == nil {
                    SubjectNotSelectedView(graphType: .emotion, isCompact: true)
                } else {
                    GraphEmptyStateView(graphType: .emotion, isCompact: true)
                }
            }
        }
        .onTapGesture {
            showEmotionSheet = true
        }
    }
    
    private func behaviorReportContent(_ report: BehaviorReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let filteredRanking = report.summaryRanking.filter {
                $0.event.lowercased() != "other" && $0.event.lowercased() != "その他"
            }
            
            if filteredRanking.count > 1 {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(filteredRanking.prefix(10).enumerated()), id: \.element.id) { index, behavior in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.body)  // caption → body
                                .fontWeight(.medium)
                                .foregroundStyle(Color.safeColor("BehaviorTextSecondary"))
                                .frame(width: 24, alignment: .leading)

                            Text(behavior.event)
                                .font(.body)  // subheadline → body
                                .foregroundStyle(Color.safeColor("BehaviorTextPrimary"))
                                .lineLimit(1)

                            Spacer()

                            Text("\(behavior.count)")
                                .font(.body)  // caption → body
                                .foregroundStyle(Color.safeColor("BehaviorTextTertiary"))
                        }
                    }
                }
                .padding()
                .background(Color.safeColor("CardBackground"))
                .cornerRadius(8)
            }
        }
    }
    
    // 感情データの計算用のヘルパー関数
    // 📊 パフォーマンス最適化: 1回のループで全感情の合計を計算（Phase 3-A）
    private func calculateEmotionPercentages(from activeTimePoints: [EmotionTimePoint]) -> [(String, Double, String, Color)] {
        // 各感情の合計値を1回のループで計算
        var totals: [String: Double] = [
            "neutral": 0.0, "joy": 0.0, "anger": 0.0, "sadness": 0.0
        ]

        for point in activeTimePoints {
            totals["neutral"]! += point.neutral
            totals["joy"]! += point.joy
            totals["anger"]! += point.anger
            totals["sadness"]! += point.sadness
        }

        // 全感情の総計
        let grandTotal = totals.values.reduce(0.0, +)

        guard grandTotal > 0 else { return [] }

        // パーセンテージを計算
        return [
            ("neutral", totals["neutral"]! / grandTotal * 100, "😐", Color.safeColor("EmotionNeutral")),
            ("joy", totals["joy"]! / grandTotal * 100, "😊", Color.safeColor("EmotionJoy")),
            ("anger", totals["anger"]! / grandTotal * 100, "😠", Color.safeColor("ErrorColor")),
            ("sadness", totals["sadness"]! / grandTotal * 100, "😢", Color.safeColor("PrimaryActionColor"))
        ]
    }
    
    private func emotionReportContent(_ report: EmotionReport) -> some View {
        VStack(spacing: 16) {
            if !report.emotionGraph.isEmpty {
                let activeTimePoints = report.emotionGraph.filter { $0.totalEmotions > 0 }

                if !activeTimePoints.isEmpty {
                    // 📊 パフォーマンス最適化: キャッシュされた結果を使用
                    let allEmotions = cachedEmotionPercentages

                // トップ感情（1位のみ）を絵文字で表示
                if let topEmotion = allEmotions.first {
                    VStack(spacing: 8) {
                        Text(topEmotion.2)
                            .font(.system(size: 108))  // 1.5倍に拡大

                        HStack(spacing: 8) {
                            Text(emotionLabel(for: topEmotion.0))
                                .font(.caption)
                                .foregroundStyle(Color.safeColor("BehaviorTextPrimary"))
                                .textCase(.uppercase)
                                .tracking(1.0)

                            Text("\(Int(topEmotion.1.rounded()))%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.safeColor("BehaviorTextPrimary"))
                        }
                    }
                    .padding(.bottom, 30)  // 下に30px余白
                }

                // 感情バー（4つすべて表示）
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(allEmotions.enumerated()), id: \.element.0) { index, emotion in
                        HStack {
                            Text(emotionLabel(for: emotion.0))
                                .font(.body)  // caption → body
                                .frame(width: 80, alignment: .leading)

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.safeColor("BorderLight").opacity(0.2))
                                        .frame(height: 6)
                                        .cornerRadius(3)

                                    Rectangle()
                                        .fill(Color.safeColor("AppAccentColor"))  // 統一感のため紫色に変更
                                        .frame(width: geometry.size.width * CGFloat(emotion.1) / 100, height: 6)
                                        .cornerRadius(3)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
                .padding()
                .background(Color.safeColor("CardBackground"))
                .cornerRadius(8)
                } else {
                    // アクティブなデータポイントがない場合
                    Text("感情データがありません")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            } else {
                // emotionGraphが空の場合
                Text("データなし")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }
    
    private func emotionLabel(for key: String) -> String {
        switch key.lowercased() {
        case "neutral": return "中立"
        case "joy": return "喜び"
        case "trust": return "信頼"
        case "fear": return "恐れ"
        case "surprise": return "驚き"
        case "sadness": return "悲しみ"
        case "disgust": return "嫌悪"
        case "anger": return "怒り"
        case "anticipation": return "期待"
        default: return key
        }
    }
    
    private func clearAllData() {
        behaviorReport = nil
        emotionReport = nil
        subject = nil
        dashboardSummary = nil
        timeBlocks = []  // グラフ用データもクリア
    }


    /// showLoading: false keeps the current content on screen and swaps the data in place
    /// (used for Realtime updates, so the page does not flash or jump to the top).
    private func loadAllData(showLoading: Bool = true) async {
        // 📊 パフォーマンス最適化: 詳細ログを削減
        guard let subjectId = subjectManager.selectedSubjectID else {
            // データをクリア
            await MainActor.run {
                self.behaviorReport = nil
                self.emotionReport = nil
                self.subject = nil
                self.dashboardSummary = nil
                self.timeBlocks = []
            }
            return
        }

        // ローディング開始
        if showLoading {
            await MainActor.run {
                isLoading = true
            }
        }

        defer {
            if showLoading {
                Task { @MainActor in
                    isLoading = false
                }
            }
        }

        // 📊 Performance optimization: Parallel network requests
        let timezone = subjectManager.getTimezone(for: subjectId)

        async let resultTask = dataManager.fetchAllReports(
            subjectId: subjectId,
            localDate: localDate,
            timezone: timezone
        )
        async let timeBlocksTask = dataManager.fetchDashboardTimeBlocks(
            subjectId: subjectId,
            localDate: localDate,
            timezone: timezone
        )

        let (result, fetchedTimeBlocks) = await (resultTask, timeBlocksTask)

        // 取得したデータを設定
        await MainActor.run {
            self.behaviorReport = result.behaviorReport
            self.emotionReport = result.emotionReport
            self.subject = result.subject
            self.dashboardSummary = result.dashboardSummary
            self.timeBlocks = fetchedTimeBlocks  // グラフ用データ

            // 📊 パフォーマンス最適化: 感情データのキャッシュを更新
            if let emotionReport = result.emotionReport {
                let activeTimePoints = emotionReport.emotionGraph.filter { $0.totalEmotions > 0 }
                if !activeTimePoints.isEmpty {
                    let emotions = calculateEmotionPercentages(from: activeTimePoints)
                    let nonZeroEmotions = emotions.filter { $0.1 > 0 }
                    self.cachedEmotionPercentages = nonZeroEmotions.sorted { $0.1 > $1.1 }
                } else {
                    self.cachedEmotionPercentages = []
                }
            } else {
                self.cachedEmotionPercentages = []
            }

            // Phase 2: データ取得後にフィルタリングを明示的に実行
            self.updateFilteredData()
        }
    }
}

// MARK: - Spot Analysis Card

struct SpotAnalysisCard: View {
    let timeBlock: DashboardTimeBlock
    var onTapDetail: (() -> Void)? = nil

    private var summaryFirstLine: String? {
        guard let summary = timeBlock.summary else { return nil }
        let lines = summary.components(separatedBy: .newlines)
        return lines.first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row: time + score + mini gauge
            HStack(spacing: 12) {
                Text(timeBlock.displayTime)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(white: 0.6))

                if let score = timeBlock.vibeScore {
                    HStack(spacing: 6) {
                        Text(String(format: "%@%.0f", score >= 0 ? "+" : "", score))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(timeBlock.scoreColor)
                    }
                }

                Spacer()
                
                // Mini Emotion Gauge (if available)
                if !timeBlock.topEmotions.isEmpty {
                    miniEmotionGauge(timeBlock.topEmotions)
                        .frame(width: 40, height: 4)
                }

                if onTapDetail != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(white: 0.25))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            // Card content
            VStack(alignment: .leading, spacing: 10) {
                // While the pipeline runs, the card shows how far it has got
                if timeBlock.stages.isInProgress {
                    StageProgressRow(stages: timeBlock.stages, compact: true)
                } else if timeBlock.summary == nil {
                    // Finished (or stopped) without an analysis
                    if timeBlock.stages.isEmpty {
                        Text("分析の結果がありません")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(white: 0.6))
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("分析できませんでした")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.accentCoral)
                            StageProgressRow(stages: timeBlock.stages, compact: true)
                        }
                    }
                }

                if let firstLine = summaryFirstLine {
                    Text(firstLine)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                        .lineSpacing(2)
                }

                // Tags row 
                HStack(spacing: 6) {
                    if let behavior = timeBlock.behavior, !behavior.isEmpty {
                        tagPill(text: behavior, color: .accentTeal, backgroundColor: Color.accentTeal.opacity(0.1))
                    }

                    if let emotion = timeBlock.emotion, !emotion.isEmpty {
                        tagPill(text: emotion, color: .accentTealMuted, backgroundColor: Color.accentTealMuted.opacity(0.1))
                    }
                }

                if let analysis = timeBlock.analysis, !analysis.isEmpty {
                    Text(analysis)
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.5))
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1) // 1px border for high-density look
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTapDetail?()
        }
    }

    private func tagPill(text: String, color: Color, backgroundColor: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
    }
    
    @ViewBuilder
    private func miniEmotionGauge(_ emotions: [(name: String, score: Double)]) -> some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Determine colors based on emotions
                let totalScore = emotions.reduce(0) { $0 + $1.score }
                ForEach(0..<min(emotions.count, 3), id: \.self) { i in
                    let em = emotions[i]
                    let ratio = totalScore > 0 ? (em.score / totalScore) : 0
                    let color = getEmotionColor(em.name)
                    Rectangle()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(ratio))
                }
            }
            .cornerRadius(2)
        }
    }
    
    private func getEmotionColor(_ name: String) -> Color {
        // basic mapping
        let n = name.lowercased()
        if n.contains("joy") || n.contains("happy") || n.contains("喜び") || n.contains("ポジティブ") { return Color.safeColor("SuccessColor") }
        if n.contains("anger") || n.contains("sad") || n.contains("怒り") || n.contains("悲しみ") || n.contains("ネガティブ") { return Color.safeColor("ErrorColor") }
        if n.contains("stress") || n.contains("fear") { return Color.safeColor("WarningColor") }
        return Color.accentTeal
    }
}

// MARK: - Spot Analysis List Section (Shared Component)

struct SpotAnalysisListSection: View {
    let title: String
    let spotResults: [DashboardTimeBlock]
    var showMoreButton: Bool = false
    let onTapSpot: (DashboardTimeBlock) -> Void
    var onTapShowMore: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()

                if showMoreButton {
                    Text("\(spotResults.count)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(white: 0.36))
                }
            }
            .padding(.bottom, 16)

            if !spotResults.isEmpty {
                VStack(spacing: 10) {
                    ForEach(spotResults, id: \.localTime) { block in
                        SpotAnalysisCard(
                            timeBlock: block,
                            onTapDetail: {
                                onTapSpot(block)
                            }
                        )
                    }
                }
                .padding(.bottom, 12)

                if showMoreButton, let onTapShowMore = onTapShowMore {
                    Button(action: onTapShowMore) {
                        HStack {
                            Text("Show all")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.accentTeal)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.accentTeal)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                Text("No analysis data")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.36))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.darkCard)
                    .cornerRadius(12)
            }
        }
    }
}

// スクロールオフセット用のPreferenceKey
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
