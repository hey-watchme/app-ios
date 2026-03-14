//
//  SpotDetailView.swift
//  ios_watchme_v9
//
//  Spot analysis detail page - Dark theme
//

import SwiftUI

struct SpotDetailView: View {
    let deviceId: String
    let spotData: DashboardTimeBlock

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: SupabaseDataManager
    @State private var rawSectionsLoadedFull: Set<String> = []

    private let rawPreviewCharacterLimit = 4_000
    private let rawLargeContentThreshold = 12_000

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
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
                        contentCard(title: "Summary", content: summary, icon: "text.alignleft")
                    }

                    // Analysis
                    if let analysis = spotData.analysis, !analysis.isEmpty {
                        contentCard(title: "Analysis", content: analysis, icon: "brain.head.profile")
                    }

                    // Behavior
                    if let behavior = spotData.behavior {
                        contentCard(title: "Behavior", content: behavior, icon: "figure.walk")
                    }

                    // Emotion
                    if let emotion = spotData.emotion, !emotion.isEmpty {
                        contentCard(title: "Emotion", content: emotion, icon: "face.smiling")
                    }

                    // Raw data
                    rawAnalysisSection

                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color.darkBase)
            .navigationTitle(formatNavigationTitle())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.accentTeal)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - View Components

    private func vibeScoreCard(_ score: Double) -> some View {
        HStack(spacing: 20) {
            // Ring gauge
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 4)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: min(max((score + 100) / 200, 0), 1))
                    .stroke(vibeScoreColor(score), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 72, height: 72)

                Text(String(format: "%.0f", score))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("VIBE SCORE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(white: 0.45))
                    .tracking(1.0)

                Text(vibeStatusLabel(score))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(vibeScoreColor(score))

                // Score bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(vibeScoreColor(score))
                            .frame(width: geo.size.width * min(max((score + 100) / 200, 0), 1), height: 6)
                    }
                }
                .frame(height: 6)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func contentCard(title: String, content: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.accentTeal)
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(white: 0.45))
                    .tracking(0.8)
                Spacer()
            }

            Text(content)
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.78))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func sceneMappingCard(_ sm: SceneMapping) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "map")
                    .font(.system(size: 14))
                    .foregroundColor(.accentTeal)
                Text("SCENE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(white: 0.45))
                    .tracking(0.8)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                if let participants = sm.participants, !participants.isEmpty {
                    sceneMappingRow(label: "Participants", value: participants)
                }
                if let activity = sm.core_activity, !activity.isEmpty {
                    sceneMappingRow(label: "Activity", value: activity)
                }
                if let detail = sm.behavior_detail, !detail.isEmpty {
                    sceneMappingRow(label: "Interaction", value: detail)
                }
                if let atmosphere = sm.atmosphere, !atmosphere.isEmpty {
                    sceneMappingRow(label: "Atmosphere", value: atmosphere)
                }
                if let uncertainty = sm.uncertainty, !uncertainty.isEmpty {
                    sceneMappingRow(label: "Uncertainty", value: uncertainty)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func sceneMappingRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(white: 0.45))
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Raw Analysis Section

    private var rawAnalysisSection: some View {
        Group {
            if hasAnyRawData {
                VStack(alignment: .leading, spacing: 12) {
                    Text("DATA")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(white: 0.36))
                        .tracking(1.0)

                    if let transcription = spotData.vibeTranscriberResult {
                        rawDataDisclosure(id: "stt", title: "STT", content: transcription)
                    }

                    if !spotData.behaviorTimePoints.isEmpty {
                        rawDataDisclosure(id: "sed", title: "SED", content: behaviorExtractorJSONString)
                    }

                    if let humeRaw = spotData.emotionFeaturesResultHumeRaw, !humeRaw.isEmpty {
                        rawDataDisclosure(id: "ser", title: "SER", content: humeRaw)
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

    private func rawDataDisclosure(id: String, title: String, content: String) -> some View {
        let byteCount = content.lengthOfBytes(using: .utf8)
        let isLargeContent = byteCount >= rawLargeContentThreshold
        let isFullLoaded = rawSectionsLoadedFull.contains(id)
        let shouldShowFullContent = !isLargeContent || isFullLoaded
        let previewText: String = {
            let preview = String(content.prefix(rawPreviewCharacterLimit))
            if content.count > rawPreviewCharacterLimit {
                return preview + "\n\n… truncated (preview only)"
            }
            return preview
        }()

        return DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                if isLargeContent, !isFullLoaded {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Large raw data", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentTealMuted)

                        Text("Size: \(formattedByteCount(byteCount)). \(expectedLoadHint(for: byteCount))")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.62))

                        Button("全文を読み込む（重くなる可能性あり）") {
                            rawSectionsLoadedFull.insert(id)
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.accentTealMuted.opacity(0.35))
                        )
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                }

                ScrollView(.horizontal, showsIndicators: true) {
                    if shouldShowFullContent {
                        Text(content)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color(white: 0.45))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    } else {
                        Text(previewText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color(white: 0.45))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.disabled)
                    }
                }
                .padding(.vertical, 8)

                if isLargeContent, isFullLoaded {
                    Button("プレビュー表示に戻す") {
                        rawSectionsLoadedFull.remove(id)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(white: 0.62))
                }
            }
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Text(formattedByteCount(byteCount))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(white: 0.45))
            }
        }
        .tint(Color(white: 0.36))
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func formattedByteCount(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func expectedLoadHint(for bytes: Int) -> String {
        if bytes >= 180_000 {
            return "端末によっては展開に数十秒〜2分かかる場合があります。"
        }
        if bytes >= 80_000 {
            return "端末によっては展開に数秒〜30秒かかる場合があります。"
        }
        return "重い場合はプレビュー表示で確認してください。"
    }

    // MARK: - Helpers

    private func formatNavigationTitle() -> String {
        guard let localDate = spotData.date, let localTime = spotData.localTime else {
            return "Spot Analysis"
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

        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"

        if let time = formatter.date(from: timeString) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: time)
        }

        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let time = formatter.date(from: timeString) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: time)
        }

        return timeString
    }

    private func vibeScoreColor(_ score: Double) -> Color {
        Color.vibeScoreColor(for: score)
    }

    private func vibeStatusLabel(_ score: Double) -> String {
        if score >= 30 { return "Positive" }
        else if score >= 0 { return "Good" }
        else if score >= -30 { return "Neutral" }
        else { return "Low" }
    }
}
