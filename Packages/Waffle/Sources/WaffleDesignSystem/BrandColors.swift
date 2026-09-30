//
//  BrandColors.swift
//  WaffleDesignSystem
//
//  The Waffle brand palette, defined in code so the colors resolve identically in every
//  module and in host `swift build` without asset-catalog symbol generation. Values
//  mirror the `.colorset`s in the app's asset catalog. Declared on
//  `ShapeStyle where Self == Color` so `.wafflePrimary` works both as a `Color` and
//  directly in `.foregroundStyle`/`.fill`/`.tint`.
//

import SwiftUI

public extension ShapeStyle where Self == Color {
    /// Warm waffle yellow — backgrounds and gradients.
    static var wafflePrimary: Color { Color(red: 0xF1 / 255, green: 0xE0 / 255, blue: 0x94 / 255) }

    /// Golden syrup brown — secondary accents.
    static var waffleSecondary: Color { Color(red: 0xDF / 255, green: 0xA6 / 255, blue: 0x56 / 255) }

    /// Dark roast brown — primary CTAs and toast chrome.
    static var waffleTertiary: Color { Color(red: 0x44 / 255, green: 0x20 / 255, blue: 0x1A / 255) }
}
