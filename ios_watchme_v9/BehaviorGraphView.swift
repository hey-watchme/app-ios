//
//  BehaviorGraphView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/25.
//

import SwiftUI

struct BehaviorGraphView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.5))
            
            Text("行動グラフ")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Coming Soon")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("行動パターンの分析機能を準備中です")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .navigationTitle("行動グラフ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        BehaviorGraphView()
    }
}