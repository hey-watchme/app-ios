//
//  DeviceSectionView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/08/02.
//

import SwiftUI

/// デバイス一覧を表示する共通Viewコンポーネント
/// DeviceSelectionViewとUserInfoViewの両方で使用される
struct DeviceSectionView: View {
    // MARK: - Properties
    
    let devices: [Device]
    let selectedDeviceID: String?
    let subjectsByDevice: [String: Subject]
    let showSelectionUI: Bool // 選択UIを表示するか（チェックマークなど）
    let isCompact: Bool // コンパクト表示モード（UserInfoView用）
    
    // MARK: - Callbacks
    
    let onDeviceSelected: ((String) -> Void)?
    let onEditSubject: ((String, Subject) -> Void)?
    let onAddSubject: ((String) -> Void)?
    
    // MARK: - Initializer
    
    init(
        devices: [Device],
        selectedDeviceID: String?,
        subjectsByDevice: [String: Subject],
        showSelectionUI: Bool = true,
        isCompact: Bool = false,
        onDeviceSelected: ((String) -> Void)? = nil,
        onEditSubject: ((String, Subject) -> Void)? = nil,
        onAddSubject: ((String) -> Void)? = nil
    ) {
        self.devices = devices
        self.selectedDeviceID = selectedDeviceID
        self.subjectsByDevice = subjectsByDevice
        self.showSelectionUI = showSelectionUI
        self.isCompact = isCompact
        self.onDeviceSelected = onDeviceSelected
        self.onEditSubject = onEditSubject
        self.onAddSubject = onAddSubject
    }
    
    // MARK: - Body
    
    var body: some View {
        ForEach(Array(devices.enumerated()), id: \.element.device_id) { index, device in
            VStack(alignment: .leading, spacing: 8) {
                // デバイス情報部分
                if showSelectionUI {
                    // 選択可能なボタンスタイル（DeviceSelectionView用）
                    Button(action: {
                        print("🔵 DeviceSectionView: Button tapped for \(device.device_id.prefix(8))")
                        onDeviceSelected?(device.device_id)
                    }) {
                        deviceInfoContent(for: device)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(
                        device.device_id == selectedDeviceID ? Color.white : Color.gray.opacity(0.2)
                    )
                } else {
                    // 静的な表示（UserInfoView用）
                    deviceInfoContent(for: device)
                }
                
                // 観測対象情報（コンパクトモードでは表示しない）
                if !isCompact {
                    observationTargetSection(for: device.device_id)
                        .padding(.leading, showSelectionUI ? 60 : 20)
                }
            }
            .padding(.vertical, isCompact ? 4 : 8)
            
            // セパレーター（最後の要素以外）
            if index < devices.count - 1 && !showSelectionUI {
                Divider()
                    .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Private Views
    
    @ViewBuilder
    private func deviceInfoContent(for device: Device) -> some View {
        HStack {
            // デバイスアイコン
            Image(systemName: getDeviceIcon(for: device))
                .font(.system(size: isCompact ? 24 : 28))
                .foregroundColor(device.device_id == selectedDeviceID ? .primary : .secondary)
                .frame(width: isCompact ? 35 : 40)

            VStack(alignment: .leading, spacing: 4) {
                // デバイスID（短縮表示）
                Text("デバイス: \(device.device_id.prefix(8))...")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(device.device_id == selectedDeviceID ? .primary : .secondary)
                
                // タイムゾーン表示
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.caption2)
                    Text("タイムゾーン: \(device.timezone ?? "未設定")")
                        .font(.caption)
                }
                .foregroundColor(device.device_id == selectedDeviceID ? .primary : .secondary)
                
                // 測定対象（簡易表示）
                if let subject = subjectsByDevice[device.device_id] {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                        Text(subject.name ?? "名前未設定")
                            .font(.caption)
                    }
                    .foregroundColor(device.device_id == selectedDeviceID ? .primary : .secondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.caption2)
                        Text("測定対象未設定")
                            .font(.caption)
                    }
                    .foregroundColor(Color.safeColor("WarningColor"))
                }
                
                // ロール情報（showSelectionUIがtrueの場合のみ表示）
                if showSelectionUI, let role = device.role {
                    HStack(spacing: 4) {
                        Image(systemName: role == "owner" ? "crown.fill" : "eye.fill")
                            .font(.caption2)
                        Text(role == "owner" ? "オーナー" : "閲覧者")
                            .font(.caption2)
                    }
                    .foregroundColor(device.device_id == selectedDeviceID ? .primary : .secondary.opacity(0.7))
                }
                
                // 選択中の表示（UserInfoView用）
                if !showSelectionUI && device.device_id == selectedDeviceID {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.safeColor("SuccessColor"))
                        Text("現在選択中")
                            .font(.caption)
                            .foregroundColor(Color.safeColor("SuccessColor"))
                    }
                }
            }
            
