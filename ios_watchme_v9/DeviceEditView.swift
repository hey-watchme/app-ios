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
    @EnvironmentObject var userAccountManager: UserAccountManager
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
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var isGeneratingQR = false
    @State private var qrCodeUrl: String?

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

                    // QRコード共有セクション
                    VStack(alignment: .leading, spacing: 12) {
                        Label("デバイス共有用QRコード", systemImage: "qrcode")
                            .font(.headline)
                            .foregroundColor(.primary)

                        if let qrUrl = qrCodeUrl {
                            // QRコード画像を表示
                            VStack(spacing: 12) {
                                AsyncImage(url: URL(string: qrUrl)) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 200, height: 200)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 200, height: 200)
                                            .cornerRadius(12)
                                    case .failure:
                                        Image(systemName: "exclamationmark.triangle")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 200, height: 200)
                                            .foregroundColor(.gray)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)

                                // 共有ボタン
                                if let url = URL(string: qrUrl) {
                                    ShareLink(item: url) {
                                        Label("QRコードを共有", systemImage: "square.and.arrow.up")
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(Color.blue)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                        } else {
                            // QRコード生成ボタン
                            Button(action: {
                                Task {
                                    await generateQRCode()
                                }
                            }) {
                                HStack {
                                    if isGeneratingQR {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                        Text("生成中...")
                                    } else {
                                        Image(systemName: "qrcode")
                                        Text("QRコードを生成")
                                    }
                                }
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue.opacity(isGeneratingQR ? 0.6 : 1.0))
                                .cornerRadius(12)
                            }
                            .disabled(isGeneratingQR)
                        }
                    }
                    .padding(.top, 8)


                    // Unlink device button (always visible if user can unlink)
                    if device.canUnlinkDevice {
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
                    }

                    // Delete device button (only for owners of non-demo devices)
                    if device.canDeleteDevice {
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack {
                                if isDeleting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                    Text("削除中...")
                                } else {
                                    Image(systemName: "trash.fill")
                                    Text("このデバイスを削除")
                                }
                            }
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.8).opacity(isDeleting ? 0.6 : 1.0))
                            .cornerRadius(12)
                        }
                        .disabled(isDeleting || isUnlinking)
                    }

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
        .alert("このデバイスを削除しますか？", isPresented: $showDeleteConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("削除する", role: .destructive) {
                Task {
                    await deleteDevice()
                }
            }
        } message: {
            Text("デバイス本体とすべての連携が削除されます。この操作は取り消せません。\n\n本当に削除しますか？")
        }
    }
    
    private func loadDeviceInfo() {
        // Load device info
        deviceType = device.device_type
        timezone = device.timezone ?? "未設定"
        qrCodeUrl = device.qr_code_url
    }

    private func generateQRCode() async {
        print("🔵 [DeviceEditView] QRコード生成開始")
        print("   - Device ID: \(device.device_id)")

        await MainActor.run {
            isGeneratingQR = true
        }

        do {
            print("📡 [DeviceEditView] QRCodeService呼び出し中...")
            let generatedUrl = try await QRCodeService.shared.generateQRCode(for: device.device_id)

            await MainActor.run {
                qrCodeUrl = generatedUrl
                isGeneratingQR = false
            }

            print("✅ [DeviceEditView] QR code generated: \(generatedUrl)")

            // Refresh device list to update qr_code_url in DeviceManager
            if let userId = userAccountManager.currentUser?.profile?.userId {
                await deviceManager.fetchUserDevices(for: userId)
            }
        } catch {
            await MainActor.run {
                isGeneratingQR = false
                errorMessage = "QRコードの生成に失敗しました: \(error.localizedDescription)"
                showErrorAlert = true
            }
            print("❌ [DeviceEditView] QR code generation error: \(error)")
            print("   - Device ID: \(device.device_id)")
            print("   - Error details: \(error)")
        }
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

    private func deleteDevice() async {
        await MainActor.run {
            isDeleting = true
        }

        do {
            // NetworkManagerを遅延初期化（削除時のみインスタンス化）
            let networkManager = NetworkManager()
            try await networkManager.deleteDevice(deviceId: device.device_id)

            // 成功したら少し待ってから画面を閉じる
            try? await Task.sleep(nanoseconds: 500_000_000)

            await MainActor.run {
                isPresented = false
            }

            // デバイスリストを再読み込み
            if let userId = userAccountManager.currentUser?.profile?.userId {
                await deviceManager.initializeDevices(for: userId)
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                errorMessage = "デバイスの削除に失敗しました: \(error.localizedDescription)"
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
            status: "active",
            role: "owner"
        )
        
        DeviceEditView(device: sampleDevice, isPresented: .constant(true))
            .environmentObject(DeviceManager())
            .environmentObject(SupabaseDataManager())
            .environmentObject(UserAccountManager(deviceManager: DeviceManager()))
    }
}