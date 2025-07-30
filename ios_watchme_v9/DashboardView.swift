//
//  DashboardView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/27.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var authManager: SupabaseAuthManager
    @Binding var selectedDate: Date
    @State private var showSubjectRegistration = false
    @State private var showSubjectEdit = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 心理グラフハイライト
                vibeGraphCard
                
                // 行動グラフハイライト
                behaviorGraphCard
                
                // 感情グラフハイライト
                emotionGraphCard
                
                // 観測対象情報
                if let subject = dataManager.subject {
                    observationTargetCard(subject)
                } else {
                    noObservationTargetCard()
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal)
            .padding(.top, 20)
        }
        .background(Color(.systemGray6))
        .onAppear {
            Task {
                await fetchAllReports()
            }
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            Task {
                await fetchAllReports()
            }
        }
        .onChange(of: deviceManager.selectedDeviceID) { oldValue, newValue in
            Task {
                await fetchAllReports()
            }
        }
        .sheet(isPresented: $showSubjectRegistration) {
            if let deviceID = deviceManager.selectedDeviceID ?? deviceManager.localDeviceIdentifier {
                SubjectRegistrationView(
                    deviceID: deviceID, 
                    isPresented: $showSubjectRegistration,
                    editingSubject: nil
                )
                .environmentObject(dataManager)
                .environmentObject(deviceManager)
                .environmentObject(authManager)
            }
        }
        .sheet(isPresented: $showSubjectEdit) {
            if let deviceID = deviceManager.selectedDeviceID ?? deviceManager.localDeviceIdentifier,
               let subject = dataManager.subject {
                SubjectRegistrationView(
                    deviceID: deviceID,
                    isPresented: $showSubjectEdit,
                    editingSubject: subject
                )
                .environmentObject(dataManager)
                .environmentObject(deviceManager)
                .environmentObject(authManager)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var vibeGraphCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("心理状態")
                    .font(.headline)
                Spacer()
            }
            
            if let vibeReport = dataManager.dailyReport {
                vibeReportContent(vibeReport)
            } else {
                GraphEmptyStateView(
                    graphType: .vibe,
                    isDeviceLinked: !deviceManager.userDevices.isEmpty,
                    isCompact: true
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    @ViewBuilder
    private func vibeReportContent(_ vibeReport: DailyVibeReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 平均スコアとアイコン
            HStack(spacing: 16) {
                Text(vibeReport.emotionIcon(for: vibeReport.averageScore))
                    .font(.system(size: 48))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("平均スコア")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(vibeReport.averageScore))点")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(vibeReport.scoreColor(for: vibeReport.averageScore))
                }
                
                Spacer()
            }
            
            // 時間分布
            HStack(spacing: 12) {
                TimeDistributionBadge(
                    label: "ポジティブ",
                    hours: vibeReport.positiveHours,
                    color: .green
                )
                TimeDistributionBadge(
                    label: "ニュートラル",
                    hours: vibeReport.neutralHours,
                    color: .gray
                )
                TimeDistributionBadge(
                    label: "ネガティブ",
                    hours: vibeReport.negativeHours,
                    color: .red
                )
            }
            
            // AIインサイト（最初の1つ）
            if let firstInsight = vibeReport.insights.first {
                Text(firstInsight)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
    }
    
    private var behaviorGraphCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "figure.walk")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("行動パターン")
                    .font(.headline)
                Spacer()
            }
            
            if let behaviorReport = dataManager.dailyBehaviorReport {
                behaviorReportContent(behaviorReport)
            } else {
                GraphEmptyStateView(
                    graphType: .behavior,
                    isDeviceLinked: !deviceManager.userDevices.isEmpty,
                    isCompact: true
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    @ViewBuilder
    private func behaviorReportContent(_ behaviorReport: BehaviorReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // TOP3の行動
            ForEach(Array(behaviorReport.summaryRanking.prefix(3)), id: \.event) { item in
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
    
    private var emotionGraphCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundColor(.pink)
                Text("感情分析")
                    .font(.headline)
                Spacer()
            }
            
            if let emotionReport = dataManager.dailyEmotionReport {
                emotionReportContent(emotionReport)
            } else {
                GraphEmptyStateView(
                    graphType: .emotion,
                    isDeviceLinked: !deviceManager.userDevices.isEmpty,
                    isCompact: true
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
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
    
    private func fetchAllReports() async {
        if let deviceID = deviceManager.selectedDeviceID ?? deviceManager.localDeviceIdentifier {
            await dataManager.fetchAllReports(deviceId: deviceID, date: selectedDate)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private func formatDateForAPI(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
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
    
    // MARK: - 観測対象カード
    private func observationTargetCard(_ subject: Subject) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("観測対象")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 20) {
                // アバターエリア
                if let avatarUrlString = subject.avatarUrl,
                   avatarUrlString.hasPrefix("data:image") {
                    // Base64データの場合
                    if let imageData = Data(base64Encoded: String(avatarUrlString.dropFirst(22)), options: .ignoreUnknownCharacters),
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        // デフォルトアバター
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    }
                } else if let avatarUrlString = subject.avatarUrl,
                          let avatarUrl = URL(string: avatarUrlString) {
                    // URLの場合
                    AsyncImage(url: avatarUrl) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                            .frame(width: 60, height: 60)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                } else {
                    // デフォルトアバター
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                }
                
                // 情報エリア
                VStack(alignment: .leading, spacing: 8) {
                    if let name = subject.name {
                        Text(name)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    if let ageGender = subject.ageGenderDisplay {
                        Text(ageGender)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let notes = subject.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    showSubjectEdit = true
                }) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("編集")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - 観測対象未登録カード
    private func noObservationTargetCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("観測対象")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                
                VStack(spacing: 8) {
                    Text("このデバイスで観測している人物のプロフィールを登録しましょう")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("観測対象を登録すると、詳細な情報を表示できます")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .cornerRadius(8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// 時間分布バッジコンポーネント
struct TimeDistributionBadge: View {
    let label: String
    let hours: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1fh", hours))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}