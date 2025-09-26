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
    let onEditDevice: (() -> Void)?
    
    var body: some View {
        Button(action: onSelect) {
            ZStack {
                // 背景 - 選択時はパープル、通常時は白
                RoundedRectangle(cornerRadius: 24)
                    .fill(isSelected ? Color.safeColor("AppAccentColor") : Color.white) // パープル #6200ff
                    .shadow(color: .black.opacity(isSelected ? 0.15 : 0.1), radius: 10, x: 0, y: 5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                isSelected ? Color.clear : Color.safeColor("BorderLight").opacity(0.1),
                                lineWidth: 1
                            )
                    )
                
                VStack(spacing: 16) {
                    // トグルボタンと選択状態
                    HStack {
                        // カスタムトグルスタイル - 紫色背景時は専用デザイン
                        Toggle("", isOn: .constant(isSelected))
                            .labelsHidden()
                            .toggleStyle(PurpleBackgroundToggleStyle(isOnPurpleBackground: isSelected))
                            .disabled(true) // ボタン全体でクリックするので、トグル自体は無効化
                        
                        Text(isSelected ? "選択中のデバイス" : "このデバイスを選択する")
                            .font(.body)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundColor(isSelected ? .white : .primary)
                        
                        Spacer()
                    }
                    
                    // 区切り線（トグルボタンの下）
                    Divider()
                        .background(isSelected ? Color.white.opacity(0.5) : Color.gray.opacity(0.3))
                    
                    // デバイスID情報
                    VStack(alignment: .leading, spacing: 4) {
                        Text("デバイスID")
                            .font(.caption)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        
                        Text(device.device_id)
                            .font(.system(.footnote, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundColor(isSelected ? .white : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // デバイス詳細情報
                    VStack(alignment: .leading, spacing: 8) {
                        // デバイスタイプ
                        DetailInfoRowNoIcon(
                            label: "デバイスタイプ",
                            value: getDeviceTypeDisplayName(),
                            isSelected: isSelected
                        )
                        
                        // デバイスタイムゾーン
                        DetailInfoRowNoIcon(
                            label: "デバイスタイムゾーン",
                            value: device.timezone ?? "未設定",
                            isSelected: isSelected
                        )
                    }
                    
                    // デバイス情報編集ボタン
                    if let onEditDevice = onEditDevice {
                        HStack {
                            Spacer()
                            Button(action: onEditDevice) {
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle")
                                    Text("デバイス詳細")
                                }
                                .font(.caption)
                                .foregroundColor(isSelected ? .white.opacity(0.9) : Color.safeColor("PrimaryActionColor"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .stroke(isSelected ? Color.white.opacity(0.3) : Color.safeColor("PrimaryActionColor").opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    // 区切り線
                    Divider()
                        .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.3))
                    
                    // 観測対象情報
                    HStack(spacing: 12) {
                        // 観測対象アバター（AvatarViewコンポーネントを使用）
                        if let subject = subject {
                            ZStack {
                                AvatarView(type: .subject, id: subject.subjectId, size: 50)
                                
                                // 選択時の枠線
                                Circle()
                                    .stroke(isSelected ? Color.white.opacity(0.3) : Color.safeColor("BorderLight").opacity(0.2), lineWidth: 2)
                                    .frame(width: 50, height: 50)
                            }
                        } else {
                            Circle()
                                .fill(isSelected ? Color.white.opacity(0.2) : Color.safeColor("BorderLight").opacity(0.1))
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
                                    .foregroundColor(isSelected ? Color.safeColor("AppAccentColor") : Color.safeColor("PrimaryActionColor"))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Color.white : Color.safeColor("PrimaryActionColor").opacity(0.1))
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
                                    .foregroundColor(isSelected ? Color.safeColor("WarningColor") : Color.safeColor("WarningColor"))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Color.white : Color.safeColor("WarningColor").opacity(0.1))
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

// MARK: - Detail Info Row Without Icon
struct DetailInfoRowNoIcon: View {
    let label: String
    let value: String
    let isSelected: Bool
    
    init(label: String, value: String, isSelected: Bool = false) {
        self.label = label
        self.value = value
        self.isSelected = isSelected
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Custom Toggle Style
struct PurpleBackgroundToggleStyle: ToggleStyle {
    let isOnPurpleBackground: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            ZStack {
                // トラック（溝の部分）
                Capsule()
                    .fill(isOnPurpleBackground ? 
                          Color(red: 0.3, green: 0.1, blue: 0.5).opacity(0.8) :  // 紫色の暗い色
                          (configuration.isOn ? Color.green : Color.gray.opacity(0.3)))
                    .frame(width: 51, height: 31)
                
                // サム（つまみ部分）
                Circle()
                    .fill(Color.white)
                    .frame(width: 27, height: 27)
                    .offset(x: configuration.isOn ? 11 : -11)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
            }
            .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
            
            configuration.label
        }
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
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
                onAddSubject: { },
                onEditDevice: { }
            )
            
            // 選択されていないデバイス
            DeviceCard(
                device: sampleDevice,
                isSelected: false,
                subject: nil,
                onSelect: { },
                onEditSubject: { _ in },
                onAddSubject: { },
                onEditDevice: { }
            )
        }
        .padding()
        .background(Color.safeColor("BehaviorBackgroundPrimary"))
    }
}