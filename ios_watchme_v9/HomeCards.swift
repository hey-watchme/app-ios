//
//  HomeCards.swift
//  ios_watchme_v9
//
//  The parts of the home screen (platform docs/product/screens.md「ホーム」):
//  the one activity card at the top, and one card per recording of the day with its picture.
//

import SwiftUI

// MARK: - Activity card

/// What the activity card says. One line that changes as a recording is sent and analysed,
/// stops at "done" until it is seen, and disappears when there is nothing to tell.
enum ActivityBanner: Equatable {
    /// Chunks are still on the phone, waiting to be sent.
    case sending(left: Int)
    /// A recording is being analysed; `stage` is the step it is on.
    case analysing(recordingID: String, name: String, stage: String)
    /// A recording's analysis finished and has not been looked at yet.
    case recordingDone(recordingID: String, name: String)
    /// The day's analysis was updated from a recording and has not been looked at yet.
    case dayUpdated(recordingID: String, label: String, name: String)

    /// The key remembered once the person has looked at it.
    var seenKey: String? {
        switch self {
        case .recordingDone(let id, _): return "\(id)#recording"
        case .dayUpdated(let id, _, _): return "\(id)#day"
        default: return nil
        }
    }

    private static func sortKey(_ block: DashboardTimeBlock) -> String {
        block.recordedAt ?? block.localTime ?? ""
    }

    /// Finished results older than this are not announced (e.g. a day looked at later).
    private static let freshFor: TimeInterval = 12 * 3600

    static func current(blocks: [DashboardTimeBlock], unsentChunks: Int, viewingDate: String?, seen: Set<String>) -> ActivityBanner? {
        if unsentChunks > 0 {
            return .sending(left: unsentChunks)
        }
        // Newest first, recordings whose analysis is tracked stage by stage
        let tracked = blocks.filter { !$0.stages.isEmpty }.sorted { sortKey($0) > sortKey($1) }

        if let running = tracked.first(where: { $0.stages.isInProgress }) {
            let stages: [SpotStage] = running.stages.ordered
            let step: SpotStage? = stages.first(where: { $0.status == "running" }) ?? stages.first(where: { $0.status == "queued" })
            var label = "分析"
            if let step {
                label = step.stage == "day_so_far" ? SpotStage.dayAnalysisLabel(for: running.date) : step.label
            }
            return .analysing(recordingID: running.id, name: ActivityFeed.recordingName(running, viewingDate: viewingDate), stage: label)
        }

        guard let latest = tracked.first else { return nil }
        let finished = latest.stages.compactMap { SpotStage.parse($0.updatedAt) }.max()
        guard let finished, Date().timeIntervalSince(finished) < freshFor else { return nil }

        let recordingDone = ActivityBanner.recordingDone(recordingID: latest.id, name: ActivityFeed.recordingName(latest, viewingDate: viewingDate))
        if let key = recordingDone.seenKey, !seen.contains(key) {
            return recordingDone
        }
        if latest.stages.contains(where: { $0.stage == "day_so_far" && $0.status == "completed" }) {
            let dayUpdated = ActivityBanner.dayUpdated(recordingID: latest.id, label: SpotStage.dayAnalysisLabel(for: latest.date),
                                                       name: ActivityFeed.recordingName(latest, viewingDate: viewingDate) + "から")
            if let key = dayUpdated.seenKey, !seen.contains(key) {
                return dayUpdated
            }
        }
        return nil
    }
}

/// Remembers which finished results the person has looked at, so the card does not repeat them.
enum ActivitySeen {
    private static let key = "activity.seen"
    private static let limit = 100

    static func load() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func add(_ entry: String) {
        var entries = UserDefaults.standard.stringArray(forKey: key) ?? []
        guard !entries.contains(entry) else { return }
        entries.append(entry)
        UserDefaults.standard.set(Array(entries.suffix(limit)), forKey: key)
    }
}

/// The slim card at the top of the home screen.
struct ActivityBannerView: View {
    let banner: ActivityBanner
    let onTap: () -> Void
    let onShowLog: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    icon
                        .frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.6))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if isTappable {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(white: 0.5))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isTappable)

            Button(action: onShowLog) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.5))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("処理の記録")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkCard)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: 1))
        )
        .animation(.easeInOut(duration: 0.25), value: banner)
    }

    @ViewBuilder
    private var icon: some View {
        switch banner {
        case .sending, .analysing:
            ProgressView().tint(.accentTeal)
        case .recordingDone, .dayUpdated:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.accentTeal)
        }
    }

    /// What happened, in a word or two.
    private var title: String {
        switch banner {
        case .sending: return "送信中"
        case .analysing: return "分析中"
        case .recordingDone: return "分析完了"
        case .dayUpdated(_, let label, _): return "\(label)を更新"
        }
    }

    /// Which recording, then the detail.
    private var subtitle: String {
        switch banner {
        case .sending(let left): return "録音データ・残り\(left)件"
        case .analysing(_, let name, let stage): return "\(name)・\(stage)"
        case .recordingDone(_, let name): return name
        case .dayUpdated(_, _, let name): return name
        }
    }

    private var isTappable: Bool {
        switch banner {
        case .sending: return false
        default: return true
        }
    }

    private var borderColor: Color {
        switch banner {
        case .recordingDone, .dayUpdated: return Color.accentTeal.opacity(0.4)
        default: return Color.white.opacity(0.1)
        }
    }
}

