//
//  PrivacyPolicyView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/08/19.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("最終更新日: 2026年11月14日")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("WatchMe Team（以下「当社」といいます）は、本アプリケーションにおけるユーザーの個人情報の取扱いについて、以下のとおりプライバシーポリシー（以下「本ポリシー」といいます）を定めます。")
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(.bottom, 10)

                        Group {
                            PolicySection(
                                title: "1. 収集する個人情報",
                                content: """
                                当社は、本アプリの提供にあたり、以下の個人情報を収集します。

                                【アカウント情報】
                                • メールアドレス（Google アカウントでログインした場合は、Google から受け取るもの）
                                • パスワード（メールアドレスで登録した場合。暗号化して保存）
                                • ユーザー名・プロフィール画像（任意）

                                【観測対象（お子さまなど）の情報】
                                • 名前、年齢、性別、メモなど、利用者が登録した情報（任意）

                                【録音と分析のデータ】
                                • この iPhone で録音した音声、および利用者が取り込んだ動画・音声ファイルの音声
                                • 録音日時とタイムゾーン
                                • 音声から作る文字起こし、会話の指標（話した量・速さ・間など）、声の特徴、周囲の音、出来事（叱る・褒める・笑う などの回数）、分析の文章
                                • デバイスの識別情報、プッシュ通知のための識別子

                                録音には、利用者本人のほか、ご家族やお子さまなど、その場にいる方の声が含まれます。
                                """
                            )

                            PolicySection(
                                title: "2. 個人情報の利用目的",
                                content: """
                                収集した個人情報は、以下の目的で利用します。

                                • 録音の分析と、その結果の表示（日ごとの変化、出来事の回数など）
                                • 分析が終わったことなどのお知らせ
                                • ユーザーサポートの提供
                                • 本アプリの改善（研究への協力に同意した方の音声については、「研究への協力」の項目のとおり）
                                • 利用規約違反への対応

                                本アプリの分析は、医療的な診断を行うものではありません。
                                """
                            )

                            PolicySection(
                                title: "3. 個人情報の管理",
                                content: """
                                当社は、個人情報を以下の方法で適切に管理します。

                                【セキュリティ対策】
                                • 通信の暗号化（TLS）と、保存するデータの暗号化
                                • 利用者は、自分が連携しているデバイスのデータだけを閲覧できます

                                【保存場所】
                                • データは日本国内（東京）のサーバーに保存します。分析の一部は、下記の外部サービスで処理します

                                【保存期間】
                                • 音声: 分析が終わってから3日で削除します（研究への協力に同意した場合を除く）
                                • 文字起こし・分析結果・観測対象の情報: アカウントがある間保存し、アカウントの削除とともに削除します
                                • アカウントを削除すると、そのアカウントだけが使っているデバイスの録音と分析結果、観測対象の情報、プロフィール画像も削除します。他のアカウントも連携しているデバイスのデータは、連携だけを解除して残します
                                """
                            )

                            PolicySection(
                                title: "4. 個人情報の第三者提供",
                                content: """
                                当社は、以下の場合を除き、個人情報を第三者に提供しません。

                                • ユーザーの同意がある場合
                                • 法令に基づく場合
                                • 人の生命、身体または財産の保護のために必要な場合
                                • 公衆衛生の向上または児童の健全な育成の推進のために必要な場合
                                • 国の機関等の法令の定める事務の遂行に協力する必要がある場合
                                """
                            )

                            PolicySection(
                                title: "5. 外部サービスの利用",
                                content: """
                                本アプリは、録音の分析と保存のために、以下の外部サービスを利用しています。各サービスに送ったデータは、本アプリの処理のためだけに使われ、各社の AI モデルの学習には使われない契約・設定で利用しています。

                                【Google（Gemini API）】
                                • 文字起こし、録音の場面の説明
                                • プライバシーポリシー: https://policies.google.com/privacy

                                【OpenAI（API）】
                                • 分析の文章、出来事の抽出（文字起こしと測定値を送ります。音声は送りません）
                                • プライバシーポリシー: https://openai.com/policies/privacy-policy

                                【Amazon Web Services（東京リージョン）】
                                • 音声の保存と分析の処理
                                • プライバシーポリシー: https://aws.amazon.com/privacy

                                【Supabase（東京リージョン）】
                                • ログインとデータベース
                                • プライバシーポリシー: https://supabase.com/privacy
                                """
                            )

                            PolicySection(
                                title: "6. Cookieの使用",
                                content: """
                                本アプリでは、サービス向上のため、Cookie および類似技術を使用することがあります。

                                • セッション管理
                                • ユーザー設定の保存
                                • 利用状況の分析

                                ユーザーは、デバイスの設定により Cookie を無効にすることができますが、一部の機能が利用できなくなる場合があります。
                                """
                            )

                            PolicySection(
                                title: "7. 子どものプライバシー",
                                content: """
                                本アプリは、保護者が利用者となり、お子さまを観測対象として登録して使うことを想定しています。13歳未満の方が自分でアカウントを作ることは想定していません。

                                お子さまの声や情報は、保護者である利用者の判断と同意のもとで録音・登録してください。お子さまの情報の削除は、観測対象の削除、デバイスの削除、またはアカウントの削除で行えます。
                                """
                            )

                            PolicySection(
                                title: "8. 研究への協力（任意）",
                                content: """
                                会員登録のとき、または初めてログインしたときに、研究への協力を選べます。協力するかどうかは任意で、マイページでいつでも変更できます。

                                • 協力した場合: 録音した音声を研究用の保管場所に残し、本アプリの分析の改善（精度の確認や、分析に使うモデルの評価・学習）のためだけに使います。外部に提供したり、公開したりしません
                                • 協力しない場合: 音声は分析が終わってから3日で削除します
                                • 取りやめた場合: それまでに保管した音声を削除します（同じデバイスに連携している別のアカウントが協力している場合、そのデバイスの音声は残ります）
                                • いつ、どの内容に同意したかを記録します
                                """
                            )

                            PolicySection(
                                title: "9. ユーザーの権利",
                                content: """
                                ユーザーは、自己の個人情報について以下の権利を有します。

                                • 開示請求: 保有する個人情報の開示を請求する権利
                                • 訂正請求: 個人情報の訂正を請求する権利
                                • 削除請求: 個人情報の削除を請求する権利
                                • 利用停止請求: 個人情報の利用停止を請求する権利
                                • データポータビリティ: 個人情報を機械可読形式で受け取る権利

                                これらの請求は、アプリ内の設定画面またはサポート窓口から行うことができます。
                                """
                            )

                            PolicySection(
                                title: "10. プライバシーポリシーの変更",
                                content: """
                                当社は、必要に応じて本ポリシーを変更することがあります。

                                重要な変更がある場合は、アプリ内通知またはメールでお知らせします。変更後の本ポリシーは、アプリ内に掲示した時点から効力を生じるものとします。
                                """
                            )

                            PolicySection(
                                title: "11. お問い合わせ",
                                content: """
                                本ポリシーに関するお問い合わせは、以下の窓口までお願いします。

                                WatchMe Team
                                メール: support@hey-watch.me
                                Web: https://hey-watch.me/privacy

                                お問い合わせフォーム: アプリ内設定画面より
                                """
                            )
                        }

                        Text("以上")
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    }
                    .padding()
                }
            }
            .navigationTitle("プライバシーポリシー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

struct PolicySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(content)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(4)
        }
        .padding(.bottom, 8)
    }
}

#Preview {
    PrivacyPolicyView()
}
