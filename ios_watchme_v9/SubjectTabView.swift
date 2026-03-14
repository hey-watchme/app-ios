//
//  SubjectTabView.swift
//  ios_watchme_v9
//
//  分析対象タブ - 分析対象の情報表示・編集画面
//

import SwiftUI

struct SubjectTabView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager

    @State private var showSubjectEdit = false
    @State private var showNeuralInfo = false
    @State private var showIntelligenceInfo = false
    @State private var selectedCognitiveType: CognitiveTypeOption = .behavioralImpulsive
    @State private var isUpdatingType = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.darkBase.ignoresSafeArea()

            if let subject = deviceManager.selectedSubject {
                // 分析対象が設定されている場合
                ScrollView {
                    VStack(spacing: 0) {
                        // 地図ヘッダー（4:3 比率で表示、上を少し見切らせる）
                        // Location display: city/prefecture if available, otherwise show Japan map
                        GeometryReader { proxy in
                            let mapHeight = proxy.size.width * 0.75
                            let visibleHeight = mapHeight * 0.82
                            let clipOffset = mapHeight * 0.08
                            MapSnapshotView(
                                locationName: subject.locationDisplay ?? "日本",
                                height: mapHeight
                            )
                            .frame(height: mapHeight)
                            .offset(y: -clipOffset)
                            .clipped()
                        }
                        .frame(height: UIScreen.main.bounds.width * 0.75 * 0.82)

                        // プロフィールセクション（ダークカード）
                        VStack(alignment: .leading, spacing: 16) {
                            // アバターと基本情報
                            HStack(alignment: .top, spacing: 12) {
                                // 左：小さめのアバター（SSOT: Subject.avatarUrl を渡す）
                                AvatarView(type: .subject, id: subject.subjectId, size: 60, avatarUrl: subject.avatarUrl)
                                    .environmentObject(dataManager)

                                // 右：名前、年齢・性別・地域
                                VStack(alignment: .leading, spacing: 4) {
                                    // 名前
                                    if let name = subject.name, !name.isEmpty {
                                        Text(name)
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    } else {
                                        Text("名前未設定")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(Color(white: 0.56))
                                    }

                                    // 年齢・性別・地域を1行で表示
                                    HStack(spacing: 6) {
                                        if let age = subject.age {
                                            Text("\(age)歳")
                                                .font(.subheadline)
                                                .foregroundColor(Color(white: 0.56))
                                        }

                                        if let gender = subject.gender, !gender.isEmpty {
                                            if subject.age != nil {
                                                Text("•")
                                                    .font(.subheadline)
                                                    .foregroundColor(Color(white: 0.56))
                                            }
                                            Text(gender)
                                                .font(.subheadline)
                                                .foregroundColor(Color(white: 0.56))
                                        }

                                        // Location (prefecture and city)
                                        if let locationName = subject.locationDisplay {
                                            if subject.age != nil || subject.gender != nil {
                                                Text("•")
                                                    .font(.subheadline)
                                                    .foregroundColor(Color(white: 0.56))
                                            }
                                            Text(locationName)
                                                .font(.subheadline)
                                                .foregroundColor(Color(white: 0.56))
                                        }
                                    }

                                    Spacer()
                                }
                            }

                            // プロフィール文章（メモ）
                            if let notes = subject.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .lineSpacing(4)
                            }

                            // プロフィール編集ボタン
                            Button(action: {
                                showSubjectEdit = true
                            }) {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text("プロフィールを編集")
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.darkElevated)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                            }
                        }
                        .padding(20)
                        .background(Color.darkCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)
                        .padding(.horizontal, 0)
                        .padding(.top, 0)

                        // 認知タイプセクション - 一旦非表示
                        // cognitiveTypeSection
                        //     .padding(.horizontal, 20)
                        //     .padding(.top, 20)

                        // 神経機能モデル（レーダーチャート）- 一旦非表示
                        // neuralFunctionSection
                        //     .padding(.horizontal, 20)
                        //     .padding(.top, 20)

                        // 知性の形式モデル - 一旦非表示
                        // intelligenceSection
                        //     .padding(.horizontal, 20)
                        //     .padding(.top, 20)

                        Spacer(minLength: 50)
                    }
                }
            } else {
                // 分析対象が未設定の場合
                VStack(spacing: 20) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 80))
                        .foregroundColor(Color(white: 0.50))
                    Text("未登録")
                        .font(.title3)
                        .foregroundColor(.white)
                    Text("選択中のデバイス（\(currentDeviceTypeLabel)）で音声分析している対象者を登録しておくことで、分析の精度が向上します。年齢、性別、プロフィールの情報等が分析の前提として活用されます。")
                        .font(.caption)
                        .foregroundColor(Color(white: 0.56))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    // 新規登録ボタン
                    Button(action: {
                        showSubjectEdit = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("分析対象を登録")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.safeColor("AppAccentColor"))
                        .cornerRadius(12)
                    }
                    .padding(.top, 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            }
        }
        .sheet(isPresented: $showSubjectEdit) {
            if let deviceId = deviceManager.selectedDeviceID {
                SubjectRegistrationView(
                    deviceID: deviceId,
                    isPresented: $showSubjectEdit,
                    editingSubject: deviceManager.selectedSubject
                )
                .environmentObject(dataManager)
                .environmentObject(deviceManager)
                .environmentObject(userAccountManager)
            }
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

    private var currentDeviceTypeLabel: String {
        guard let selectedDeviceID = deviceManager.selectedDeviceID,
              let device = deviceManager.devices.first(where: { $0.device_id == selectedDeviceID }) else {
            return "未選択"
        }

        switch device.device_type.lowercased() {
        case "ios":
            return "iPhone"
        case "observer":
            return "オブザーバー"
        case "android":
            return "Android"
        case "web":
            return "Webブラウザ"
        case "demo":
            return "デモデバイス"
        default:
            return device.device_type
        }
    }

    // MARK: - 認知タイプセクション
    private var cognitiveTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // セクションヘッダー
            Text("タイプ")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            if let subject = deviceManager.selectedSubject, let cognitiveTypeData = subject.cognitiveTypeData {
                // タイプ選択済み - カードのみ表示
                cognitiveTypeCard(for: cognitiveTypeData)
            } else {
                // タイプ未選択 - カルーセル + 選択ボタン
                VStack(spacing: 16) {
                    Text("分析対象のタイプを選択")
                        .font(.headline)
                        .foregroundColor(Color(white: 0.56))

                    // カルーセル
                    TabView(selection: $selectedCognitiveType) {
                        ForEach(CognitiveTypeOption.allCases) { type in
                            cognitiveTypeCard(for: type)
                                .tag(type)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .frame(height: 200)

                    // 選択ボタン
                    Button(action: {
                        selectCognitiveType()
                    }) {
                        HStack {
                            if isUpdatingType {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("このタイプを選択")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.safeColor("AppAccentColor"))
                        .cornerRadius(12)
                    }
                    .disabled(isUpdatingType)
                }
            }
        }
    }

    // MARK: - 認知タイプカード
    private func cognitiveTypeCard(for type: CognitiveTypeOption) -> some View {
        VStack(spacing: 12) {
            Text(type.emoji)
                .font(.system(size: 60))

            Text(type.categoryName)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(type.typeName)
                .font(.title3)
                .foregroundColor(Color(white: 0.56))

            Text(type.description)
                .font(.callout)
                .foregroundColor(Color(white: 0.56))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - タイプ選択処理
    private func selectCognitiveType() {
        guard let subject = deviceManager.selectedSubject,
              let deviceId = deviceManager.selectedDeviceID else { return }

        isUpdatingType = true

        Task {
            do {
                // Update subject using existing updateSubject method
                try await dataManager.updateSubject(
                    subjectId: subject.subjectId,
                    deviceId: deviceId,
                    name: subject.name ?? "",
                    age: subject.age,
                    gender: subject.gender,
                    cognitiveType: selectedCognitiveType.rawValue,
                    prefecture: subject.prefecture,
                    city: subject.city,
                    avatarUrl: nil,
                    notes: subject.notes
                )

                // Update local subject data
                if let userId = userAccountManager.currentUser?.id {
                    await deviceManager.loadDevices(for: userId)
                }

                await MainActor.run {
                    isUpdatingType = false
                }
            } catch {
                print("Error updating cognitive type: \(error)")
                await MainActor.run {
                    isUpdatingType = false
                }
            }
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
                    .foregroundColor(.white)

                Spacer()

                Button(action: { showNeuralInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(Color(white: 0.56))
                }
            }

            // レーダーチャート
            VStack(spacing: 20) {
                RadarChartView(
                    dataPoints: [
                        RadarDataPoint(label: "🎯 注意制御", value: 0.6, color: .accentTeal),
                        RadarDataPoint(label: "🧭 実行機能", value: 0.7, color: .accentTealMuted),
                        RadarDataPoint(label: "⚙️ WM", value: 0.5, color: .accentTeal),
                        RadarDataPoint(label: "❤️ 感情制御", value: 0.4, color: .accentCoral),
                        RadarDataPoint(label: "🌈 発想", value: 0.8, color: .accentTealMuted)
                    ]
                )
                .frame(height: 300)

                // 凡例
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle().fill(Color.accentTeal).frame(width: 12, height: 12)
                        Text("注意制御").font(.caption)
                        Spacer()
                        Text("60%").font(.caption).foregroundColor(Color(white: 0.56))
                    }
                    HStack {
                        Circle().fill(Color.accentTeal).frame(width: 12, height: 12)
                        Text("実行機能").font(.caption)
                        Spacer()
                        Text("70%").font(.caption).foregroundColor(Color(white: 0.56))
                    }
                    HStack {
                        Circle().fill(Color.accentTeal).frame(width: 12, height: 12)
                        Text("ワーキングメモリ").font(.caption)
                        Spacer()
                        Text("50%").font(.caption).foregroundColor(Color(white: 0.56))
                    }
                    HStack {
                        Circle().fill(Color.accentCoral).frame(width: 12, height: 12)
                        Text("感情制御").font(.caption)
                        Spacer()
                        Text("40%").font(.caption).foregroundColor(Color(white: 0.56))
                    }
                    HStack {
                        Circle().fill(Color.accentTealMuted).frame(width: 12, height: 12)
                        Text("発想流動性").font(.caption)
                        Spacer()
                        Text("80%").font(.caption).foregroundColor(Color(white: 0.56))
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.darkCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
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
                    .foregroundColor(.white)

                Spacer()

                Button(action: { showIntelligenceInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(Color(white: 0.56))
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
                    .fill(Color.darkCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
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
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        .frame(width: radius * 2, height: radius * 2)
                }

                // データのポリゴン
                RadarPolygonShape(
                    sides: dataPoints.count,
                    scale: 1.0,
                    values: dataPoints.map { $0.value }
                )
                .fill(Color.accentTeal.opacity(0.22))
                .frame(width: radius * 2, height: radius * 2)

                RadarPolygonShape(
                    sides: dataPoints.count,
                    scale: 1.0,
                    values: dataPoints.map { $0.value }
                )
                .stroke(Color.accentTeal, lineWidth: 2)
                .frame(width: radius * 2, height: radius * 2)

                // ラベル
                ForEach(0..<dataPoints.count, id: \.self) { index in
                    let angle = Double(index) * (360.0 / Double(dataPoints.count)) - 90
                    let radian = angle * .pi / 180
                    let x = center.x + CGFloat(cos(radian)) * (radius + 30)
                    let y = center.y + CGFloat(sin(radian)) * (radius + 30)

                    Text(dataPoints[index].label)
                        .font(.caption)
                        .foregroundColor(.white)
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
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Color(white: 0.56))
                }
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.56))
                    .monospacedDigit()
            }

            // プログレスバー
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.10))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentTeal.opacity(0.85))
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
                        .foregroundColor(.white)
                        .lineSpacing(4)
                }
                .padding(20)
            }
            .background(Color.darkBase)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.darkBase, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
