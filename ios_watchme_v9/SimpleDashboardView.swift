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
    let subjectComments: [SubjectComment]
    let cachedEmotionPercentages: [(String, Double, String, Color)]
    let timestamp: Date
}

struct SimpleDashboardView: View {
    @Binding var selectedDate: Date
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var userAccountManager: UserAccountManager
    
    // スティッキーヘッダーの表示状態を内部で管理
    @State private var showStickyHeader = false
    
    // 各データを個別に管理（シンプルに）
    @State private var behaviorReport: BehaviorReport?
    @State private var emotionReport: EmotionReport?
    @State private var subject: Subject?
    @State private var dashboardSummary: DashboardSummary?  // メインデータソース
    @State private var subjectComments: [SubjectComment] = []  // コメント機能追加
    @State private var isLoading = false
    @State private var lastLoadedDeviceID: String? = nil  // 最後に読み込んだデバイスID

    // 📊 パフォーマンス最適化: 計算結果のキャッシュ
    @State private var cachedEmotionPercentages: [(String, Double, String, Color)] = []

    // 📊 パフォーマンス最適化: データキャッシュ（Phase 1-A）
    @State private var dataCache: [String: CachedDashboardData] = [:]
    @State private var cacheKeys: [String] = []  // LRU管理用
    private let maxCacheSize = 15  // 最近15日分をキャッシュ（スワイプ体験向上）

    // 📊 パフォーマンス最適化: デバイス選択直後フラグ（Phase 5-A）
    @State private var isInitialLoad = false

    // コメント入力用
    @State private var newCommentText = ""
    @State private var isAddingComment = false
    @FocusState private var isCommentFieldFocused: Bool  // キーボード制御用

