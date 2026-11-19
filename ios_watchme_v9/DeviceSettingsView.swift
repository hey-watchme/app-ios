//
//  DeviceSettingsView.swift
//  ios_watchme_v9
//
//  すべてのデバイス - every linked recording container, opened from the 分析対象 screen
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
    @State private var editingContext: SubjectEditingContext? = nil
    @State private var deviceEditingContext: DeviceEditingContext? = nil


    // MARK: - Body
    var body: some View {
        ScrollView {
            ZStack {
            Color.darkBase.ignoresSafeArea()

            VStack(spacing: 0) {
                // DeviceManager.stateに基づいた表示切り替え
                switch deviceManager.state {
                case .idle, .loading:
                    ProgressView("デバイス一覧を読み込み中...")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 200)

                case .available(let allDevices):
                    // One list: subjects are chosen on the 分析対象 screen, so devices are not
                    // grouped by kind here (docs/product/subjects-and-devices.md)
                    if allDevices.isEmpty {
                        EmptyDeviceState()
                    } else {
                        DeviceList(devices: allDevices)
                    }

                    Spacer(minLength: 100)

                case .error(let message):
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.accentTealMuted)
                        Text("エラーが発生しました")
                            .font(.title3)
                            .foregroundColor(.white)
                        Text(message)
                            .font(.caption)
                            .foregroundColor(Color(white: 0.56))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                }
                }
                .padding(.top, 20)
            }
        }
        .background(Color.darkBase.ignoresSafeArea())
        .navigationTitle("すべてのデバイス")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.darkBase, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.white)
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
    }

    // MARK: - Empty State
    @ViewBuilder
    private func EmptyDeviceState() -> some View {
        UnifiedCard(title: "デバイス") {
            VStack(spacing: 20) {
                Image(systemName: "iphone.slash")
                    .font(.system(size: 50))
                    .foregroundColor(Color(white: 0.56))

                Text("連携されたデバイスがありません")
                    .font(.title3)
                    .foregroundColor(Color(white: 0.56))

                Text("この iPhone で録音すると、ここに表示されます")
                    .font(.footnote)
                    .foregroundColor(Color(white: 0.56))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 20)
        }
        .padding(.horizontal)
    }

    // MARK: - Device List
    @ViewBuilder
    private func DeviceList(devices: [Device]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
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


    // MARK: - Data Loading
    // loadAllData()とloadSampleDevice()は削除
    // → DeviceManagerで一元管理されるため不要
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