// MARK: - A recording of the day

/// One recording on the home screen: its time and score, the picture, and the summary.
/// The picture is drawn large on purpose: someone new to the app should see from the home
/// screen alone what it does.
struct HomeRecordingCard: View {
    let block: DashboardTimeBlock
    let onOpen: () -> Void
    @StateObject private var events = SpotEventsStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 8) {
                    Text("\(block.displayTime) の録音")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    if let score = block.vibeScore {
                        Text(String(format: "%@%.0f", score >= 0 ? "+" : "", score))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color.vibeScoreColor(for: score))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.vibeScoreColor(for: score).opacity(0.15)))
                    }
                    Spacer()
                    Text("詳しく")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.5))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(white: 0.5))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if block.stages.isInProgress {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8).tint(.accentTeal)
                    Text("分析中です。終わるとここに録音の流れが出ます")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.6))
                }
            } else if let recordedAt = block.recordedAt {
                SpotEventsCard(deviceId: block.deviceId, recordedAt: recordedAt, localTime: block.localTime,
                               metricsRaw: block.metricsRaw, store: events, part: .picture, embedded: true)
            }

            if let summary = block.summary, !summary.isEmpty {
                Button(action: onOpen) {
                    Text(summary)
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.75))
                        .lineSpacing(3)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .detailCard()
    }
}

// MARK: - The day's events, most frequent first

/// What happened most across all the day's recordings: laughter at the top is a good day,
/// reprimands at the top a hard one. Counts as counted (low-confidence events left out);
/// a recording analysed more than once counts by its newest version.
struct HomeEventRankingCard: View {
    let deviceId: String
    let localDate: String
    /// Changes when a recording of the day finishes its analysis, so the counts are read again.
    let refreshKey: String

    private struct Run: Decodable {
        let recorded_at: String
        let extractor_version: String
        let counts: [String: Int]?
    }

    private struct Entry: Identifiable {
        let type: String
        let count: Int
        var id: String { type }
    }

    @State private var entries: [Entry] = []
    @State private var recordings = 0

    private static let shown = 5

    var body: some View {
        // A VStack so that .task runs even while there is nothing to show
        VStack(spacing: 0) {
            if !entries.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("この日の出来事")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(recordings)件の録音から")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.5))
                    }

                    let top = entries.first?.count ?? 1
                    ForEach(Array(entries.prefix(Self.shown).enumerated()), id: \.element.id) { index, entry in
                        row(rank: index + 1, entry: entry, top: top)
                    }
                }
                .detailCard()
            }
        }
        .task(id: "\(deviceId)-\(localDate)-\(refreshKey)") { await load() }
    }

    private func row(rank: Int, entry: Entry, top: Int) -> some View {
        let sample = TimelineEvent(id: 0, type: entry.type, start: 0, end: 0, intensity: nil)
        let color: Color = sample.direction.map { $0 > 0 ? .accentTeal : .accentCoral } ?? Color(white: 0.55)
        return HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Color(white: 0.5))
                .frame(width: 16)
            Text(sample.emoji ?? "・")
                .font(.system(size: 20))
                .frame(width: 26)
            Text(SpotEventsCard.typeNames[entry.type] ?? entry.type)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(width: 86, alignment: .leading)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.7))
                    .frame(width: max(geo.size.width * CGFloat(entry.count) / CGFloat(max(top, 1)), 6), height: 8)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 20)
            Text("\(entry.count)回")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private func load() async {
        do {
            let runs: [Run] = try await SupabaseClientManager.shared.client
                .from("spot_event_runs")
                .select("recorded_at, extractor_version, counts")
                .eq("device_id", value: deviceId)
                .eq("local_date", value: localDate)
                .execute()
                .value
            var newest: [String: Run] = [:]
            for run in runs where (newest[run.recorded_at]?.extractor_version ?? "") < run.extractor_version {
                newest[run.recorded_at] = run
            }
            var totals: [String: Int] = [:]
            for run in newest.values {
                for (type, count) in run.counts ?? [:] where count > 0 {
                    totals[type, default: 0] += count
                }
            }
            recordings = newest.count
            entries = totals.map { Entry(type: $0.key, count: $0.value) }
                .sorted { $0.count != $1.count ? $0.count > $1.count : $0.type < $1.type }
        } catch {
            guard !Task.isCancelled else { return }
            print("❌ [Ranking] could not load \(localDate): \(error)")
        }
    }
}
