//
//  QuestionMode.swift
//  ios_watchme_v9
//
//  Questions the analysis could not settle, answered with one tap (platform docs/product/questions.md).
//  An entry (a banner on a recording, a section on the dashboard, a banner on the profile) shows how
//  many are open; tapping it opens the question mode: はい / いいえ by swiping, choices by tapping,
//  わからない and 後で always there (後で sends nothing, so the question comes back next time).
//  Answering is optional; nothing breaks when nobody answers.
//

import AVFoundation
import SwiftUI

// MARK: - Entry

struct QuestionsEntry: View {
    enum Place {
        case recording, dashboard, profile(name: String?)
    }

    let subjectId: String?
    var recordedAt: String? = nil
    var scope: String? = nil
    let place: Place

    @EnvironmentObject private var subjectManager: SubjectManager
    @State private var questions: [FamilyQuestion] = []
    @State private var showMode = false

    var body: some View {
        // The zero-height view keeps the entry on screen while nothing is open, so .task runs
        // (a modifier on an empty Group never appears).
        ZStack {
            Color.clear.frame(height: 0)
            if !questions.isEmpty {
                Button {
                    HapticManager.shared.playSelectionHaptic()
                    showMode = true
                } label: {
                    banner
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .task(id: "\(subjectId ?? "")|\(recordedAt ?? "")|\(scope ?? "")") { await load() }
        .fullScreenCover(isPresented: $showMode, onDismiss: { Task { await load() } }) {
            QuestionModeView(questions: questions, showsDate: showsDate)
        }
    }

    /// The dashboard gathers the open questions of every day, so each card names its date.
    private var showsDate: Bool {
        if case .dashboard = place { return true }
        return false
    }

    private var title: String {
        switch place {
        case .recording: return "分からなかったところが \(questions.count) 件あります"
        case .dashboard: return "分析の確認が \(questions.count) 件あります"
        case .profile(let name): return "\(name.map { "\($0)さん" } ?? "分析対象")についての質問が \(questions.count) 件"
        }
    }

    private var subtitle: String {
        switch place {
        case .recording: return "答えると、この録音の分析が正確になります"
        case .dashboard: return "はい・いいえで答えるだけ。答えなくても構いません"
        case .profile: return "答えた内容はプロフィールに残り、次の分析から使われます"
        }
    }

    private var banner: some View {
        HStack(spacing: 12) {
            Text("\(questions.count)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.darkBase)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.accentTeal))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.56))
            }
            Spacer(minLength: 8)
            Text("答える")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.accentTeal)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.accentTeal)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentTeal.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentTeal.opacity(0.35), lineWidth: 1))
        )
    }

    private func load() async {
        // Only owners answer; a view-only member is not asked.
        let isViewer = subjectManager.subjects.first(where: { $0.subjectId.lowercased() == subjectId?.lowercased() })?.isViewer ?? false
        guard let subjectId, !isViewer else { questions = []; return }
        let found = await QuestionService.open(subjectId: subjectId, recordedAt: recordedAt, scope: scope)
        withAnimation(.easeInOut(duration: 0.25)) { questions = found }
    }
}

// MARK: - Question mode

struct QuestionModeView: View {
    let questions: [FamilyQuestion]
    var showsDate = false

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var answers: [String: String] = [:]
    /// Put off with 後で: not sent, so they stay open and come back next time.
    @State private var later: Set<String> = []
    @State private var drag: CGSize = .zero
    @State private var sending = false
    @State private var sendError: String?
    @StateObject private var player = QuestionSnippetPlayer()

    private var done: Bool { index >= questions.count }
    private var current: FamilyQuestion? { done ? nil : questions[index] }

