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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // アプリアイコンとバージョン情報
                    VStack(spacing: 16) {
                        Image("AppIcon")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .cornerRadius(20)
                            .shadow(radius: 5)
                        
                        Text("WatchMe")
                            .font(.title)
                            .fontWeight(.bold)
                        
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
                            
                            Text("""
                            WatchMeは、日々の感情や行動を記録し、AIによる分析を通じて心理状態や生活パターンを可視化するライフログアプリケーションです。
                            
                            30分ごとの自動音声記録により、あなたの一日を詳細に記録し、感情の変化や行動パターンを分析します。
                            """)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        
                        Divider()
                        
                        // 主な機能
                        Section {
                            Text("主な機能")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                FeatureRow(icon: "mic.fill", title: "自動音声記録", description: "30分ごとに自動で音声を記録")
                                FeatureRow(icon: "brain", title: "AI感情分析", description: "最新のAI技術で感情を分析")
                                FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "データ可視化", description: "感情や行動をグラフで表示")
                                FeatureRow(icon: "shield.fill", title: "プライバシー保護", description: "データは安全に暗号化して保存")
                            }
                        }
                        
                        Divider()
                        
                        // 開発情報
                        Section {
                            Text("開発情報")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                InfoPair(label: "開発元", value: "WatchMe Team")
                                InfoPair(label: "サポート", value: "support@watchme.app")
                                InfoPair(label: "ウェブサイト", value: "https://watchme.app")
                            }
                        }
                        
                        Divider()
                        
                        // 謝辞
                        Section {
                            Text("謝辞")
                                .font(.headline)
                            
                            Text("""
                            WatchMeの開発にあたり、多くのオープンソースプロジェクトを利用させていただいています。
                            
                            • Supabase - 認証とデータベース
                            • OpenAI - 感情分析エンジン
                            • Swift Package Manager - 依存関係管理
                            
                            すべての貢献者の皆様に感謝いたします。
                            """)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        
                        // コピーライト
                        Text("© 2025 WatchMe Team. All rights reserved.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 20)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("このアプリについて")
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

// MARK: - Helper Views
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
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