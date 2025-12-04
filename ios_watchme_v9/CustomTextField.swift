//
//  CustomTextField.swift
//  ios_watchme_v9
//
//  Created for performance optimization - Native UITextField wrapper
//  This solves the 30-second freeze issue when focusing on text fields
//

import SwiftUI
import UIKit

/// High-performance text field using UIViewRepresentable
/// Solves the SwiftUI TextField freeze issue by using native UITextField
struct CustomTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var keyboardType: UIKeyboardType = .default
    var isEnabled: Bool = true
    var textContentType: UITextContentType? = nil
    var isSecure: Bool = false
    var onCommit: (() -> Void)?

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.isEnabled = isEnabled
        textField.borderStyle = .roundedRect
        textField.font = UIFont.systemFont(ofSize: 16)

        // CRITICAL Performance optimizations for Japanese input
        // Disable ALL predictive text features that cause hangs
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.smartDashesType = .no
        textField.smartQuotesType = .no
        textField.smartInsertDeleteType = .no

        // Additional optimizations for Japanese input system
        textField.autocapitalizationType = .none
        textField.inlinePredictionType = .no // iOS 17+ inline predictions

        // Disable text input traits that might trigger candidate lookup
        if #available(iOS 17.0, *) {
            textField.writingToolsBehavior = .none // Disable writing tools
        }

        // Set input assistant to minimal mode
        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []

        // Set text content type if provided
        if let contentType = textContentType {
            textField.textContentType = contentType
        }

        // Handle secure text entry
        textField.isSecureTextEntry = isSecure

        // Accessibility
        textField.isAccessibilityElement = true
        textField.accessibilityLabel = placeholder

        // Add target for editing changed event
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textFieldDidChange(_:)),
            for: .editingChanged
        )

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Only update if different to avoid triggering keyboard issues
        if uiView.text != text {
            uiView.text = text
        }
        uiView.isEnabled = isEnabled
        uiView.placeholder = placeholder
        uiView.keyboardType = keyboardType
        uiView.isSecureTextEntry = isSecure
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CustomTextField

        init(_ parent: CustomTextField) {
            self.parent = parent
        }

        @objc func textFieldDidChange(_ textField: UITextField) {
            // Update parent's text binding
            parent.text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            // Call onCommit if provided
            parent.onCommit?()

            // Dismiss keyboard
            textField.resignFirstResponder()
            return true
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            // Don't call becomeFirstResponder again - it's already first responder
            // This was causing redundant keyboard activation
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            // Final sync
            parent.text = textField.text ?? ""
        }
    }
}

/// Custom TextEditor replacement for multi-line text input
struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isEnabled: Bool = true

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = isEnabled
        textView.isSelectable = true
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = UIColor.systemGray6
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // CRITICAL Performance optimizations for Japanese input
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.autocapitalizationType = .none
        textView.inlinePredictionType = .no

        // Disable text input traits that might trigger candidate lookup
        if #available(iOS 17.0, *) {
            textView.writingToolsBehavior = .none
        }

        // Set input assistant to minimal mode
        textView.inputAssistantItem.leadingBarButtonGroups = []
        textView.inputAssistantItem.trailingBarButtonGroups = []

        // Set initial text
        textView.text = text.isEmpty ? placeholder : text
        textView.textColor = text.isEmpty ? .placeholderText : .label

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only update if different
        if uiView.text != text && !text.isEmpty {
            uiView.text = text
            uiView.textColor = .label
        }
        uiView.isEditable = isEnabled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor

        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.text == parent.placeholder {
                textView.text = ""
                textView.textColor = .label
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                textView.text = parent.placeholder
                textView.textColor = .placeholderText
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            if textView.text != parent.placeholder {
                parent.text = textView.text
            }
        }
    }
}

// MARK: - View Modifiers for easy styling
extension CustomTextField {
    func textFieldStyle(_ style: TextFieldStyle) -> some View {
        // Return self wrapped in a styling view
        self
            .frame(height: 36)
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }
}

struct CustomTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(height: 36)
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }
}