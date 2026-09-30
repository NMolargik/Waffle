//
//  AddressTextField.swift
//  WaffleFeatureGrid
//
//  A UIKit-backed text field for the toolbar address bar. SwiftUI's `@FocusState` is
//  not driven for a `TextField` hosted inside a toolbar's principal item (the bar is a
//  separate hosting root), so editing state comes from `UITextFieldDelegate` instead —
//  which fires no matter where the field lives.
//

#if os(iOS)
import SwiftUI
import UIKit

struct AddressTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    /// True while the field is first responder. Written by the delegate.
    @Binding var isEditing: Bool
    var onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.placeholder = placeholder
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartDashesType = .no
        field.smartQuotesType = .no
        field.keyboardType = .webSearch
        field.returnKeyType = .go
        field.clearButtonMode = .whileEditing
        field.textContentType = .URL
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        // Let the SwiftUI frame decide the width; never grow to fit content.
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        field.placeholder = placeholder
        field.textAlignment = isEditing ? .left : .center
        if field.text != text {
            field.text = text
        }
        // The full URL is swapped in on begin-editing; select it once it lands so
        // typing replaces it, just like Safari. Deferred a turn: UIKit places its
        // own initial caret after `didBeginEditing` returns, which would clobber a
        // selection set synchronously here.
        if context.coordinator.needsSelectAll, field.isFirstResponder {
            context.coordinator.needsSelectAll = false
            DispatchQueue.main.async {
                guard field.isFirstResponder else { return }
                field.selectedTextRange = field.textRange(from: field.beginningOfDocument, to: field.endOfDocument)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AddressTextField
        var needsSelectAll = false

        init(parent: AddressTextField) {
            self.parent = parent
        }

        @objc func textChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            needsSelectAll = true
            parent.isEditing = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.isEditing = false
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            textField.resignFirstResponder()
            return true
        }
    }
}
#endif
