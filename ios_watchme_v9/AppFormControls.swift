//
//  AppFormControls.swift
//  ios_watchme_v9
//
//  Shared form parts: the text field box, its label, and the full-width buttons used
//  on the sign-in and sign-up screens. Every form uses these so fonts, sizes and
//  colors stay the same everywhere.
//

import SwiftUI

enum AppForm {
    static let fieldHeight: CGFloat = 52
    static let cornerRadius: CGFloat = 14
    static let fieldFont = Font.system(size: 16)
    static let buttonFont = Font.system(size: 17, weight: .semibold)
    static let labelFont = Font.system(size: 13, weight: .medium)
    static let labelColor = Color(white: 0.64)
    /// Placeholder text. The system placeholder color is too dim on the dark field.
    static let placeholderColor = Color(white: 0.56)
    static let fieldBackground = Color.darkSurface
}

/// Small gray label above a field.
struct AppFieldLabel: View {
    let text: String
    var required = false

    var body: some View {
        HStack(spacing: 2) {
            Text(text)
            if required {
                Text("*").foregroundColor(.accentCoral)
            }
        }
        .font(AppForm.labelFont)
        .foregroundColor(AppForm.labelColor)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Text field in a dark rounded box with a readable placeholder. Secure fields get an
/// eye button to show the password. Keyboard type, content type, onSubmit and
/// disabled are applied by the caller as usual; pass `focus`/`field` to move focus
/// between fields from the caller.
struct AppTextField<Field: Hashable>: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure = false
    var axis: Axis = .horizontal
    var focus: FocusState<Field?>.Binding? = nil
    var field: Field? = nil

    @FocusState private var ownFocus: Bool
    @State private var revealed = false

    private var isFocused: Bool {
        if let focus, let field { return focus.wrappedValue == field }
        return ownFocus
    }

    var body: some View {
        HStack(alignment: axis == .vertical ? .top : .center, spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.accentTeal.opacity(0.85))
                    .padding(.top, axis == .vertical ? 2 : 0)
            }

            focused(input)

            if isSecure {
                Button(action: { revealed.toggle() }) {
                    Image(systemName: revealed ? "eye.slash" : "eye")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppForm.labelColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, axis == .vertical ? 14 : 0)
        .frame(minHeight: AppForm.fieldHeight)
        .background(
            RoundedRectangle(cornerRadius: AppForm.cornerRadius, style: .continuous)
                .fill(AppForm.fieldBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppForm.cornerRadius, style: .continuous)
                .stroke(isFocused ? Color.accentTeal.opacity(0.9) : Color.white.opacity(0.12),
                        lineWidth: isFocused ? 1.6 : 1)
        )
    }

    @ViewBuilder
    private var input: some View {
        let prompt = Text(placeholder).foregroundColor(AppForm.placeholderColor)
        Group {
            if isSecure && !revealed {
                SecureField("", text: $text, prompt: prompt)
            } else {
                TextField("", text: $text, prompt: prompt, axis: axis)
            }
        }
        .textFieldStyle(.plain)
        .font(AppForm.fieldFont)
        .foregroundColor(.brightText)
        .tint(.accentTeal)
    }

    @ViewBuilder
    private func focused(_ view: some View) -> some View {
        if let focus, let field {
            view.focused(focus, equals: field)
        } else {
            view.focused($ownFocus)
        }
    }
}

/// Fields that do not take part in caller-driven focus.
enum AppNoField: Hashable {}

extension AppTextField where Field == AppNoField {
    init(_ placeholder: String, text: Binding<String>, icon: String? = nil,
         isSecure: Bool = false, axis: Axis = .horizontal) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.isSecure = isSecure
        self.axis = axis
    }
}

extension AppTextField {
    init(_ placeholder: String, text: Binding<String>, icon: String? = nil,
         isSecure: Bool = false, focus: FocusState<Field?>.Binding, field: Field) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.isSecure = isSecure
        self.focus = focus
        self.field = field
    }
}

/// Full-width button for sign-in, sign-up and similar actions.
struct AppFormButton: View {
    enum Style {
        /// White (Sign in with Apple).
        case light
        /// Dark with a thin border (Google).
        case dark
        /// Teal (the main action: email).
        case accent
    }

    let title: String
    var systemImage: String? = nil
    var style: Style = .accent
    var isLoading = false
    let action: () -> Void

    private var foreground: Color {
        switch style {
        case .light: return .black
        case .dark: return .white
        case .accent: return .darkBase
        }
    }

    private var background: Color {
        switch style {
        case .light: return .white
        case .dark: return .darkElevated
        case .accent: return .accentTeal
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(foreground)
                        .scaleEffect(0.8)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(title)
                    .font(AppForm.buttonFont)
                    .lineLimit(1)
            }
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: AppForm.fieldHeight)
            .background(
                RoundedRectangle(cornerRadius: AppForm.cornerRadius, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppForm.cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(style == .dark ? 0.14 : 0), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Gray heading between the sign-in buttons and the email form.
struct AppFormSectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppForm.labelFont)
            .foregroundColor(Color(white: 0.56))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }
}
