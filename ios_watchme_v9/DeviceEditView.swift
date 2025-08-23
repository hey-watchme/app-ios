//
//  DeviceEditView.swift
//  ios_watchme_v9
//
//  デバイス情報編集画面
//

import SwiftUI

struct DeviceEditView: View {
    let device: Device
    @Binding var isPresented: Bool
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @State private var deviceName: String = ""
    @State private var deviceType: String = ""
    @State private var timezone: String = ""
    @State private var notes: String = ""
    @State private var isLoading = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showUnlinkConfirmation = false
    @State private var isUnlinking = false
    @State private var showUnlinkSuccess = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // デバイスID（読み取り専用）
                    VStack(alignment: .leading, spacing: 8) {
                        Label("デバイスID", systemImage: "qrcode")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(device.device_id)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.secondary)
                    }
                    
                    // デバイスタイプ（読み取り専用）
                    VStack(alignment: .leading, spacing: 8) {
                        Label("デバイスタイプ", systemImage: "iphone")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(getDeviceTypeDisplayName())
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.secondary)
                    }
                    
                    // デバイスタイムゾーン（読み取り専用）
                    VStack(alignment: .leading, spacing: 8) {
                        Label("デバイスタイムゾーン", systemImage: "globe")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(device.timezone ?? "未設定")
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.secondary)
                    }
                    
                    // 権限（読み取り専用）
                    if let role = device.role {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("権限", systemImage: role == "owner" ? "crown.fill" : "eye.fill")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(role == "owner" ? "オーナー" : "閲覧者")
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 登録日時（読み取り専用）
                    if let createdAt = device.created_at {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("登録日時", systemImage: "calendar")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(formatCreatedDate(createdAt))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    
                    // デバイス連携解除ボタン
                    Button(action: {
                        showUnlinkConfirmation = true
                    }) {
                        HStack {
                            if isUnlinking {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("解除中...")
                            } else {
                                Image(systemName: "minus.circle.fill")
                                Text("デバイス連携解除")
                            }
                        }
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(isUnlinking ? 0.6 : 1.0))
                        .cornerRadius(12)
                    }
                    .disabled(isUnlinking)
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("デバイス詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        isPresented = false
                    }
                }
                
                // 将来的に保存機能を実装する場合はここに追加
                /*
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        Task {
                            await saveDeviceInfo()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(isLoading)
                }
                */
            }
        }
        .onAppear {
            loadDeviceInfo()
        }
        .alert("成功", isPresented: $showSuccessAlert) {
            Button("OK") {
                isPresented = false
            }
        } message: {
            Text("デバイス情報を更新しました")
        }
        .alert("エラー", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("デバイス連携を解除しますか？", isPresented: $showUnlinkConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("解除する", role: .destructive) {
                Task {
                    await unlinkDevice()
                }
            }
        } message: {
            Text("このアカウントとデバイスの連携が解除され、データを閲覧できなくなります。\n\n本当に解除しますか？")
        }
    }
    
    private func loadDeviceInfo() {
        // 将来的にデバイス名などを読み込む場合はここで実装
        deviceType = device.device_type
        timezone = device.timezone ?? "未設定"
    }
    
    private func saveDeviceInfo() async {
        // 将来的にデバイス情報を保存する機能を実装
        isLoading = true
        defer { isLoading = false }
        
        // TODO: Supabaseでデバイス情報を更新する処理を実装
        // 現時点では読み取り専用なので何もしない
        
        showSuccessAlert = true
    }
    
    private func getDeviceTypeDisplayName() -> String {
        switch device.device_type.lowercased() {
        case "ios":
            return "iPhone/iPad"
        case "android":
            return "Android"
        case "web":
            return "Webブラウザ"
        default:
            return device.device_type.capitalized
        }
    }
    
    private func formatCreatedDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .long
            displayFormatter.timeStyle = .short
            displayFormatter.locale = Locale(identifier: "ja_JP")
            return displayFormatter.string(from: date)
        }
        return dateString
    }
    
    private func unlinkDevice() async {
        await MainActor.run {
            isUnlinking = true
        }
        
        do {
            // デバイス連携を解除
            try await deviceManager.unlinkDevice(device.device_id)
            
            // 成功したら少し待ってから画面を閉じる
            await MainActor.run {
                showUnlinkSuccess = true
            }
            
            // 0.5秒待つ（ユーザーが成功を認識できるように）
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                isPresented = false
            }
        } catch {
            await MainActor.run {
                isUnlinking = false
                errorMessage = "デバイス連携の解除に失敗しました: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }
}

// MARK: - Preview
struct DeviceEditView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleDevice = Device(
            device_id: "12345678-1234-1234-1234-123456789012",
            device_type: "ios",
            timezone: "Asia/Tokyo",
            owner_user_id: "user1",
            subject_id: nil,
            created_at: "2025-08-15T10:30:00Z",
            role: "owner"
        )
        
        DeviceEditView(device: sampleDevice, isPresented: .constant(true))
            .environmentObject(DeviceManager())
            .environmentObject(SupabaseDataManager())
    }
}