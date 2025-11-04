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

        // Prefer truncation (not font shrinking) when space is tight.
        textField.adjustsFontSizeToFitWidth = false
        textField.minimumFontSize = 12

        // Truncate long URLs in the middle.
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingMiddle
        var attrs = textField.defaultTextAttributes
        attrs[.paragraphStyle] = paragraph
        textField.defaultTextAttributes = attrs

        // Prefer to grow wide and resist shrinking horizontally.
        textField.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange), for: .editingChanged)
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidEndOnExit), for: .editingDidEndOnExit)
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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SelectAllTextField
        var shouldSelectAll = false

        init(_ parent: SelectAllTextField) {
            self.parent = parent
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

        @objc func textFieldDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        @objc func textFieldDidEndOnExit(_ textField: UITextField) {
            parent.onSubmit()
        }
    }
}