    var body: some View {
        VStack(spacing: 20) {
            header
            if let question = current {
                Spacer(minLength: 0)
                card(question)
                    .id(question.id)
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                Spacer(minLength: 0)
                actions(question)
            } else {
                summary
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.darkBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onDisappear { player.stop() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.darkElevated)
                    Capsule().fill(Color.accentTeal)
                        .frame(width: proxy.size.width * CGFloat(min(index, questions.count)) / CGFloat(max(questions.count, 1)))
                }
            }
            .frame(height: 6)
            if !done {
                Text("\(index + 1) / \(questions.count)")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundColor(Color(white: 0.56))
            }
            CloseButton { Task { await finish() } }
        }
    }

    // MARK: Card

    private func card(_ question: FamilyQuestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Text(question.scopeName(withDate: showsDate))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.accentTeal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .overlay(Capsule().stroke(Color.accentTeal.opacity(0.5), lineWidth: 1))
                Text(question.topicName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(white: 0.45))
                    .tracking(0.6)
            }

            if let quote = question.context?.quote, !quote.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("「\(quote)」")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    HStack {
                        Text([question.clock, question.context?.who].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ・ "))
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundColor(Color(white: 0.56))
                        Spacer()
                        if let key = question.context?.audio_key, let start = question.context?.start_sec {
                            Button {
                                Task { await player.toggle(audioKey: key, at: start) }
                            } label: {
                                Label(player.isPlaying ? "止める" : "前後を聞く",
                                      systemImage: player.isPlaying ? "stop.fill" : "play.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                            }
                            .disabled(player.isLoading)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.darkElevated))
            }

            Text(question.prompt)
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            if question.isYesNo {
                Text("右へ はい ・ 左へ いいえ")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.45))
            } else {
                VStack(spacing: 8) {
                    ForEach(question.options, id: \.key) { option in
                        Button {
                            answer(option.key)
                        } label: {
                            Text(option.label)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.darkElevated)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.darkCard)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
        .overlay(alignment: .topTrailing) { stamp("はい", color: .accentTeal, visible: drag.width > 30) }
        .overlay(alignment: .topLeading) { stamp("いいえ", color: .accentCoral, visible: drag.width < -30) }
        .offset(x: drag.width, y: drag.height * 0.2)
        .rotationEffect(.degrees(Double(drag.width) / 25))
        .gesture(swipe, including: question.isYesNo ? .all : .subviews)
    }

    private func stamp(_ text: String, color: Color, visible: Bool) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .heavy))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 3))
            .rotationEffect(.degrees(visible && color == .accentTeal ? 8 : -8))
            .padding(16)
            .opacity(visible ? min(1, abs(Double(drag.width)) / 90) : 0)
    }

    private var swipe: some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                if value.translation.width > 100 {
                    fling(yes: true)
                } else if value.translation.width < -100 {
                    fling(yes: false)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { drag = .zero }
                }
            }
    }

    private func fling(yes: Bool) {
        withAnimation(.easeIn(duration: 0.18)) { drag = CGSize(width: yes ? 600 : -600, height: 0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            answer(yes ? "yes" : "no")
        }
    }

    // MARK: Actions

    private func actions(_ question: FamilyQuestion) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if question.isYesNo {
                    actionButton("いいえ", fill: .accentCoral, text: .darkBase) { fling(yes: false) }
                }
                actionButton("わからない", fill: .darkElevated, text: .white) { answer("unsure") }
                if question.isYesNo {
                    actionButton("はい", fill: .accentTeal, text: .darkBase) { fling(yes: true) }
                }
            }
            HStack {
                // A wrong tap is easy to make; nothing is sent until the end, so going back is free
                if index > 0 {
                    Button { back() } label: {
                        Label("戻る", systemImage: "chevron.left")
                    }
                }
                Spacer()
                Button("後で") { putOff() }
            }
            .font(.system(size: 14))
            .foregroundColor(Color(white: 0.56))
            .padding(6)
        }
    }

    private func actionButton(_ title: String, fill: Color, text: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14).fill(fill))
        }
        .buttonStyle(.plain)
    }

    private func answer(_ key: String) {
        guard let question = current else { return }
        player.stop()
        HapticManager.shared.playLightImpact()
        answers[question.question_id] = key
        drag = .zero
        withAnimation(.easeInOut(duration: 0.2)) { index += 1 }
    }

    /// Leave this question for another time: nothing is sent for it.
    private func putOff() {
        guard let question = current else { return }
        player.stop()
        HapticManager.shared.playLightImpact()
        later.insert(question.question_id)
        drag = .zero
        withAnimation(.easeInOut(duration: 0.2)) { index += 1 }
    }

    /// The question before this one again, with its answer cleared.
    private func back() {
        guard index > 0 else { return }
        player.stop()
        drag = .zero
        sendError = nil
        withAnimation(.easeInOut(duration: 0.2)) { index -= 1 }
        answers[questions[index].question_id] = nil
        later.remove(questions[index].question_id)
    }

    // MARK: Summary

    private var answeredCount: Int { answers.values.filter { $0 != "unsure" }.count }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ありがとうございました")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            HStack(spacing: 8) {
                tally(answeredCount, "答えた")
                tally(answers.values.filter { $0 == "unsure" }.count, "わからない")
                tally(later.count, "後で")
            }
            if sending {
                ProgressView().tint(.accentTeal)
            } else if let sendError {
                Text(sendError)
                    .font(.system(size: 13))
                    .foregroundColor(.accentCoral)
                Button("もう一度送る") { Task { await send() } }
                    .foregroundColor(.accentTeal)
            } else if answeredCount > 0 {
                Text("閉じると答えを送ります。答えをもとに、件数と分析の文章を作り直します。1 分ほどで反映されます。音声は聞き直しません。")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.56))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !later.isEmpty {
                Text("「後で」にした \(later.count) 件は、次に開いたときにまた出ます。")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.56))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            HStack(spacing: 10) {
                actionButton("戻る", fill: .darkElevated, text: .white) { back() }
                actionButton("閉じる", fill: .accentTeal, text: .darkBase) { Task { await finish() } }
            }
            .disabled(sending)
        }
    }

    private func tally(_ n: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(n)")
                .font(.system(size: 22, weight: .bold).monospacedDigit())
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.56))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.darkCard))
    }

    // MARK: Sending

    private func send() async {
        guard !answers.isEmpty else { return }
        sending = true
        sendError = nil
        defer { sending = false }
        do {
            try await QuestionService.send(answers)
        } catch {
            sendError = error.localizedDescription
        }
    }

    /// Closing sends what was answered so far (in the middle too). If sending fails, the
    /// screen stays so the error and "もう一度送る" can be seen.
    private func finish() async {
        if !answers.isEmpty {
            await send()
            if sendError != nil {
                if !done { withAnimation { index = questions.count } }
                return
            }
        }
        dismiss()
    }
}

