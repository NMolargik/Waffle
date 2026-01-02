//
//  SelectAllTextField.swift
//  Waffle
//
//  Created by Nick Molargik on 9/10/25.
//

import Foundation
import UIKit
import SwiftUI

struct SelectAllTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void = {}

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.borderStyle = .none
        textField.backgroundColor = .clear

        // URL bar settings - no autocapitalization or autocorrection
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.keyboardType = .webSearch

        // Prefer truncation (not font shrinking) when space is tight.
        textField.adjustsFontSizeToFitWidth = false
        textField.minimumFontSize = 12

        // Truncate long URLs at the end (show beginning of URL).
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        var attrs = textField.defaultTextAttributes
        attrs[.paragraphStyle] = paragraph
        textField.defaultTextAttributes = attrs

        // Prefer to grow wide and resist shrinking horizontally.
        textField.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange), for: .editingChanged)
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidEndOnExit), for: .editingDidEndOnExit)

        // Store reference for focus management
        context.coordinator.textField = textField

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
        uiView.placeholder = placeholder
        if context.coordinator.shouldSelectAll {
            uiView.selectAll(nil)
            context.coordinator.shouldSelectAll = false
        }
    }

    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        nil // Use default sizing
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SelectAllTextField
        var shouldSelectAll = false
        weak var textField: UITextField?

        init(_ parent: SelectAllTextField) {
            self.parent = parent
        }

        func focus() {
            textField?.becomeFirstResponder()
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            shouldSelectAll = true
            DispatchQueue.main.async { [weak self, weak textField] in
                if let should = self?.shouldSelectAll, should {
                    textField?.selectAll(nil)
                    self?.shouldSelectAll = false
                }
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            // Scroll to beginning when editing ends so truncation shows the start of the URL
            let beginning = textField.beginningOfDocument
            textField.selectedTextRange = textField.textRange(from: beginning, to: beginning)
        }

        @objc func textFieldDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        @objc func textFieldDidEndOnExit(_ textField: UITextField) {
            parent.onSubmit()
        }
    }
}
