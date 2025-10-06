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
                // LargeDateSectionが画面外に出そうになったら固定ヘッダーを表示
                // LargeDateSectionの高さが約200ptなので、-150ptを闾値とする
                print("📍 SimpleDashboardView: Scroll offset detected: \(value)")
                let shouldShowStickyHeader = value < -150
                print("📍 SimpleDashboardView: shouldShowStickyHeader = \(shouldShowStickyHeader), current showStickyHeader = \(showStickyHeader)")
                if shouldShowStickyHeader != showStickyHeader {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showStickyHeader = shouldShowStickyHeader
                        print("📍 SimpleDashboardView: Updated showStickyHeader to \(showStickyHeader)")
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
            // DeviceManagerがready状態の時のみデータ取得を実行
            guard deviceManager.state == .ready else {
                return
            }
            
            // 日付またはデバイスIDが変更されたときに実行
            await loadAllData()
        }
        .onChange(of: deviceManager.state) { oldState, newState in
            // DeviceManagerがidleやloadingからreadyに変わったときにデータを取得
            if oldState != .ready && newState == .ready {
                print("🎯 SimpleDashboardView: DeviceManager became ready, loading data")
                Task {
                    await loadAllData()
                }
            }
        }
        .onChange(of: deviceManager.selectedDeviceID) { oldDeviceId, newDeviceId in
            // デバイスが切り替わったときにデータをクリア
            if oldDeviceId != nil && newDeviceId != nil && oldDeviceId != newDeviceId {
                clearAllData()
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
                        isDeviceLinked: !deviceManager.userDevices.isEmpty,
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
                            
                            Text(topBehavior.event)
                                .font(.caption)
                                .foregroundStyle(Color.safeColor("BehaviorTextPrimary"))  // 黒に変更
                                .textCase(.uppercase)
                                .tracking(1.0)
                            
                            Text("\(topBehavior.count)回")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.safeColor("BehaviorTextPrimary"))  // 黒に変更
                        }
                    }
                    
                    behaviorReportContent(behaviorReport)
                }
            } else {
                GraphEmptyStateView(
                    graphType: .behavior,
                    isDeviceLinked: !deviceManager.userDevices.isEmpty,
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
                    isDeviceLinked: !deviceManager.userDevices.isEmpty,
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
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.safeColor("BehaviorTextSecondary"))
                                .frame(width: 20, alignment: .leading)
                            
                            Text(behavior.event)
                                .font(.subheadline)
                                .foregroundStyle(Color.safeColor("BehaviorTextPrimary"))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(behavior.count)")
                                .font(.caption)
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
    private func calculateEmotionPercentages(from activeTimePoints: [EmotionTimePoint]) -> [(String, Double, String, Color)] {
        // 各感情の合計値を計算
        let totalJoy = activeTimePoints.map { $0.joy }.reduce(0, +)
        let totalTrust = activeTimePoints.map { $0.trust }.reduce(0, +)
        let totalFear = activeTimePoints.map { $0.fear }.reduce(0, +)
        let totalSurprise = activeTimePoints.map { $0.surprise }.reduce(0, +)
        let totalSadness = activeTimePoints.map { $0.sadness }.reduce(0, +)
        let totalDisgust = activeTimePoints.map { $0.disgust }.reduce(0, +)
        let totalAnger = activeTimePoints.map { $0.anger }.reduce(0, +)
        let totalAnticipation = activeTimePoints.map { $0.anticipation }.reduce(0, +)
        
        // 全感情の総計
        let grandTotal = totalJoy + totalTrust + totalFear + totalSurprise +
                        totalSadness + totalDisgust + totalAnger + totalAnticipation
        
        guard grandTotal > 0 else { return [] }
        
        // パーセンテージを計算
        return [
            ("joy", Double(totalJoy) / Double(grandTotal) * 100, "😊", Color.safeColor("EmotionJoy")),
            ("trust", Double(totalTrust) / Double(grandTotal) * 100, "🤝", Color.safeColor("EmotionTrust")),
            ("fear", Double(totalFear) / Double(grandTotal) * 100, "😨", Color.safeColor("EmotionFear")),
            ("surprise", Double(totalSurprise) / Double(grandTotal) * 100, "😲", Color.safeColor("EmotionSurprise")),
            ("sadness", Double(totalSadness) / Double(grandTotal) * 100, "😢", Color.safeColor("EmotionSadness")),
            ("disgust", Double(totalDisgust) / Double(grandTotal) * 100, "🤢", Color.safeColor("EmotionDisgust")),
            ("anger", Double(totalAnger) / Double(grandTotal) * 100, "😠", Color.safeColor("EmotionAnger")),
            ("anticipation", Double(totalAnticipation) / Double(grandTotal) * 100, "🎯", Color.safeColor("EmotionAnticipation"))
        ]
    }
    
    private func emotionReportContent(_ report: EmotionReport) -> some View {
        VStack(spacing: 16) {
            if !report.emotionGraph.isEmpty {
                let activeTimePoints = report.emotionGraph.filter { $0.totalEmotions > 0 }
                
                if !activeTimePoints.isEmpty {
                    let emotions = calculateEmotionPercentages(from: activeTimePoints)
                    let nonZeroEmotions = emotions.filter { $0.1 > 0 }
                    let topEmotions = nonZeroEmotions.sorted { $0.1 > $1.1 }.prefix(3)
                
                // トップ感情を絵文字で表示
                HStack(spacing: 16) {
                    ForEach(Array(topEmotions.enumerated()), id: \.element.0) { index, emotion in
                        VStack(spacing: 4) {
                            Text(emotion.2)
                                .font(.system(size: 36))
                            
                            Text("\(Int(emotion.1.rounded()))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 感情バー
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(topEmotions.enumerated()), id: \.element.0) { index, emotion in
                        HStack {
                            Text(emotionLabel(for: emotion.0))
                                .font(.caption)
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
        print("🔄 SimpleDashboardView: loadAllData() called.")
        print("   - selectedDeviceID: \(deviceManager.selectedDeviceID ?? "nil")")

        guard let deviceId = deviceManager.selectedDeviceID else {
            print("❌ SimpleDashboardView: loadAllData() - deviceId is nil. Clearing data.")
            print("   - selectedDeviceID was: \(deviceManager.selectedDeviceID ?? "nil")")
            // データをクリア
            await MainActor.run {
                self.behaviorReport = nil
                self.emotionReport = nil
                self.subject = nil
                self.dashboardSummary = nil
            }
            return
        }
        
        print("✅ SimpleDashboardView: loadAllData() - deviceId is \(deviceId). Proceeding to fetch data.")
        
        // デバッグログ
        print("🔍 SimpleDashboardView loading data")
        print("   📱 Device ID: \(deviceId)")
        print("   📅 Selected Date: \(selectedDate)")
        print("   🌍 Device Timezone: \(deviceManager.getTimezone(for: deviceId).identifier)")
        print("   🕐 Current iPhone Time: \(Date())")
        print("   📱 iPhone Timezone: \(TimeZone.current.identifier)")
        
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
            self.subjectComments = result.subjectComments ?? []  // コメントデータも設定
        }
        
        // デバッグログ - 取得結果
        print("✅ SimpleDashboardView data loaded:")
        print("   - Dashboard Summary: \(result.dashboardSummary != nil ? "✓" : "✗")")
        print("   - Behavior: \(result.behaviorReport != nil ? "✓" : "✗")")
        print("   - Emotion: \(result.emotionReport != nil ? "✓" : "✗")")
        print("   - Subject: \(result.subject != nil ? "✓" : "✗")")
        
        if let summary = result.dashboardSummary {
            print("   📊 Dashboard date: \(summary.date), average: \(summary.averageVibe ?? 0)")
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