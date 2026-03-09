//
//  SpotDetailView.swift
//  ios_watchme_v9
//
//  Spot analysis detail page
//

import SwiftUI

struct SpotDetailView: View {
    let deviceId: String
    let spotData: DashboardTimeBlock

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: SupabaseDataManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Vibe Score
                    if let vibeScore = spotData.vibeScore {
                        vibeScoreCard(vibeScore)
                    }

                    // Scene Mapping
                    if let sm = spotData.sceneMapping {
                        sceneMappingCard(sm)
                    }

                    // Summary
                    if let summary = spotData.summary {
                        contentCard(title: "概要", content: summary, icon: "text.alignleft")
                    }

                    // Analysis
                    if let analysis = spotData.analysis, !analysis.isEmpty {
                        contentCard(title: "分析", content: analysis, icon: "brain.head.profile")
                    }

                    // Behavior
                    if let behavior = spotData.behavior {
                        contentCard(title: "行動", content: behavior, icon: "figure.walk")
                    }

                    // Emotion
                    if let emotion = spotData.emotion, !emotion.isEmpty {
                        contentCard(title: "感情", content: emotion, icon: "face.smiling")
                    }

                    // Raw analysis results (collapsible, for debug/advanced users)
                    rawAnalysisSection

                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color(.systemBackground))
            .navigationTitle(formatNavigationTitle())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - View Components

    private func vibeScoreCard(_ score: Double) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.accentPurple)
                Text("気分")
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

    private func sceneMappingCard(_ sm: SceneMapping) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map")
                    .foregroundColor(.accentPurple)
                Text("シーン")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                if let participants = sm.participants, !participants.isEmpty {
                    sceneMappingRow(label: "参加者", value: participants)
                }
                if let activity = sm.core_activity, !activity.isEmpty {
                    sceneMappingRow(label: "活動", value: activity)
                }
                if let detail = sm.behavior_detail, !detail.isEmpty {
                    sceneMappingRow(label: "やり取り", value: detail)
                }
                if let atmosphere = sm.atmosphere, !atmosphere.isEmpty {
                    sceneMappingRow(label: "雰囲気", value: atmosphere)
                }
                if let uncertainty = sm.uncertainty, !uncertainty.isEmpty {
                    sceneMappingRow(label: "不確実性", value: uncertainty)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    private func sceneMappingRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Raw Analysis Section (ASR, SED, SER)

    private var rawAnalysisSection: some View {
        Group {
            if hasAnyRawData {
                VStack(alignment: .leading, spacing: 12) {
                    Text("DATA")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    // 1. STT
                    if let transcription = spotData.vibeTranscriberResult {
                        rawDataDisclosure(
                            title: "STT",
                            content: transcription
                        )
                    }

                    // 2. SED
                    if !spotData.behaviorTimePoints.isEmpty {
                        rawDataDisclosure(
                            title: "SED",
                            content: behaviorExtractorJSONString
                        )
                    }

                    // 3. SER
                    if let humeRaw = spotData.emotionFeaturesResultHumeRaw, !humeRaw.isEmpty {
                        rawDataDisclosure(
                            title: "SER",
                            content: humeRaw
                        )
                    }
                }
            }
        }
    }

    private var hasAnyRawData: Bool {
        spotData.vibeTranscriberResult != nil
            || !spotData.behaviorTimePoints.isEmpty
            || (spotData.emotionFeaturesResultHumeRaw.map { !$0.isEmpty } ?? false)
    }

    private var behaviorExtractorJSONString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(spotData.behaviorTimePoints),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }

    private func rawDataDisclosure(title: String, content: String) -> some View {
        DisclosureGroup {
            Text(content)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .textSelection(.enabled)
        } label: {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Helpers

    private func formatNavigationTitle() -> String {
        guard let localDate = spotData.date, let localTime = spotData.localTime else {
            return "スポット分析"
        }

        let dateString = formatDateShort(localDate)
        let timeString = formatTime(localTime)
        return "\(dateString) \(timeString)"
    }

    private func formatDateShort(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        formatter.dateFormat = "M/d (E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

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
