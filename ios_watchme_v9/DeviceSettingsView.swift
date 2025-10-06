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
                } else if deviceManager.userDevices.isEmpty {
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
        .onChange(of: deviceManager.state) { oldState, newState in
            if newState == .ready && oldState != .ready {
                Task { await loadAllData() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SubjectUpdated"))) { _ in
            Task { await loadAllData() }
        }
        .sheet(isPresented: $showQRScanner) {
            QRCodeScannerView(isPresented: $showQRScanner) { scannedCode in
                Task { await handleQRCodeScanned(scannedCode) }
            }
        }
        .sheet(item: $editingContext, onDismiss: {
            Task { await loadAllData() }
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
            Task {
                if let userId = userAccountManager.currentUser?.profile?.userId {
                    await deviceManager.fetchUserDevices(for: userId)
                    await loadAllData()
                }
            }
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
            ForEach(Array(deviceManager.userDevices.filter { $0.device_id != DeviceManager.sampleDeviceID }.reversed().enumerated()), id: \.element.device_id) { index, device in
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
                    onEditDevice: { }
                )
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
                        .background(Color.safeColor("PrimaryActionColor"))
                        .cornerRadius(12)
                    }

                    Button(action: {
                        if let url = URL(string: "https://hey-watch.me/") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "cart.fill")
                            Text("デバイスを購読する")
                        }
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.safeColor("PrimaryActionColor"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.safeColor("PrimaryActionColor"), lineWidth: 1)
                        )
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
        while deviceManager.state == .idle || deviceManager.state == .loading {
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

    /// 全デバイスの観測対象を取得
    private func loadSubjects() async {
        var newSubjects: [String: Subject] = [:]

        // 連携中のデバイスの観測対象を取得
        for device in deviceManager.userDevices {
            let result = await dataManager.fetchAllReports(
                deviceId: device.device_id,
                date: Date(),
                timezone: deviceManager.getTimezone(for: device.device_id)
            )
            if let subject = result.subject {
                newSubjects[device.device_id] = subject
            }
        }

        // サンプルデバイスの観測対象も取得
        if let sampleDevice = sampleDevice {
            let result = await dataManager.fetchAllReports(
                deviceId: sampleDevice.device_id,
                date: Date(),
                timezone: deviceManager.getTimezone(for: sampleDevice.device_id)
            )
            if let subject = result.subject {
                newSubjects[sampleDevice.device_id] = subject
            }
        }

        await MainActor.run {
            self.subjectsByDevice = newSubjects
        }
    }

    /// QRコードをスキャンしてデバイスを追加
    private func handleQRCodeScanned(_ code: String) async {
        if deviceManager.userDevices.contains(where: { $0.device_id == code }) {
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
