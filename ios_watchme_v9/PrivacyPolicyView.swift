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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("最終更新日: 2025年8月19日")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("WatchMe Team（以下「当社」といいます）は、本アプリケーションにおけるユーザーの個人情報の取扱いについて、以下のとおりプライバシーポリシー（以下「本ポリシー」といいます）を定めます。")
                        .font(.body)
                        .padding(.bottom, 10)
                    
                    Group {
                        PolicySection(
                            title: "1. 収集する個人情報",
                            content: """
                            当社は、本アプリの提供にあたり、以下の個人情報を収集します。
                            
                            【アカウント情報】
                            • メールアドレス
                            • パスワード（暗号化して保存）
                            • ユーザー名（任意）
                            • プロフィール画像（任意）
                            
                            【利用データ】
                            • 音声録音データ（30分ごとの自動録音）
                            • 録音日時とタイムゾーン情報
                            • デバイス識別情報
                            • アプリの利用履歴
                            
                            【分析データ】
                            • AI による感情分析結果
                            • 行動パターン分析結果
                            • 統計データ
                            """
                        )
                        
                        PolicySection(
                            title: "2. 個人情報の利用目的",
                            content: """
                            収集した個人情報は、以下の目的で利用します。
                            
                            • 本アプリのサービス提供
                            • ユーザーの感情・行動分析とフィードバック
                            • ユーザーサポートの提供
                            • サービスの改善と新機能の開発
                            • 統計データの作成（個人を特定できない形式）
                            • 重要なお知らせや更新情報の通知
                            • 利用規約違反への対応
                            """
                        )
                        
                        PolicySection(
                            title: "3. 個人情報の管理",
                            content: """
                            当社は、個人情報を以下の方法で適切に管理します。
                            
                            【セキュリティ対策】
                            • SSL/TLS による通信の暗号化
                            • データベースの暗号化
                            • アクセス権限の厳格な管理
                            • 定期的なセキュリティ監査
                            
                            【保存期間】
                            • アカウント削除後、30日以内にすべての個人情報を削除
                            • 音声データは録音から90日間保存（設定により変更可能）
                            • 分析結果は無期限で保存（個人識別情報は除外）
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
                            本アプリは、以下の外部サービスを利用しています。
                            
                            【Supabase】
                            • 認証とデータベース管理
                            • プライバシーポリシー: https://supabase.com/privacy
                            
                            【OpenAI API】
                            • 感情分析と自然言語処理
                            • データは分析のみに使用され、OpenAI のモデル訓練には使用されません
                            • プライバシーポリシー: https://openai.com/privacy
                            
                            【Amazon S3】
                            • 音声ファイルとアバター画像の保存
                            • プライバシーポリシー: https://aws.amazon.com/privacy
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
                            本アプリは、13歳未満の子どもを対象としていません。13歳未満の子どもの個人情報を意図的に収集することはありません。
                            
                            13歳未満の子どもが個人情報を提供したことが判明した場合、速やかに削除します。
                            """
                        )
                        
                        PolicySection(
                            title: "8. ユーザーの権利",
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
                            title: "9. プライバシーポリシーの変更",
                            content: """
                            当社は、必要に応じて本ポリシーを変更することがあります。
                            
                            重要な変更がある場合は、アプリ内通知またはメールでお知らせします。変更後の本ポリシーは、アプリ内に掲示した時点から効力を生じるものとします。
                            """
                        )
                        
                        PolicySection(
                            title: "10. お問い合わせ",
                            content: """
                            本ポリシーに関するお問い合わせは、以下の窓口までお願いします。
                            
                            WatchMe Team
                            メール: privacy@watchme.app
                            
                            お問い合わせフォーム: アプリ内設定画面より
                            """
                        )
                    }
                    
                    Text("以上")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
                .padding()
            }
            .navigationTitle("プライバシーポリシー")
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