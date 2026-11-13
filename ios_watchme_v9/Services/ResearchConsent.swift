//
//  ResearchConsent.swift
//  ios_watchme_v9
//
//  Research consent (opt-in): whether the user lets WatchMe keep the audio of their
//  recordings to check and improve the analysis. Without it, audio is deleted a few
//  days after processing. The choice is made when signing up (checkbox) or on first
//  sign-in (prompt), and can be changed in My Page. The server keeps a log of every
//  change (platform docs/security.md, account API /account/research-consent).
//

import SwiftUI

/// Wording and version of the explanation the user agrees to. Bump the version when
/// the text changes in substance, so the server records which text was agreed to.
enum ResearchConsentInfo {
    static let policyVersion = "research-v1-2026-11-14"

    static let title = "研究への協力（任意）"

    static let summary = "録音した音声を、WatchMe の分析の精度を確かめ改善するために保管することに同意します。"

    static let points: [String] = [
        "協力しない場合、音声は分析が終わってから3日で削除されます。文字起こしと分析結果は、アカウントがある間だけ残ります。",
        "協力する場合、音声を研究用の保管場所に残し、WatchMe の分析の改善（精度の確認や、分析に使うモデルの評価・学習）のためだけに使います。外部に提供したり、公開したりすることはありません。",
        "録音には、ご家族やお子さまの声が含まれます。保護者として、録音に含まれる方の了解を得たうえでご協力ください。",
        "マイページでいつでも取りやめられます。取りやめると、それまでに保管した音声は削除されます（同じデバイスに連携している別のアカウントが協力している場合、そのデバイスの音声は残ります）。",
        "アカウントやデバイスを削除したときも、保管した音声は削除されます。",
    ]
}

/// The server's answer for /account/research-consent.
struct ResearchConsentState: Decodable, Equatable {
    let decided: Bool
    let consented: Bool
    let research_objects_deleted: Int?
}

@MainActor
final class ResearchConsentStore: ObservableObject {
    static let shared = ResearchConsentStore()

    @Published private(set) var state: ResearchConsentState?
    @Published var showFirstLoginPrompt = false

    private let pendingKey = "pendingResearchConsent"
    private let network = NetworkManager()

    /// Remember the sign-up checkbox until the new account can call the API (email
    /// sign-up may need confirmation first). Applied on the next sign-in with this email.
    static func rememberSignupChoice(_ consented: Bool, email: String) {
        UserDefaults.standard.set(["email": email.lowercased(), "consented": consented], forKey: "pendingResearchConsent")
    }

    /// After sign-in: apply a pending sign-up choice, or ask once when the user has never
    /// decided. Guests are skipped (their data is not kept beyond the session's account).
    func syncAfterSignIn(email: String?, isAnonymous: Bool) async {
        guard !isAnonymous else { return }
        if let pending = UserDefaults.standard.dictionary(forKey: pendingKey),
           let pendingEmail = pending["email"] as? String,
           let consented = pending["consented"] as? Bool,
           pendingEmail == (email ?? "").lowercased() {
            if let saved = try? await network.setResearchConsent(consented, source: "signup") {
                state = saved
                UserDefaults.standard.removeObject(forKey: pendingKey)
                return
            }
        }
        guard let current = try? await network.fetchResearchConsent() else { return }
        state = current
        showFirstLoginPrompt = !current.decided
    }

    func refresh() async {
        if let current = try? await network.fetchResearchConsent() {
            state = current
        }
    }

    func set(_ consented: Bool, source: String) async throws {
        state = try await network.setResearchConsent(consented, source: source)
        showFirstLoginPrompt = false
    }
}

/// The explanation, shared by the sign-up screen, the first sign-in prompt and My Page.
struct ResearchConsentDetailsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ResearchConsentInfo.summary)
                .font(.subheadline)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(ResearchConsentInfo.points, id: \.self) { point in
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

/// Asked once after the first sign-in when the user has not decided yet (e.g. Google
/// sign-in, which has no sign-up form). Both answers are equally easy; nothing is
/// pre-selected.
struct ResearchConsentPromptView: View {
    @ObservedObject var store: ResearchConsentStore
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("WatchMe の分析はまだ開発の途中です。録音した音声を保管させていただけると、新しい分析の方法が出たときに精度を確かめ、改善できます。協力するかどうかは任意で、あとからマイページで変えられます。")
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)

                    ResearchConsentDetailsView()

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.accentCoral)
                    }

                    VStack(spacing: 12) {
                        Button {
                            Task { await choose(true) }
                        } label: {
                            Text("協力する")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            Task { await choose(false) }
                        } label: {
                            Text("協力しない")
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
            .navigationTitle(ResearchConsentInfo.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(true)
    }

    private func choose(_ consented: Bool) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.set(consented, source: "first_login")
        } catch {
            errorMessage = "保存できませんでした。通信状況を確かめて、もう一度お試しください。"
        }
    }
}

/// My Page row: current choice with a switch. Turning it off asks first, because the
/// kept audio is deleted.
struct ResearchConsentRow: View {
    @ObservedObject var store: ResearchConsentStore
    @State private var confirmWithdraw = false
    @State private var showDetails = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("研究への協力")
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
                    get: { store.state?.consented ?? false },
                    set: { newValue in
                        if newValue {
                            Task { await save(true) }
                        } else {
                            confirmWithdraw = true
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
        .alert("研究への協力を取りやめますか？", isPresented: $confirmWithdraw) {
            Button("キャンセル", role: .cancel) { }
            Button("取りやめる", role: .destructive) {
                Task { await save(false) }
            }
        } message: {
            Text("これまでに保管した音声は削除されます。今後の音声は、分析が終わってから3日で削除されます。")
        }
        .sheet(isPresented: $showDetails) {
            NavigationStack {
                ScrollView {
                    ResearchConsentDetailsView()
                        .padding(24)
                }
                .navigationTitle(ResearchConsentInfo.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("閉じる") { showDetails = false }
                    }
                }
            }
        }
    }

    private func save(_ consented: Bool) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await store.set(consented, source: "settings")
        } catch {
            errorMessage = "変更できませんでした。もう一度お試しください。"
        }
    }
}
