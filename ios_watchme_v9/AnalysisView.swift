//
//  AnalysisView.swift
//  ios_watchme_v9
//
//  分析ページ - 認知スタイルと神経機能の分析
//

import SwiftUI

struct AnalysisView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager

    @State private var subject: Subject? = nil
    @State private var isLoading = true
    @State private var showCognitiveInfo = false
    @State private var showNeuralInfo = false
    @State private var showIntelligenceInfo = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // 観測対象情報
                if let subject = subject {
                    subjectHeader(subject)
                }

                // 認知スタイル（行動系を最も当てはまるものとして表示）
                primaryCognitiveStyleSection

                // 神経機能モデル（レーダーチャート）
                neuralFunctionSection

                // 知性の形式モデル
                intelligenceSection

                Spacer(minLength: 50)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(Color(.systemBackground))
        .task(id: deviceManager.selectedDeviceID) {
            await loadSubject()
        }
        .sheet(isPresented: $showNeuralInfo) {
            InfoSheet(
                title: "神経機能モデルとは",
                content: """
                前頭葉ネットワークを中心とした認知神経科学の視点で、注意・実行・感情制御の機能を整理したモデルです。

                このモデルは以下の5つの機能で構成されています：

                🎯 注意制御：集中力・注意の切替・持続力
                🧭 実行機能：計画・優先順位・段取り
                ⚙️ ワーキングメモリ：情報の保持・操作
                ❤️ 感情制御：衝動・不安・共感の調整
                🌈 発想流動性：創造性・連想力

                ADHD傾向やASD傾向の理解にも役立つフレームワークです。
                """
            )
        }
        .sheet(isPresented: $showIntelligenceInfo) {
            InfoSheet(
                title: "知性の形式モデルとは",
                content: """
                ハワード・ガードナーの多重知能理論を拡張したモデルです。

                知能は単一の数値（IQ）ではなく、複数の独立した知性の組み合わせで構成されています。

                このモデルでは9つの知性領域を評価します：

                • 言語的知性：言葉で考える
                • 論理数学的知性：構造・法則で考える
                • 空間的知性：イメージで考える
                • 身体運動的知性：体を通して考える
                • 音楽的知性：リズム・音で考える
                • 対人的知性：他者との関係で理解する
                • 内省的知性：自分を理解する
                • 博物的知性：パターンで理解する
                • 存在的知性：哲学的に考える

                すべての人に独自の知性の組み合わせがあり、それぞれに価値があります。
                """
            )
        }
    }

    // MARK: - 観測対象ヘッダー
    @ViewBuilder
    private func subjectHeader(_ subject: Subject) -> some View {
        HStack(spacing: 12) {
            Text("観測対象:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let name = subject.name {
                Text(name)
                    .font(.title3)
                    .fontWeight(.medium)

                if let age = subject.age {
                    Text("(\(age)歳)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - 主要な認知スタイル（行動系）
    private var primaryCognitiveStyleSection: some View {
        VStack(alignment: .center, spacing: 16) {
            // 行動系を大きく表示
            VStack(spacing: 12) {
                Text("⚡")
                    .font(.system(size: 60))

                Text("行動系")
                    .font(.title)
                    .fontWeight(.bold)

                Text("衝動型")
                    .font(.title3)
                    .foregroundColor(.secondary)

                Text("この観測対象は、素早く行動に移すタイプです")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    // MARK: - 神経機能モデルセクション（レーダーチャート）
    private var neuralFunctionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // セクションヘッダー
            HStack {
                Text("神経機能モデル")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { showNeuralInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }

            // レーダーチャート
            VStack(spacing: 20) {
                RadarChartView(
                    dataPoints: [
                        RadarDataPoint(label: "🎯 注意制御", value: 0.6, color: .blue),
                        RadarDataPoint(label: "🧭 実行機能", value: 0.7, color: .green),
                        RadarDataPoint(label: "⚙️ WM", value: 0.5, color: .orange),
                        RadarDataPoint(label: "❤️ 感情制御", value: 0.4, color: .red),
                        RadarDataPoint(label: "🌈 発想", value: 0.8, color: .purple)
                    ]
                )
                .frame(height: 300)

                // 凡例
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle().fill(Color.blue).frame(width: 12, height: 12)
                        Text("注意制御").font(.caption)
                        Spacer()
                        Text("60%").font(.caption).foregroundColor(.secondary)
                    }
                    HStack {
                        Circle().fill(Color.green).frame(width: 12, height: 12)
                        Text("実行機能").font(.caption)
                        Spacer()
                        Text("70%").font(.caption).foregroundColor(.secondary)
                    }
                    HStack {
                        Circle().fill(Color.orange).frame(width: 12, height: 12)
                        Text("ワーキングメモリ").font(.caption)
                        Spacer()
                        Text("50%").font(.caption).foregroundColor(.secondary)
                    }
                    HStack {
                        Circle().fill(Color.red).frame(width: 12, height: 12)
                        Text("感情制御").font(.caption)
                        Spacer()
                        Text("40%").font(.caption).foregroundColor(.secondary)
                    }
                    HStack {
                        Circle().fill(Color.purple).frame(width: 12, height: 12)
                        Text("発想流動性").font(.caption)
                        Spacer()
                        Text("80%").font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    // MARK: - 知性の形式モデルセクション
    private var intelligenceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // セクションヘッダー
            HStack {
                Text("知性の形式モデル")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { showIntelligenceInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }

            // 横棒グラフ（多重知能）
            VStack(spacing: 16) {
                IntelligenceBar(title: "言語的知性", subtitle: "言葉で考える", value: 0.7)
                IntelligenceBar(title: "論理数学的知性", subtitle: "構造・法則で考える", value: 0.6)
                IntelligenceBar(title: "空間的知性", subtitle: "イメージで考える", value: 0.8)
                IntelligenceBar(title: "身体運動的知性", subtitle: "体を通して考える", value: 0.5)
                IntelligenceBar(title: "音楽的知性", subtitle: "リズム・音で考える", value: 0.7)
                IntelligenceBar(title: "対人的知性", subtitle: "他者との関係で理解", value: 0.6)
                IntelligenceBar(title: "内省的知性", subtitle: "自分を理解する", value: 0.8)
                IntelligenceBar(title: "博物的知性", subtitle: "パターンで理解する", value: 0.5)
                IntelligenceBar(title: "存在的知性", subtitle: "哲学的に考える", value: 0.6)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    // MARK: - データ取得
    private func loadSubject() async {
        guard let deviceId = deviceManager.selectedDeviceID else {
            await MainActor.run {
                subject = nil
                isLoading = false
            }
            return
        }

        await MainActor.run {
            isLoading = true
        }

        let fetchedSubject = await dataManager.fetchSubjectInfo(deviceId: deviceId)

        await MainActor.run {
            subject = fetchedSubject
            isLoading = false
        }
    }
}

// MARK: - レーダーチャートデータポイント
struct RadarDataPoint {
    let label: String
    let value: Double // 0.0 〜 1.0
    let color: Color
}

// MARK: - レーダーチャートView
struct RadarChartView: View {
    let dataPoints: [RadarDataPoint]

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 * 0.7

            ZStack {
                // 背景グリッド（5段階）
                ForEach(1...5, id: \.self) { level in
                    RadarPolygonShape(sides: dataPoints.count, scale: Double(level) / 5.0)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        .frame(width: radius * 2, height: radius * 2)
                }

                // データのポリゴン
                RadarPolygonShape(
                    sides: dataPoints.count,
                    scale: 1.0,
                    values: dataPoints.map { $0.value }
                )
                .fill(Color.blue.opacity(0.3))
                .frame(width: radius * 2, height: radius * 2)

                RadarPolygonShape(
                    sides: dataPoints.count,
                    scale: 1.0,
                    values: dataPoints.map { $0.value }
                )
                .stroke(Color.blue, lineWidth: 2)
                .frame(width: radius * 2, height: radius * 2)

                // ラベル
                ForEach(0..<dataPoints.count, id: \.self) { index in
                    let angle = Double(index) * (360.0 / Double(dataPoints.count)) - 90
                    let radian = angle * .pi / 180
                    let x = center.x + CGFloat(cos(radian)) * (radius + 30)
                    let y = center.y + CGFloat(sin(radian)) * (radius + 30)

                    Text(dataPoints[index].label)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

// MARK: - レーダーチャート用ポリゴンシェイプ
struct RadarPolygonShape: Shape {
    let sides: Int
    let scale: Double
    var values: [Double]? = nil

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        for i in 0..<sides {
            let angle = Double(i) * (360.0 / Double(sides)) - 90
            let radian = angle * .pi / 180
            let value = values?[i] ?? 1.0
            let distance = radius * scale * value
            let x = center.x + CGFloat(cos(radian)) * distance
            let y = center.y + CGFloat(sin(radian)) * distance

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()

        return path
    }
}

// MARK: - 知性バーコンポーネント
struct IntelligenceBar: View {
    let title: String
    let subtitle: String
    let value: Double // 0.0 〜 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            // プログレスバー
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.tertiarySystemFill))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.8))
                        .frame(width: geometry.size.width * CGFloat(value))
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - 情報シートコンポーネント
struct InfoSheet: View {
    let title: String
    let content: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                }
                .padding(20)
            }
            .navigationTitle(title)
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
