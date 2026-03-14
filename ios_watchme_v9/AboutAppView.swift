//
//  AboutAppView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/08/19.
//

import SwiftUI

struct AboutAppView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // アプリアイコンとバージョン情報
                        VStack(spacing: 16) {
                            Image("AppIcon")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .cornerRadius(20)
                                .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)

                            Text("WatchMe")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Text("バージョン 9.21.0")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)

                        VStack(alignment: .leading, spacing: 20) {
                            // アプリの概要
                            Section {
                                Text("WatchMeについて")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("""
                                WatchMeは、音声の言語的情報に加えて、韻律的情報（声の抑揚・テンポ・間など）を分析し、心理状態や発達特性を可視化して課題解決に役立てるサポートツールです。

                                WatchMeはデバイスを使った自動音声記録を活用したサポートツールですが、アプリ単体でもデバイスのマイク、カメラロールの動画、またはデバイスに保存された他の音声ファイルを使用して録音・分析できます。ぜひ機能をお試しください。
                                """)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }

                            Divider()
                                .background(Color(.separator))

                            // 主な機能
                            Section {
                                Text("主な機能")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                VStack(alignment: .leading, spacing: 12) {
                                    FeatureRow(icon: "mic.fill", title: "デバイスを使った自動音声記録（オプション）", description: "対応デバイス利用時に自動音声記録を有効化できます")
                                    FeatureRow(icon: "waveform", title: "アプリ単体での録音・分析", description: "端末マイク・カメラロール動画・端末内音声ファイルに対応")
                                    FeatureRow(icon: "brain", title: "AI感情分析", description: "最新のAI技術で感情を分析")
                                    FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "データ可視化", description: "感情や行動をグラフで表示")
                                    FeatureRow(icon: "shield.fill", title: "プライバシー保護", description: "データは安全に暗号化して保存")
                                }
                            }

                            Divider()
                                .background(Color(.separator))

                            // 開発情報
                            Section {
                                Text("開発情報")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                VStack(alignment: .leading, spacing: 8) {
                                    InfoPair(label: "開発元", value: "WatchMe Team")
                                    InfoPair(label: "サポート", value: "support@hey-watch.me")
                                    InfoPair(label: "ウェブサイト", value: "https://hey-watch.me")
                                }
                            }

                            Divider()
                                .background(Color(.separator))

                            // 利用上の案内
                            Section {
                                Text("利用上の案内")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("""
                                • 本アプリは日常の状態把握と支援を目的としたツールであり、医療診断を行うものではありません。
                                • 分析結果は録音環境や入力データの品質により変動する場合があります。
                                • データの取り扱いについては、プライバシーポリシーおよび利用規約をご確認ください。
                                """)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }

                            // コピーライト
                            Text("© WatchMe Team. All rights reserved.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 20)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("このアプリについて")
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

// MARK: - Helper Views
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentTeal)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct InfoPair: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
        .font(.subheadline)
    }
}

#Preview {
    AboutAppView()
}
