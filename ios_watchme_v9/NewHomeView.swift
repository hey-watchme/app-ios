//
//  NewHomeView.swift
//  ios_watchme_v9
//
//  新しいホーム画面（ダッシュボード）- 統一デザインシステム版
//

import SwiftUI

struct NewHomeView: View {
    // ViewModelを使用（既存のDashboardViewModelを流用）
    @ObservedObject var viewModel: DashboardViewModel
    
    // 認証と画面遷移のためのプロパティ
    @EnvironmentObject var authManager: SupabaseAuthManager
    @State private var showSubjectRegistration = false
    @State private var showSubjectEdit = false
    
    // タブ遷移のためのBinding
    @Binding var selectedTab: Int
    
    // データ更新の追跡用
    @State private var lastRefreshDate: Date? = nil
    @State private var isRefreshing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 心理グラフカード
                vibeGraphCard
                
                // 行動グラフカード
                behaviorGraphCard
                    .padding(.horizontal)
                
                // 感情グラフカード
                emotionGraphCard
                    .padding(.horizontal)
                
                // 観測対象カード
                Group {
                    if let subject = viewModel.dataManager.subject {
                        observationTargetCard(subject)
                    } else {
                        noObservationTargetCard()
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
            .padding(.top, 20)
        }
        .background(
            // ライトな背景
            Color(red: 0.937, green: 0.937, blue: 0.937) // #efefef
                .ignoresSafeArea()
        )
        .onAppear {
            viewModel.onAppear()
            lastRefreshDate = viewModel.selectedDate
        }
        .onChange(of: viewModel.selectedDate) { oldDate, newDate in
            // 日付が変更されたら確実にデータを更新
            if oldDate != newDate {
                refreshData(for: newDate)
            }
        }
        .onChange(of: viewModel.deviceManager.selectedDeviceID) { _, _ in
            // デバイスが変更されたら確実にデータを更新
            refreshData(for: viewModel.selectedDate)
        }
        .sheet(isPresented: $showSubjectRegistration) {
            if let deviceID = viewModel.deviceManager.selectedDeviceID ?? viewModel.deviceManager.localDeviceIdentifier {
                SubjectRegistrationView(
                    deviceID: deviceID,
                    isPresented: $showSubjectRegistration,
                    editingSubject: nil
                )
                .environmentObject(viewModel.dataManager)
                .environmentObject(viewModel.deviceManager)
                .environmentObject(authManager)
            }
        }
        .sheet(isPresented: $showSubjectEdit) {
            if let deviceID = viewModel.deviceManager.selectedDeviceID ?? viewModel.deviceManager.localDeviceIdentifier,
               let subject = viewModel.dataManager.subject {
                SubjectRegistrationView(
                    deviceID: deviceID,
                    isPresented: $showSubjectEdit,
                    editingSubject: subject
                )
                .environmentObject(viewModel.dataManager)
                .environmentObject(viewModel.deviceManager)
                .environmentObject(authManager)
            }
        }
    }
    
