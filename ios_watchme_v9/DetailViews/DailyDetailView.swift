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

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: SupabaseDataManager

    @State private var dailySummary: DashboardSummary?
    @State private var spotResults: [SpotResult] = []
    @State private var isLoading = true
    @State private var showSpotDetail = false
    @State private var selectedSpot: SpotResult?

    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding()
                } else if let summary = dailySummary {
                    VStack(spacing: 24) {
                        // Date header
                        dateHeader

                        // Vibe Score
                        if let vibeScore = summary.averageVibe {
                            vibeScoreCard(Double(vibeScore))
                        }

                        // Summary
                        if let insights = summary.insights {
                            summaryCard(insights)
                        }

                        // Vibe Scores Time Series
                        if let vibeScores = summary.vibeScores, !vibeScores.isEmpty {
                            vibeScoresChart(vibeScores)
                        }

                        // Burst Events
                        if let burstEvents = summary.burstEvents, !burstEvents.isEmpty {
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
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)

                        Text("Data not found")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    .padding()
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Daily Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedSpot) { spot in
            SpotDetailView(deviceId: deviceId, recordedAt: spot.recordedAt)
                .environmentObject(dataManager)
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true

        // Fetch daily summary
        let startDate = dateFromString(localDate) ?? Date()
        let dailyResults = await dataManager.fetchDailyResultsRange(
            deviceId: deviceId,
            startDate: startDate,
            endDate: startDate
        )
        dailySummary = dailyResults.first

        // Fetch spot results for the day
        spotResults = await dataManager.fetchSpotsForDay(deviceId: deviceId, localDate: localDate)

        isLoading = false
    }

    // MARK: - View Components

    private var dateHeader: some View {
        Text(formatDateHeader(localDate))
            .font(.title2)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func vibeScoreCard(_ score: Double) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.accentPurple)
                Text("Daily Average Vibe Score")
                    .font(.headline)
                Spacer()
            }

            Text(String(format: "%.1f", score))
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(vibeScoreColor(score))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    private func summaryCard(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.accentPurple)
                Text("Daily Summary")
                    .font(.headline)
                Spacer()
            }

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
                Text("Burst Events")
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
                Text("Spot Results (\(spotResults.count))")
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

    private func spotResultRow(_ spot: SpotResult) -> some View {
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
                    .foregroundColor(vibeScoreColor(vibeScore))
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
        formatter.dateFormat = "HH:mm:ss"
        guard let time = formatter.date(from: timeString) else {
            return timeString
        }

        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }

    private func dateFromString(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
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
}
