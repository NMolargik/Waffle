//
//  WaffleButtonStyles.swift
//  Waffle
//
//  Created by Nick Molargik on 1/2/26.
//

import SwiftUI

/// Primary button style for main CTAs - uses brand colors with hover feedback
struct WafflePrimaryButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.waffleTertiary)
                    .opacity(configuration.isPressed ? 0.8 : (isHovered ? 0.9 : 1.0))
            )
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

/// Secondary button style for less prominent actions
struct WaffleSecondaryButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.medium)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.waffleSecondary.opacity(isHovered ? 0.25 : 0.15))
            )
            .foregroundStyle(Color.waffleTertiary)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.waffleSecondary.opacity(isHovered ? 0.6 : 0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

/// List item button style with subtle hover feedback
struct WaffleListButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(isHovered ? 0.08 : 0))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.12), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

/// Icon button style for toolbar and action buttons
struct WaffleIconButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(
                Circle()
                    .fill(Color.accentColor.opacity(isHovered ? 0.15 : 0))
            )
            .foregroundStyle(isHovered ? Color.accentColor : Color.primary)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.12), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Convenience Extensions

extension ButtonStyle where Self == WafflePrimaryButtonStyle {
    static var wafflePrimary: WafflePrimaryButtonStyle { WafflePrimaryButtonStyle() }
}

extension ButtonStyle where Self == WaffleSecondaryButtonStyle {
    static var waffleSecondary: WaffleSecondaryButtonStyle { WaffleSecondaryButtonStyle() }
}

extension ButtonStyle where Self == WaffleListButtonStyle {
    static var waffleList: WaffleListButtonStyle { WaffleListButtonStyle() }
}

extension ButtonStyle where Self == WaffleIconButtonStyle {
    static var waffleIcon: WaffleIconButtonStyle { WaffleIconButtonStyle() }
}

#Preview("Button Styles") {
    VStack(spacing: 20) {
        Button("Primary Action") { }
            .buttonStyle(.wafflePrimary)

        Button("Secondary Action") { }
            .buttonStyle(.waffleSecondary)

        Button {
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text("List Item")
                        .font(.headline)
                    Text("Description text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
        }
        .buttonStyle(.waffleList)

        Button {
        } label: {
            Image(systemName: "gear")
                .font(.title2)
        }
        .buttonStyle(.waffleIcon)
    }
    .padding()
}