    // MARK: - Vibe Graph Card
    private var vibeGraphCard: some View {
        Group {
            if let vibeReport = viewModel.dataManager.dailyReport {
                ModernVibeCard(
                    vibeReport: vibeReport,
                    onNavigateToDetail: {
                        selectedTab = 1
                    }
                )
                .padding(.horizontal)
                // データ変更時に確実にカード全体を再生成
                .id("\(vibeReport.deviceId)_\(vibeReport.date)_\(Date().timeIntervalSince1970)")
            } else {
                // エンプティステート
                UnifiedCard(
                    title: "気分",
                    navigationLabel: "心理グラフ",
                    onNavigate: {
                        selectedTab = 1
                    }
                ) {
                    GraphEmptyStateView(
                        graphType: .vibe,
                        isDeviceLinked: !viewModel.deviceManager.userDevices.isEmpty,
                        isCompact: true
                    )
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Behavior Graph Card
    private var behaviorGraphCard: some View {
        UnifiedCard(
            title: "行動",
            navigationLabel: "行動グラフ",
            onNavigate: {
                selectedTab = 2
            }
        ) {
            if let behaviorReport = viewModel.dataManager.dailyBehaviorReport {
                VStack(spacing: 8) {
                    // 「その他」カテゴリを除外したランキングを取得
                    let filteredRanking = behaviorReport.summaryRanking.filter { 
                        $0.event.lowercased() != "other" && $0.event.lowercased() != "その他" 
                    }
                    
                    // 絵文字とメインメッセージ（最多行動）
                    if let topBehavior = filteredRanking.first {
                        VStack(spacing: 8) {
                            Text("🚶")
                                .font(.system(size: 72))
                            
                            Text(topBehavior.event)
                                .font(.caption)
                                .foregroundStyle(Color.blue)
                                .textCase(.uppercase)
                                .tracking(1.0)
                            
                            HStack(spacing: 4) {
                                Text("今日のメイン:")
                                    .font(.caption2)
                                    .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4))
                                
                                Text("\(topBehavior.count)回")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.blue.opacity(0.8))
                            }
                        }
                    }
                    
                    // TOP3の行動リスト
                    behaviorReportContent(behaviorReport)
                }
            } else {
                GraphEmptyStateView(
                    graphType: .behavior,
                    isDeviceLinked: !viewModel.deviceManager.userDevices.isEmpty,
                    isCompact: true
                )
            }
        }
    }
    
    // MARK: - Emotion Graph Card
    private var emotionGraphCard: some View {
        UnifiedCard(
            title: "感情",
            navigationLabel: "感情グラフ",
            onNavigate: {
                selectedTab = 3
            }
        ) {
            if let emotionReport = viewModel.dataManager.dailyEmotionReport {
                VStack(spacing: 8) {
                    // 顔文字とメインメッセージ（最多感情）
                    let topEmotion = getTopEmotion(emotionReport)
                    VStack(spacing: 8) {
                        Text(getEmotionEmoji(topEmotion.0))
                            .font(.system(size: 72))
                        
                        Text(getEmotionJapanese(topEmotion.0))
                            .font(.caption)
                            .foregroundStyle(Color.pink)
                            .textCase(.uppercase)
                            .tracking(1.0)
                        
                        HStack(spacing: 4) {
                            Text("今日の最大:")
                                .font(.caption2)
                                .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4))
                            
                            Text("\(topEmotion.1)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.pink.opacity(0.8))
                        }
                    }
                    
                    // 感情ランキング
                    emotionReportContent(emotionReport)
                }
            } else {
                GraphEmptyStateView(
                    graphType: .emotion,
                    isDeviceLinked: !viewModel.deviceManager.userDevices.isEmpty,
                    isCompact: true
                )
            }
        }
    }
    
