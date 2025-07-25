//
//  EmotionGraphView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/25.
//

import SwiftUI

struct EmotionGraphView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "heart.text.square")
                .font(.system(size: 80))
                .foregroundColor(.pink.opacity(0.5))
            
            Text("感情グラフ")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Coming Soon")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("感情の変化を詳細に分析する機能を準備中です")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .navigationTitle("感情グラフ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        EmotionGraphView()
    }
}