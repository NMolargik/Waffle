//
//  AddressBarView.swift
//  WaffleFeatureGrid
//
//  Safari-style address bar. Idle, it shows just the compact host name centered (never
//  a clipped scheme or mid-URL fragment) and shares the toolbar with the other controls;
//  editing, it shows the full URL with everything selected and expands to fill the
//  window while the hosting toolbar hides its other controls.
//

#if os(iOS)
import SwiftUI
import WaffleCore

public struct AddressBarView: View {
    /// The full address — the source of truth, written back on submit.
    @Binding var text: String
    var placeholder: String
    /// The hosting window's content width, measured by the caller. The bar
    /// fills it, minus room for the surrounding toolbar controls.
    var availableWidth: CGFloat
    /// Points to leave free for the other toolbar controls around the bar.
    var reservedControlWidth: CGFloat
    var onSubmit: () -> Void
    /// Reports editing so the hosting toolbar can hide its other controls while
    /// the bar expands to fill the window.
    var onEditingChanged: ((Bool) -> Void)?

    /// Driven by the UIKit field's delegate — `@FocusState` doesn't track a
    /// field hosted in a toolbar item.
    @State private var isEditing = false
    /// What the field shows: the compact host when idle, the full URL while
    /// editing. Edits stay local until submit so a mid-edit page navigation
    /// can't clobber the user's typing.
    @State private var displayText: String = ""

    public init(
        text: Binding<String>,
        placeholder: String,
        availableWidth: CGFloat = 0,
        reservedControlWidth: CGFloat = 430,
        onSubmit: @escaping () -> Void = {},
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.availableWidth = availableWidth
        self.reservedControlWidth = reservedControlWidth
        self.onSubmit = onSubmit
        self.onEditingChanged = onEditingChanged
    }

    /// Idle: share the toolbar with the surrounding controls. Editing: the
    /// controls hide and the bar takes the whole window.
    private var barWidth: CGFloat {
        isEditing
            ? AppConfiguration.editingAddressBarWidth(forWindowWidth: availableWidth)
            : AppConfiguration.addressBarWidth(
                forWindowWidth: availableWidth,
                reservedForControls: reservedControlWidth
            )
    }

    public var body: some View {
        AddressTextField(
            text: $displayText,
            placeholder: placeholder,
            isEditing: $isEditing,
            onSubmit: {
                text = displayText
                onSubmit()
            }
        )
        .onAppear {
            displayText = URLDisplayFormatter.compact(text)
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                // Show the full address; the field selects it all once it lands.
                displayText = text
            } else {
                displayText = URLDisplayFormatter.compact(text)
            }
            onEditingChanged?(editing)
        }
        .onChange(of: text) { _, newValue in
            // Page navigations update the idle display; never while editing.
            if !isEditing {
                displayText = URLDisplayFormatter.compact(newValue)
            }
        }
        .padding(.horizontal, 12)
        .frame(width: barWidth, height: AppConfiguration.barControlHeight)
        .clipShape(Capsule())
        .glassEffect(.regular, in: .capsule)
        .animation(.snappy, value: isEditing)
        .accessibilityLabel(Text("Address bar"))
    }
}

#Preview {
    @Previewable @State var text = "https://www.cnbc.com/markets/something/very/long"
    AddressBarView(text: $text, placeholder: "Search or enter a URL", availableWidth: 900)
        .padding()
}
#endif
