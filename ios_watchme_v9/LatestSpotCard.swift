//
//  LatestSpotCard.swift
//  ios_watchme_v9
//
//  The newest recording, pinned under the hero. It appears as soon as a recording is
//  uploaded and fills in as each analysis stage finishes: first the transcript, then the
//  surrounding sounds, the scene, and finally the analysis. Self-contained: no section title.
//

import SwiftUI

struct LatestSpotCard: View {
    let timeBlock: DashboardTimeBlock
    var onTapDetail: (() -> Void)? = nil

    private let maxTurns = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 14) {
                progress
                transcriptSection
                soundsSection
                sceneSection
                summarySection
                analysisSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTapDetail?()
        }
        .animation(.easeInOut(duration: 0.3), value: timeBlock)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Text("LATEST")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.accentTeal)
                .tracking(0.8)

            Text(timeBlock.displayTime)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.6))

            if let score = timeBlock.vibeScore {
                Text(String(format: "%@%.0f", score >= 0 ? "+" : "", score))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(timeBlock.scoreColor)
            }

            Spacer()

            if timeBlock.stages.isInProgress {
                Text("分析中")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.accentTeal)
            }

            if onTapDetail != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(white: 0.25))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Progress

    @ViewBuilder
    private var progress: some View {
        if timeBlock.stages.isInProgress {
            StageProgressRow(stages: timeBlock.stages, compact: true)
        } else if timeBlock.summary == nil {
            if timeBlock.stages.isEmpty {
                Text("分析の結果がありません")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(white: 0.6))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("分析できませんでした")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.accentCoral)
                    StageProgressRow(stages: timeBlock.stages, compact: true)
                }
            }
        }
    }

    // MARK: - Sections (each appears once its stage has a result)

    @ViewBuilder
    private var transcriptSection: some View {
        let turns = timeBlock.conversationTurns
        if !turns.isEmpty {
            let roles = timeBlock.speakerRoles
            section("文字起こし") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(turns.prefix(maxTurns)) { turn in
                        HStack(alignment: .top, spacing: 8) {
                            if let speaker = turn.speaker {
                                Text(roles[speaker] ?? speaker)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(white: 0.45))
                                    .lineLimit(1)
                                    .frame(maxWidth: 72, alignment: .leading)
                                    .padding(.top, 1)
                            }
                            Text(turn.text)
                                .font(.system(size: 13))
                                .foregroundColor(Color(white: 0.85))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if turns.count > maxTurns {
                        Text("ほか \(turns.count - maxTurns) 件の発話")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.45))
                    }
                }
            }
        } else if let text = transcriptFallback {
            section("文字起こし") {
                bodyText(text, color: Color(white: 0.85))
                    .lineLimit(3)
            }
        }
    }

    /// Before Persist only the transcribe stage's preview exists; old rows may hold plain text.
    private var transcriptFallback: String? {
        if let raw = timeBlock.vibeTranscriberResult, timeBlock.transcriptObject == nil, !raw.isEmpty {
            return raw
        }
        return timeBlock.stagePayload("transcribe", "preview")?
            .replacingOccurrences(of: "SPEAKER ", with: "")
            .replacingOccurrences(of: "\n", with: " ")
    }

    @ViewBuilder
    private var soundsSection: some View {
        let sounds = timeBlock.topBehaviors.prefix(4).map(\.label)
        if !sounds.isEmpty {
            section("周りの音") {
                bodyText(sounds.joined(separator: " / "), color: Color(white: 0.78))
            }
        }
    }

    @ViewBuilder
    private var sceneSection: some View {
        if let scene = timeBlock.sceneSummary ?? timeBlock.stagePayload("scene", "summary") {
            section("場面") {
                bodyText(scene, color: Color(white: 0.78))
            }
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        if let summary = timeBlock.summary ?? timeBlock.stagePayload("profile", "summary") {
            section("サマリー") {
                VStack(alignment: .leading, spacing: 8) {
                    bodyText(summary, color: .white)
                    tags
                }
            }
        }
    }

    @ViewBuilder
    private var tags: some View {
        let behavior = timeBlock.behavior.flatMap { $0.isEmpty ? nil : $0 }
        let emotion = timeBlock.emotion.flatMap { $0.isEmpty ? nil : $0 }
        if behavior != nil || emotion != nil {
            HStack(spacing: 6) {
                if let behavior {
                    tagPill(behavior, color: .accentTeal)
                }
                if let emotion {
                    tagPill(emotion, color: .accentTealMuted)
                }
            }
        }
    }

    @ViewBuilder
    private var analysisSection: some View {
        if let analysis = timeBlock.analysis, !analysis.isEmpty {
            section("分析") {
                bodyText(analysis, color: Color(white: 0.6))
            }
        }
    }

    // MARK: - Building blocks

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(white: 0.45))
                .tracking(0.8)
            content()
        }
        .transition(.opacity)
    }

    private func bodyText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(color)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func tagPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .cornerRadius(6)
    }
}
