//
//  AlignedIconLabelStyle.swift
//  WaffleDesignSystem
//
//  A label style whose icon sits in a fixed-width square frame so rows of labels align.
//

import SwiftUI

public struct AlignedIconLabelStyle: LabelStyle {
    var iconSize: CGFloat
    var iconWidth: CGFloat
    var iconColor: Color?

    public init(iconSize: CGFloat = 22, iconWidth: CGFloat = 28, iconColor: Color? = nil) {
        self.iconSize = iconSize
        self.iconWidth = iconWidth
        self.iconColor = iconColor
    }

    public func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 8) {
            configuration.icon
                .foregroundStyle(iconColor ?? .primary)
                .font(.system(size: iconSize, weight: .regular))
                // Square frame so the icon's visual center is stable.
                .frame(width: iconWidth, height: iconSize, alignment: .center)

            configuration.title
        }
    }
}