    // モーダル表示管理
    @State private var showVibeSheet = false
    @State private var showBehaviorSheet = false
    @State private var showEmotionSheet = false
    
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
                    VStack(spacing: 20) {
                        if isLoading {
                            ProgressView("読み込み中...")
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            // 気分カード
                            vibeGraphCard
                                .padding(.horizontal, 20)
                            
                            // 行動グラフカード
                            behaviorGraphCard
                                .padding(.horizontal, 20)
                            
                            // 感情グラフカード
                            emotionGraphCard
                                .padding(.horizontal, 20)
                            
                            // コメントセクション
                            if let subject = subject {
                                commentSection(subject: subject)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 20)
                            }
                            
                            // 観測対象カード（最下部に移動）
                            Group {
                                if let subject = subject {
                                    observationTargetCard(subject)
                                } else {
                                    noObservationTargetCard()
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            
                            Spacer(minLength: 100)
                        }
                    }
                    .padding(.top, 8)  // 日付セクションとの余白を8pxに変更
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
        .task(id: LoadDataTrigger(date: selectedDate, deviceId: deviceManager.selectedDeviceID)) {
            // 📊 パフォーマンス最適化: データ取得を一元化（Phase 1-A: デバウンス + キャッシュ）
            guard case .available = deviceManager.state else {
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
            let dateString = formatter.string(from: selectedDate)
            let cacheKey = "\(deviceId)_\(dateString)"

            // ✅ キャッシュヒット → 即座に表示（スワイプ超高速）
            if let cached = dataCache[cacheKey] {
                // キャッシュが新鮮か確認（5分以内）
                if Date().timeIntervalSince(cached.timestamp) < 300 {
                    await MainActor.run {
                        self.dashboardSummary = cached.dashboardSummary
                        self.behaviorReport = cached.behaviorReport
                        self.emotionReport = cached.emotionReport
                        self.subject = cached.subject
                        self.subjectComments = cached.subjectComments
                        self.cachedEmotionPercentages = cached.cachedEmotionPercentages
                    }
                    print("✅ [Cache HIT] Data loaded from cache for \(dateString)")
                    return
                } else {
                    print("⚠️ [Cache EXPIRED] Cache data is older than 5 minutes for \(dateString)")
                }
            }

            // 📊 Phase 5-B: 即座にローディング表示を開始
            await MainActor.run {
                isLoading = true
            }

            // ✅ キャッシュミス → デバウンス処理（Phase 5-A: デバイス選択直後はスキップ）
            if !isInitialLoad {
                // スワイプ操作時のみデバウンス適用（無駄なリクエスト防止）
                print("⏳ [Debounce] Waiting 300ms before loading data for \(dateString)...")
                try? await Task.sleep(for: .milliseconds(300))

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
            print("📡 [API Request] Loading data for \(dateString)...")
            await loadAllData()

            // ✅ キャッシュに保存
            await MainActor.run {
                let cached = CachedDashboardData(
                    dashboardSummary: self.dashboardSummary,
                    behaviorReport: self.behaviorReport,
                    emotionReport: self.emotionReport,
                    subject: self.subject,
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
                    print("🗑️ [Cache LRU] Removed old cache for key: \(oldKey)")
                }

                print("💾 [Cache SAVED] Data cached for \(dateString) (total: \(cacheKeys.count)/\(maxCacheSize))")
            }
        }
        .onChange(of: deviceManager.selectedDeviceID) { oldDeviceId, newDeviceId in
            // デバイスが切り替わったときにデータとキャッシュをクリア（Phase 1-A）
            if oldDeviceId != nil && newDeviceId != nil && oldDeviceId != newDeviceId {
                clearAllData()
                // キャッシュもクリア
                dataCache.removeAll()
                cacheKeys.removeAll()
                print("🗑️ [Cache CLEARED] All cache cleared due to device change")

                // 📊 Phase 5-A: 初回読み込みフラグを設定（デバウンススキップ）
                isInitialLoad = true
                print("⚡️ [Initial Load Flag] Set to true for immediate data loading")
            }
        }
        .sheet(isPresented: $showVibeSheet) {
            NavigationView {
                HomeView(subject: subject, dashboardSummary: dashboardSummary, selectedDate: selectedDate)
                    .environmentObject(deviceManager)
                    .environmentObject(dataManager)
                    .environmentObject(userAccountManager)
                    .navigationBarTitleDisplayMode(.large)
                    .navigationTitle("気分詳細")
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
                BehaviorGraphView(behaviorReport: behaviorReport, selectedDate: selectedDate)
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
                EmotionGraphView(emotionReport: emotionReport, selectedDate: selectedDate)
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
    }
    
    // MARK: - View Components
    
    private var vibeGraphCard: some View {
        Group {
            if let summary = dashboardSummary {
                ModernVibeCard(
                    dashboardSummary: summary,
                    onNavigateToDetail: { },
                    showTitle: false  // タイトルを非表示
                )
                .onTapGesture {
                    isCommentFieldFocused = false  // キーボードを閉じる
                    showVibeSheet = true
                }
            } else {
                UnifiedCard(
                    title: "気分",
                    navigationLabel: "気分詳細",
                    onNavigate: { }
                ) {
                    GraphEmptyStateView(
                        graphType: .vibe,
                        isDeviceLinked: !deviceManager.devices.isEmpty,
                        isCompact: true
                    )
                }
                .onTapGesture {
                    isCommentFieldFocused = false  // キーボードを閉じる
                    showVibeSheet = true
                }
            }
        }
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
                GraphEmptyStateView(
                    graphType: .behavior,
                    isDeviceLinked: !deviceManager.devices.isEmpty,
                    isCompact: true
                )
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
                GraphEmptyStateView(
                    graphType: .emotion,
                    isDeviceLinked: !deviceManager.devices.isEmpty,
                    isCompact: true
                )
            }
        }
        .onTapGesture {
            isCommentFieldFocused = false  // キーボードを閉じる
            showEmotionSheet = true
        }
    }
    
    private func observationTargetCard(_ subject: Subject) -> some View {
        ObservationTargetCard(
            title: "観測対象"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    // アバター
                    if let avatarURL = subject.avatarUrl, !avatarURL.isEmpty {
                        AsyncImage(url: URL(string: avatarURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                )
                        } placeholder: {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.white.opacity(0.6))
                                )
                        }
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white.opacity(0.6))
                            )
                    }
                    
