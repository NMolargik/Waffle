//
//  WaffleButtonStyles.swift
//  WaffleDesignSystem
//
//  Brand button styles with pointer-hover feedback (iPad/Mac).
//

import SwiftUI

/// Primary button style for main CTAs - uses brand colors with hover feedback
public struct WafflePrimaryButtonStyle: ButtonStyle {
    @State private var isHovered = false

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
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
public struct WaffleSecondaryButtonStyle: ButtonStyle {
    @State private var isHovered = false

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
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
public struct WaffleListButtonStyle: ButtonStyle {
    @State private var isHovered = false

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
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
public struct WaffleIconButtonStyle: ButtonStyle {
    @State private var isHovered = false

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
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

public extension ButtonStyle where Self == WafflePrimaryButtonStyle {
    static var wafflePrimary: WafflePrimaryButtonStyle { WafflePrimaryButtonStyle() }
}

public extension ButtonStyle where Self == WaffleSecondaryButtonStyle {
    static var waffleSecondary: WaffleSecondaryButtonStyle { WaffleSecondaryButtonStyle() }
}

public extension ButtonStyle where Self == WaffleListButtonStyle {
    static var waffleList: WaffleListButtonStyle { WaffleListButtonStyle() }
}

public extension ButtonStyle where Self == WaffleIconButtonStyle {
    static var waffleIcon: WaffleIconButtonStyle { WaffleIconButtonStyle() }
}

#if DEBUG
#Preview("Button Styles") {
    VStack(spacing: 20) {
        Button { } label: { Text(verbatim: "Primary Action") }
            .buttonStyle(.wafflePrimary)

        Button { } label: { Text(verbatim: "Secondary Action") }
            .buttonStyle(.waffleSecondary)

        Button {
        } label: {
            Image(systemName: "gear")
                .font(.title2)
        }
        .buttonStyle(.waffleIcon)
    }
    .padding()
}
#endif
