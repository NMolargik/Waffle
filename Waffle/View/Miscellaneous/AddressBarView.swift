//
//  AddressBarView.swift
//  Waffle
//
//  Safari-style address bar, pure SwiftUI. Idle, it shows just the compact
//  host name centered (never a clipped scheme or mid-URL fragment); focused,
//  it shows the full URL with everything selected, ready to replace.
//

import SwiftUI

struct AddressBarView: View {
    /// The full address — the source of truth, written back on submit.
    @Binding var text: String
    var placeholder: String
    /// The hosting window's content width, measured by the caller. The bar
    /// fills it, minus room for the surrounding toolbar controls.
    var availableWidth: CGFloat = 0
    /// Points to leave free for the other toolbar controls around the bar.
    var reservedControlWidth: CGFloat = 430
    var onSubmit: () -> Void = {}

    @FocusState private var isFocused: Bool
    /// What the field shows: the compact host when idle, the full URL while
    /// editing. Edits stay local until submit so a mid-edit page navigation
    /// can't clobber the user's typing.
    @State private var displayText: String = ""
    @State private var selection: TextSelection? = nil

    var body: some View {
        TextField(placeholder, text: $displayText, selection: $selection)
            .focused($isFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.webSearch)
            .submitLabel(.go)
            .multilineTextAlignment(isFocused ? .leading : .center)
            .onAppear {
                displayText = URLDisplayFormatter.compact(text)
            }
            .onChange(of: isFocused) { _, focused in
                if focused {
                    // Show the full address with everything selected, so
                    // typing replaces it — just like Safari.
                    displayText = text
                    selection = TextSelection(range: displayText.startIndex..<displayText.endIndex)
                } else {
                    displayText = URLDisplayFormatter.compact(text)
                }
            }
            .onChange(of: text) { _, newValue in
                // Page navigations update the idle display; never while editing.
                if !isFocused {
                    displayText = URLDisplayFormatter.compact(newValue)
                }
            }
            .onSubmit {
                text = displayText
                onSubmit()
                isFocused = false
            }
            .padding(.horizontal, 12)
            .frame(
                width: AppConfiguration.addressBarWidth(
                    forWindowWidth: availableWidth,
                    reservedForControls: reservedControlWidth
                ),
                height: AppConfiguration.barControlHeight
            )
            .clipShape(Capsule())
            .glassEffect(.regular, in: .capsule)
            .accessibilityLabel(Text("Address bar"))
    }
}

#Preview {
    @Previewable @State var text = "https://www.cnbc.com/markets/something/very/long"
    AddressBarView(text: $text, placeholder: "Search or enter a URL", availableWidth: 900)
        .padding()
}
