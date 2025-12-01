//
//  SpotDetailView.swift
//  ios_watchme_v9
//
//  Spot analysis detail page
//

import SwiftUI

struct SpotDetailView: View {
    let deviceId: String
    let recordedAt: String

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: SupabaseDataManager

    @State private var spotResult: SpotResult?
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding()
                } else if let result = spotResult {
                    VStack(spacing: 24) {
                        // Time header
                        timeHeader(result)

                        // Vibe Score
                        if let vibeScore = result.vibeScore {
                            vibeScoreCard(vibeScore)
                        }

                        // Summary
                        if let summary = result.summary {
                            contentCard(title: "Summary", content: summary, icon: "text.alignleft")
                        }

                        // Behavior
                        if let behavior = result.behavior {
                            contentCard(title: "Behavior", content: behavior, icon: "figure.walk")
                        }

                        // Transcription
                        if let transcription = result.transcription {
                            contentCard(title: "Transcription", content: transcription, icon: "waveform")
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
            .navigationTitle("Spot Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        spotResult = await dataManager.fetchSpotDetail(deviceId: deviceId, recordedAt: recordedAt)
        isLoading = false
    }

    // MARK: - View Components

    private func timeHeader(_ result: SpotResult) -> some View {
        VStack(spacing: 8) {
            if let localDate = result.localDate, let localTime = result.localTime {
                Text(formatDate(localDate))
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text(formatTime(localTime))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    private func vibeScoreCard(_ score: Double) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.accentPurple)
                Text("Vibe Score")
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

    private func contentCard(title: String, content: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentPurple)
                Text(title)
                    .font(.headline)
                Spacer()
            }

            Text(content)
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

    // MARK: - Helpers

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        formatter.dateFormat = "yyyy/M/d (E)"
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
