//
//  SimpleDashboardView.swift
//  ios_watchme_v9
//
//  シンプルなダッシュボード実装（日付バグ修正版）
//

import SwiftUI

// データ取得のトリガーを管理する構造体
struct LoadDataTrigger: Equatable {
    let date: Date
    let deviceId: String?
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
    let date: Date  // このビューが表示する固有の日付
    @Binding var selectedDate: Date  // TabViewの選択状態（ナビゲーション用）
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var userAccountManager: UserAccountManager

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

    // 📊 パフォーマンス最適化: 計算結果のキャッシュ
    @State private var cachedEmotionPercentages: [(String, Double, String, Color)] = []

    // 📊 パフォーマンス最適化: データキャッシュ（Phase 1-A）
    @State private var dataCache: [String: CachedDashboardData] = [:]
    @State private var cacheKeys: [String] = []  // LRU管理用
    private let maxCacheSize = 30  // 最近30日分をキャッシュ（スワイプ体験向上＆メモリ効率改善）

    // 📊 パフォーマンス最適化: デバイス選択直後フラグ（Phase 5-A）
    @State private var isInitialLoad = false

    // Pull-to-Refresh trigger (simple approach)
    @State private var refreshTrigger = 0

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

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    // 大きい日付セクション（スクロール可能）
                    LargeDateSection(selectedDate: $selectedDate)
                        .environmentObject(deviceManager)
                        .environmentObject(dataManager)
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: geometry.frame(in: .named("scroll")).minY
                                    )
                            }
                        )
                    
                    // ダッシュボードコンテンツ
                    // 📊 Performance optimization: LazyVStack for on-demand rendering
                    LazyVStack(spacing: 20) {
                        if isLoading {
                            // 📊 Skeleton loading for better perceived performance
                            SkeletonView()
                        } else {
                            // 📊 Progressive rendering: Show content as it becomes available

                            // Priority 1: Vibe card (always show - empty state is handled inside)
                            vibeGraphCard
                                .padding(.horizontal, 20)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))

                            // Priority 2: Recent analysis (show when timeBlocks is available)
                            if !timeBlocks.isEmpty {
                                spotAnalysisSection
                                    .padding(.horizontal, 20)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            // 行動グラフカード（一時的に非表示）
                            // behaviorGraphCard
                            //     .padding(.horizontal, 20)

                            // 感情グラフカード（一時的に非表示）
                            // emotionGraphCard
                            //     .padding(.horizontal, 20)

                            // Priority 3: Comments (show when subject and comments are available)
                            if let subject = subject, (!subjectComments.isEmpty || dashboardSummary != nil) {
                                commentSection(subject: subject)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 20)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                            Spacer(minLength: 100)
                        }
                    }
                    .padding(.top, 8)  // 日付セクションとの余白を8pxに変更
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
                Color.white
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
                StickyDateHeader(selectedDate: $selectedDate)
                    .environmentObject(deviceManager)
                    .environmentObject(dataManager)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task(id: LoadDataTrigger(date: date, deviceId: deviceManager.selectedDeviceID)) {
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

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = deviceManager.getTimezone(for: deviceId)
            let dateString = formatter.string(from: date)
            let cacheKey = "\(deviceId)_\(dateString)"

            // ✅ キャッシュヒット → 即座に表示（スワイプ超高速）
            if let cached = dataCache[cacheKey] {
                // キャッシュが新鮮か確認（30分以内に延長してAPI呼び出しを削減）
                if Date().timeIntervalSince(cached.timestamp) < 1800 {
                    await MainActor.run {
                        self.dashboardSummary = cached.dashboardSummary
                        self.behaviorReport = cached.behaviorReport
                        self.emotionReport = cached.emotionReport
                        self.subject = cached.subject
                        self.timeBlocks = cached.timeBlocks  // グラフ用データ
                        self.subjectComments = cached.subjectComments
                        self.cachedEmotionPercentages = cached.cachedEmotionPercentages
                    }
                    print("✅ [Cache HIT] Data loaded from cache for \(dateString)")
                    return
                } else {
                    print("⚠️ [Cache EXPIRED] Cache data is older than 30 minutes for \(dateString)")
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
        .onChange(of: refreshTrigger) { oldValue, newValue in
            // Pull-to-Refresh: Clear cache when trigger changes
            guard newValue > 0 else { return }

            if let deviceId = deviceManager.selectedDeviceID {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.timeZone = deviceManager.getTimezone(for: deviceId)
                let dateString = formatter.string(from: date)
                let cacheKey = "\(deviceId)_\(dateString)"

                dataCache.removeValue(forKey: cacheKey)
                cacheKeys.removeAll { $0 == cacheKey }

                print("🔄 [Pull-to-Refresh] Cache cleared for \(dateString), will reload via .task()")
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
        .onChange(of: pushManager.latestUpdate) { oldValue, newValue in
            // Handle push notification updates from centralized manager
            guard let update = newValue else { return }

            // Only process dashboard refresh notifications
            guard update.type == .refreshDashboard else { return }

            // Filter: Only process if this view's device matches
            guard update.deviceId == deviceManager.selectedDeviceID else {
                print("⚠️ [PUSH] Update ignored (different device)")
                return
            }

            // Filter: Only process today's data
            let calendar = deviceManager.deviceCalendar
            let today = calendar.startOfDay(for: Date())

            guard calendar.isDate(date, inSameDayAs: today) else {
                print("⚠️ [PUSH] Update ignored (not today's view)")
                return
            }

            print("🔄 [PUSH] Dashboard update received: \(update.deviceId) - \(update.date)")

            // Clear today's cache
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = deviceManager.getTimezone(for: update.deviceId)
            let todayString = formatter.string(from: today)
            let todayCacheKey = "\(update.deviceId)_\(todayString)"

            dataCache.removeValue(forKey: todayCacheKey)
            cacheKeys.removeAll { $0 == todayCacheKey }

            print("🗑️ [PUSH] Cache cleared: \(todayCacheKey)")

            // Reload data
            Task {
                await loadAllData()

                // Show toast after data is loaded
                await MainActor.run {
                    ToastManager.shared.showInfo(title: update.message)
                    print("🍞 [PUSH] Toast displayed: \(update.message)")
                }
            }
        }
        .sheet(isPresented: $showVibeSheet) {
            NavigationView {
                AnalysisListView(timeBlocks: timeBlocks, selectedDate: date)
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
                BehaviorGraphView(selectedDate: date)
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
                EmotionGraphView(selectedDate: date)
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

    private var spotAnalysisSection: some View {
        let latestBlocks = Array(timeBlocks.suffix(3).reversed())

        return SpotAnalysisListSection(
            title: "最新情報",
            spotResults: latestBlocks,
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
            date: date,
            timezone: timezone
        )
        async let timeBlocksTask = dataManager.fetchDashboardTimeBlocks(
            deviceId: deviceId,
            date: date,
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
        }
    }
    
    // MARK: - コメントセクション
    
    @ViewBuilder
    private func commentSection(subject: Subject) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // セクションヘッダー
            HStack {
                Text("コメント")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.safeColor("BehaviorTextPrimary"))
                
                Spacer()
                
                Text("\(subjectComments.count)件")
                    .font(.caption)
                    .foregroundStyle(Color.safeColor("BehaviorTextSecondary"))
            }
            
            // コメント入力欄
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.safeColor("AppAccentColor"))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("コメントを追加...", text: $newCommentText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .lineLimit(3...6)
                            .padding(12)
                            .background(Color.safeColor("CardBackground"))
                            .cornerRadius(12)
                            .focused($isCommentFieldFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                // リターンキー（完了）でキーボードを閉じる
                                isCommentFieldFocused = false
                            }
                        
                        if !newCommentText.isEmpty {
                            HStack {
                                Spacer()
                                
                                Button("キャンセル") {
                                    newCommentText = ""
                                }
                                .font(.caption)
                                .foregroundStyle(Color.safeColor("BehaviorTextSecondary"))
                                
                                Button("投稿") {
                                    Task {
                                        await addComment(subjectId: subject.subjectId)
                                    }
                                    isCommentFieldFocused = false  // 投稿後キーボードを閉じる
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.safeColor("AppAccentColor"))
                                .cornerRadius(12)
                                .disabled(isAddingComment)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.safeColor("BehaviorBackgroundPrimary").opacity(0.3))
                .cornerRadius(16)
            }
            
            // コメントリスト
            VStack(spacing: 12) {
                ForEach(subjectComments) { comment in
                    commentRow(comment)
                }
            }
            
            if subjectComments.isEmpty {
                Text("まだコメントがありません")
                    .font(.caption)
                    .foregroundStyle(Color.safeColor("BehaviorTextTertiary"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
    }
    
    @ViewBuilder
    private func commentRow(_ comment: SubjectComment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // アバター表示（SSOT: SubjectComment.userAvatarUrl を渡す）
            AvatarView(userId: comment.userId, size: 32, avatarUrl: comment.userAvatarUrl)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.displayName)
                        .font(.caption.bold())
                        .foregroundStyle(Color.safeColor("BehaviorTextPrimary"))
                    
                    Text("・")
                        .font(.caption)
                        .foregroundStyle(Color.safeColor("BehaviorTextTertiary"))
                    
                    Text(comment.formattedDate)
                        .font(.caption)
                        .foregroundStyle(Color.safeColor("BehaviorTextTertiary"))
                    
                    Spacer()
                }
                
                Text(comment.commentText)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.safeColor("BehaviorTextPrimary"))
                    .fixedSize(horizontal: false, vertical: true)

                // アクションボタン（削除・通報）
                if let currentUserId = userAccountManager.currentUser?.profile?.userId {
                    HStack {
                        Spacer()

                        // 自分のコメントの場合は削除ボタン
                        if comment.userId == currentUserId {
                            Button {
                                Task {
                                    await deleteComment(commentId: comment.id)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.safeColor("BehaviorTextTertiary").opacity(0.5))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        // 他人のコメントの場合は通報ボタン
                        else {
                            Button {
                                reportTargetComment = comment
                                showReportCommentSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.bubble")
                                        .font(.system(size: 10))
                                    Text("通報")
                                        .font(.system(size: 10))
                                }
                                .foregroundStyle(Color.safeColor("BehaviorTextTertiary").opacity(0.5))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.safeColor("CardBackground"))
        .cornerRadius(12)
    }
    
    // コメント追加
    private func addComment(subjectId: String) async {
        guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let userId = userAccountManager.currentUser?.profile?.userId else {
            return
        }
        
        isAddingComment = true
        defer { isAddingComment = false }
        
        do {
            try await dataManager.addComment(
                subjectId: subjectId,
                userId: userId,
                commentText: newCommentText.trimmingCharacters(in: .whitespacesAndNewlines),
                date: date  // このビューの日付を使用
            )

            // コメント追加成功後
            newCommentText = ""

            // コメントリストを再取得（同じ日付のコメントのみ）
            let comments = await dataManager.fetchComments(subjectId: subjectId, date: date)
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
        VStack(alignment: .leading, spacing: 8) {
            // Header row (time and score) - outside the card
            HStack(spacing: 12) {
                Text(timeBlock.displayTime)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.safeColor("BehaviorTextPrimary"))

                Spacer()

                if let score = timeBlock.vibeScore {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(timeBlock.scoreColor)
                            .frame(width: 6, height: 6)
                        Text(String(format: "%@%.0fpt", score >= 0 ? "+" : "", score))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(timeBlock.scoreColor)
                    }
                } else {
                    Text("-")
                        .font(.system(size: 13))
                        .foregroundColor(Color.safeColor("BehaviorTextTertiary"))
                }
            }

            // Card content (gray background)
            VStack(alignment: .leading, spacing: 12) {
                // Summary (transcription) - moved to top, no title
                if let firstLine = summaryFirstLine {
                    Text(firstLine)
                        .font(.system(size: 13))
                        .foregroundColor(Color.safeColor("BehaviorTextPrimary"))
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Behavior (from spot_results.behavior)
                if let behavior = timeBlock.behavior, !behavior.isEmpty {
                    HStack(spacing: 4) {
                        Text("[行動]")
                            .font(.system(size: 13))
                            .foregroundColor(Color.safeColor("BehaviorTextSecondary"))

                        Text(behavior)
                            .font(.system(size: 13))
                            .foregroundColor(Color.safeColor("PrimaryActionColor"))
                            .lineLimit(1)
                    }
                }

                // Emotion (from spot_results.emotion)
                if let emotion = timeBlock.emotion, !emotion.isEmpty {
                    HStack(spacing: 4) {
                        Text("[感情]")
                            .font(.system(size: 13))
                            .foregroundColor(Color.safeColor("BehaviorTextSecondary"))

                        Text(emotion)
                            .font(.system(size: 13))
                            .foregroundColor(Color.safeColor("PrimaryActionColor"))
                            .lineLimit(1)
                    }
                }

                // Detail button
                if let onTapDetail = onTapDetail {
                    Button(action: onTapDetail) {
                        HStack {
                            Text("詳細を見る")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.safeColor("AppAccentColor"))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.safeColor("AppAccentColor"))
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(16)
            .background(Color.safeColor("CardBackground"))
            .cornerRadius(12)
        }
    }
}

// MARK: - Analysis List View

struct AnalysisListView: View {
    let timeBlocks: [DashboardTimeBlock]
    let selectedDate: Date
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager

    @State private var selectedSpotForDetail: DashboardTimeBlock?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if timeBlocks.isEmpty {
                    // Empty state
                    Group {
                        if deviceManager.selectedDeviceID == nil {
                            DeviceNotSelectedView(graphType: .vibe)
                        } else {
                            GraphEmptyStateView(graphType: .vibe)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    // 時系列順（古い→新しい）で全件表示
                    VStack(spacing: 20) {
                        ForEach(timeBlocks, id: \.localTime) { block in
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

                Spacer(minLength: 50)
            }
            .padding(.top, 20)
        }
        .background(Color.white)
        .sheet(item: $selectedSpotForDetail) { spot in
            if let deviceId = deviceManager.selectedDeviceID {
                SpotDetailView(deviceId: deviceId, spotData: spot)
                    .environmentObject(dataManager)
            }
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
            // Section title
            HStack {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.safeColor("BehaviorTextPrimary"))
                Spacer()
            }
            .padding(.bottom, 30)

            if !spotResults.isEmpty {
                VStack(spacing: 20) {
                    ForEach(spotResults, id: \.localTime) { block in
                        SpotAnalysisCard(
                            timeBlock: block,
                            onTapDetail: {
                                onTapSpot(block)
                            }
                        )
                    }
                }
                .padding(.bottom, 16)

                // "Show more" button (optional)
                if showMoreButton, let onTapShowMore = onTapShowMore {
                    Button(action: onTapShowMore) {
                        HStack {
                            Text("もっと見る")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.safeColor("AppAccentColor"))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.safeColor("AppAccentColor"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.safeColor("CardBackground"))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                // Empty state
                Text("分析データがありません")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.safeColor("CardBackground"))
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