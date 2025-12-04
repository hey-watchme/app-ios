//
//  OptimizedTextField.swift
//  ios_watchme_v9
//
//  Ultra-optimized text field to solve Japanese input freeze issues
//

import SwiftUI
import UIKit

/// Minimal UITextField wrapper with aggressive optimizations
struct OptimizedTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var keyboardType: UIKeyboardType = .default
    var isEnabled: Bool = true

    // Create a static configuration to avoid recreating
    static let textFieldConfiguration: (UITextField) -> Void = { textField in
        // Disable EVERYTHING that could cause delays
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.smartDashesType = .no
        textField.smartQuotesType = .no
        textField.smartInsertDeleteType = .no
        textField.inlinePredictionType = .no

        // Clear all bar button items
        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []

        // iOS 17+ optimizations
        if #available(iOS 17.0, *) {
            textField.writingToolsBehavior = .none
        }
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()

        // Apply configuration
        Self.textFieldConfiguration(textField)

        // Basic setup
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.isEnabled = isEnabled
        textField.borderStyle = .roundedRect
        textField.font = .systemFont(ofSize: 16)
        textField.text = text

        // Use simple target-action instead of delegate for performance
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textChanged),
            for: .editingChanged
        )

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Only update if actually changed
        if uiView.text != text {
            uiView.text = text
        }

        // Only update enabled state if changed
        if uiView.isEnabled != isEnabled {
            uiView.isEnabled = isEnabled
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject {
        let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func textChanged(_ textField: UITextField) {
            text.wrappedValue = textField.text ?? ""
        }
    }
}

/// Wrapper that adds a performance monitoring layer
struct PerformanceTextField: View {
    @Binding var text: String
    var placeholder: String
    var keyboardType: UIKeyboardType = .default
    var isEnabled: Bool = true

    @State private var isFocused = false

    var body: some View {
        OptimizedTextField(
            text: $text,
            placeholder: placeholder,
            keyboardType: keyboardType,
            isEnabled: isEnabled
        )
        .frame(height: 36)
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { _ in
            if !isFocused {
                isFocused = true
                #if DEBUG
                print("⚡ TextField focus started")
                #endif
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidEndEditingNotification)) { _ in
            if isFocused {
                isFocused = false
                #if DEBUG
                print("⚡ TextField focus ended")
                #endif
            }
        }
    }
}

/// Helper to disable predictive features globally for the app
struct KeyboardOptimizer {
    @MainActor
    static func optimizeForPerformance() {
        // Removed UIAppearance calls due to thread safety issues
        // Each text field now configures itself individually
        #if DEBUG
        print("⚡ Keyboard optimization: Individual text fields will disable autocorrection")
        #endif
    }
}