                    // 情報
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subject.name ?? "名前未設定")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            if let age = subject.age {
                                Label("\(age)歳", systemImage: "calendar")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            if let gender = subject.gender {
                                Label(gender, systemImage: "person")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                // プロフィール（notes）を表示
                if let notes = subject.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private func noObservationTargetCard() -> some View {
        ObservationTargetCard(
            title: "観測対象"
        ) {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("観測対象が未設定です")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
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
        var totals: [String: Int] = [
            "joy": 0, "trust": 0, "fear": 0, "surprise": 0,
            "sadness": 0, "disgust": 0, "anger": 0, "anticipation": 0
        ]

        for point in activeTimePoints {
            totals["joy"]! += point.joy
            totals["trust"]! += point.trust
            totals["fear"]! += point.fear
            totals["surprise"]! += point.surprise
            totals["sadness"]! += point.sadness
            totals["disgust"]! += point.disgust
            totals["anger"]! += point.anger
            totals["anticipation"]! += point.anticipation
        }

        // 全感情の総計
        let grandTotal = totals.values.reduce(0, +)

        guard grandTotal > 0 else { return [] }

        // パーセンテージを計算
        return [
            ("joy", Double(totals["joy"]!) / Double(grandTotal) * 100, "😊", Color.safeColor("EmotionJoy")),
            ("trust", Double(totals["trust"]!) / Double(grandTotal) * 100, "🤝", Color.safeColor("EmotionTrust")),
            ("fear", Double(totals["fear"]!) / Double(grandTotal) * 100, "😨", Color.safeColor("EmotionFear")),
            ("surprise", Double(totals["surprise"]!) / Double(grandTotal) * 100, "😲", Color.safeColor("EmotionSurprise")),
            ("sadness", Double(totals["sadness"]!) / Double(grandTotal) * 100, "😢", Color.safeColor("EmotionSadness")),
            ("disgust", Double(totals["disgust"]!) / Double(grandTotal) * 100, "🤢", Color.safeColor("EmotionDisgust")),
            ("anger", Double(totals["anger"]!) / Double(grandTotal) * 100, "😠", Color.safeColor("EmotionAnger")),
            ("anticipation", Double(totals["anticipation"]!) / Double(grandTotal) * 100, "🎯", Color.safeColor("EmotionAnticipation"))
        ]
    }
    
    private func emotionReportContent(_ report: EmotionReport) -> some View {
        VStack(spacing: 16) {
            if !report.emotionGraph.isEmpty {
                let activeTimePoints = report.emotionGraph.filter { $0.totalEmotions > 0 }

                if !activeTimePoints.isEmpty {
                    // 📊 パフォーマンス最適化: キャッシュされた結果を使用
                    let topEmotions = cachedEmotionPercentages.prefix(3)
                
                // トップ感情を絵文字で表示
                HStack(spacing: 16) {
                    ForEach(Array(topEmotions.enumerated()), id: \.element.0) { index, emotion in
                        VStack(spacing: 4) {
                            Text(emotion.2)
                                .font(.system(size: 54))  // 36 * 1.5 = 54

                            Text("\(Int(emotion.1.rounded()))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 30)  // 上下に30px余白
                
                // 感情バー
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(topEmotions.enumerated()), id: \.element.0) { index, emotion in
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
        
        // データ取得
        let timezone = deviceManager.getTimezone(for: deviceId)
        let result = await dataManager.fetchAllReports(
            deviceId: deviceId,
            date: selectedDate,
            timezone: timezone
        )
        
        // 取得したデータを設定
        await MainActor.run {
            self.behaviorReport = result.behaviorReport
            self.emotionReport = result.emotionReport
            self.subject = result.subject
            self.dashboardSummary = result.dashboardSummary
            self.subjectComments = result.subjectComments ?? []

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
            // アバター表示（AvatarViewはユーザーIDから自動的にURLを構築）
            AvatarView(userId: comment.userId, size: 32)
            
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
                
                // 自分のコメントの場合のみ削除ボタン表示（右下に配置）
                if let currentUserId = userAccountManager.currentUser?.profile?.userId,
                   comment.userId == currentUserId {
                    HStack {
                        Spacer()
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
                date: selectedDate  // 選択中の日付を追加
            )
            
            // コメント追加成功後
            newCommentText = ""
            
            // コメントリストを再取得（同じ日付のコメントのみ）
            let comments = await dataManager.fetchComments(subjectId: subjectId, date: selectedDate)
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

// スクロールオフセット用のPreferenceKey
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}