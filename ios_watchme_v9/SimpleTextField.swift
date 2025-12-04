//
//  SimpleTextField.swift
//  ios_watchme_v9
//
//  最小限のシンプルなTextField実装
//  パフォーマンス問題を解決するための統一実装
//

import SwiftUI
import UIKit

/// 最もシンプルなUITextFieldラッパー
struct SimpleTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var isEnabled: Bool = true

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        setupTextField(textField, context: context)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        // テキストが実際に変更された場合のみ更新
        if textField.text != text {
            textField.text = text
        }
        textField.isEnabled = isEnabled
    }

    private func setupTextField(_ textField: UITextField, context: Context) {
        // 基本設定のみ
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.borderStyle = .roundedRect
        textField.font = .systemFont(ofSize: 16)

        // 予測変換を完全に無効化
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no

        // デリゲート設定
        textField.delegate = context.coordinator

        // 初期値設定
        textField.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SimpleTextField

        init(_ parent: SimpleTextField) {
            self.parent = parent
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // テキスト変更を即座に反映
            if let text = textField.text,
               let textRange = Range(range, in: text) {
                let updatedText = text.replacingCharacters(in: textRange, with: string)
                parent.text = updatedText
            }
            return true
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

/// シンプルなTextEditor
struct SimpleTextEditor: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var isEnabled: Bool = true

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        setupTextView(textView, context: context)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text && !text.isEmpty {
            textView.text = text
            textView.textColor = .label
        }
        textView.isEditable = isEnabled
    }

    private func setupTextView(_ textView: UITextView, context: Context) {
        textView.font = .systemFont(ofSize: 16)
        textView.backgroundColor = .systemGray6
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // 予測変換を無効化
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no

        // デリゲート設定
        textView.delegate = context.coordinator

        // 初期表示
        if text.isEmpty {
            textView.text = placeholder
            textView.textColor = .placeholderText
        } else {
            textView.text = text
            textView.textColor = .label
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SimpleTextEditor

        init(_ parent: SimpleTextEditor) {
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