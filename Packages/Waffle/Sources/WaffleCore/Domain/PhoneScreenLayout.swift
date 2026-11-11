//
//  PhoneScreenLayout.swift
//  WaffleCore
//
//  Where the pane workspace, the control bar and (in desk mode) the control deck sit on
//  an iPhone or iPhone Duo screen. Pure geometry so the "nothing crosses the fold" and
//  "controls don't crowd the web content" rules are host-tested.
//

import CoreGraphics
import Foundation

nonisolated public struct PhoneScreenLayout: Equatable, Sendable {
    /// Where the panes live.
    public var workspace: CGRect
    /// The compact control bar; nil in desk mode (the deck replaces it).
    public var bar: CGRect?
    /// Desk mode: the flat half holding the pane switcher, timers and layouts.
    public var deck: CGRect?
    /// The fold in the workspace's own coordinates, when panes must respect it.
    public var fold: FoldGutter?
    /// Groups A and B sit side by side (true) or stacked (false).
    public var primaryIsHorizontal: Bool

    public static let barHeight: CGFloat = 56
    public static let margin: CGFloat = 6
    public static let maxBarWidth: CGFloat = 520

    /// - Parameters:
    ///   - size: the full screen, including safe areas.
    ///   - safe: safe-area insets (top, leading, bottom, trailing).
    ///   - fold: the fold in screen coordinates, or nil when the SDK reports none.
    ///   - mode: compact or the Duo's inner display.
    ///   - deskMode: laptop pose: panes on the upright half, controls on the flat half.
    ///   - barOnFarSide: put the bar under the B side of a vertical fold (the selected pane's side).
    public static func compute(
        size: CGSize,
        safe: (top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat),
        fold: FoldGutter?,
        mode: PaneMode,
        deskMode: Bool,
        barOnFarSide: Bool = false,
        barHeight: CGFloat = barHeight,
        margin: CGFloat = margin
    ) -> PhoneScreenLayout {
        let left = safe.leading + margin
        let right = size.width - safe.trailing - margin
        let top = safe.top + margin
        let bottom = size.height - safe.bottom - margin
        let fullWidth = max(right - left, 0)

        // Desk mode: the fold must be horizontal so there is an upright half above it.
        if deskMode, mode == .inner, let fold, !fold.primaryIsHorizontal {
            let foldStart = fold.position - fold.thickness / 2
            let foldEnd = fold.position + fold.thickness / 2
            let upright = CGRect(x: left, y: top, width: fullWidth, height: max(foldStart - margin - top, 0))
            let flat = CGRect(x: left, y: foldEnd + margin, width: fullWidth, height: max(bottom - foldEnd - margin, 0))
            return PhoneScreenLayout(
                workspace: upright, bar: nil, deck: flat, fold: nil,
                primaryIsHorizontal: upright.width >= upright.height
            )
        }

        let barTop = bottom - barHeight
        let workspaceBottom = barTop - margin
        var workspace = CGRect(x: left, y: top, width: fullWidth, height: max(workspaceBottom - top, 0))

        var barX = left
        var barWidth = min(fullWidth, maxBarWidth)
        let primaryIsHorizontal: Bool
        var localFold: FoldGutter?

        if mode == .inner {
            let resolved = fold ?? FoldGutter.centered(in: size)
            primaryIsHorizontal = resolved.primaryIsHorizontal
            localFold = FoldGutter(
                primaryIsHorizontal: resolved.primaryIsHorizontal,
                position: resolved.position - (resolved.primaryIsHorizontal ? workspace.minX : workspace.minY),
                thickness: resolved.thickness,
                isActive: resolved.isActive
            )
            if resolved.primaryIsHorizontal && resolved.isActive {
                // Vertical fold, device partially open: keep the bar on one side of it. With
                // the fold inactive (flat, or no fold) the whole width is usable.
                let gutterStart = resolved.position - max(resolved.thickness, PaneFrameCalculator.defaultSpacing) / 2
                let gutterEnd = resolved.position + max(resolved.thickness, PaneFrameCalculator.defaultSpacing) / 2
                if barOnFarSide {
                    barX = gutterEnd + margin
                    barWidth = min(right - barX, maxBarWidth)
                } else {
                    barX = left
                    barWidth = min(gutterStart - margin - left, maxBarWidth)
                }
            } else {
                barX = left + (fullWidth - barWidth) / 2
            }
        } else {
            primaryIsHorizontal = size.width > size.height
            barX = left + (fullWidth - barWidth) / 2
        }

        workspace.size.width = max(workspace.width, 0)
        let bar = CGRect(x: barX, y: barTop, width: max(barWidth, 0), height: barHeight)
        return PhoneScreenLayout(workspace: workspace, bar: bar, deck: nil, fold: localFold, primaryIsHorizontal: primaryIsHorizontal)
    }
}
