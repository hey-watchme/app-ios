//
//  UploadUIUpdateTest.swift
//  ios_watchme_v9
//
//  UI更新問題の検証用テストコード
//

import SwiftUI

// テスト用のビュー
struct UploadUIUpdateTestView: View {
    @StateObject private var testRecording = RecordingModel(fileName: "test.wav", date: Date())
    @State private var updateCount = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("アップロード状態テスト")
                .font(.title)
            
            // RecordingModelの状態表示
            VStack(alignment: .leading, spacing: 10) {
                Text("ファイル名: \(testRecording.fileName)")
                Text("アップロード済み: \(testRecording.isUploaded ? "✅" : "❌")")
                Text("更新回数: \(updateCount)")
            }
            .padding()
            .background(Color.safeColor("BorderLight").opacity(0.1))
            .cornerRadius(10)
            
            // 状態変更ボタン
            HStack(spacing: 20) {
                Button("アップロード済みに変更") {
                    testRecording.markAsUploaded()
                    updateCount += 1
                    print("✅ markAsUploaded呼び出し - isUploaded: \(testRecording.isUploaded)")
                }
                .padding()
                .background(Color.safeColor("SuccessColor"))
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("リセット") {
                    testRecording.resetUploadStatus()
                    updateCount += 1
                    print("🔄 resetUploadStatus呼び出し - isUploaded: \(testRecording.isUploaded)")
                }
                .padding()
                .background(Color.safeColor("WarningColor"))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // RecordingRowViewのテスト
            Text("RecordingRowViewのテスト:")
                .font(.headline)
                .padding(.top)
            
            RecordingRowView(
                recording: testRecording,
                isSelected: false,
                onSelect: {
                    print("行が選択されました")
                },
                onDelete: { _ in
                    print("削除がリクエストされました")
                }
            )
            .padding()
            
            Spacer()
        }
        .padding()
        .onReceive(testRecording.$isUploaded) { newValue in
            print("📊 isUploadedの変更を検知: \(newValue)")
        }
    }
}

// プレビュー
struct UploadUIUpdateTestView_Previews: PreviewProvider {
    static var previews: some View {
        UploadUIUpdateTestView()
    }
}