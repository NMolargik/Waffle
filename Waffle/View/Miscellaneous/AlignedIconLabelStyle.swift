//
//  AlignedIconLabelStyle.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import SwiftUI

struct AlignedIconLabelStyle: LabelStyle {
    var iconSize: CGFloat = 22
    var iconWidth: CGFloat = 28
    var iconColor: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 8) {
            configuration.icon
                .foregroundStyle(iconColor ?? .primary)
                .font(.system(size: iconSize, weight: .regular))
                // Use a square frame so the icon’s visual center is stable.
                .frame(width: iconWidth, height: iconSize, alignment: .center)

            configuration.title
        }
    }
}
