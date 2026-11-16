//
//  AIProcessingConsent.swift
//  ios_watchme_v9
//
//  Before the first recording or import, explain where the audio goes (our servers,
//  Google Gemini, OpenAI) and ask for permission (App Review Guideline 5.1.2(i)).
//  The answer is kept on this iPhone per account and per version of the explanation;
//  changing what is sent means bumping `version` so everyone is asked again.
//

import SwiftUI

enum AIProcessingConsent {
    static let version = "2026-11-17"

    private static func key(_ userId: String) -> String { "aiProcessingConsent.\(userId)" }

    static func isGranted(userId: String?) -> Bool {
        guard let userId else { return false }
        return UserDefaults.standard.string(forKey: key(userId)) == version
    }

    static func grant(userId: String?) {
        guard let userId else { return }
        UserDefaults.standard.set(version, forKey: key(userId))
    }

    static let points = [
        "音声は、東京にある当社のサーバー（Amazon Web Services）に送って分析します。音声は分析が終わってから3日で削除します（研究への協力に同意した場合を除く）。",
        "文字起こしと場面の説明のために、音声を Google（Gemini API）に送ります。",
        "分析の文章と出来事の数え上げのために、文字起こしと測定値を OpenAI に送ります。音声は送りません。",
        "送ったデータは本アプリの分析のためだけに使われ、各社の AI モデルの学習には使われません。",
        "録音には、その場にいるご家族などの声も含まれます。",
    ]
}

/// Shown in place of the recording screen until the user agrees.
struct AIProcessingConsentView: View {
    let onAgree: () -> Void
    let onDecline: () -> Void
    @State private var showPolicy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("WatchMe は、録音や取り込んだ音声を次のように処理して分析します。")
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(AIProcessingConsent.points, id: \.self) { point in
                            HStack(alignment: .top, spacing: 4) {
                                Text("・")
                                Text(point)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .font(.subheadline)
                        }
                    }

                    Button("プライバシーポリシーを読む") { showPolicy = true }
                        .font(.subheadline)

                    VStack(spacing: 12) {
                        Button(action: onAgree) {
                            Text("同意して進む")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: onDecline) {
                            Text("同意しない")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(24)
            }
            .navigationTitle("録音の分析について")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showPolicy) {
            PrivacyPolicyView()
        }
    }
}
