//
//  ActivityFeed.swift
//  ios_watchme_v9
//
//  The activity area at the top of the dashboard: one small card per analysis event
//  (a recording arriving, each stage running or finishing), so the user can see results
//  arriving one by one. Built from spot_stages, which the dashboard already receives in real time.
//

import SwiftUI

struct ActivityItem: Identifiable, Equatable {
    let id: String
    let recordingID: String  // DashboardTimeBlock.id
    let title: String
    let status: String       // running, completed, failed, skipped
    let detail: String
    let date: Date?
}

enum ActivityFeed {
    /// Events of the given recordings, running ones first, then newest first.
    /// Queued stages are left out: only what is moving or has finished is shown.
    static func items(from blocks: [DashboardTimeBlock], viewingDate: String? = nil) -> [ActivityItem] {
        blocks.flatMap { items(for: $0, viewingDate: viewingDate) }.sorted { a, b in
            let aRunning = a.status == "running", bRunning = b.status == "running"
            if aRunning != bRunning { return aRunning }
            return (a.date ?? .distantPast) > (b.date ?? .distantPast)
        }
    }

    /// Events of one recording: the recording itself, then each stage that has started.
    static func items(for block: DashboardTimeBlock, viewingDate: String? = nil) -> [ActivityItem] {
        let stages = block.stages.map(\.effective)
        let name = recordingName(block, viewingDate: viewingDate)
        let recordingStatus: String
        let recordingDetail: String
        if block.stages.isInProgress {
            recordingStatus = "running"
            recordingDetail = "\(name)を分析中"
        } else if stages.contains(where: { $0.status == "failed" }) {
            recordingStatus = "failed"
            recordingDetail = "\(name)・一部できませんでした"
        } else {
            recordingStatus = "completed"
            recordingDetail = "\(name)・分析済み"
        }

        var items = [ActivityItem(
            id: "\(block.id)_recording",
            recordingID: block.id,
            title: "録音を受信",
            status: recordingStatus,
            detail: recordingDetail,
            date: SpotStage.parse(block.createdAt)
        )]
        for stage in stages where stage.status != "queued" {
            items.append(ActivityItem(
                id: "\(block.id)_\(stage.stage)",
                recordingID: block.id,
                title: stage.label,
                status: stage.status,
                detail: detail(for: stage),
                date: SpotStage.parse(stage.updatedAt)
            ))
        }
        return items
    }

    /// "15:02 の録音", or "11/6 15:02 の録音" when it was recorded on a day other than the one being viewed.
    static func recordingName(_ block: DashboardTimeBlock, viewingDate: String?) -> String {
        guard let viewingDate, let date = block.date, date != viewingDate else {
            return "\(block.displayTime) の録音"
        }
        let parts = date.split(separator: "-")
        let monthDay = parts.count == 3 ? "\(Int(parts[1]) ?? 0)/\(Int(parts[2]) ?? 0)" : date
        return "\(monthDay) \(block.displayTime) の録音"
    }

    private static func detail(for stage: SpotStage) -> String {
        switch stage.status {
        case "running": return "処理中"
        case "failed": return stage.error ?? "できませんでした"
        case "skipped": return "対象なし"
        default: break
        }
        guard case .object(let payload)? = stage.payload else { return "完了" }
        switch stage.stage {
        case "transcribe":
            if let speakers = number(payload["speaker_count"]), let words = number(payload["word_count"]) {
                return "\(Int(speakers))人の声・\(Int(words))語"
            }
        case "scene":
            if case .string(let summary)? = payload["summary"], !summary.isEmpty { return summary }
        case "profile":
            if let score = number(payload["vibe_score"]) {
                return String(format: "スコア %@%.0f", score >= 0 ? "+" : "", score)
            }
        case "day_so_far":
            if let count = number(payload["processed_count"]) { return "\(Int(count))件の録音から更新" }
        case "measure", "emotion":
            if case .bool(false)? = payload["available"] { return "測定できる声がありません" }
        default:
            break
        }
        return "完了"
    }

    private static func number(_ value: JSONValue?) -> Double? {
        switch value {
        case .int(let v)?: return Double(v)
        case .double(let v)?: return v
        default: return nil
        }
    }

    static func timeText(_ date: Date?, timezone: TimeZone) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Status icon (shared by the strip and the log)

struct ActivityStatusIcon: View {
    let status: String

    var body: some View {
        switch status {
        case "running":
            ProgressView().scaleEffect(0.6).frame(width: 14, height: 14).tint(.accentTeal)
        case "completed":
            Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundColor(.accentTealMuted)
        case "failed":
            Image(systemName: "xmark.circle.fill").font(.system(size: 13)).foregroundColor(.accentCoral)
        default:
            Image(systemName: "minus.circle").font(.system(size: 13)).foregroundColor(Color(white: 0.45))
        }
    }
}

// MARK: - Strip (top of the dashboard)

struct ActivityStripView: View {
    let items: [ActivityItem]
    let timezone: TimeZone
    var limit: Int = 10
    let onTapItem: (ActivityItem) -> Void
    let onShowLog: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items.prefix(limit)) { item in
                    card(item)
                        .onTapGesture { onTapItem(item) }
                        .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
                }
                logButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: items)
        }
    }

    private func card(_ item: ActivityItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ActivityStatusIcon(status: item.status)
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            Text(item.detail)
                .font(.system(size: 11))
                .foregroundColor(item.status == "failed" ? .accentCoral : Color(white: 0.6))
                .lineLimit(2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Text(ActivityFeed.timeText(item.date, timezone: timezone))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(white: 0.4))
        }
        .padding(12)
        .frame(width: 148, height: 96, alignment: .topLeading)
        .background(cardBackground(highlighted: item.status == "running"))
        .contentShape(Rectangle())
    }

    private var logButton: some View {
        Button(action: onShowLog) {
            VStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 16))
                Text("アクティビティログ")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.accentTeal)
            .frame(width: 112, height: 96)
            .background(cardBackground(highlighted: false))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func cardBackground(highlighted: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.darkCard)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(highlighted ? Color.accentTeal.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Log (every event of the day, grouped by recording)

struct ActivityLogView: View {
    let blocks: [DashboardTimeBlock]
    let timezone: TimeZone
    var viewingDate: String? = nil
    let onTapRecording: (DashboardTimeBlock) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if blocks.isEmpty {
                    Text("この日のアクティビティはありません")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                }
                ForEach(blocks.reversed()) { block in
                    recordingSection(block)
                }
            }
            .padding(20)
        }
        .background(Color.darkBase.ignoresSafeArea())
    }

    private func recordingSection(_ block: DashboardTimeBlock) -> some View {
        // Recording first, then the stages in the order they finished
        let events = ActivityFeed.items(for: block, viewingDate: viewingDate)
        let rows = [events[0]] + events.dropFirst().sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(ActivityFeed.recordingName(block, viewingDate: viewingDate))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(white: 0.3))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture { onTapRecording(block) }

            ForEach(rows) { item in
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                HStack(alignment: .top, spacing: 10) {
                    ActivityStatusIcon(status: item.status)
                        .frame(width: 16)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(white: 0.85))
                        Text(item.detail)
                            .font(.system(size: 12))
                            .foregroundColor(item.status == "failed" ? .accentCoral : Color(white: 0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Text(ActivityFeed.timeText(item.date, timezone: timezone))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.4))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkCard)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
    }
}
