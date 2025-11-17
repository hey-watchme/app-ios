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

    // MARK: - State
    @State private var subjectsByDevice: [String: Subject] = [:]
    @State private var sampleDevice: Device? = nil
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
                if isLoading {
                    ProgressView("デバイス一覧を読み込み中...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if deviceManager.devices.isEmpty {
                    EmptyDeviceState()
                } else {
                    DeviceList()
                }

                Spacer().frame(height: 50)

                SampleDeviceSection()

                Spacer().frame(height: 50)

                DeviceAddCard()

                Spacer(minLength: 100)
            }
            .padding(.top, 20)
        }
        .background(Color.safeColor("BehaviorBackgroundPrimary").ignoresSafeArea())
        .navigationTitle("デバイス設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await loadAllData()
        }
        // 📊 パフォーマンス最適化: デバイス選択時のstate変更による不要なリロードを防止
        // デバイスデータは.taskで初回読み込み済み、SubjectUpdated時のみリロード
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SubjectUpdated"))) { _ in
            Task { await loadAllData() }
        }
        .sheet(isPresented: $showQRScanner) {
            QRCodeScannerView(isPresented: $showQRScanner) { scannedCode in
                Task { await handleQRCodeScanned(scannedCode) }
            }
        }
        .sheet(item: $editingContext, onDismiss: {
            // 📊 パフォーマンス最適化: Subject更新時は該当デバイスのみ再取得
            // ⚠️ 旧: loadAllData() → 全データ再読み込み（重い）
            // ✅ 新: 該当デバイスのSubjectのみ再取得（軽い）
            if let deviceId = editingContext?.deviceID {
                Task { await reloadSubject(for: deviceId) }
            }
        }) { context in
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
        VStack(alignment: .leading, spacing: 16) {
            Text("デバイス一覧")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal)

            // サンプルデバイスを除外してデバイス一覧を表示
            ForEach(deviceManager.devices.filter { $0.device_id != DeviceManager.sampleDeviceID }.reversed(), id: \.device_id) { device in
                DeviceCard(
                    device: device,
                    isSelected: device.device_id == deviceManager.selectedDeviceID,
                    subject: subjectsByDevice[device.device_id],
                    onSelect: {
                        if deviceManager.selectedDeviceID == device.device_id {
                            deviceManager.selectDevice(nil)
                        } else {
                            deviceManager.selectDevice(device.device_id)
                        }
                    },
                    onEditSubject: { subject in
                        editingContext = SubjectEditingContext(
                            deviceID: device.device_id,
                            editingSubject: subject
                        )
                    },
                    onAddSubject: {
                        editingContext = SubjectEditingContext(
                            deviceID: device.device_id,
                            editingSubject: nil
                        )
                    },
                    onEditDevice: {
                        deviceEditingContext = DeviceEditingContext(device: device)
                    }
                )
                .id(device.device_id)  // 📊 パフォーマンス最適化: 安定したIDで再描画を最小化
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Sample Device Section
    @ViewBuilder
    private func SampleDeviceSection() -> some View {
        if let sampleDevice = sampleDevice {
            VStack(alignment: .leading, spacing: 16) {
                Text("サンプルデバイス")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal)

                DeviceCard(
                    device: sampleDevice,
                    isSelected: sampleDevice.device_id == deviceManager.selectedDeviceID,
                    subject: subjectsByDevice[sampleDevice.device_id],
                    onSelect: {
                        if deviceManager.selectedDeviceID == sampleDevice.device_id {
                            deviceManager.selectDevice(nil)
                        } else {
                            deviceManager.selectDevice(sampleDevice.device_id)
                        }
                    },
                    onEditSubject: { subject in
                        editingContext = SubjectEditingContext(
                            deviceID: sampleDevice.device_id,
                            editingSubject: subject
                        )
                    },
                    onAddSubject: {
                        editingContext = SubjectEditingContext(
                            deviceID: sampleDevice.device_id,
                            editingSubject: nil
                        )
                    },
                    onEditDevice: {
                        // サンプルデバイスも詳細表示（閲覧のみ）
                        deviceEditingContext = DeviceEditingContext(device: sampleDevice)
                    }
                )
                .id(sampleDevice.device_id)  // 📊 パフォーマンス最適化: 安定したIDで再描画を最小化
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

    /// すべてのデータを正しい順序で読み込む
    private func loadAllData() async {
        isLoading = true

        // 1. デバイスマネージャーが準備完了するまで待機
        while case .loading = deviceManager.state {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // 2. サンプルデバイスを取得
        await loadSampleDevice()

        // 3. 全デバイスの観測対象を取得（サンプルデバイス含む）
        await loadSubjects()

        isLoading = false
    }

    /// サンプルデバイスを取得
    private func loadSampleDevice() async {
        do {
            let devices: [Device] = try await supabase
                .from("devices")
                .select("*")
                .eq("device_id", value: DeviceManager.sampleDeviceID)
                .execute()
                .value

            if let device = devices.first {
                await MainActor.run {
                    self.sampleDevice = device
                }
            }
        } catch {
            print("❌ サンプルデバイスの取得に失敗: \(error)")
        }
    }

    /// 特定デバイスのSubject情報のみを再取得（Subject更新時）
    private func reloadSubject(for deviceId: String) async {
        print("🔄 Reloading subject for device: \(deviceId)")

        // 📊 パフォーマンス最適化: Subject更新時はキャッシュを強制更新
        if let subject = await dataManager.fetchSubjectInfo(deviceId: deviceId, forceRefresh: true) {
            await MainActor.run {
                self.subjectsByDevice[deviceId] = subject
            }
            print("✅ Subject reloaded for device: \(deviceId)")
        } else {
            await MainActor.run {
                self.subjectsByDevice[deviceId] = nil
            }
            print("ℹ️ No subject found for device: \(deviceId)")
        }
    }

    /// 全デバイスの観測対象を取得（最適化版 - デバイス取得時に既にJOINで取得済み）
    private func loadSubjects() async {
        var newSubjects: [String: Subject] = [:]

        // 🚀 パフォーマンス最適化: DeviceManager.devicesに既にsubject情報が含まれている
        // JOIN取得により、個別のRPC呼び出しは不要（nilの場合もDBにsubject_idがないので呼び出し不要）
        for device in deviceManager.devices {
            if let subject = device.subject {
                newSubjects[device.device_id] = subject
                print("✅ [DeviceSettings] Subject loaded from device cache: \(subject.name ?? "Unknown")")
            }
            // else: subject_idがnullの場合、RPC呼び出しは不要（結果は同じnil）
        }

        // サンプルデバイスの観測対象も取得
        if let sampleDevice = sampleDevice {
            if !deviceManager.devices.contains(where: { $0.device_id == sampleDevice.device_id }) {
                // サンプルデバイスはdevices配列に含まれていない場合のみRPC呼び出し
                if let subject = await dataManager.fetchSubjectInfo(deviceId: sampleDevice.device_id) {
                    newSubjects[sampleDevice.device_id] = subject
                }
            } else {
                // デバイス配列に含まれている場合、そこからSubjectを取得
                if let device = deviceManager.devices.first(where: { $0.device_id == sampleDevice.device_id }),
                   let subject = device.subject {
                    newSubjects[sampleDevice.device_id] = subject
                }
                print("ℹ️ Sample device already included in devices, skipping duplicate fetch")
            }
        }

        await MainActor.run {
            self.subjectsByDevice = newSubjects
        }
    }

    /// QRコードをスキャンしてデバイスを追加
    private func handleQRCodeScanned(_ code: String) async {
        if deviceManager.devices.contains(where: { $0.device_id == code }) {
            addDeviceError = "このデバイスは既に追加されています。"
            showAddDeviceAlert = true
            return
        }

        do {
            if let userId = userAccountManager.currentUser?.profile?.userId {
                try await deviceManager.addDeviceByQRCode(code, for: userId)
                addedDeviceId = code
                showSuccessAlert = true
                await loadAllData()
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