            Spacer()
            
            // 選択中のチェックマーク（DeviceSelectionView用）
            if showSelectionUI && device.device_id == selectedDeviceID {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color.safeColor("AppAccentColor"))
            }
        }
    }
    
    @ViewBuilder
    private func observationTargetSection(for deviceId: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundColor(Color.safeColor("WarningColor"))
                Text("観測対象")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            
            if let subject = subjectsByDevice[deviceId] {
                // 観測対象が登録されている場合
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        InfoRowTwoLine(
                            label: "名前",
                            value: subject.name ?? "未設定",
                            icon: "person.crop.circle",
                            valueColor: .primary
                        )
                    }
                    
                    if let ageGender = subject.ageGenderDisplay {
                        InfoRow(label: "年齢・性別", value: ageGender, icon: "info.circle")
                    }
                    
                    if let onEdit = onEditSubject {
                        HStack {
                            Spacer()
                            Button(action: {
                                onEdit(deviceId, subject)
                            }) {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text("編集")
                                }
                                .font(.caption)
                                .foregroundColor(Color.safeColor("PrimaryActionColor"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.safeColor("PrimaryActionColor").opacity(0.1))
                                .cornerRadius(4)
                            }
                        }
                    }
                }
                .padding(.leading, 20)
            } else {
                // 観測対象が登録されていない場合
                VStack(alignment: .leading, spacing: 6) {
                    InfoRow(label: "状態", value: "未登録", icon: "person.crop.circle.badge.questionmark", valueColor: .secondary)
                    
                    if let onAdd = onAddSubject {
                        HStack {
                            Spacer()
                            Button(action: {
                                onAdd(deviceId)
                            }) {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                    Text("観測対象を追加")
                                }
                                .font(.caption)
                                .foregroundColor(Color.safeColor("WarningColor"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.safeColor("WarningColor").opacity(0.1))
                                .cornerRadius(4)
                            }
                        }
                    }
                }
                .padding(.leading, 20)
            }
        }
    }
    
    private func getDeviceIcon(for device: Device) -> String {
        switch device.device_type.lowercased() {
        case "ios":
            return "iphone"
        case "android":
            return "smartphone"
        case "web":
            return "desktopcomputer"
        default:
            return "square.dashed"
        }
    }
}

// MARK: - Preview

struct DeviceSectionView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleDevices = [
            Device(
                device_id: "12345678-1234-1234-1234-123456789012",
                device_type: "ios",
                timezone: "Asia/Tokyo",
                owner_user_id: "user1",
                subject_id: nil,
                created_at: nil,
                status: "active",
                role: "owner"
            ),
            Device(
                device_id: "87654321-4321-4321-4321-210987654321",
                device_type: "android",
                timezone: "America/New_York",
                owner_user_id: "user1",
                subject_id: nil,
                created_at: nil,
                status: "active",
                role: "viewer"
            )
        ]
        
        let sampleSubjects: [String: Subject] = [
            "12345678-1234-1234-1234-123456789012": Subject(
                subjectId: "sub1",
                name: "田中太郎",
                age: 30,
                gender: "男性",
                avatarUrl: nil,
                notes: nil,
                createdByUserId: "user1",
                createdAt: "2025-08-02T00:00:00Z",
                updatedAt: "2025-08-02T00:00:00Z"
            )
        ]
        
        VStack {
            // DeviceSelectionView用のプレビュー
            List {
                Section(header: Text("DeviceSelectionView用")) {
                    DeviceSectionView(
                        devices: sampleDevices,
                        selectedDeviceID: sampleDevices[0].device_id,
                        subjectsByDevice: sampleSubjects,
                        showSelectionUI: true,
                        onDeviceSelected: { deviceId in
                            print("Selected device: \(deviceId)")
                        }
                    )
                }
            }
            .listStyle(InsetGroupedListStyle())
            
            // UserInfoView用のプレビュー
            ScrollView {
                VStack {
                    Text("UserInfoView用")
                        .font(.headline)
                        .padding()
                    
                    DeviceSectionView(
                        devices: sampleDevices,
                        selectedDeviceID: sampleDevices[0].device_id,
                        subjectsByDevice: sampleSubjects,
                        showSelectionUI: false,
                        onEditSubject: { deviceId, subject in
                            print("Edit subject for device: \(deviceId)")
                        },
                        onAddSubject: { deviceId in
                            print("Add subject for device: \(deviceId)")
                        }
                    )
                    .padding()
                }
            }
        }
    }
}