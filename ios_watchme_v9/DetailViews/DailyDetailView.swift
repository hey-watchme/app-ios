//
//  DailyDetailView.swift
//  ios_watchme_v9
//
//  Daily analysis detail page
//

import SwiftUI
import Charts

struct DailyDetailView: View {
    let deviceId: String
    let localDate: String
    let dailySummary: DashboardSummary
    let spotResults: [DashboardTimeBlock]

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: SupabaseDataManager

    @State private var selectedSpot: DashboardTimeBlock?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Vibe Score
                    if let vibeScore = dailySummary.averageVibe {
                        vibeScoreCard(Double(vibeScore))
                    }

                    // Summary
                    if let insights = dailySummary.insights {
                        summaryCard(insights)
                    }

                    // Vibe Scores Time Series
                    if let vibeScores = dailySummary.vibeScores, !vibeScores.isEmpty {
                        vibeScoresChart(vibeScores)
                    }

                    // Burst Events
                    if let burstEvents = dailySummary.burstEvents, !burstEvents.isEmpty {
                        burstEventsSection(burstEvents)
                    }

                    // Spot Results
                    if !spotResults.isEmpty {
                        spotResultsSection
                    }

                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color(.systemBackground))
            .navigationTitle(formatDateHeader(localDate))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedSpot) { spot in
            SpotDetailView(deviceId: deviceId, spotData: spot)
                .environmentObject(dataManager)
        }
    }

    // MARK: - View Components

    private func vibeScoreCard(_ score: Double) -> some View {
        VStack(spacing: 8) {
            // Emoji (same as ModernVibeCard)
            Text(emotionEmoji(for: score))
                .font(.system(size: 108))

            // Score
            Text(String(format: "%.0f pt", score))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(scoreColor(for: score).opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 24)
    }

    // Emoji logic (same as ModernVibeCard)
    private func emotionEmoji(for score: Double) -> String {
        if score > 50 {
            return "👏"
        } else if score > 30 {
            return "✌️"
        } else if score > 0 {
            return "👍"
        } else if score > -30 {
            return "👌"
        } else if score > -50 {
            return "💪"
        } else {
            return "💔"
        }
    }

    // Score color logic (same as ModernVibeCard)
    private func scoreColor(for score: Double) -> Color {
        if score > 30 {
            return .green
        } else if score < -30 {
            return .red
        } else {
            return .gray
        }
    }

    private func summaryCard(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summary)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    private func vibeScoresChart(_ scores: [VibeScoreDataPoint]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.accentPurple)
                Text("Vibe Score Timeline")
                    .font(.headline)
                Spacer()
            }

            Chart {
                ForEach(scores.indices, id: \.self) { index in
                    LineMark(
                        x: .value("Time", scores[index].time),
                        y: .value("Score", scores[index].score)
                    )
                    .foregroundStyle(.purple)
                    .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 200)
            .chartYScale(domain: -50...50)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                    AxisValueLabel(format: .dateTime.hour())
                    AxisGridLine()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    private func burstEventsSection(_ events: [BurstEvent]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.accentPurple)
                Text("ハイライト")
                    .font(.headline)
                Spacer()
            }

            ForEach(events.indices, id: \.self) { index in
                burstEventRow(events[index])
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    private func burstEventRow(_ event: BurstEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(event.time)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.event)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text(String(format: "Change: %+.1f", event.scoreChange))
                    .font(.caption)
                    .foregroundColor(event.scoreChange >= 0 ? .green : .red)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var spotResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.accentPurple)
                Text("時間別分析結果 (\(spotResults.count))")
                    .font(.headline)
                Spacer()
            }

            ForEach(spotResults) { spot in
                spotResultRow(spot)
                    .onTapGesture {
                        selectedSpot = spot
                    }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    private func spotResultRow(_ spot: DashboardTimeBlock) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let localTime = spot.localTime {
                    Text(formatTime(localTime))
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                if let summary = spot.summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if let vibeScore = spot.vibeScore {
                Text(String(format: "%.1f", vibeScore))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(scoreColor(for: vibeScore))
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
        )
    }

    // MARK: - Helpers

    private func formatDateHeader(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        formatter.dateFormat = "yyyy年M月d日 (E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func formatTime(_ timeString: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // ISO8601 format with milliseconds: "2025-11-27T07:31:01.352"
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"

        if let time = formatter.date(from: timeString) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: time)
        }

        // Fallback: try without milliseconds
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let time = formatter.date(from: timeString) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: time)
        }

        return timeString
    }

    private func dateFromString(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }

}
