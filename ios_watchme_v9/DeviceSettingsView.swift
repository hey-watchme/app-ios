//
//  DeviceSettingsView.swift
//  ios_watchme_v9
//
//  デバイス設定画面（マイページのデバイス版）
//  独立したページとして実装
//

import SwiftUI

struct DeviceSettingsView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var authManager: SupabaseAuthManager
    @State private var subjectsByDevice: [String: Subject] = [:]
    @State private var showQRScanner = false
    @State private var showAddDeviceAlert = false
    @State private var addDeviceError: String?
    @State private var showSuccessAlert = false
    @State private var addedDeviceId: String?
    @State private var showSubjectRegistration = false
    @State private var showSubjectEdit = false
    @State private var selectedDeviceForSubject: String? = nil
    @State private var editingSubject: Subject? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if deviceManager.isLoading {
                    ProgressView("デバイス一覧を読み込み中...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if deviceManager.userDevices.isEmpty {
                    EmptyDeviceState()
                } else {
                    DeviceList()
                }
                
                // デバイス追加カード
                DeviceAddCard()
                
                Spacer(minLength: 100)
            }
            .padding(.top, 20)
        }
        .background(
            Color(red: 0.937, green: 0.937, blue: 0.937)
                .ignoresSafeArea()
        )
        .navigationTitle("デバイス設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            loadSubjectsForAllDevices()
        }
        .sheet(isPresented: $showQRScanner) {
            QRCodeScannerView(isPresented: $showQRScanner) { scannedCode in
                Task {
                    await handleQRCodeScanned(scannedCode)
                }
            }
        }
        .sheet(isPresented: $showSubjectRegistration, onDismiss: {
            loadSubjectsForAllDevices()
        }) {
            if let deviceID = selectedDeviceForSubject {
                SubjectRegistrationView(
                    deviceID: deviceID,
                    isPresented: $showSubjectRegistration,
                    editingSubject: nil
                )
                .environmentObject(dataManager)
                .environmentObject(deviceManager)
                .environmentObject(authManager)
            }
        }
        .sheet(isPresented: $showSubjectEdit, onDismiss: {
            loadSubjectsForAllDevices()
        }) {
            if let deviceID = selectedDeviceForSubject,
               let subject = editingSubject {
                SubjectRegistrationView(
                    deviceID: deviceID,
                    isPresented: $showSubjectEdit,
                    editingSubject: subject
                )
                .environmentObject(dataManager)
                .environmentObject(deviceManager)
                .environmentObject(authManager)
            }
        }
        .alert("デバイス追加エラー", isPresented: $showAddDeviceAlert, presenting: addDeviceError) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error)
        }
        .alert("デバイスを追加しました", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let deviceId = addedDeviceId {
                Text("device_id: \(deviceId.prefix(8))... が閲覧可能になりました！")
            }
        }
    }
    
    // MARK: - Empty State
    @ViewBuilder
    private func EmptyDeviceState() -> some View {
        UnifiedCard(title: "デバイス") {
            VStack(spacing: 20) {
                Image(systemName: "iphone.slash")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
                
                Text("連携されたデバイスがありません")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Text("他のデバイスから測定データを\n共有することができます")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 20)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Device List
    @ViewBuilder
    private func DeviceList() -> some View {
        VStack(spacing: 16) {
            // 新しく登録されたデバイスが上に来るよう逆順でソート
            ForEach(Array(deviceManager.userDevices.reversed().enumerated()), id: \.element.device_id) { index, device in
                DeviceCard(
                    device: device,
                    isSelected: device.device_id == deviceManager.selectedDeviceID,
                    subject: subjectsByDevice[device.device_id],
                    onSelect: {
                        deviceManager.selectDevice(device.device_id)
                    },
                    onEditSubject: { subject in
                        selectedDeviceForSubject = device.device_id
                        editingSubject = subject
                        showSubjectEdit = true
                    },
                    onAddSubject: {
                        selectedDeviceForSubject = device.device_id
                        showSubjectRegistration = true
                    }
                )
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Device Add Card
    @ViewBuilder
    private func DeviceAddCard() -> some View {
        UnifiedCard(title: "新しいデバイス") {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("QRコードでデバイスを追加")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("他のデバイスから共有されたQRコードをスキャンしてください")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Button(action: {
                    showQRScanner = true
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("QRコードをスキャン")
                    }
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
        .padding(.horizontal)
    }
    
    // MARK: - Helper Methods
    private func loadSubjectsForAllDevices() {
        Task {
            var newSubjects: [String: Subject] = [:]
            
            for device in deviceManager.userDevices {
                // 各デバイスの観測対象を取得
                await dataManager.fetchSubjectForDevice(deviceId: device.device_id)
                if let subject = dataManager.subject {
                    newSubjects[device.device_id] = subject
                }
            }
            
            await MainActor.run {
                self.subjectsByDevice = newSubjects
            }
        }
    }
    
    private func handleQRCodeScanned(_ code: String) async {
        // UUIDの妥当性チェック
        guard UUID(uuidString: code) != nil else {
            addDeviceError = "無効なQRコードです。デバイスIDが正しくありません。"
            showAddDeviceAlert = true
            return
        }
        
        // 既に追加済みかチェック
        if deviceManager.userDevices.contains(where: { $0.device_id == code }) {
            addDeviceError = "このデバイスは既に追加されています。"
            showAddDeviceAlert = true
            return
        }
        
        // デバイスを追加
        do {
            if let userId = authManager.currentUser?.id {
                try await deviceManager.addDeviceByQRCode(code, for: userId)
                // 成功時のフィードバック
                addedDeviceId = code
                showSuccessAlert = true
                // サブジェクト情報を再読み込み
                loadSubjectsForAllDevices()
            } else {
                addDeviceError = "ユーザー情報の取得に失敗しました。"
                showAddDeviceAlert = true
            }
        } catch {
            addDeviceError = "デバイスの追加に失敗しました: \(error.localizedDescription)"
            showAddDeviceAlert = true
        }
    }
}

// MARK: - Preview
struct DeviceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DeviceSettingsView()
                .environmentObject(DeviceManager())
                .environmentObject(SupabaseDataManager())
                .environmentObject(SupabaseAuthManager(deviceManager: DeviceManager()))
        }
    }
}