//
//  DeviceSettingsView.swift
//  ios_watchme_v9
//
//  デバイス設定画面（マイページのデバイス版）
//  独立したページとして実装
//

import SwiftUI

// MARK: - 編集コンテキスト

struct SubjectEditingContext: Identifiable {
    let id = UUID()
    let deviceID: String
    let editingSubject: Subject?

    var isEditing: Bool {
        editingSubject != nil
    }
}

struct DeviceEditingContext: Identifiable {
    let id = UUID()
    let device: Device
}

// MARK: - メインビュー

struct DeviceSettingsView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var userAccountManager: UserAccountManager
    @Environment(\.dismiss) var dismiss

    // MARK: - State
    // サンプルデバイスはDeviceManagerで統合管理されるため削除
    @State private var isLoading = true

    // MARK: - Sheet State
    @State private var showQRScanner = false
    @State private var editingContext: SubjectEditingContext? = nil
    @State private var deviceEditingContext: DeviceEditingContext? = nil

    // MARK: - Alert State
    @State private var showAddDeviceAlert = false
    @State private var addDeviceError: String?
    @State private var showSuccessAlert = false
    @State private var addedDeviceId: String?

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // DeviceManager.stateに基づいた表示切り替え
                switch deviceManager.state {
                case .idle, .loading:
                    ProgressView("デバイス一覧を読み込み中...")
                        .frame(maxWidth: .infinity, minHeight: 200)

                case .available(let allDevices):
                    // Classify devices by type
                    let observerDevices = allDevices.filter { $0.device_type == "observer" }
                    let iosDevices = allDevices.filter { $0.device_type == "ios" || $0.device_type == "android" }
                    let sampleDevices = allDevices.filter { $0.device_type == "demo" }

                    // Show empty state only if no devices at all
                    if allDevices.isEmpty {
                        EmptyDeviceState()
                    } else {
                        // Observer Section
                        if !observerDevices.isEmpty {
                            DeviceList(title: "Observer", devices: observerDevices)
                            Spacer().frame(height: 50)
                        }

                        // iPhone Section
                        if !iosDevices.isEmpty {
                            DeviceList(title: "iPhone", devices: iosDevices)
                            Spacer().frame(height: 50)
                        }

                        // Sample Devices Section
                        if !sampleDevices.isEmpty {
                            DeviceList(title: "サンプルデバイス", devices: sampleDevices, isSampleSection: true)
                            Spacer().frame(height: 50)
                        }
                    }

                    DeviceAddCard()

                    Spacer(minLength: 100)

                case .error(let message):
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("エラーが発生しました")
                            .font(.title3)
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(.top, 20)
        }
        .background(Color.safeColor("BehaviorBackgroundPrimary").ignoresSafeArea())
        .navigationTitle("デバイス設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            // DeviceManager.stateが既に.availableの場合は何もしない
            if case .idle = deviceManager.state {
                print("⚠️ DeviceSettingsView: DeviceManager未初期化 - 初期化が必要")
            } else if case .available = deviceManager.state {
                print("✅ DeviceSettingsView: DeviceManager初期化済み - 表示準備完了")
            }
            // ローディング状態を解除
            isLoading = false
        }
        // 📊 パフォーマンス最適化: デバイス選択時のstate変更による不要なリロードを防止
        // デバイスデータは既にDeviceManagerで管理されているため、特別な処理は不要
        // SubjectUpdated通知は削除（selectedSubjectが計算プロパティになったため不要）
        .sheet(isPresented: $showQRScanner) {
            QRCodeScannerView(isPresented: $showQRScanner) { scannedCode in
                Task { await handleQRCodeScanned(scannedCode) }
            }
        }
        .sheet(item: $editingContext) { context in
            SubjectRegistrationView(
                deviceID: context.deviceID,
                isPresented: .constant(false),
                editingSubject: context.editingSubject
            )
            .environmentObject(dataManager)
            .environmentObject(deviceManager)
            .environmentObject(userAccountManager)
        }
        .sheet(item: $deviceEditingContext, onDismiss: {
            // 📊 パフォーマンス最適化: デバイス編集後の不要な再読み込みを削除
            // ⚠️ 旧: fetchUserDevices() + loadAllData() → 全データ再読み込み（重い、チラつきの原因）
            // ✅ 新: 何もしない（デバイス情報は既に取得済み、変更があればdeviceManagerが自動で反映）
            // 注意: デバイス削除時はDeviceManager側で自動的にリストが更新される
        }) { context in
            DeviceEditView(
                device: context.device,
                isPresented: Binding(
                    get: { deviceEditingContext != nil },
                    set: { if !$0 { deviceEditingContext = nil } }
                )
            )
            .environmentObject(deviceManager)
            .environmentObject(dataManager)
            .environmentObject(userAccountManager)
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
    private func DeviceList(title: String, devices: [Device], isSampleSection: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal)

            // Display devices (reversed order)
            ForEach(devices.reversed(), id: \.device_id) { device in
                DeviceCard(
                    device: device,
                    isSelected: device.device_id == deviceManager.selectedDeviceID,
                    subject: device.subject,
                    onSelect: {
                        // ラジオボタン方式: 常に1つ選択状態を維持（解除はしない）
                        deviceManager.selectDevice(device.device_id)
                        dismiss()
                    },
                    onEditSubject: { subject in
                        // Always allow navigation (view/edit depends on device permissions)
                        editingContext = SubjectEditingContext(
                            deviceID: device.device_id,
                            editingSubject: subject
                        )
                    },
                    onAddSubject: {
                        // Allow navigation if device can edit subject
                        if device.canEditSubject {
                            editingContext = SubjectEditingContext(
                                deviceID: device.device_id,
                                editingSubject: nil
                            )
                        }
                    },
                    onEditDevice: {
                        // Always allow navigation (view/edit depends on device permissions)
                        deviceEditingContext = DeviceEditingContext(device: device)
                    }
                )
                .id(device.device_id)
                .padding(.horizontal)
            }
        }
    }


    // MARK: - Device Add Card
    @ViewBuilder
    private func DeviceAddCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新しいデバイス")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal)

            UnifiedCard(title: "デバイスを追加") {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("録音デバイスに表示されたQRコードをスキャンすると、デバイス一覧に追加されます。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("デモデータ登録する時も、こちらからご登録いただけます。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: {
                        showQRScanner = true
                    }) {
                        HStack {
                            Image(systemName: "qrcode")
                            Text("QRコードをスキャン")
                        }
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.safeColor("AppAccentColor"))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Data Loading
    // loadAllData()とloadSampleDevice()は削除
    // → DeviceManagerで一元管理されるため不要


    /// QRコードをスキャンしてデバイスを追加
    private func handleQRCodeScanned(_ code: String) async {
        if deviceManager.devices.contains(where: { $0.device_id == code }) {
            addDeviceError = "このデバイスは既に追加されています。"
            showAddDeviceAlert = true
            return
        }

        do {
            if let userId = userAccountManager.effectiveUserId {
                try await deviceManager.addDeviceByQRCode(code, for: userId)
                addedDeviceId = code
                showSuccessAlert = true
                // DeviceManagerのfetchUserDevicesが自動的にinitializeDevicesを呼び出す
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
                .environmentObject(UserAccountManager(deviceManager: DeviceManager()))
        }
    }
}
