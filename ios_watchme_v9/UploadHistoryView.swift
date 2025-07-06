//
//  UploadHistoryView.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/07/06.
//

import SwiftUI

struct UploadHistoryView: View {
    @State private var historyItems: [UploadHistoryItem] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("履歴を読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if historyItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("アップロード履歴がありません")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("録音をアップロードすると、ここに履歴が表示されます")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section(header: 
                            HStack {
                                Text("アップロード済みファイル")
                                Spacer()
                                Text("\(historyItems.count)件")
                                    .foregroundColor(.secondary)
                            }
                        ) {
                            ForEach(historyItems.indices, id: \.self) { index in
                                UploadHistoryRowView(item: historyItems[index])
                            }
                        }
                    }
                    .refreshable {
                        loadHistory()
                    }
                }
            }
            .navigationTitle("アップロード履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("クリア") {
                        clearHistory()
                    }
                    .foregroundColor(.red)
                    .disabled(historyItems.isEmpty)
                }
            }
        }
        .onAppear {
            loadHistory()
        }
    }
    
    private func loadHistory() {
        isLoading = true
        
        DispatchQueue.global(qos: .background).async {
            let items = UploadManager.getUploadHistory()
            
            DispatchQueue.main.async {
                self.historyItems = items
                self.isLoading = false
            }
        }
    }
    
    private func clearHistory() {
        UserDefaults.standard.removeObject(forKey: "uploadHistory")
        historyItems = []
        print("🗑️ アップロード履歴をクリア")
    }
}

struct UploadHistoryRowView: View {
    let item: UploadHistoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(item.fileSizeFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("録音: \(DateFormatter.historyDate.string(from: item.originalDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("アップロード: \(DateFormatter.historyDate.string(from: item.uploadedAt))")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
        }
        .padding(.vertical, 4)
    }
}

// 日付フォーマッター拡張
extension DateFormatter {
    static let historyDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

#Preview {
    UploadHistoryView()
}