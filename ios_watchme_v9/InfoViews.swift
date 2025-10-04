//
//  InfoViews.swift
//  ios_watchme_v9
//

import SwiftUI

// MARK: - 情報セクション
struct InfoSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                content
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - 情報行
struct InfoRow: View {
    let label: String
    let value: String
    let icon: String
    let valueColor: Color
    
    init(label: String, value: String, icon: String, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.icon = icon
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.black)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - 2行表示情報行
struct InfoRowTwoLine: View {
    let label: String
    let value: String
    let icon: String
    let valueColor: Color

    init(label: String, value: String, icon: String, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.icon = icon
        self.valueColor = valueColor
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.black)
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(valueColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer()
        }
    }
}

// MARK: - リストスタイル情報セクション
struct InfoListSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 0) {
                content
            }
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
}

// MARK: - リストスタイル情報行（左端：ラベル、右端：値）
struct InfoListRow: View {
    let label: String
    let value: String
    let showDivider: Bool
    let valueColor: Color

    init(label: String, value: String, showDivider: Bool = true, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.showDivider = showDivider
        self.valueColor = valueColor
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(valueColor)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if showDivider {
                Divider()
                    .background(Color(.systemGray4))
            }
        }
    }
}