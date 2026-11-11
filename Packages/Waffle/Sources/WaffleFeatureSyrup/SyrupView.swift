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
    @State private var scrollHeight: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    public init(store: StoreManager, phonePitch: SyrupPitch? = nil, onPurchased: (() -> Void)? = nil, onClose: (() -> Void)? = nil) {
        self.store = store
        self.phonePitch = phonePitch
        self.onPurchased = onPurchased
        self.onClose = onClose
    }

    public var body: some View {
        ScrollView {
          VStack {
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button {
                        onClose?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            // Phone: a full 44-point target (the iPad sheet keeps its size).
                            .frame(width: phonePitch == nil ? nil : 44, height: phonePitch == nil ? nil : 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Close"))
                }

                Image(systemName: "drop.fill")
                    .font(.system(size: 48))
                    // Dark brown vanishes on a dark sheet: the brand gold there.
                    .foregroundStyle(colorScheme == .dark ? Color.wafflePrimary : Color.waffleTertiary)

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

            // Phone: the price and the buttons sit at the bottom of the sheet, so a short
            // pitch does not leave the lower part of the sheet empty.
            if phonePitch != nil { Spacer(minLength: 12) }

            if phonePitch != nil {
                // Never a hardcoded price: the live StoreKit price, or neutral wording.
                if let price = store.product?.displayPrice {
                    Text("\(price), one time. No subscription.")
                        .font(.headline)
                } else {
                    Text("A one-time purchase. No subscription.")
                        .font(.headline)
                }
            } else if let price = store.product?.displayPrice {
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

            Text(LocalizedStringKey(phonePitch == nil
                 ? "Syrup is a one-time purchase. Use Family Sharing to share Syrup with family.  "
                 : "Syrup is a one-time purchase. With Family Sharing, your whole family can use it."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding([.horizontal, .bottom])
          }
          .frame(minHeight: phonePitch == nil ? nil : scrollHeight)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { scrollHeight = $0 }
        .padding()
        .frame(minWidth: phonePitch == nil ? 420 : nil, minHeight: phonePitch == nil ? 520 : nil)
    }

    // MARK: - iPhone and iPhone Duo

    private static func lead(for trigger: SyrupTrigger) -> LocalizedStringKey {
        switch trigger {
        case .general: "Get more from Waffle with Syrup"
        case .thirdPane: "Add a third pane with Syrup"
        case .secondLayout: "Save more layouts with Syrup"
        case .deskMode: "Use Desk Mode with Syrup"
        }
    }

    private func phoneFeatures(_ pitch: SyrupPitch) -> some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(pitch.features, id: \.self) { feature in
                    phoneLabel(feature, device: pitch.device)
                        .fontWeight(feature == pitch.leadFeature ? .semibold : .regular)
                }
            }
            .labelStyle(AlignedIconLabelStyle(iconSize: 22, iconWidth: 40, iconColor: .secondary))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)

            // What else the purchase covers, on the other devices.
            Group {
                if pitch.device.isFoldable {
                    Text("Also unlocks Waffle on iPad: bigger grids, pop-out, fullscreen and rearranging")
                } else {
                    Text("Also unlocks Waffle on iPad and iPhone Duo: bigger grids, a third and fourth pane, Desk Mode")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            // The free side, said plainly (and it fills the sheet honestly).
            Label("Always free: two panes, one saved layout, auto-refresh and content blocking", systemImage: "checkmark.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .labelStyle(AlignedIconLabelStyle(iconSize: 22, iconWidth: 40, iconColor: .secondary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
        }
    }

    @ViewBuilder
    private func phoneLabel(_ feature: SyrupFeature, device: SyrupDevice) -> some View {
        switch feature {
        case .morePanes:
            if device.isInnerDisplay {
                Label("A third and fourth pane on this display", systemImage: "rectangle.split.2x2")
            } else {
                Label("A third and fourth pane when you unfold your iPhone Duo", systemImage: "rectangle.split.2x2")
            }
        case .unlimitedLayouts:
            Label("Unlimited saved layouts", systemImage: "square.and.arrow.down")
        case .deskMode:
            if device.isInnerDisplay {
                Label("Desk Mode when this display is half-folded", systemImage: "laptopcomputer")
            } else {
                Label("Desk Mode when your iPhone Duo is half-folded", systemImage: "laptopcomputer")
            }
        }
    }
}
#endif
