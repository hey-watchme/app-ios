//
//  DeviceSettingsView.swift
//  ios_watchme_v9
//
//  デバイス設定画面（マイページのデバイス版）
//  独立したページとして実装
//

import SwiftUI

// 編集コンテキストを定義（SwiftUIのベストプラクティス）
struct SubjectEditingContext: Identifiable {
    let id = UUID()
    let deviceID: String
    let editingSubject: Subject?
    
    var isEditing: Bool {
        editingSubject != nil
    }
}

// デバイス編集コンテキスト
struct DeviceEditingContext: Identifiable {
    let id = UUID()
    let device: Device
}

struct DeviceSettingsView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var userAccountManager: UserAccountManager
    @State private var subjectsByDevice: [String: Subject] = [:]
    @State private var isLoadingSubjects = true  // 明示的なローディング状態
    @State private var showQRScanner = false
    @State private var showAddDeviceAlert = false
    @State private var addDeviceError: String?
    @State private var showSuccessAlert = false
    @State private var addedDeviceId: String?
    @State private var sampleDevice: Device? = nil  // サンプルデバイス（DBから取得）

    // sheet(item:)パターン用の状態管理
    @State private var editingContext: SubjectEditingContext? = nil
    @State private var deviceEditingContext: DeviceEditingContext? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if deviceManager.isLoading || isLoadingSubjects {
                    ProgressView("デバイス一覧を読み込み中...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if deviceManager.userDevices.isEmpty {
                    EmptyDeviceState()
                } else {
                    DeviceList()
                }

                // サンプルデバイスセクション
                SampleDeviceSection()

                // デバイス追加カード
                DeviceAddCard()
                
                Spacer(minLength: 100)
            }
            .padding(.top, 20)
        }
        .background(
            Color.safeColor("BehaviorBackgroundPrimary")
                .ignoresSafeArea()
        )
        .navigationTitle("デバイス設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            // iOS 15+の推奨パターン：.taskモディファイアで非同期処理
            await loadSubjectsForAllDevices()
            await loadSampleDevice()
            isLoadingSubjects = false
        }
        .sheet(isPresented: $showQRScanner) {
            QRCodeScannerView(isPresented: $showQRScanner) { scannedCode in
                Task {
                    await handleQRCodeScanned(scannedCode)
                }
            }
        }
        // SwiftUIベストプラクティス：sheet(item:)パターン
        .sheet(item: $editingContext, onDismiss: {
            Task {
                await loadSubjectsForAllDevices()
            }
        }) { context in
            SubjectRegistrationView(
                deviceID: context.deviceID,
                isPresented: .constant(false),  // itemベースなので不要
                editingSubject: context.editingSubject
            )
            .environmentObject(dataManager)
            .environmentObject(deviceManager)
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
        // デバイス編集画面のシート
        .sheet(item: $deviceEditingContext, onDismiss: {
            // シートが閉じられた後にデバイス一覧を再読み込み
            Task {
                if let userId = userAccountManager.currentUser?.id {
                    await deviceManager.fetchUserDevices(for: userId)
                    await loadSubjectsForAllDevices()
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
            // 連携中のデバイス タイトル
            Text("連携中のデバイス")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            // 新しく登録されたデバイスが上に来るよう逆順でソート
            ForEach(Array(deviceManager.userDevices.reversed().enumerated()), id: \.element.device_id) { index, device in
                DeviceCard(
                    device: device,
                    isSelected: device.device_id == deviceManager.selectedDeviceID,
                    subject: subjectsByDevice[device.device_id],
                    onSelect: {
                        // 既に選択中なら解除、そうでなければ選択
                        if deviceManager.selectedDeviceID == device.device_id {
                            deviceManager.selectDevice(nil)
                        } else {
                            deviceManager.selectDevice(device.device_id)
                        }
                    },
                    onEditSubject: { subject in
                        // sheet(item:)パターンで編集コンテキストを設定
                        editingContext = SubjectEditingContext(
                            deviceID: device.device_id,
                            editingSubject: subject
                        )
                    },
                    onAddSubject: {
                        // sheet(item:)パターンで新規追加コンテキストを設定
                        editingContext = SubjectEditingContext(
                            deviceID: device.device_id,
                            editingSubject: nil
                        )
                    },
                    onEditDevice: {
                        // デバイス編集画面を表示
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
                // サンプルデバイス タイトル
                Text("サンプルデバイス")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal)

                DeviceCard(
                    device: sampleDevice,
                    isSelected: sampleDevice.device_id == deviceManager.selectedDeviceID,
                    subject: subjectsByDevice[sampleDevice.device_id],
                    onSelect: {
                        // 既に選択中なら解除、そうでなければ選択
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
                        // サンプルデバイスは編集不可
                    }
                )
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Device Add Card
    @ViewBuilder
    private func DeviceAddCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 新しいデバイス タイトル
            Text("新しいデバイス")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            UnifiedCard(title: "デバイスを追加") {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title2)
                            .foregroundColor(Color.safeColor("PrimaryActionColor"))
                        
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
                        .background(Color.safeColor("PrimaryActionColor"))
                        .cornerRadius(12)
                    }
                    
                    // デバイスを購読するボタン
                    Button(action: {
                        // Webサイトを開く
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
    
    // MARK: - Helper Methods
    private func loadSubjectsForAllDevices() async {
        var newSubjects: [String: Subject] = [:]
        
        for device in deviceManager.userDevices {
            // 各デバイスの観測対象を取得（RPC経由で効率的に）
            let result = await dataManager.fetchAllReports(
                deviceId: device.device_id,
                date: Date(),  // 日付は任意（Subjectのみ必要）
                timezone: deviceManager.getTimezone(for: device.device_id)
            )
            if let subject = result.subject {
                newSubjects[device.device_id] = subject
            }
        }
        
        await MainActor.run {
            self.subjectsByDevice = newSubjects
        }
    }
    
    private func handleQRCodeScanned(_ code: String) async {
        // 既に追加済みかチェック
        if deviceManager.userDevices.contains(where: { $0.device_id == code }) {
            addDeviceError = "このデバイスは既に追加されています。"
            showAddDeviceAlert = true
            return
        }
        
        // デバイスを追加
        do {
            if let userId = userAccountManager.currentUser?.id {
                try await deviceManager.addDeviceByQRCode(code, for: userId)
                // 成功時のフィードバック
                addedDeviceId = code
                showSuccessAlert = true
                // サブジェクト情報を再読み込み
                await loadSubjectsForAllDevices()
            } else {
                addDeviceError = "ユーザー情報の取得に失敗しました。"
                showAddDeviceAlert = true
            }
        } catch {
            addDeviceError = "デバイスの追加に失敗しました: \(error.localizedDescription)"
            showAddDeviceAlert = true
        }
    }

    // MARK: - サンプルデバイスの取得
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
                print("✅ サンプルデバイスを取得: \(device.device_id), type: \(device.device_type)")
            } else {
                print("⚠️ サンプルデバイスが見つかりません")
            }
        } catch {
            print("❌ サンプルデバイスの取得に失敗: \(error)")
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