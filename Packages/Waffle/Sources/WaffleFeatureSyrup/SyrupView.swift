//
//  SyrupView.swift
//  WaffleFeatureSyrup
//
//  The Syrup purchase sheet. Takes the `StoreManager` directly (it is already an
//  @Observable presentation-ready object); purchase/close outcomes flow out via closures.
//

#if os(iOS)
import SwiftUI
import WaffleCore
import WaffleDesignSystem
import WaffleServices

public struct SyrupView: View {
    private let store: StoreManager
    private let onPurchased: (() -> Void)?
    private let onClose: (() -> Void)?
    /// Set on iPhone and iPhone Duo: lists what Syrup unlocks there instead of the iPad grid features.
    private let phonePitch: SyrupPitch?

    public init(store: StoreManager, phonePitch: SyrupPitch? = nil, onPurchased: (() -> Void)? = nil, onClose: (() -> Void)? = nil) {
        self.store = store
        self.phonePitch = phonePitch
        self.onPurchased = onPurchased
        self.onClose = onClose
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button {
                        onClose?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Close"))
                }

                Image(systemName: "drop.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.waffleTertiary)

                Text(verbatim: "Syrup")
                    .font(.largeTitle).bold()

                if let phonePitch {
                    Text(Self.lead(for: phonePitch.trigger))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Waffle + Syrup, what could be better?")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Unlock the full Waffle experience")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                if let phonePitch {
                    phoneFeatures(phonePitch)
                } else {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Up to \(AppConfiguration.maxPremiumRows)x\(AppConfiguration.maxPremiumCols) waffles (double the \(AppConfiguration.maxFreeRows)x\(AppConfiguration.maxFreeCols) limit)", systemImage: "square.grid.3x3")
                    Label("Rearrange waffles", systemImage: "arrow.left.arrow.right.square")
                    Label("Pop out cells into their own windows", systemImage: "rectangle.on.rectangle")
                    Label("Fullscreen a single cell", systemImage: "arrow.up.left.and.arrow.down.right.rectangle")
                    Label("Create and update Preset waffles", systemImage: "square.and.arrow.down")
                    Label("Syrup is shared for free with your whole family", systemImage: "person.2")
                }
                .labelStyle(AlignedIconLabelStyle(iconSize: 22, iconWidth: 40, iconColor: .secondary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                }
            }

            if let price = store.product?.displayPrice {
                Text("Only \(price). One time. No subscription!")
                    .font(.headline)
            } else {
                Text("Loading price…")
                    .font(.headline)
            }

            if let msg = store.errorMessage {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            VStack(spacing: 12) {
                Button {
                    Task {
                        let ok = await store.purchase()
                        if ok {
                            onPurchased?()
                        }
                    }
                } label: {
                    HStack {
                        if store.isLoading { ProgressView() }
                        Text("Buy Syrup")
                            .bold()
                    }
                }
                .buttonStyle(.wafflePrimary)
                .disabled(store.isLoading || store.product == nil)

                Button {
                    Task {
                        let ok = await store.restore()
                        if ok {
                            onPurchased?()
                        }
                    }
                } label: {
                    Text("Restore Purchases")
                }
                .buttonStyle(.waffleSecondary)
                .disabled(store.isLoading)
            }

            Text("Syrup is a one-time purchase. Use Family Sharing to share Syrup with family.  ")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding([.horizontal, .bottom])
        }
        .padding()
        .frame(minWidth: phonePitch == nil ? 420 : nil, minHeight: phonePitch == nil ? 520 : nil)
    }

    // MARK: - iPhone and iPhone Duo

    private static func lead(for trigger: SyrupTrigger) -> LocalizedStringKey {
        switch trigger {
        case .general: "Get more from Waffle on iPhone"
        case .thirdPane: "Add a third pane with Syrup"
        case .secondLayout: "Save more layouts with Syrup"
        case .autoRefresh: "Keep every pane fresh with Syrup"
        case .deskMode: "Use Desk Mode with Syrup"
        }
    }

    private func phoneFeatures(_ pitch: SyrupPitch) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(pitch.features, id: \.self) { feature in
                phoneLabel(feature, isInnerDisplay: pitch.isInnerDisplay)
                    .fontWeight(feature == pitch.leadFeature ? .semibold : .regular)
            }
            Label("Syrup is shared for free with your whole family", systemImage: "person.2")
        }
        .labelStyle(AlignedIconLabelStyle(iconSize: 22, iconWidth: 40, iconColor: .secondary))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    @ViewBuilder
    private func phoneLabel(_ feature: SyrupFeature, isInnerDisplay: Bool) -> some View {
        switch feature {
        case .morePanes:
            if isInnerDisplay {
                Label("A third and fourth pane on iPhone Duo's inner display", systemImage: "rectangle.split.2x2")
            } else {
                Label("Panes three and four on iPhone Duo's inner display and on iPad", systemImage: "rectangle.split.2x2")
            }
        case .unlimitedLayouts:
            Label("Unlimited saved layouts", systemImage: "square.and.arrow.down")
        case .autoRefresh:
            Label("Auto-refresh timers for each pane", systemImage: "timer")
        case .deskMode:
            Label("Desk Mode when your iPhone Duo is half-folded", systemImage: "laptopcomputer")
        }
    }
}
#endif
