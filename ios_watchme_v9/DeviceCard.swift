//
//  DeviceCard.swift
//  ios_watchme_v9
//
//  個別デバイス用のカードコンポーネント
//  Apple風のミニマル・フレンドリーなデザイン
//

import SwiftUI

struct DeviceCard: View {
    let device: Device
    let isSelected: Bool
    let subject: Subject?
    let onSelect: () -> Void
    let onEditSubject: ((Subject) -> Void)?
    let onAddSubject: (() -> Void)?
    
    var body: some View {
        Button(action: onSelect) {
            ZStack {
                // 背景 - 選択時はパープル、通常時は白
                RoundedRectangle(cornerRadius: 24)
                    .fill(isSelected ? Color(red: 0.384, green: 0, blue: 1) : Color.white) // パープル #6200ff
                    .shadow(color: .black.opacity(isSelected ? 0.15 : 0.1), radius: 10, x: 0, y: 5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                isSelected ? Color.clear : Color.gray.opacity(0.1),
                                lineWidth: 1
                            )
                    )
                
                VStack(spacing: 16) {
                    // ヘッダー部分（選択インジケーター）
                    HStack {
                        Spacer()
                        if isSelected {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 24, height: 24)
                                
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(red: 0.384, green: 0, blue: 1))
                            }
                        }
                    }
                    
                    // デバイス情報
                    HStack(spacing: 12) {
                        // デバイスアイコン
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.white.opacity(0.2) : Color.gray.opacity(0.1))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: getDeviceIcon())
                                .font(.title2)
                                .foregroundColor(isSelected ? .white : .secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("デバイス")
                                .font(.caption)
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                            
                            Text(device.device_id.prefix(8) + "...")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                                .foregroundColor(isSelected ? .white : .primary)
                        }
                        
                        Spacer()
                    }
                    
                    // 観測対象情報
                    HStack(spacing: 12) {
                        // 観測対象アバター（AvatarViewコンポーネントを使用）
                        if let subject = subject {
                            ZStack {
                                AvatarView(type: .subject, id: subject.subjectId, size: 50)
                                
                                // 選択時の枠線
                                Circle()
                                    .stroke(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 2)
                                    .frame(width: 50, height: 50)
                            }
                        } else {
                            Circle()
                                .fill(isSelected ? Color.white.opacity(0.2) : Color.gray.opacity(0.1))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "person.fill.questionmark")
                                        .foregroundColor(isSelected ? .white.opacity(0.6) : .secondary)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("観測対象")
                                .font(.caption)
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                            
                            Text(subject?.name ?? "未設定")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(isSelected ? .white : .primary)
                        }
                        
                        Spacer()
                    }
                    
                    // デバイス詳細情報
                    VStack(alignment: .leading, spacing: 8) {
                        // デバイスタイプ
                        DetailInfoRow(
                            icon: "gear",
                            label: "デバイスタイプ",
                            value: getDeviceTypeDisplayName(),
                            iconColor: isSelected ? .white.opacity(0.9) : .gray,
                            isSelected: isSelected
                        )
                        
                        // タイムゾーン
                        DetailInfoRow(
                            icon: "globe",
                            label: "タイムゾーン",
                            value: device.timezone ?? "未設定",
                            iconColor: isSelected ? .white.opacity(0.9) : .blue,
                            isSelected: isSelected
                        )
                        
                        // ロール情報
                        if let role = device.role {
                            DetailInfoRow(
                                icon: role == "owner" ? "crown.fill" : "eye.fill",
                                label: "権限",
                                value: role == "owner" ? "オーナー" : "閲覧者",
                                iconColor: isSelected ? .white.opacity(0.9) : (role == "owner" ? .orange : .blue),
                                isSelected: isSelected
                            )
                        }
                        
                        // 登録日時
                        if let createdAt = device.created_at {
                            DetailInfoRow(
                                icon: "calendar.badge.plus",
                                label: "登録日",
                                value: formatCreatedDate(createdAt),
                                iconColor: isSelected ? .white.opacity(0.9) : .green,
                                isSelected: isSelected
                            )
                        }
                    }
                    
                    // 観測対象アクション
                    HStack {
                        Spacer()
                        
                        if let subject = subject {
                            // 編集ボタン
                            if let onEditSubject = onEditSubject {
                                Button(action: {
                                    onEditSubject(subject)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pencil")
                                        Text("観測対象を編集")
                                    }
                                    .font(.caption)
                                    .foregroundColor(isSelected ? Color(red: 0.384, green: 0, blue: 1) : .blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Color.white : Color.blue.opacity(0.1))
                                    )
                                }
                            }
                        } else {
                            // 追加ボタン
                            if let onAddSubject = onAddSubject {
                                Button(action: onAddSubject) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "person.badge.plus")
                                        Text("観測対象を追加")
                                    }
                                    .font(.caption)
                                    .foregroundColor(isSelected ? .orange : .orange)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Color.white : Color.orange.opacity(0.1))
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .buttonStyle(PlainButtonStyle())
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
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            displayFormatter.locale = Locale(identifier: "ja_JP")
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Detail Info Row
struct DetailInfoRow: View {
    let icon: String
    let label: String
    let value: String
    let iconColor: Color
    let isSelected: Bool
    
    init(icon: String, label: String, value: String, iconColor: Color, isSelected: Bool = false) {
        self.icon = icon
        self.label = label
        self.value = value
        self.iconColor = iconColor
        self.isSelected = isSelected
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Info Row Compact (Legacy)
struct InfoRowCompact: View {
    let icon: String
    let label: String
    let value: String
    let iconColor: Color
    let isSelected: Bool
    
    init(icon: String, label: String, value: String, iconColor: Color, isSelected: Bool = false) {
        self.icon = icon
        self.label = label
        self.value = value
        self.iconColor = iconColor
        self.isSelected = isSelected
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(iconColor)
                .frame(width: 16)
            
            Text(label)
                .font(.caption)
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                .frame(width: 60, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
            
            Spacer()
        }
    }
}

// MARK: - Preview
struct DeviceCard_Previews: PreviewProvider {
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
        
        let sampleSubject = Subject(
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
        
        VStack(spacing: 16) {
            // 選択されたデバイス
            DeviceCard(
                device: sampleDevice,
                isSelected: true,
                subject: sampleSubject,
                onSelect: { },
                onEditSubject: { _ in },
                onAddSubject: { }
            )
            
            // 選択されていないデバイス
            DeviceCard(
                device: sampleDevice,
                isSelected: false,
                subject: nil,
                onSelect: { },
                onEditSubject: { _ in },
                onAddSubject: { }
            )
        }
        .padding()
        .background(Color(red: 0.937, green: 0.937, blue: 0.937))
    }
}