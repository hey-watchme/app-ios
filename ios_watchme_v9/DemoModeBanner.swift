//
//  DemoModeBanner.swift
//  ios_watchme_v9
//
//  デモモード時に表示するオーバーレイバナー
//

import SwiftUI

struct DemoModeBanner: View {
    @State private var showInfo = false
    @EnvironmentObject var deviceManager: DeviceManager

    var body: some View {
        VStack {
            Spacer()

            // バナー本体（全体をクリッカブルに）
            Button(action: {
                showInfo.toggle()
            }) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16))

                    Text("サンプルデバイス選択中")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        showInfo.toggle()
                    }) {
                        Text("詳細")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.purple.opacity(0.9)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .shadow(radius: 4, y: -2)
        }
        .animation(.easeInOut, value: showInfo)
        .sheet(isPresented: $showInfo) {
            DemoModeInfoSheet()
                .environmentObject(deviceManager)
        }
    }
}

// デモモードの詳細説明シート
struct DemoModeInfoSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var deviceManager: DeviceManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // ヘッダー
                    VStack(alignment: .leading, spacing: 8) {
                        Text("サンプルデバイスについて")
                            .font(.system(size: 30))
                            .fontWeight(.bold)

                        Text("このデモでは、架空の分析対象の分析結果を見ることができます。「オブザーバー」と呼ばれる音声分析デバイスから定期的にデータが送られてくるので、リアルタイムで状態をチェックすることが可能です。WatchMeを通じて何が分かるのか、体験してみてください。")
                            .font(.system(size: 16))
                            .foregroundColor(Color(white: 0.56))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 10)

                    // 利用可能な機能
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("利用可能な機能")
                                .foregroundColor(.white)
                        }
                        .font(.system(size: 20, weight: .semibold))

                        VStack(alignment: .leading, spacing: 8) {
                            DemoFeatureRow(icon: "chart.line.uptrend.xyaxis", text: "ダッシュボード・グラフの閲覧", isAvailable: true)
                            DemoFeatureRow(icon: "calendar", text: "過去のデータ参照", isAvailable: true)
                            DemoFeatureRow(icon: "hand.tap", text: "UIの操作体験", isAvailable: true)
                        }
                        .padding(.leading, 8)
                    }

                    Divider().background(Color.white.opacity(0.08))

                    // 利用できない機能
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("利用できない機能")
                                .foregroundColor(.white)
                        }
                        .font(.system(size: 20, weight: .semibold))

                        VStack(alignment: .leading, spacing: 8) {
                            DemoFeatureRow(icon: "mic.fill", text: "音声分析", isAvailable: false)
                            DemoFeatureRow(icon: "plus.circle", text: "デバイスの追加・編集", isAvailable: false)
                            DemoFeatureRow(icon: "bubble.left", text: "コメント投稿", isAvailable: false)
                            DemoFeatureRow(icon: "envelope", text: "ニュースレターの購読", isAvailable: false)
                        }
                        .padding(.leading, 8)
                    }

                    Divider().background(Color.white.opacity(0.08))

                    // デモ終了ボタン
                    Button(action: {
                        // 実デバイスがあれば優先選択し、なければ未選択に戻す
                        if let ownerRealDevice = deviceManager.realDevices.first(where: { $0.role == "owner" }) {
                            deviceManager.selectDevice(ownerRealDevice.device_id)
                        } else if let firstRealDevice = deviceManager.realDevices.first {
                            deviceManager.selectDevice(firstRealDevice.device_id)
                        } else {
                            deviceManager.selectDevice(nil)
                        }
                        // シートを閉じる
                        dismiss()
                    }) {
                        Text("デモを終了する")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentTeal)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .background(Color.darkBase.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.darkBase, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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

// 機能の行表示用コンポーネント
struct DemoFeatureRow: View {
    let icon: String
    let text: String
    var isAvailable: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.white)

            Text(text)
                .font(.footnote)
                .foregroundColor(Color(white: 0.56))

            Spacer()
        }
    }
}

struct DemoModeBanner_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.1)
                .ignoresSafeArea()

            DemoModeBanner()
        }
    }
}
