//
//  DeviceSelectionView.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/07/30.
//

import SwiftUI

struct DeviceSelectionView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                if deviceManager.isLoading {
                    ProgressView("デバイス一覧を読み込み中...")
                        .padding()
                } else if deviceManager.userDevices.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "iphone.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("連携されたデバイスがありません")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text("他のデバイスから測定データを\n共有することができます")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        Section(header: Text("利用可能なデバイス")) {
                            ForEach(deviceManager.userDevices, id: \.device_id) { device in
                                DeviceRowView(
                                    device: device,
                                    isSelected: deviceManager.selectedDeviceID == device.device_id,
                                    subject: dataManager.subject
                                ) {
                                    deviceManager.selectDevice(device.device_id)
                                    // 少し遅延を入れてからシートを閉じる（アニメーション用）
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        isPresented = false
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("デバイス選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// デバイス行の表示用ビュー
struct DeviceRowView: View {
    let device: Device
    let isSelected: Bool
    let subject: Subject?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // デバイスアイコン
                Image(systemName: getDeviceIcon())
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? .blue : .gray)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    // デバイスID（短縮表示）
                    Text("デバイス: \(device.device_id.prefix(8))...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(isSelected ? .primary : .secondary)
                    
                    // 測定対象
                    if let subject = subject {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                            Text(subject.name ?? "名前未設定")
                                .font(.caption)
                        }
                        .foregroundColor(isSelected ? .blue : .secondary)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill.questionmark")
                                .font(.caption2)
                            Text("測定対象未設定")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                    }
                    
                    // ロール情報
                    if let role = device.role {
                        HStack(spacing: 4) {
                            Image(systemName: role == "owner" ? "crown.fill" : "eye.fill")
                                .font(.caption2)
                            Text(role == "owner" ? "オーナー" : "閲覧者")
                                .font(.caption2)
                        }
                        .foregroundColor(isSelected ? .blue.opacity(0.7) : .secondary.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // 選択中のチェックマーク
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(
            isSelected ? Color.blue.opacity(0.1) : Color.clear
        )
    }
    
    private func getDeviceIcon() -> String {
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

// プレビュー用
struct DeviceSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceSelectionView(isPresented: .constant(true))
            .environmentObject(DeviceManager())
            .environmentObject(SupabaseDataManager())
    }
}