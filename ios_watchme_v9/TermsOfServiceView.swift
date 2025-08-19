//
//  TermsOfServiceView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/08/19.
//

import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("最終更新日: 2025年8月19日")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Group {
                        TermsSection(
                            title: "第1条（利用規約の適用）",
                            content: """
                            本利用規約（以下「本規約」といいます）は、WatchMeアプリケーション（以下「本アプリ」といいます）の利用に関する条件を定めるものです。
                            
                            ユーザーは、本規約に同意の上、本アプリをご利用いただくものとします。
                            """
                        )
                        
                        TermsSection(
                            title: "第2条（定義）",
                            content: """
                            本規約において使用する用語の定義は以下のとおりとします。
                            
                            1. 「ユーザー」とは、本アプリを利用するすべての方をいいます
                            2. 「当社」とは、本アプリを運営するWatchMe Teamをいいます
                            3. 「コンテンツ」とは、本アプリ上で提供される情報、データ、文章、音声等をいいます
                            """
                        )
                        
                        TermsSection(
                            title: "第3条（アカウント登録）",
                            content: """
                            1. ユーザーは、本アプリの利用にあたり、真実かつ正確な情報を登録するものとします
                            2. ユーザーは、登録情報に変更が生じた場合、速やかに変更手続きを行うものとします
                            3. 登録情報の管理責任はユーザーにあり、第三者への貸与・譲渡は禁止します
                            """
                        )
                        
                        TermsSection(
                            title: "第4条（利用料金）",
                            content: """
                            1. 本アプリの基本機能は無料でご利用いただけます
                            2. 一部の高度な機能については、別途定める料金が発生する場合があります
                            3. 有料機能の料金は、アプリ内で明示します
                            """
                        )
                        
                        TermsSection(
                            title: "第5条（禁止事項）",
                            content: """
                            ユーザーは、本アプリの利用にあたり、以下の行為を行わないものとします。
                            
                            1. 法令または公序良俗に違反する行為
                            2. 犯罪行為に関連する行為
                            3. 当社または第三者の知的財産権を侵害する行為
                            4. 当社のサーバーまたはネットワークに過度な負荷をかける行為
                            5. 本アプリの運営を妨害する行為
                            6. 不正アクセスまたはこれを試みる行為
                            7. 他のユーザーに関する個人情報等を収集または蓄積する行為
                            8. 他のユーザーに成りすます行為
                            9. 反社会的勢力に対して直接または間接に利益を供与する行為
                            10. その他、当社が不適切と判断する行為
                            """
                        )
                        
                        TermsSection(
                            title: "第6条（知的財産権）",
                            content: """
                            1. 本アプリに関する知的財産権は、すべて当社または当社にライセンスを許諾している者に帰属します
                            2. ユーザーは、本アプリの利用により得られる一切の情報について、当社の事前の書面による承諾を得ずに転載、複製等を行わないものとします
                            """
                        )
                        
                        TermsSection(
                            title: "第7条（プライバシー）",
                            content: """
                            ユーザーの個人情報の取扱いについては、別途定めるプライバシーポリシーによるものとし、ユーザーは、プライバシーポリシーに従って当社がユーザーの個人情報を取り扱うことに同意するものとします。
                            """
                        )
                        
                        TermsSection(
                            title: "第8条（免責事項）",
                            content: """
                            1. 当社は、本アプリの提供する情報の正確性、有用性等について、いかなる保証も行いません
                            2. 当社は、本アプリの利用によりユーザーに生じた損害について、一切の責任を負いません
                            3. 当社は、本アプリの提供の中断、停止、終了、変更等によりユーザーに生じた損害について、一切の責任を負いません
                            """
                        )
                        
                        TermsSection(
                            title: "第9条（サービスの変更・終了）",
                            content: """
                            1. 当社は、ユーザーに通知することなく、本アプリの内容を変更または終了することができるものとします
                            2. 当社は、本条に基づく変更または終了によりユーザーに生じた損害について、一切の責任を負いません
                            """
                        )
                        
                        TermsSection(
                            title: "第10条（利用規約の変更）",
                            content: """
                            1. 当社は、必要と判断した場合には、ユーザーに通知することなく本規約を変更することができるものとします
                            2. 変更後の本規約は、本アプリ内に掲示した時点から効力を生じるものとします
                            """
                        )
                        
                        TermsSection(
                            title: "第11条（準拠法・管轄裁判所）",
                            content: """
                            1. 本規約の解釈にあたっては、日本法を準拠法とします
                            2. 本規約に関して紛争が生じた場合には、東京地方裁判所を第一審の専属的合意管轄裁判所とします
                            """
                        )
                    }
                    
                    Text("以上")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
                .padding()
            }
            .navigationTitle("利用規約")
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

struct TermsSection: View {
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
    TermsOfServiceView()
}