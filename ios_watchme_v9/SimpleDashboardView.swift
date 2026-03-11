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
    let deviceId: String?
    let refreshTrigger: Int  // Pull-to-Refresh用
}

// 📊 パフォーマンス最適化: キャッシュデータ構造（Phase 1-A）
struct CachedDashboardData {
    let dashboardSummary: DashboardSummary?
    let behaviorReport: BehaviorReport?
    let emotionReport: EmotionReport?
    let subject: Subject?
    let timeBlocks: [DashboardTimeBlock]  // グラフ用データ
    let subjectComments: [SubjectComment]
    let cachedEmotionPercentages: [(String, Double, String, Color)]
    let timestamp: Date
}

struct SimpleDashboardView: View {
    let localDate: String
    @Binding var selectedLocalDate: String
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var userAccountManager: UserAccountManager

    init(localDate: String, selectedLocalDate: Binding<String>) {
        self.localDate = localDate
        self._selectedLocalDate = selectedLocalDate
    }

    private var currentTimezone: TimeZone {
        if let deviceId = deviceManager.selectedDeviceID {
            return deviceManager.getTimezone(for: deviceId)
        }
        return deviceManager.selectedDeviceTimezone
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
    @State private var subjectComments: [SubjectComment] = []  // コメント機能追加
    @State private var isLoading = false
    @State private var lastLoadedDeviceID: String? = nil  // 最後に読み込んだデバイスID

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
    @State private var lastHandledPushTimestamp: Date?

    // コメント入力用
    @State private var newCommentText = ""
    @State private var isAddingComment = false
    @FocusState private var isCommentFieldFocused: Bool  // キーボード制御用

    // コメント通報用
    @State private var showReportCommentSheet = false
    @State private var reportTargetComment: SubjectComment?

    // モーダル表示管理
    @State private var showVibeSheet = false
    @State private var showBehaviorSheet = false
    @State private var showEmotionSheet = false
    @State private var selectedSpotForDetail: DashboardTimeBlock?
    private let floatingHeaderContentInset: CGFloat = 40

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    // 大きい日付セクション（スクロール可能）
                    LargeDateSection(selectedDate: selectedDateBinding)
                        .environmentObject(deviceManager)
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
                            // 1. Horizon Metrics (Top Scrollable Pills)
                            MetricsHorizonView(
                                vibeScore: dashboardSummary?.averageVibe.map { Double($0) },
                                activityCount: timeBlocks.count
                            )
                            .transition(.opacity)
                            
                            // 2. Main Hero Gauge
                            ModernHeroGaugeView(dashboardSummary: dashboardSummary)
                                .padding(.horizontal, 20)
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                .onTapGesture {
                                    isCommentFieldFocused = false
                                    showVibeSheet = true
                                }
                                
                            // 3. Vitals Range Cards 
                            let stressValue = dashboardSummary?.averageVibe.map { max(10, min(90, 50 - Double($0) * 0.4)) } ?? 42.0
                            VitalsRangeCard(
                                title: "Stress Levels",
                                value: stressValue,
                                maxValue: 100,
                                label: stressValue < 40 ? "LOW" : "ELEVATED",
                                optimalRange: (0.0, 0.4), // 0-40 is optimal
                                color: stressValue < 40 ? .accentEmerald : .accentAmber,
                                icon: "heart.text.square"
                            )
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))

                            // 4. Activity Comparison
                            DailyActivityOverviewCard(
                                analysisCount: timeBlocks.count,
                                targetCount: 24
                            )
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))

                            // Latest analysis
                            if !timeBlocks.isEmpty {
                                latestAnalysisSection
                                    .padding(.horizontal, 20)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            // Highlights
                            if showHighlightSection {
                                highlightSection
                                    .padding(.horizontal, 20)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            // Comments
                            if let subject = subject, (!subjectComments.isEmpty || dashboardSummary != nil) {
                                commentSection(subject: subject)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                            Spacer(minLength: 100)
                        }
                    }
                    .padding(.top, 8)
                    .animation(.easeInOut(duration: 0.3), value: isLoading)
                    .animation(.easeInOut(duration: 0.3), value: dashboardSummary?.date)
                    .animation(.easeInOut(duration: 0.3), value: timeBlocks.count)
                    .animation(.easeInOut(duration: 0.3), value: subjectComments.count)
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
            .scrollDismissesKeyboard(.interactively)  // スクロール時にキーボードを閉じる
            .onTapGesture {
                // ScrollView内の空白部分をタップしたらキーボードを閉じる
                // 既存のボタンやNavigationLinkには影響しない
                isCommentFieldFocused = false
            }
            
            // 固定日付ヘッダー（条件付き表示）
            if showStickyHeader {
                StickyDateHeader(selectedDate: selectedDateBinding)
                    .environmentObject(deviceManager)
                    .environmentObject(dataManager)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task(id: LoadDataTrigger(localDate: localDate, deviceId: deviceManager.selectedDeviceID, refreshTrigger: refreshTrigger)) {
            // 📊 パフォーマンス最適化: データ取得を一元化（Phase 1-A: デバウンス + キャッシュ）
            guard deviceManager.isReady else {
                #if DEBUG
                print("⏸️ [SimpleDashboardView] DeviceManager not ready, skipping data load")
                #endif
                await MainActor.run {
                    clearAllData()
                }
                return
            }

            // キャッシュキーの生成
            guard let deviceId = deviceManager.selectedDeviceID else {
                await MainActor.run {
                    clearAllData()
                }
                return
            }

            let dateString = localDate
            let cacheKey = "\(deviceId)_\(dateString)"

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
                        self.subjectComments = cached.subjectComments
                        self.cachedEmotionPercentages = cached.cachedEmotionPercentages

                        // Phase 2: キャッシュ復元時もフィルタリング実行
                        self.updateFilteredData()
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
                    subjectComments: self.subjectComments,
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
        .onChange(of: deviceManager.selectedDeviceID) { oldDeviceId, newDeviceId in
            // デバイスが切り替わったときにデータとキャッシュをクリア（Phase 1-A）
            if oldDeviceId != nil && newDeviceId != nil && oldDeviceId != newDeviceId {
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
        .sheet(isPresented: $showVibeSheet) {
            NavigationView {
                AnalysisListView(timeBlocks: timeBlocks, selectedDate: displayDate)
                    .environmentObject(deviceManager)
                    .environmentObject(dataManager)
                    .environmentObject(userAccountManager)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle("分析結果の一覧")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("閉じる") {
                                showVibeSheet = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showBehaviorSheet) {
            NavigationView {
                BehaviorGraphView(selectedDate: displayDate)
                    .environmentObject(deviceManager)
                    .environmentObject(dataManager)
                    .navigationBarTitleDisplayMode(.large)
                    .navigationTitle("行動グラフ")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("閉じる") {
                                showBehaviorSheet = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showEmotionSheet) {
            NavigationView {
                EmotionGraphView(selectedDate: displayDate)
                    .environmentObject(deviceManager)
                    .environmentObject(dataManager)
                    .navigationBarTitleDisplayMode(.large)
                    .navigationTitle("感情グラフ")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("閉じる") {
                                showEmotionSheet = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showReportCommentSheet) {
            if let comment = reportTargetComment {
                FeedbackFormView(context: .reportComment(
                    commentId: comment.id,
                    commentText: comment.commentText
                ))
                .environmentObject(userAccountManager)
            }
        }
        .sheet(item: $selectedSpotForDetail) { spot in
            if let deviceId = deviceManager.selectedDeviceID {
                SpotDetailView(deviceId: deviceId, spotData: spot)
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

        // Filter: Only process if this view's device matches
        guard update.deviceId == deviceManager.selectedDeviceID else {
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
        print("🔄 [PUSH] Dashboard update received: \(update.deviceId) - \(update.date)")

        let cacheKey = "\(update.deviceId)_\(update.date)"
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

        return dashboardSummary != nil || !timeBlocks.isEmpty || !subjectComments.isEmpty
    }

    private func refreshCurrentDayIfNeeded(reason: String) {
        guard let deviceId = deviceManager.selectedDeviceID else { return }
        let timezone = deviceManager.getTimezone(for: deviceId)

        guard isToday(localDate, timezone: timezone) else { return }

        refreshTrigger += 1
        print("🔄 [Dashboard Refresh] Triggered for current day (\(reason))")
    }
    
    // MARK: - View Components
    
    private var vibeGraphCard: some View {
        Group {
            if let summary = dashboardSummary {
                ModernVibeCard(
                    dashboardSummary: summary,
                    timeBlocks: timeBlocks,  // spot_resultsから取得したグラフデータ
                    onNavigateToDetail: { },
                    showTitle: false  // タイトルを非表示
                )
                .onTapGesture {
                    isCommentFieldFocused = false  // キーボードを閉じる
                    showVibeSheet = true
                }
            } else {
                // エンプティーステート：ナビゲーションボタンを非表示
                if deviceManager.selectedDeviceID == nil {
                    DeviceNotSelectedView(graphType: .vibe, isCompact: true)
                } else {
                    GraphEmptyStateView(graphType: .vibe, isCompact: true)
                }
            }
        }
    }

    // Latest 1 analysis (newest)
    private var latestAnalysisSection: some View {
        let latestBlock = Array(timeBlocks.suffix(1))

        return SpotAnalysisListSection(
            title: "最新情報",
            spotResults: latestBlock,
            showMoreButton: false,
            onTapSpot: { block in
                selectedSpotForDetail = block
            }
        )
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
    private var highlightSection: some View {
        // Use @State variable (already filtered and sorted)
        SpotAnalysisListSection(
            title: "ハイライト",
            spotResults: highlightBlocks,
            showMoreButton: true,
            onTapSpot: { block in
                selectedSpotForDetail = block
            },
            onTapShowMore: {
                isCommentFieldFocused = false
                showVibeSheet = true
            }
        )
    }
    
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
                if deviceManager.selectedDeviceID == nil {
                    DeviceNotSelectedView(graphType: .behavior, isCompact: true)
                } else {
                    GraphEmptyStateView(graphType: .behavior, isCompact: true)
                }
            }
        }
        .onTapGesture {
            isCommentFieldFocused = false  // キーボードを閉じる
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
                if deviceManager.selectedDeviceID == nil {
                    DeviceNotSelectedView(graphType: .emotion, isCompact: true)
                } else {
                    GraphEmptyStateView(graphType: .emotion, isCompact: true)
                }
            }
        }
        .onTapGesture {
            isCommentFieldFocused = false  // キーボードを閉じる
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
        subjectComments = []  // コメントもクリア
    }


    private func loadAllData() async {
        // 📊 パフォーマンス最適化: 詳細ログを削減
        guard let deviceId = deviceManager.selectedDeviceID else {
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
        await MainActor.run {
            isLoading = true
        }

        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        // 📊 Performance optimization: Parallel network requests
        let timezone = deviceManager.getTimezone(for: deviceId)

        async let resultTask = dataManager.fetchAllReports(
            deviceId: deviceId,
            localDate: localDate,
            timezone: timezone
        )
        async let timeBlocksTask = dataManager.fetchDashboardTimeBlocks(
            deviceId: deviceId,
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
            self.subjectComments = result.subjectComments ?? []
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
    
    // MARK: - コメントセクション
    
    @ViewBuilder
    private func commentSection(subject: Subject) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Comments")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(subjectComments.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.36))
            }

            // Input field
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.accentTeal)

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .lineLimit(3...6)
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .focused($isCommentFieldFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                isCommentFieldFocused = false
                            }

                        if !newCommentText.isEmpty {
                            HStack {
                                Spacer()

                                Button("Cancel") {
                                    newCommentText = ""
                                }
                                .font(.system(size: 12))
                                .foregroundStyle(Color(white: 0.56))

                                Button("Post") {
                                    Task {
                                        await addComment(subjectId: subject.subjectId)
                                    }
                                    isCommentFieldFocused = false
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.accentTeal)
                                .cornerRadius(10)
                                .disabled(isAddingComment)
                            }
                        }
                    }
                }
                .padding(14)
                .background(Color.darkCard)
                .cornerRadius(16)
            }

            VStack(spacing: 8) {
                ForEach(subjectComments) { comment in
                    commentRow(comment)
                }
            }

            if subjectComments.isEmpty {
                Text("No comments yet")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.36))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
    }
    
    @ViewBuilder
    private func commentRow(_ comment: SubjectComment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(userId: comment.userId, size: 28, avatarUrl: comment.userAvatarUrl)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(comment.formattedDate)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.36))

                    Spacer()
                }

                Text(comment.commentText)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.78))
                    .fixedSize(horizontal: false, vertical: true)

                if let currentUserId = userAccountManager.effectiveUserId {
                    HStack {
                        Spacer()

                        if comment.userId == currentUserId {
                            Button {
                                Task {
                                    await deleteComment(commentId: comment.id)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(white: 0.25))
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Button {
                                reportTargetComment = comment
                                showReportCommentSheet = true
                            } label: {
                                Image(systemName: "exclamationmark.bubble")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(white: 0.25))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.darkCard)
        .cornerRadius(12)
    }
    
    // コメント追加
    private func addComment(subjectId: String) async {
        guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let userId = userAccountManager.effectiveUserId else {
            return
        }
        
        isAddingComment = true
        defer { isAddingComment = false }
        
        do {
            try await dataManager.addComment(
                subjectId: subjectId,
                userId: userId,
                commentText: newCommentText.trimmingCharacters(in: .whitespacesAndNewlines),
                localDate: localDate
            )

            // コメント追加成功後
            newCommentText = ""

            // コメントリストを再取得（同じ日付のコメントのみ）
            let comments = await dataManager.fetchComments(subjectId: subjectId, localDate: localDate)
            await MainActor.run {
                self.subjectComments = comments
            }
        } catch {
            print("❌ Failed to add comment: \(error)")
        }
    }
    
    // コメント削除
    private func deleteComment(commentId: String) async {
        do {
            try await dataManager.deleteComment(commentId: commentId)

            // 削除成功後、コメントリストから削除
            await MainActor.run {
                self.subjectComments.removeAll { $0.id == commentId }
            }
        } catch {
            print("❌ Failed to delete comment: \(error)")
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
                        tagPill(text: emotion, color: .accentAmber, backgroundColor: Color.accentAmber.opacity(0.1))
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

// MARK: - Analysis List View

struct AnalysisListView: View {
    let timeBlocks: [DashboardTimeBlock]
    let selectedDate: Date
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager

    @State private var selectedSpotForDetail: DashboardTimeBlock?
    @State private var filterType: AnalysisFilterType = .all
    @State private var sortOrder: AnalysisSortOrder = .newest

    // Phase 2: フィルタ・ソート結果を@State変数で明示的に管理
    @State private var filteredAndSortedBlocks: [DashboardTimeBlock] = []

    // Filter types
    enum AnalysisFilterType: String, CaseIterable {
        case all = "すべての分析"
        case withConversation = "会話あり"
    }

    // Sort order
    enum AnalysisSortOrder: String, CaseIterable {
        case newest = "最新の分析"
        case oldest = "最も古い分析"
    }

    // Phase 2: フィルタリングとソートロジック（明示的な更新）
    private func updateFilteredAndSortedData() {
        var blocks = timeBlocks

        // Apply filter
        if filterType == .withConversation {
            blocks = blocks.filter { block in
                guard let rating = block.rating else {
                    // rating が nil の場合は除外（古いデータ）
                    return false
                }
                return rating > 0
            }
        }

        // Apply sort
        if sortOrder == .newest {
            blocks = blocks.reversed() // newest first
        }
        // For .oldest, keep original order (oldest first)

        filteredAndSortedBlocks = blocks
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                filterControls
                listContent
                Spacer(minLength: 50)
            }
        }
        .background(Color.darkBase)
        .sheet(item: $selectedSpotForDetail) { spot in
            if let deviceId = deviceManager.selectedDeviceID {
                SpotDetailView(deviceId: deviceId, spotData: spot)
                    .environmentObject(dataManager)
            }
        }
        .onAppear {
            updateFilteredAndSortedData()
        }
        .onChange(of: timeBlocks) { oldValue, newValue in
            updateFilteredAndSortedData()
        }
        .onChange(of: filterType) { oldValue, newValue in
            updateFilteredAndSortedData()
        }
        .onChange(of: sortOrder) { oldValue, newValue in
            updateFilteredAndSortedData()
        }
    }

    @ViewBuilder
    private var filterControls: some View {
        if !timeBlocks.isEmpty {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Menu {
                        ForEach(AnalysisFilterType.allCases, id: \.self) { type in
                            Button(action: {
                                filterType = type
                            }) {
                                HStack {
                                    Text(type.rawValue)
                                    if filterType == type {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 13))
                            Text(filterType.rawValue)
                                .font(.system(size: 13))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Color.accentTeal)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.darkCard)
                        .cornerRadius(10)
                    }

                    Menu {
                        ForEach(AnalysisSortOrder.allCases, id: \.self) { order in
                            Button(action: {
                                sortOrder = order
                            }) {
                                HStack {
                                    Text(order.rawValue)
                                    if sortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .font(.system(size: 13))
                            Text(sortOrder.rawValue)
                                .font(.system(size: 13))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Color.accentTeal)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.darkCard)
                        .cornerRadius(10)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)

                HStack {
                    Text("\(filteredAndSortedBlocks.count) results")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.45))
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 20)
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if timeBlocks.isEmpty {
            Group {
                if deviceManager.selectedDeviceID == nil {
                    DeviceNotSelectedView(graphType: .vibe)
                } else {
                    GraphEmptyStateView(graphType: .vibe)
                }
            }
            .padding(.horizontal)
        } else if filteredAndSortedBlocks.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(white: 0.25))
                Text("No matching results")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.36))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else {
            VStack(spacing: 20) {
                ForEach(filteredAndSortedBlocks, id: \.localTime) { block in
                    SpotAnalysisCard(
                        timeBlock: block,
                        onTapDetail: {
                            selectedSpotForDetail = block
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
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