// MARK: - Snippet player

/// Plays a few seconds around the moment a question is about, through a short-lived URL from
/// GET /audio (the API checks the token and the subject membership). In every build: without hearing
/// the moment, a question often cannot be answered (owner's decision, 2026-11-20).
@MainActor
final class QuestionSnippetPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var isLoading = false

    private let serverURL = "https://api.hey-watch.me"
    private var player: AVPlayer?
    private var stopTask: Task<Void, Never>?

    func toggle(audioKey: String, at seconds: Double) async {
        if isPlaying { stop(); return }
        isLoading = true
        defer { isLoading = false }
        guard var components = URLComponents(string: "\(serverURL)/audio"),
              let bearer = await SupabaseClientManager.shared.bearerToken() else { return }
        components.queryItems = [URLQueryItem(name: "audio_key", value: audioKey)]
        guard let requestURL = components.url else { return }
        var request = URLRequest(url: requestURL)
        request.setValue(bearer, forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urlString = object["url"] as? String, let url = URL(string: urlString) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        let player = AVPlayer(url: url)
        await player.seek(to: CMTime(seconds: max(0, seconds - 2), preferredTimescale: 600))
        player.play()
        self.player = player
        isPlaying = true
        stopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 9_000_000_000)
            self?.stop()
        }
    }

    func stop() {
        stopTask?.cancel()
        stopTask = nil
        player?.pause()
        player = nil
        isPlaying = false
    }
}
