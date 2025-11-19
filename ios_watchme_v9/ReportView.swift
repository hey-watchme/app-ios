//
//  ReportView.swift
//  ios_watchme_v9
//
//  レポートページ - モックアップ
//

import SwiftUI

struct ReportView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager

    // Weekly data state
    @State private var weeklyResults: WeeklyResults?
    @State private var weeklyAverageVibeScore: Double?
    @State private var isLoadingWeeklyData = false

    // 期間選択の状態
    enum Period: String, CaseIterable {
        case week = "週"
        case month = "月"
        case year = "年"
    }

    @State private var selectedPeriod: Period = .week

    // グラフの共通設定
    private let barSpacing: CGFloat = 8  // 棒グラフ間のスペース
    private let barPaddingRatio: CGFloat = 0.15  // 棒グラフの左右パディング比率

    // サンプルデータ（週次）
    let weeklyMoodData: [(day: String, value: Double)] = [
        ("月", 3.5),
        ("火", 4.2),
        ("水", 2.8),
        ("木", 4.5),
        ("金", 3.0),
        ("土", 4.8),
        ("日", 4.0)
    ]

    // サンプルデータ（月次 - 日別）
    let monthlyMoodData: [(day: String, value: Double)] = [
        ("1", 3.5), ("2", 3.7), ("3", 4.0), ("4", 3.8), ("5", 4.2),
        ("6", 3.6), ("7", 3.9), ("8", 4.1), ("9", 3.5), ("10", 3.8),
        ("11", 4.0), ("12", 3.7), ("13", 4.3), ("14", 3.9), ("15", 4.5),
        ("16", 4.2), ("17", 3.8), ("18", 4.0), ("19", 3.6), ("20", 3.9),
        ("21", 4.1), ("22", 3.7), ("23", 4.4), ("24", 4.0), ("25", 3.8),
        ("26", 4.2), ("27", 3.9), ("28", 4.1), ("29", 3.7), ("30", 4.0)
    ]

    // サンプルデータ（年次）
    let yearlyMoodData: [(day: String, value: Double)] = [
        ("1月", 3.5),
        ("2月", 3.8),
        ("3月", 4.2),
        ("4月", 3.6),
        ("5月", 4.0),
        ("6月", 3.4),
        ("7月", 4.5),
        ("8月", 3.9),
        ("9月", 4.1),
        ("10月", 3.7),
        ("11月", 4.3),
        ("12月", 4.0)
    ]

    // ダイバージェンス・インデックスのサンプルデータ（週次）
    let weeklyDivergenceData: [(day: String, cognitive: Double, emotional: Double, behavioral: Double, di: Double)] = [
        ("月", 45, 52, 38, 45),
        ("火", 58, 65, 51, 58),
        ("水", 72, 68, 75, 72),
        ("木", 85, 82, 79, 82),
        ("金", 92, 88, 95, 92),
        ("土", 78, 81, 74, 78),
        ("日", 55, 62, 48, 55)
    ]

    // ダイバージェンス・インデックスのサンプルデータ（月次 - 日別）
    let monthlyDivergenceData: [(day: String, cognitive: Double, emotional: Double, behavioral: Double, di: Double)] = [
        ("1", 45, 50, 40, 45), ("2", 48, 52, 44, 48), ("3", 52, 56, 48, 52),
        ("4", 55, 60, 52, 56), ("5", 60, 65, 58, 61), ("6", 58, 62, 55, 58),
        ("7", 62, 68, 60, 63), ("8", 65, 70, 62, 66), ("9", 68, 72, 65, 68),
        ("10", 70, 75, 68, 71), ("11", 72, 78, 70, 73), ("12", 75, 80, 72, 76),
        ("13", 78, 82, 75, 78), ("14", 80, 85, 78, 81), ("15", 82, 88, 80, 83),
        ("16", 85, 90, 82, 86), ("17", 82, 88, 80, 83), ("18", 80, 85, 78, 81),
        ("19", 78, 82, 75, 78), ("20", 75, 80, 72, 76), ("21", 72, 78, 70, 73),
        ("22", 70, 75, 68, 71), ("23", 68, 72, 65, 68), ("24", 65, 70, 62, 66),
        ("25", 62, 68, 60, 63), ("26", 60, 65, 58, 61), ("27", 58, 62, 55, 58),
        ("28", 55, 60, 52, 56), ("29", 52, 56, 48, 52), ("30", 50, 55, 48, 51)
    ]

    // ダイバージェンス・インデックスのサンプルデータ（年次）
    let yearlyDivergenceData: [(day: String, cognitive: Double, emotional: Double, behavioral: Double, di: Double)] = [
        ("1月", 45, 50, 40, 45),
        ("2月", 52, 58, 48, 53),
        ("3月", 60, 65, 58, 61),
        ("4月", 55, 60, 52, 56),
        ("5月", 68, 72, 65, 68),
        ("6月", 75, 70, 78, 74),
        ("7月", 82, 85, 80, 82),
        ("8月", 70, 68, 72, 70),
        ("9月", 78, 75, 80, 78),
        ("10月", 65, 70, 62, 66),
        ("11月", 58, 62, 55, 58),
        ("12月", 50, 55, 48, 51)
    ]

    // 期間に応じたデータ選択
    private var currentMoodData: [(day: String, value: Double)] {
        switch selectedPeriod {
        case .week:
            return weeklyMoodData
        case .month:
            return monthlyMoodData
        case .year:
            return yearlyMoodData
        }
    }

    private var currentDivergenceData: [(day: String, cognitive: Double, emotional: Double, behavioral: Double, di: Double)] {
        switch selectedPeriod {
        case .week:
            return weeklyDivergenceData
        case .month:
            return monthlyDivergenceData
        case .year:
            return yearlyDivergenceData
        }
    }

    // 現在の期間テキスト
    private var currentPeriodText: String {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .week:
            // 週の場合：「2025年11月2日〜8日」
            let weekday = calendar.component(.weekday, from: now)
            let daysFromMonday = (weekday == 1) ? 6 : weekday - 2

            guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: now),
                  let sunday = calendar.date(byAdding: .day, value: 6, to: monday) else {
                return ""
            }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.dateFormat = "yyyy年M月d日"

            let startDate = formatter.string(from: monday)
            formatter.dateFormat = "d日"
            let endDate = formatter.string(from: sunday)

            return "\(startDate)〜\(endDate)"

        case .month:
            // 月の場合：「2025年11月」
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.dateFormat = "yyyy年M月"
            return formatter.string(from: now)

        case .year:
            // 年の場合：「2025年」
            let year = calendar.component(.year, from: now)
            return "\(year)年"
        }
    }

    // 気分ハイライト（5歳児が嬉しいイベント）
    let moodHighlights: [(emoji: String, title: String, description: String)] = [
        ("🎈", "公園で友達と遊んだ", "すべり台とブランコで楽しく遊べた"),
        ("🍦", "好きなアイスクリームを食べた", "チョコレート味のアイスをもらって嬉しかった"),
        ("✈️", "折り紙で飛行機を作れた", "先生に褒められて嬉しかった")
    ]

    // ダイバージェンスローライト（困ったこと・失敗）
    let divergenceLowlights: [(emoji: String, title: String, description: String)] = [
        ("🧸", "お気に入りのおもちゃを失くした", "どこを探しても見つからず不安になった"),
        ("🥕", "給食のにんじんが食べられなかった", "苦手な野菜が多くて残してしまった"),
        ("😴", "お昼寝の時間に眠れなかった", "なかなか寝付けず落ち着かなかった")
    ]

    var body: some View {
        let _ = print("🎨 [ReportView] body rendered, selectedPeriod: \(selectedPeriod.rawValue)")

        ScrollView {
            VStack(spacing: 24) {
                // ヘッダー
                VStack(alignment: .leading, spacing: 8) {
                    Text("レポート")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(currentPeriodText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Weekly Report Section (今週のレポート)
                if selectedPeriod == .week {
                    weeklyReportSection
                        .padding(.horizontal, 20)
                }

                // 期間選択UI
                periodSelector
                    .padding(.horizontal, 20)

                // 気分
                moodBarChart
                    .padding(.horizontal, 20)

                // 気分ハイライト
                highlightsSection(events: moodHighlights)
                    .padding(.horizontal, 20)

                // ダイバージェンス・インデックス
                divergenceIndexSection
                    .padding(.horizontal, 20)

                // ダイバージェンスローライト
                highlightsSection(events: divergenceLowlights)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
        .background(Color(.systemBackground))
        .task {
            print("🚀 [ReportView] .task triggered")
            await loadWeeklyData()
        }
    }

    // MARK: - 期間選択UI
    private var periodSelector: some View {
        HStack(spacing: 0) {
            ForEach(Period.allCases, id: \.self) { period in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPeriod = period
                    }
                }) {
                    Text(period.rawValue)
                        .font(.system(size: 15, weight: selectedPeriod == period ? .semibold : .regular))
                        .foregroundColor(selectedPeriod == period ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedPeriod == period ?
                            Color(.systemBackground) :
                            Color.clear
                        )
                        .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - 棒グラフ
    private var moodBarChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("気分")
                .font(.title3)
                .fontWeight(.semibold)

            GeometryReader { geometry in
                let totalWidth = geometry.size.width - 40 // 右側の目盛りスペース
                let barWidth = totalWidth / CGFloat(currentMoodData.count)
                let barInnerWidth = barWidth * (1 - barPaddingRatio * 2)
                let chartHeight: CGFloat = 200
                let maxValue: Double = 5.0

                HStack(spacing: 0) {
                    // グラフ部分
                    VStack(spacing: 4) {
                        // グリッドライン + バー
                        ZStack(alignment: .bottom) {
                            // 背景グリッドライン
                            VStack(spacing: 0) {
                                ForEach([5.0, 4.0, 3.0, 2.0, 1.0], id: \.self) { value in
                                    HStack {
                                        Rectangle()
                                            .fill(Color(.systemGray5))
                                            .frame(height: 0.5)
                                        Spacer()
                                    }
                                    .frame(height: chartHeight / 5)
                                }
                            }

                            // バー
                            HStack(alignment: .bottom, spacing: 0) {
                                ForEach(Array(currentMoodData.enumerated()), id: \.offset) { index, data in
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.accentPurple)
                                        .frame(width: barInnerWidth, height: barHeight(for: data.value))
                                        .frame(width: barWidth)
                                }
                            }
                        }
                        .frame(height: chartHeight)

                        // ラベル部分
                        HStack(spacing: 0) {
                            ForEach(Array(currentMoodData.enumerated()), id: \.offset) { index, data in
                                Text(shouldShowLabel(index: index, total: currentMoodData.count) ? data.day : "")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(width: barWidth)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                            }
                        }
                    }
                    .frame(width: totalWidth)

                    // 右側の目盛り
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach([5.0, 4.0, 3.0, 2.0, 1.0, 0.0], id: \.self) { value in
                            Text(String(format: "%.0f", value))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(height: value == 0 ? 0 : chartHeight / 5, alignment: .top)
                        }
                    }
                    .frame(width: 30)
                }
            }
            .frame(height: 230)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }

    // MARK: - ハイライト/ローライト共通セクション
    private func highlightsSection(events: [(emoji: String, title: String, description: String)]) -> some View {
        VStack(spacing: 12) {
            ForEach(events, id: \.title) { event in
                HStack(alignment: .top, spacing: 12) {
                    // 絵文字アイコン
                    Text(event.emoji)
                        .font(.system(size: 32))
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(Color(.systemGray6))
                        )

                    // イベント詳細
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(event.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
            }
        }
    }

    // MARK: - ヘルパー関数

    /// 気分の値に応じたバーの高さを計算
    private func barHeight(for value: Double) -> CGFloat {
        let maxValue: Double = 5.0
        let maxHeight: CGFloat = 160
        return CGFloat(value / maxValue) * maxHeight
    }

    /// 気分の値に応じた色を返す
    private func colorForMood(_ value: Double) -> Color {
        switch value {
        case 0..<2.5:
            return Color.red
        case 2.5..<3.5:
            return Color.orange
        case 3.5..<4.5:
            return Color.yellow
        default:
            return Color.green
        }
    }

    /// ラベルを表示すべきかを判定（最初・真ん中・最後のみ表示）
    private func shouldShowLabel(index: Int, total: Int) -> Bool {
        if total <= 7 {
            // 7つ以下なら全て表示
            return true
        } else if total <= 12 {
            // 12以下なら最初・真ん中・最後
            return index == 0 || index == total / 2 || index == total - 1
        } else {
            // 30日のような多い場合は、最初・中間2つ・最後
            let quarter = total / 4
            return index == 0 || index == quarter || index == quarter * 2 || index == quarter * 3 || index == total - 1
        }
    }

    // MARK: - ダイバージェンス・インデックス
    private var divergenceIndexSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ダイバージェンス")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                // グラフエリア
                divergenceChart

                // 凡例
                divergenceLegend
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }

    private var divergenceChart: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width - 40 // 右側の目盛りスペース
            let chartHeight: CGFloat = 280
            let dataCount = currentDivergenceData.count
            let barWidth = totalWidth / CGFloat(dataCount)
            let barInnerWidth = barWidth * (1 - barPaddingRatio * 2)
            let maxValue: Double = 100.0

            HStack(spacing: 0) {
                // グラフ部分
                VStack(spacing: 4) {
                    // グラフエリア
                    ZStack(alignment: .bottom) {
                        // 背景グリッドライン
                        VStack(spacing: 0) {
                            ForEach([100, 80, 60, 40, 20], id: \.self) { value in
                                HStack {
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .frame(height: 0.5)
                                    Spacer()
                                }
                                .frame(height: chartHeight / 5)
                            }
                        }

                        // 帯域背景
                        VStack(spacing: 0) {
                            divergenceZone(label: "Extreme", range: "99-100", color: Color.red.opacity(0.1), height: chartHeight * 0.01)
                            divergenceZone(label: "Rare", range: "95-99", color: Color.orange.opacity(0.1), height: chartHeight * 0.04)
                            divergenceZone(label: "Atypical", range: "80-95", color: Color.yellow.opacity(0.1), height: chartHeight * 0.15)
                            divergenceZone(label: "Noticeable", range: "60-80", color: Color.blue.opacity(0.08), height: chartHeight * 0.2)
                            divergenceZone(label: "Typical", range: "0-60", color: Color.green.opacity(0.08), height: chartHeight * 0.6)
                        }

                        // 棒グラフ（DI総合値）
                        HStack(alignment: .bottom, spacing: 0) {
                            ForEach(Array(currentDivergenceData.enumerated()), id: \.offset) { index, data in
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.accentPurple)
                                    .frame(
                                        width: barInnerWidth,
                                        height: CGFloat(data.di / maxValue) * chartHeight
                                    )
                                    .frame(width: barWidth)
                            }
                        }

                        // 折れ線グラフ（3本）
                        ZStack {
                            // Cognitive Delta（薄いグレー）
                            lineChart(data: currentDivergenceData.map { $0.cognitive }, color: Color.gray.opacity(0.4), chartWidth: totalWidth, chartHeight: chartHeight, maxValue: maxValue)

                            // Emotional Delta（グレー）
                            lineChart(data: currentDivergenceData.map { $0.emotional }, color: Color.gray.opacity(0.6), chartWidth: totalWidth, chartHeight: chartHeight, maxValue: maxValue)

                            // Behavioral Delta（黒）
                            lineChart(data: currentDivergenceData.map { $0.behavioral }, color: Color.black.opacity(0.7), chartWidth: totalWidth, chartHeight: chartHeight, maxValue: maxValue)
                        }
                    }
                    .frame(height: chartHeight)

                    // X軸ラベル
                    HStack(spacing: 0) {
                        ForEach(Array(currentDivergenceData.enumerated()), id: \.offset) { index, data in
                            Text(shouldShowLabel(index: index, total: currentDivergenceData.count) ? data.day : "")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: barWidth)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                    }
                }
                .frame(width: totalWidth)

                // 右側の目盛り
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach([100, 80, 60, 40, 20, 0], id: \.self) { value in
                        Text("\(value)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(height: value == 0 ? 0 : chartHeight / 5, alignment: .top)
                    }
                }
                .frame(width: 30)
            }
        }
        .frame(height: 320)
    }

    private func divergenceZone(label: String, range: String, color: Color, height: CGFloat) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .fontWeight(.semibold)
                Text(range)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 8)
            Spacer()
        }
        .frame(height: height)
        .background(color)
    }

    private func lineChart(data: [Double], color: Color, chartWidth: CGFloat, chartHeight: CGFloat, maxValue: Double) -> some View {
        let dataCount = data.count
        let barWidth = chartWidth / CGFloat(dataCount)

        return ZStack {
            // ライン
            Path { path in
                for (index, value) in data.enumerated() {
                    let x = barWidth / 2 + CGFloat(index) * barWidth
                    let y = chartHeight - (CGFloat(value / maxValue) * chartHeight)

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, lineWidth: 2.5)

            // データポイント
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .position(
                        x: barWidth / 2 + CGFloat(index) * barWidth,
                        y: chartHeight - (CGFloat(value / maxValue) * chartHeight)
                    )
            }
        }
    }

    private var divergenceLegend: some View {
        HStack(spacing: 16) {
            legendItem(color: Color.gray.opacity(0.4), label: "Cognitive Δ")
            legendItem(color: Color.gray.opacity(0.6), label: "Emotional Δ")
            legendItem(color: Color.black.opacity(0.7), label: "Behavioral Δ")
            legendItem(color: Color.accentPurple, label: "DI総合")
        }
        .font(.caption)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 16, height: 3)
            Text(label)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Weekly Report Section

    private var weeklyReportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section title
            Text("今週のレポート")
                .font(.title3)
                .fontWeight(.semibold)

            if isLoadingWeeklyData {
                // Loading state
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("今週のデータを取得中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )

            } else if let weeklyResults = weeklyResults {
                VStack(alignment: .leading, spacing: 16) {
                    // Average vibe score
                    if let avgScore = weeklyAverageVibeScore {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("週の平均気分")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%+.0f", avgScore))
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(vibeScoreColor(avgScore))
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }

                    // Week summary
                    if let summary = weeklyResults.summary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("週のサマリー")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            Text(summary)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineSpacing(4)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }

                    // Memorable events
                    if let events = weeklyResults.memorableEvents, !events.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("印象的な出来事")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            ForEach(events) { event in
                                memorableEventCard(event)
                            }
                        }
                    }
                }

            } else {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("今週のデータはまだありません")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
        }
    }

    private func memorableEventCard(_ event: MemorableEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Rank and date
            HStack {
                Text("#\(event.rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentPurple)
                    )

                Text("\(event.date) (\(event.dayOfWeek)) \(event.time)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }

            // Event summary
            Text(event.eventSummary)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(4)

            // Transcription snippet
            if !event.transcriptionSnippet.isEmpty {
                Text("\"\(event.transcriptionSnippet)\"")
                    .font(.caption)
                    .italic()
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }

    private func vibeScoreColor(_ score: Double) -> Color {
        if score >= 30 {
            return .green
        } else if score >= 0 {
            return .blue
        } else if score >= -30 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Data Loading

    private func loadWeeklyData() async {
        print("🚀 [loadWeeklyData] Function started")

        print("🔍 Device Manager state:")
        print("  - Selected Device ID: \(deviceManager.selectedDeviceID ?? "nil")")
        print("  - Devices count: \(deviceManager.devices.count)")

        guard let deviceId = deviceManager.selectedDeviceID else {
            print("❌ [loadWeeklyData] No device selected")
            return
        }

        print("✅ [loadWeeklyData] Device ID: \(deviceId)")

        isLoadingWeeklyData = true

        // Calculate current week's Monday (week_start_date)
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)

        print("📅 Current date: \(now)")
        print("📅 Current weekday: \(weekday) (1=Sunday, 2=Monday)")

        let daysFromMonday = (weekday == 1) ? 6 : weekday - 2  // Sunday=1, Monday=2
        print("📅 Days from Monday: \(daysFromMonday)")

        guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: now) else {
            print("❌ Failed to calculate Monday")
            isLoadingWeeklyData = false
            return
        }

        let timezone = deviceManager.getTimezone(for: deviceId)

        // Debug logging
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timezone ?? TimeZone.current

        let mondayString = formatter.string(from: monday)
        print("📅 Calculated Monday: \(mondayString)")
        print("🔍 [ReportView] Fetching weekly data for device: \(deviceId)")
        print("🔍 [ReportView] Week start date (Monday): \(mondayString)")

        // Fetch weekly results
        async let weeklyResultsTask = dataManager.fetchWeeklyResults(deviceId: deviceId, weekStartDate: monday, timezone: timezone)
        async let avgScoreTask = dataManager.fetchWeeklyAverageVibeScore(deviceId: deviceId, weekStartDate: monday, timezone: timezone)

        weeklyResults = await weeklyResultsTask
        weeklyAverageVibeScore = await avgScoreTask

        print("🔍 [ReportView] Weekly results: \(weeklyResults != nil ? "Found" : "Not found")")
        print("🔍 [ReportView] Memorable events count: \(weeklyResults?.memorableEvents?.count ?? 0)")

        isLoadingWeeklyData = false
    }
}
