//
//  DayContentView.swift
//  ios_watchme_v9
//
//  One day's analysis, the same wherever it is opened (platform docs/product/screens.md
//  "1 日の画面"): the day's score and summary, its recordings with their pictures, a few
//  exchanges, what happened most, and who did what to whom. The home tab shows it under
//  the things that are about now (activity, open questions); the report pushes it as
//  DayScreen, which loads the day itself.
//

import SwiftUI
import Supabase

struct DayContentView<Slot: View>: View {
    let deviceId: String?
    let localDate: String
    let summary: DashboardSummary?
    let blocks: [DashboardTimeBlock]
    let onOpenSpot: (DashboardTimeBlock) -> Void
    /// What the host puts between the score and the recordings (the home's open questions).
    @ViewBuilder var afterScore: () -> Slot

    /// Changes when a recording of the day finishes its events, so the counts are read again.
    private var refreshKey: String {
        let done = blocks.filter { $0.stages.contains { $0.stage == "events" && $0.status == "completed" } }.count
        return "\(blocks.count)-\(done)"
    }

    var body: some View {
        VStack(spacing: 16) {
            // At a glance: the day's score and summary
            ModernHeroGaugeView(dashboardSummary: summary)

            afterScore()

            // The picture: each recording, newest first
            if blocks.isEmpty {
                Text("この日の録音はまだありません。下の録音ボタンから録ると、ここに録音の流れが出ます")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.5))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .detailCard()
            } else {
                ForEach(blocks.reversed()) { block in
                    HomeRecordingCard(block: block) { onOpenSpot(block) }
                }
            }

            // In detail: the words as said, what happened most, who to whom
            HomeDigestCard(blocks: blocks)
            if let deviceId {
                HomeEventRankingCard(deviceId: deviceId, localDate: localDate, refreshKey: refreshKey)
                HomeWhoToWhomCard(deviceId: deviceId, localDate: localDate, refreshKey: refreshKey)
            }
        }
    }
}

extension DayContentView where Slot == EmptyView {
    init(deviceId: String?, localDate: String, summary: DashboardSummary?, blocks: [DashboardTimeBlock],
         onOpenSpot: @escaping (DashboardTimeBlock) -> Void) {
        self.init(deviceId: deviceId, localDate: localDate, summary: summary, blocks: blocks,
                  onOpenSpot: onOpenSpot, afterScore: { EmptyView() })
    }
}

// MARK: - Who to whom

/// Who reprimanded, argued with or praised whom across the day's recordings, most frequent
/// first. Counts only, no judgement. Low-confidence events are left out; a recording
/// analysed more than once counts by its newest version.
struct HomeWhoToWhomCard: View {
    let deviceId: String
    let localDate: String
    let refreshKey: String

    private struct Run: Decodable { let recorded_at: String; let extractor_version: String }
    private struct Row: Decodable {
        let recorded_at: String
        let extractor_version: String
        let event_type: String
        let actor: String
        let target: String?
    }
    private struct Pair: Identifiable {
        let who: String
        let type: String
        let count: Int
        var id: String { "\(who)-\(type)" }
    }

    @State private var pairs: [Pair] = []

    var body: some View {
        // A VStack so that .task runs even while there is nothing to show
        VStack(spacing: 0) {
            if !pairs.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("誰から誰へ")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        InfoButton(text: "叱責・口論・褒めるについて、誰が誰にしたかを、この日の録音すべてから数えたものです。根拠の弱いものは入れていません。")
                    }
                    ForEach(pairs) { pair in
                        HStack(spacing: 10) {
                            Text(DayStrip.emoji[pair.type] ?? "・")
                                .font(.system(size: 18))
                                .frame(width: 26)
                            Text(pair.who)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                            Text(SpotEventsCard.typeNames[pair.type] ?? pair.type)
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.55))
                            Spacer()
                            Text("\(pair.count)回")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                }
                .detailCard()
            }
        }
        .task(id: "\(deviceId)-\(localDate)-\(refreshKey)") { await load() }
    }

    private func load() async {
        let client = SupabaseClientManager.shared.client
        do {
            async let runsTask: [Run] = client.from("spot_event_runs")
                .select("recorded_at, extractor_version")
                .eq("device_id", value: deviceId).eq("local_date", value: localDate)
                .execute().value
            async let rowsTask: [Row] = client.from("spot_events")
                .select("recorded_at, extractor_version, event_type, actor, target")
                .eq("device_id", value: deviceId).eq("local_date", value: localDate)
                .in("event_type", values: ["reprimand", "conflict", "praise"])
                .neq("confidence", value: "low")
                .execute().value
            let (runs, rows) = try await (runsTask, rowsTask)
            var newest: [String: String] = [:]
            for run in runs where (newest[run.recorded_at] ?? "") < run.extractor_version {
                newest[run.recorded_at] = run.extractor_version
            }
            var counts: [String: (who: String, type: String, count: Int)] = [:]
            for row in rows where newest[row.recorded_at] == row.extractor_version {
                guard let target = row.target else { continue }
                let who = "\(SpotEventsCard.roleNames[row.actor] ?? row.actor) → \(SpotEventsCard.roleNames[target] ?? target)"
                counts["\(who)-\(row.event_type)", default: (who, row.event_type, 0)].count += 1
            }
            pairs = counts.values.map { Pair(who: $0.who, type: $0.type, count: $0.count) }
                .sorted { $0.count != $1.count ? $0.count > $1.count : $0.id < $1.id }
        } catch {
            guard !Task.isCancelled else { return }
            print("❌ [WhoToWhom] could not load \(localDate): \(error)")
        }
    }
}

// MARK: - The day, opened from somewhere else

/// The day's analysis pushed onto the app's navigation stack (from the report's day panels).
/// Going back returns to where it was opened from.
struct DayScreen: View {
    let deviceId: String
    let localDate: String  // yyyy-MM-dd

    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var deviceManager: DeviceManager

    @State private var summary: DashboardSummary?
    @State private var blocks: [DashboardTimeBlock] = []
    @State private var isLoading = true
    @State private var selectedSpot: DashboardTimeBlock?

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .tint(.accentTeal)
                    .padding(.top, 60)
            } else {
                DayContentView(deviceId: deviceId, localDate: localDate, summary: summary, blocks: blocks) {
                    selectedSpot = $0
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.darkBase.ignoresSafeArea())
        .navigationTitle(dateTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.darkBase, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $selectedSpot) { spot in
            SpotDetailView(deviceId: deviceId, spotData: spot)
                .environmentObject(dataManager)
        }
        .task(id: "\(deviceId)-\(localDate)") { await load() }
    }

    private var dateTitle: String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: localDate) else { return localDate }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日（E）"
        return formatter.string(from: date)
    }

    private func load() async {
        isLoading = true
        let timezone = deviceManager.getTimezone(for: deviceId)
        async let summaryTask = dataManager.fetchDailyResults(deviceId: deviceId, localDate: localDate, timezone: timezone)
        async let blocksTask = dataManager.fetchDashboardTimeBlocks(deviceId: deviceId, localDate: localDate, timezone: timezone)
        summary = await summaryTask
        blocks = await blocksTask
        isLoading = false
    }
}