    // MARK: - Observation Target Card
    private func observationTargetCard(_ subject: Subject) -> some View {
        ObservationTargetCard(
            title: "観測対象"
        ) {
            HStack(spacing: 20) {
                // アバター
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let localURL = documentsPath.appendingPathComponent("subjects/\(subject.subjectId)/avatar.jpg")
                let imageURL = FileManager.default.fileExists(atPath: localURL.path) ? localURL : AWSManager.shared.getAvatarURL(type: "subjects", id: subject.subjectId)
                
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                    case .failure(_), .empty:
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 60, height: 60)
                    @unknown default:
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 60, height: 60)
                    }
                }
                
                // 情報
                VStack(alignment: .leading, spacing: 8) {
                    if let name = subject.name {
                        Text(name)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    
                    if let ageGender = subject.ageGenderDisplay {
                        Text(ageGender)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    
                    if let notes = subject.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // 編集ボタン
                Button(action: {
                    showSubjectEdit = true
                }) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("編集")
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.2))
                    .cornerRadius(6)
                }
            }
        }
    }
    
    private func noObservationTargetCard() -> some View {
        ObservationTargetCard(
            title: "観測対象"
        ) {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 50))
                    .foregroundStyle(.white.opacity(0.7))
                
                VStack(spacing: 8) {
                    Text("このデバイスで観測している人物のプロフィールを登録しましょう")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    Text("観測対象を登録すると、詳細な情報を表示できます")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                
                Button(action: {
                    showSubjectRegistration = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("観測対象を登録する")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Helper Views
    @ViewBuilder
    private func behaviorReportContent(_ behaviorReport: BehaviorReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 「その他」を除外したTOP3の行動を表示
            let filteredItems = behaviorReport.summaryRanking.filter { 
                $0.event.lowercased() != "other" && $0.event.lowercased() != "その他" 
            }
            ForEach(Array(filteredItems.prefix(3)), id: \.event) { item in
                HStack {
                    Text(getBehaviorEmoji(item.event))
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.event)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(item.count)回")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // パーセンテージバー
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue)
                                .frame(
                                    width: geometry.size.width * (Double(item.count) / Double(behaviorReport.totalEventCount)),
                                    height: 8
                                )
                        }
                    }
                    .frame(width: 80, height: 8)
                }
            }
        }
    }
    
    @ViewBuilder
    private func emotionReportContent(_ emotionReport: EmotionReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            emotionRankingView(emotionReport)
            emotionSummaryText(emotionReport)
        }
    }
    
    @ViewBuilder
    private func emotionRankingView(_ emotionReport: EmotionReport) -> some View {
        let totals = emotionReport.emotionTotals
        let emotions = [
            ("Joy", totals.joy, Color.yellow),
            ("Trust", totals.trust, Color.green),
            ("Fear", totals.fear, Color.purple),
            ("Surprise", totals.surprise, Color.orange),
            ("Sadness", totals.sadness, Color.blue),
            ("Disgust", totals.disgust, Color.brown),
            ("Anger", totals.anger, Color.red),
            ("Anticipation", totals.anticipation, Color.cyan)
        ]
        
        let sortedEmotions = emotions.sorted { $0.1 > $1.1 }
        let topThree = Array(sortedEmotions.prefix(3))
        
        ForEach(topThree, id: \.0) { emotion in
            HStack {
                Circle()
                    .fill(emotion.2)
                    .frame(width: 12, height: 12)
                
                Text(getEmotionJapanese(emotion.0))
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(emotion.1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func emotionSummaryText(_ emotionReport: EmotionReport) -> some View {
        let totals = emotionReport.emotionTotals
        let emotions = [
            ("Joy", totals.joy),
            ("Trust", totals.trust),
            ("Fear", totals.fear),
            ("Surprise", totals.surprise),
            ("Sadness", totals.sadness),
            ("Disgust", totals.disgust),
            ("Anger", totals.anger),
            ("Anticipation", totals.anticipation)
        ]
        
        if let maxEmotion = emotions.max(by: { $0.1 < $1.1 }) {
            Text("\(getEmotionJapanese(maxEmotion.0))が最も強く表れた1日でした")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Helper Methods
    private func getBehaviorEmoji(_ behavior: String) -> String {
        let emojiMap: [String: String] = [
            "working": "💼",
            "studying": "📚",
            "exercising": "🏃",
            "eating": "🍽️",
            "sleeping": "😴",
            "relaxing": "😌",
            "socializing": "👥",
            "commuting": "🚇",
            "shopping": "🛍️",
            "cooking": "👨‍🍳"
        ]
        return emojiMap[behavior.lowercased()] ?? "📍"
    }
    
    private func getEmotionJapanese(_ emotion: String) -> String {
        switch emotion {
        case "Joy": return "喜び"
        case "Trust": return "信頼"
        case "Fear": return "恐れ"
        case "Surprise": return "驚き"
        case "Sadness": return "悲しみ"
        case "Disgust": return "嫌悪"
        case "Anger": return "怒り"
        case "Anticipation": return "期待"
        default: return emotion
        }
    }
    
    private func getEmotionEmoji(_ emotion: String) -> String {
        switch emotion {
        case "Joy": return "😆"
        case "Trust": return "🤗"
        case "Fear": return "😨"
        case "Surprise": return "😲"
        case "Sadness": return "😢"
        case "Disgust": return "🤢"
        case "Anger": return "😡"
        case "Anticipation": return "🤩"
        default: return "😊"
        }
    }
    
    private func getTopEmotion(_ emotionReport: EmotionReport) -> (String, Int) {
        let totals = emotionReport.emotionTotals
        let emotions = [
            ("Joy", totals.joy),
            ("Trust", totals.trust),
            ("Fear", totals.fear),
            ("Surprise", totals.surprise),
            ("Sadness", totals.sadness),
            ("Disgust", totals.disgust),
            ("Anger", totals.anger),
            ("Anticipation", totals.anticipation)
        ]
        
        return emotions.max(by: { $0.1 < $1.1 }) ?? ("Joy", 0)
    }
    
    // MARK: - Data Refresh
    private func refreshData(for date: Date) {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        Task {
            // キャッシュをクリアして強制的に新しいデータを取得
            await forceRefreshData(for: date)
            
            await MainActor.run {
                isRefreshing = false
                lastRefreshDate = date
            }
        }
    }
    
    private func forceRefreshData(for date: Date) async {
        guard let deviceId = viewModel.deviceManager.selectedDeviceID ?? viewModel.deviceManager.localDeviceIdentifier else {
            return
        }
        
        // デバイスのタイムゾーンを取得
        let timezone = viewModel.deviceManager.getTimezone(for: deviceId)
        
        // 直接データマネージャーを更新（キャッシュを無視）
        await viewModel.dataManager.fetchAllReports(
            deviceId: deviceId,
            date: date,
            timezone: timezone
        )
        
        // ViewModelのキャッシュも更新されるようにトリガー
        await viewModel.onAppear()
    }
}