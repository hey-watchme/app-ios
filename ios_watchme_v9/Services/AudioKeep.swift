//
//  AudioKeep.swift
//  ios_watchme_v9
//
//  Keeping the audio for playback (opt-in, per account): whether the audio of the user's
//  recordings is kept so that a counted event can be played back where it happened.
//  Without it, audio is deleted 3 days after recording and can be played back only
//  within those days. Asked once after sign-in, changeable in My Page. The server keeps
//  the choice (account API /account/audio-keep, platform migration 20261120020000).
//

import SwiftUI

enum AudioKeepInfo {
    static let policyVersion = "audio-keep-v1-2026-11-20"

    static let title = "録音の音声を残す（任意）"

    static let summary = "音声を残すと、叱責や褒め言葉など、数えた出来事のその場面を、あとから再生して聞き直せます。"

    static let points: [String] = [
        "言葉だけでは分からない言い方や雰囲気を、あとから確かめられます。振り返りや、相談のときの材料に使えます。",
        "残さない場合、音声は録音から3日で削除されます。3日のあいだは再生でき、そのあとは文字起こしと分析結果だけが残ります。",
        "録音には、ご家族やお子さまの声が含まれます。保護者として、録音に含まれる方の了解を得たうえで選んでください。",
        "マイページでいつでも変えられます。残すのをやめると、それまでに残した音声は削除されます（同じデバイスに連携している別のアカウントが残している場合、そのデバイスの音声は残ります）。",
        "アカウントやデバイスを削除したときも、残した音声は削除されます。",
    ]
}

/// The server's answer for /account/audio-keep.
struct AudioKeepState: Decodable, Equatable {
    let decided: Bool
    let keep: Bool
}

@MainActor
final class AudioKeepStore: ObservableObject {
    static let shared = AudioKeepStore()

    @Published private(set) var state: AudioKeepState?
    @Published var showPrompt = false

    private let network = NetworkManager()

    /// After sign-in: ask once when the user has never decided. Guests are skipped.
    func syncAfterSignIn(isAnonymous: Bool) async {
        guard !isAnonymous, let current = try? await network.fetchAudioKeep() else { return }
        state = current
        showPrompt = !current.decided
    }

    func refresh() async {
        if let current = try? await network.fetchAudioKeep() {
            state = current
        }
    }

    func set(_ keep: Bool) async throws {
        state = try await network.setAudioKeep(keep)
        showPrompt = false
    }
}

struct AudioKeepDetailsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AudioKeepInfo.summary)
                .font(.subheadline)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(AudioKeepInfo.points, id: \.self) { point in
                HStack(alignment: .top, spacing: 8) {
                    Text("・")
                    Text(point)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
        }
    }
}

/// Asked once after sign-in when the user has not decided yet. Nothing is pre-selected.
struct AudioKeepPromptView: View {
    @ObservedObject var store: AudioKeepStore
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AudioKeepDetailsView()

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.accentCoral)
                    }

                    VStack(spacing: 12) {
                        Button {
                            Task { await choose(true) }
                        } label: {
                            Text("音声を残す")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            Task { await choose(false) }
                        } label: {
                            Text("残さない（3日で削除）")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.bordered)
                    }
                    .disabled(isSaving)
                }
                .padding(24)
            }
            .navigationTitle(AudioKeepInfo.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(true)
    }

    private func choose(_ keep: Bool) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.set(keep)
        } catch {
            errorMessage = "保存できませんでした。通信状況を確かめて、もう一度お試しください。"
        }
    }
}

/// My Page row. Turning it off asks first, because the kept audio is deleted.
struct AudioKeepRow: View {
    @ObservedObject var store: AudioKeepStore
    @State private var confirmOff = false
    @State private var showDetails = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("録音の音声を残す")
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.56))
                Button {
                    showDetails = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(Color(white: 0.56))
                }
                .buttonStyle(.plain)
                Spacer()
                if isSaving {
                    ProgressView().scaleEffect(0.7)
                }
                Toggle("", isOn: Binding(
                    get: { store.state?.keep ?? false },
                    set: { newValue in
                        if newValue {
                            Task { await save(true) }
                        } else {
                            confirmOff = true
                        }
                    }
                ))
                .labelsHidden()
                .disabled(store.state == nil || isSaving)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.accentCoral)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            Divider()
                .background(Color(.separator))
        }
        .task { await store.refresh() }
        .alert("音声を残すのをやめますか？", isPresented: $confirmOff) {
            Button("キャンセル", role: .cancel) { }
            Button("やめる", role: .destructive) {
                Task { await save(false) }
            }
        } message: {
            Text("これまでに残した音声は削除され、出来事を再生できなくなります。今後の音声は、録音から3日で削除されます。")
        }
        .sheet(isPresented: $showDetails) {
            NavigationStack {
                ScrollView {
                    AudioKeepDetailsView()
                        .padding(24)
                }
                .navigationTitle(AudioKeepInfo.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("閉じる") { showDetails = false }
                    }
                }
            }
        }
    }

    private func save(_ keep: Bool) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await store.set(keep)
        } catch {
            errorMessage = "変更できませんでした。もう一度お試しください。"
        }
    }
}
