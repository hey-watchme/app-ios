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
