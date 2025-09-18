//
//  SyrupView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import SwiftUI
import StoreKit

struct SyrupView: View {
    @Environment(StoreManager.self) private var store

    var onPurchased: (() -> Void)?
    var onClose: (() -> Void)?

    var body: some View {
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
                }
                
                Image(systemName: "drop.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.brown)
                
                Text("Syrup")
                    .font(.largeTitle).bold()
                
                Text("Waffle + Syrup, what could be better?")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text("Unlock the full Waffle experience")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 10) {
                    Label("Up to 4x4 waffles (double the 2x2 limit)", systemImage: "square.grid.3x3")
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
                .buttonStyle(.borderedProminent)
                .tint(.brown)
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
                .disabled(store.isLoading)
            }
            
            Text("Syrup is a one-time purchase. Use Family Sharing to share Syrup with family.  ")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding([.horizontal, .bottom])
        }
        .padding()
        .frame(minWidth: 420, minHeight: 520)
    }
}

#Preview {
    // Provide a StoreManager in the environment for the view to use.
    // This will attempt to load products in the background.
    let store = StoreManager()
    return SyrupView(
        onPurchased: { print("Purchased in preview") },
        onClose: { print("Closed in preview") }
    )
    .environment(store)
    .frame(minWidth: 420, minHeight: 520)
}
