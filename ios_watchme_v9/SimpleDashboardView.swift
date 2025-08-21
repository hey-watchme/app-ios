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
    let selectedDate: Date
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    
    // 各データを個別に管理（シンプルに）
    @State private var vibeReport: DailyVibeReport?
    @State private var behaviorReport: BehaviorReport?
    @State private var emotionReport: EmotionReport?
    @State private var subject: Subject?
    @State private var isLoading = false
    
    // モーダル表示管理
    @State private var showVibeSheet = false
    @State private var showBehaviorSheet = false
    @State private var showEmotionSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("読み込み中...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // 心理グラフカード
                    vibeGraphCard
                        .padding(.horizontal, 20)
                    
                    // 行動グラフカード
                    behaviorGraphCard
                        .padding(.horizontal, 20)
                    
                    // 感情グラフカード
                    emotionGraphCard
                        .padding(.horizontal, 20)
                    
                    // 観測対象カード
                    Group {
                        if let subject = subject {
                            observationTargetCard(subject)
                        } else {
                            noObservationTargetCard()
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 100)
                }
            }
            .padding(.top, 20)
        }
        .background(
            Color.safeColor("BehaviorBackgroundPrimary")
                .ignoresSafeArea()
        )
        .task(id: LoadDataTrigger(date: selectedDate, deviceId: deviceManager.selectedDeviceID)) {
            // DeviceManagerがready状態の時のみデータ取得を実行
            guard deviceManager.state == .ready else {
                print("⚠️ SimpleDashboardView: DeviceManager is not ready (state: \(deviceManager.state)), skipping data load")
                return
            }
            
            // 日付またはデバイスIDが変更されたときに実行
            print("📌 SimpleDashboardView: .task triggered - date: \(selectedDate), deviceId: \(deviceManager.selectedDeviceID ?? "nil")")
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
                print("🔄 SimpleDashboardView: Device changed from \(oldDeviceId!) to \(newDeviceId!), clearing data")
                clearAllData()
            }
        }
        .sheet(isPresented: $showVibeSheet) {
            NavigationView {
                HomeView(vibeReport: vibeReport, subject: subject)
                    .environmentObject(deviceManager)
                    .environmentObject(dataManager)
                    .navigationBarTitleDisplayMode(.large)
                    .navigationTitle("心理グラフ")
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
                BehaviorGraphView(behaviorReport: behaviorReport)
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
                EmotionGraphView(emotionReport: emotionReport)
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
            if let vibeReport = vibeReport {
                ModernVibeCard(
                    vibeReport: vibeReport,
                    onNavigateToDetail: { }
                )
                .onTapGesture {
                    showVibeSheet = true
                }
            } else {
                UnifiedCard(
                    title: "気分",
                    navigationLabel: "心理グラフ",
                    onNavigate: { }
                ) {
                    GraphEmptyStateView(
                        graphType: .vibe,
                        isDeviceLinked: !deviceManager.userDevices.isEmpty,
                        isCompact: true
                    )
                }
                .onTapGesture {
                    showVibeSheet = true
                }
            }
        }
    }
    
    private var behaviorGraphCard: some View {
        UnifiedCard(
            title: "行動",
            navigationLabel: "行動グラフ",
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
                                .font(.system(size: 72))
                            
                            Text(topBehavior.event)
                                .font(.caption)
                                .foregroundStyle(Color.safeColor("PrimaryActionColor"))
                                .textCase(.uppercase)
                                .tracking(1.0)
                            
                            HStack(spacing: 4) {
                                Text("今日のメイン:")
                                    .font(.caption2)
                                    .foregroundStyle(Color.safeColor("BehaviorTextSecondary"))
                                
                                Text("\(topBehavior.count)回")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.safeColor("PrimaryActionColor").opacity(0.8))
                            }
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
            showBehaviorSheet = true
        }
    }
    
    private var emotionGraphCard: some View {
        UnifiedCard(
            title: "感情",
            navigationLabel: "感情グラフ",
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
                    ForEach(Array(filteredRanking.prefix(3).enumerated()), id: \.element.id) { index, behavior in
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
    
    private func emotionReportContent(_ report: EmotionReport) -> some View {
        VStack(spacing: 16) {
            if !report.emotionGraph.isEmpty {
                // 全時間の感情の平均を計算
                let avgJoy = report.emotionGraph.map { $0.joy }.reduce(0, +) / report.emotionGraph.count
                let avgTrust = report.emotionGraph.map { $0.trust }.reduce(0, +) / report.emotionGraph.count
                let avgFear = report.emotionGraph.map { $0.fear }.reduce(0, +) / report.emotionGraph.count
                let avgSurprise = report.emotionGraph.map { $0.surprise }.reduce(0, +) / report.emotionGraph.count
                let avgSadness = report.emotionGraph.map { $0.sadness }.reduce(0, +) / report.emotionGraph.count
                let avgDisgust = report.emotionGraph.map { $0.disgust }.reduce(0, +) / report.emotionGraph.count
                let avgAnger = report.emotionGraph.map { $0.anger }.reduce(0, +) / report.emotionGraph.count
                let avgAnticipation = report.emotionGraph.map { $0.anticipation }.reduce(0, +) / report.emotionGraph.count
                
                let emotions = [
                    ("joy", avgJoy, "😊", Color.safeColor("EmotionJoy")),
                    ("trust", avgTrust, "🤝", Color.safeColor("EmotionTrust")),
                    ("fear", avgFear, "😨", Color.safeColor("EmotionFear")),
                    ("surprise", avgSurprise, "😲", Color.safeColor("EmotionSurprise")),
                    ("sadness", avgSadness, "😢", Color.safeColor("EmotionSadness")),
                    ("disgust", avgDisgust, "🤢", Color.safeColor("EmotionDisgust")),
                    ("anger", avgAnger, "😠", Color.safeColor("EmotionAnger")),
                    ("anticipation", avgAnticipation, "🎯", Color.safeColor("EmotionAnticipation"))
                ]
                
                let topEmotions = emotions.sorted { $0.1 > $1.1 }.prefix(3)
                
                // トップ感情を絵文字で表示
                HStack(spacing: 16) {
                    ForEach(Array(topEmotions.enumerated()), id: \.element.0) { index, emotion in
                        VStack(spacing: 4) {
                            Text(emotion.2)
                                .font(.system(size: 36))
                            
                            Text("\(emotion.1)%")
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
                                        .fill(emotion.3)
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
        print("🧹 SimpleDashboardView: Clearing all data")
        vibeReport = nil
        behaviorReport = nil
        emotionReport = nil
        subject = nil
    }
    
    private func loadAllData() async {
        print("🔄 SimpleDashboardView: loadAllData() called.")
        print("   - selectedDeviceID: \(deviceManager.selectedDeviceID ?? "nil")")
        print("   - localDeviceIdentifier: \(deviceManager.localDeviceIdentifier ?? "nil")")
        
        guard let deviceId = deviceManager.selectedDeviceID ?? deviceManager.localDeviceIdentifier else {
            print("❌ SimpleDashboardView: loadAllData() - deviceId is nil. Clearing data.")
            print("   - selectedDeviceID was: \(deviceManager.selectedDeviceID ?? "nil")")
            print("   - localDeviceIdentifier was: \(deviceManager.localDeviceIdentifier ?? "nil")")
            // データをクリア
            await MainActor.run {
                self.vibeReport = nil
                self.behaviorReport = nil
                self.emotionReport = nil
                self.subject = nil
            }
            return
        }
        
        print("✅ SimpleDashboardView: loadAllData() - deviceId is \(deviceId). Proceeding to fetch data.")
        
        // デバッグログ
        print("🔍 SimpleDashboardView loading data")
        print("   📱 Device ID: \(deviceId)")
        print("   📅 Selected Date: \(selectedDate)")
        print("   🌍 Timezone: \(deviceManager.getTimezone(for: deviceId))")
        
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
            self.vibeReport = result.vibeReport
            self.behaviorReport = result.behaviorReport
            self.emotionReport = result.emotionReport
            self.subject = result.subject
        }
        
        // デバッグログ - 取得結果
        print("✅ SimpleDashboardView data loaded:")
        print("   - Vibe: \(result.vibeReport != nil ? "✓" : "✗")")
        print("   - Behavior: \(result.behaviorReport != nil ? "✓" : "✗")")
        print("   - Emotion: \(result.emotionReport != nil ? "✓" : "✗")")
        print("   - Subject: \(result.subject != nil ? "✓" : "✗")")
        
        if let vibe = result.vibeReport {
            print("   📊 Vibe date: \(vibe.date), average: \(vibe.averageScore)")
        }
    }
}