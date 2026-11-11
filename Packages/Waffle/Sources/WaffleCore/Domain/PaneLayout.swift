//
//  PaneLayout.swift
//  WaffleCore
//
//  Pure pane math for iPhone and iPhone Duo. The iPad keeps its rows x cols grid; phones
//  show two to four resizable "panes" instead. Everything here is geometry and policy —
//  no UIKit/SwiftUI — so placement around the fold, compact limits, preset
//  down-conversion and free/paid gating are all host-tested.
//
//  Model: panes split into two groups, A (leading/top) and B (trailing/bottom), that sit
//  side by side along the *primary axis*. Each group stacks its own panes along the
//  perpendicular axis. On the Duo's inner display the fold is the seam between A and B,
//  so no pane ever straddles it; every other divider is free-ratio.
//

import CoreGraphics
import Foundation

// MARK: - Mode

/// How a phone scene should lay panes out. Derived from size classes (not the idiom or
/// orientation), as Apple advises for the Duo.
nonisolated public enum PaneMode: Equatable, Sendable {
    /// Regular iPhones and the Duo's outer display: at most two panes.
    case compact
    /// The Duo's inner display (regular/regular size classes): up to four panes.
    case inner

    /// Phones with a regular horizontal AND vertical size class are the Duo's inner
    /// display. (Plus/Max phones in landscape are regular width but compact height.)
    public static func resolve(horizontalRegular: Bool, verticalRegular: Bool) -> PaneMode {
        horizontalRegular && verticalRegular ? .inner : .compact
    }
}

// MARK: - Ratios

/// The three adjustable ratios of a pane layout, persisted with snapshots and presets.
nonisolated public struct PaneRatios: Equatable, Sendable, Codable {
    public static let minimum = 0.2
    public static let maximum = 0.8
    public static let `default` = PaneRatios()

    /// Share of the primary axis given to group A (ignored while the fold is active).
    public var primary: Double
    /// Share of group A's length given to its first pane (when A holds two panes).
    public var stackA: Double
    /// Share of group B's length given to its first pane (when B holds two panes).
    public var stackB: Double

    public init(primary: Double = 0.5, stackA: Double = 0.5, stackB: Double = 0.5) {
        self.primary = Self.clamp(primary)
        self.stackA = Self.clamp(stackA)
        self.stackB = Self.clamp(stackB)
    }

    public static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0.5 }
        return min(max(value, minimum), maximum)
    }

    /// Persisted form: `[primary, stackA, stackB]`.
    public var array: [Double] { [primary, stackA, stackB] }

    /// Decodes the persisted form; missing or malformed values fall back to even splits.
    public init(array: [Double]) {
        self.init(
            primary: array.count > 0 ? array[0] : 0.5,
            stackA: array.count > 1 ? array[1] : 0.5,
            stackB: array.count > 2 ? array[2] : 0.5
        )
    }
}

// MARK: - Focus

/// Which pane (if any) a phone shows alone, and when the user's "maximize" still applies.
/// Pure so the rules that were once scattered through the view are host-tested.
nonisolated public enum PaneFocus {
    /// The index of the pane shown alone, or nil when every pane is shown.
    /// - Compact displays hold two panes: with three or four open they show the selected
    ///   one (a regular iPhone or the Duo's outer display; unfolding shows them all).
    ///   Closing the Duo with one or two panes open changes nothing: both fit.
    /// - Maximize focuses the selected pane on any display.
    /// - Desk mode shows every pane on the upright half; there is no maximize there.
    public static func focusedIndex(count: Int, mode: PaneMode, isDeskMode: Bool, isMaximized: Bool, selected: Int?) -> Int? {
        guard count > 1, !isDeskMode else { return nil }
        let forced = mode == .compact && count > PaneLimits.maxCompactPanes
        guard isMaximized || forced else { return nil }
        return PaneFrameCalculator.focusIndex(selected: selected, count: count)
    }

    /// The user's maximize flag after the arrangement changed: it means nothing with a single
    /// pane (a pane added later must not open alone) and is cleared on entering desk mode,
    /// whose deck has no control to undo it.
    public static func reconciledMaximized(_ isMaximized: Bool, count: Int, isDeskMode: Bool) -> Bool {
        isMaximized && count > 1 && !isDeskMode
    }
}

// MARK: - Limits & gating

/// Which divider a drag adjusts.
nonisolated public enum PaneDividerKind: Equatable, Sendable {
    case primary, stackA, stackB
}

nonisolated public enum AddPaneDecision: Equatable, Sendable {
    case allowed
    /// The user could add a pane if they owned Syrup: show the paywall.
    case needsSyrup
    /// The display has no room for another pane regardless of entitlement.
    case atDeviceLimit
}

nonisolated public enum PaneLimits {
    /// Regular iPhones and the Duo's outer display.
    public static let maxCompactPanes = 2
    /// The Duo's inner display.
    public static let maxInnerPanes = 4
    /// Panes a free user may have. Panes three and four are Syrup.
    public static let maxFreePanes = 2
    /// Saved layouts a free user may keep on iPhone/Duo. More than one is Syrup.
    public static let maxFreeSavedLayouts = 1

    /// The most panes the display itself can hold.
    public static func deviceMax(for mode: PaneMode) -> Int {
        mode == .inner ? maxInnerPanes : maxCompactPanes
    }

    /// The most panes this user may have right now on this display.
    public static func allowedMax(for mode: PaneMode, isSyrupEnabled: Bool) -> Int {
        let device = deviceMax(for: mode)
        return isSyrupEnabled ? device : min(device, maxFreePanes)
    }

    /// The most panes an entitlement allows on any display (used when restoring state,
    /// where the mode may be the Duo's outer display even though panes were opened inside).
    public static func entitlementMax(isSyrupEnabled: Bool) -> Int {
        isSyrupEnabled ? maxInnerPanes : maxFreePanes
    }

    public static func addPane(currentCount: Int, mode: PaneMode, isSyrupEnabled: Bool) -> AddPaneDecision {
        let next = currentCount + 1
        if next > deviceMax(for: mode) { return .atDeviceLimit }
        if next > allowedMax(for: mode, isSyrupEnabled: isSyrupEnabled) { return .needsSyrup }
        return .allowed
    }

    /// Whether the user may save one more layout given how many already exist.
    public static func canSaveLayout(existingCount: Int, isSyrupEnabled: Bool) -> Bool {
        isSyrupEnabled || existingCount < maxFreeSavedLayouts
    }

    /// Panes a saved layout opens with on this display: its first panes, never an error.
    public static func openablePaneCount(saved: Int, mode: PaneMode, isSyrupEnabled: Bool) -> Int {
        max(1, min(saved, allowedMax(for: mode, isSyrupEnabled: isSyrupEnabled)))
    }

    /// Slots of a saved layout: panes for pane layouts, rows x cols for iPad grids.
    public static func savedSlotCount(paneCount: Int, rows: Int, cols: Int) -> Int {
        paneCount > 0 ? paneCount : max(1, rows) * max(1, cols)
    }

    /// The rows x cols an iPad shows for an N-pane layout, so phone layouts open there too.
    public static func gridShape(forPaneCount count: Int) -> (rows: Int, cols: Int) {
        switch count {
        case ...1: return (1, 1)
        case 2: return (1, 2)
        default: return (2, 2)
        }
    }
}

// MARK: - Fold

/// The fold (the Duo's "division" reserved region) reduced to what layout needs.
nonisolated public struct FoldGutter: Equatable, Sendable {
    /// The primary axis runs horizontally (groups A and B sit left/right) when the fold is vertical.
    public var primaryIsHorizontal: Bool
    /// Position of the fold's centre along the primary axis, in the workspace's coordinates.
    public var position: CGFloat
    /// Width of the dead zone along the primary axis.
    public var thickness: CGFloat
    /// The system only reports an active fold while the device is partially open.
    public var isActive: Bool

    public init(primaryIsHorizontal: Bool, position: CGFloat, thickness: CGFloat, isActive: Bool) {
        self.primaryIsHorizontal = primaryIsHorizontal
        self.position = position
        self.thickness = thickness
        self.isActive = isActive
    }

    /// Reduces a reported fold rectangle: a tall region means a vertical fold.
    public init(frame: CGRect, isActive: Bool) {
        if frame.height >= frame.width {
            self.init(primaryIsHorizontal: true, position: frame.midX, thickness: frame.width, isActive: isActive)
        } else {
            self.init(primaryIsHorizontal: false, position: frame.midY, thickness: frame.height, isActive: isActive)
        }
    }

    /// Where the fold sits when the SDK reports nothing (simulators, flat layouts): the
    /// middle of the display, perpendicular to its long edge.
    public static func centered(in size: CGSize) -> FoldGutter {
        let horizontal = size.width >= size.height
        return FoldGutter(
            primaryIsHorizontal: horizontal,
            position: horizontal ? size.width / 2 : size.height / 2,
            thickness: 0,
            isActive: false
        )
    }
}

// MARK: - Frames

nonisolated public struct PaneDivider: Equatable, Sendable {
    public var kind: PaneDividerKind
    /// The visible seam between the two panes.
    public var seam: CGRect
    /// The drag axis: true when the divider moves left/right.
    public var movesHorizontally: Bool
    /// The track the divider travels in, along its drag axis.
    public var trackStart: CGFloat
    public var trackLength: CGFloat
    /// The fold owns the primary divider while it is active; it cannot be dragged.
    public var isLocked: Bool
}

nonisolated public struct PaneFrames: Equatable, Sendable {
    /// One frame per pane, in pane order.
    public var panes: [CGRect]
    public var dividers: [PaneDivider]
}

nonisolated public enum PaneFrameCalculator {
    public static let defaultSpacing: CGFloat = 4
    /// Distance within which a dragged divider snaps to the fold.
    public static let snapDistance: CGFloat = 24

    /// Pane indices held by group A and group B.
    public static func slots(count: Int, primaryIsHorizontal: Bool) -> (a: [Int], b: [Int]) {
        switch count {
        case ...1: return ([0], [])
        case 2: return ([0], [1])
        case 3: return ([0], [1, 2])
        default: return primaryIsHorizontal ? ([0, 2], [1, 3]) : ([0, 1], [2, 3])
        }
    }

    /// Places `count` panes in `size`.
    /// - Parameters:
    ///   - primaryIsHorizontal: groups A and B sit left/right (true) or top/bottom (false).
    ///   - fold: when active the primary seam is pinned to it (a gutter, no pane crosses).
    public static func frames(
        count: Int,
        ratios: PaneRatios,
        size: CGSize,
        primaryIsHorizontal: Bool,
        fold: FoldGutter? = nil,
        spacing: CGFloat = defaultSpacing
    ) -> PaneFrames {
        let count = max(1, min(count, PaneLimits.maxInnerPanes))
        let bounds = CGRect(origin: .zero, size: size)
        let groups = slots(count: count, primaryIsHorizontal: primaryIsHorizontal)
        // A single pane deliberately spans the fold: on the inner display one page is shown
        // full screen, like any other app. Only multi-pane layouts keep panes off the fold.
        guard count > 1 else { return PaneFrames(panes: [bounds], dividers: []) }

        let total = primaryIsHorizontal ? size.width : size.height
        let lockedToFold = (fold?.isActive ?? false) && fold?.primaryIsHorizontal == primaryIsHorizontal
        let seamThickness = lockedToFold ? max(spacing, fold?.thickness ?? 0) : spacing

        // Primary split: where group A ends and group B begins.
        let aLength: CGFloat
        if lockedToFold, let fold {
            aLength = min(max(fold.position - seamThickness / 2, 0), max(total - seamThickness, 0))
        } else {
            aLength = max((total - seamThickness) * CGFloat(ratios.primary), 0)
        }
        let bLength = max(total - seamThickness - aLength, 0)

        let aRect: CGRect
        let bRect: CGRect
        if primaryIsHorizontal {
            aRect = CGRect(x: 0, y: 0, width: aLength, height: size.height)
            bRect = CGRect(x: aLength + seamThickness, y: 0, width: bLength, height: size.height)
        } else {
            aRect = CGRect(x: 0, y: 0, width: size.width, height: aLength)
            bRect = CGRect(x: 0, y: aLength + seamThickness, width: size.width, height: bLength)
        }

        var panes = Array(repeating: CGRect.zero, count: count)
        var dividers: [PaneDivider] = []

        let primarySeam = primaryIsHorizontal
            ? CGRect(x: aLength, y: 0, width: seamThickness, height: size.height)
            : CGRect(x: 0, y: aLength, width: size.width, height: seamThickness)
        dividers.append(PaneDivider(
            kind: .primary,
            seam: primarySeam,
            movesHorizontally: primaryIsHorizontal,
            trackStart: 0,
            trackLength: total,
            isLocked: lockedToFold
        ))

        func place(_ indices: [Int], in rect: CGRect, ratio: Double, kind: PaneDividerKind) {
            guard let first = indices.first else { return }
            if indices.count == 1 {
                panes[first] = rect
                return
            }
            // Stack perpendicular to the primary axis.
            let stackHorizontally = !primaryIsHorizontal
            let length = stackHorizontally ? rect.width : rect.height
            let firstLength = max((length - spacing) * CGFloat(ratio), 0)
            let secondLength = max(length - spacing - firstLength, 0)
            if stackHorizontally {
                panes[indices[0]] = CGRect(x: rect.minX, y: rect.minY, width: firstLength, height: rect.height)
                panes[indices[1]] = CGRect(x: rect.minX + firstLength + spacing, y: rect.minY, width: secondLength, height: rect.height)
                dividers.append(PaneDivider(
                    kind: kind,
                    seam: CGRect(x: rect.minX + firstLength, y: rect.minY, width: spacing, height: rect.height),
                    movesHorizontally: true,
                    trackStart: rect.minX,
                    trackLength: length,
                    isLocked: false
                ))
            } else {
                panes[indices[0]] = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: firstLength)
                panes[indices[1]] = CGRect(x: rect.minX, y: rect.minY + firstLength + spacing, width: rect.width, height: secondLength)
                dividers.append(PaneDivider(
                    kind: kind,
                    seam: CGRect(x: rect.minX, y: rect.minY + firstLength, width: rect.width, height: spacing),
                    movesHorizontally: false,
                    trackStart: rect.minY,
                    trackLength: length,
                    isLocked: false
                ))
            }
        }

        place(groups.a, in: aRect, ratio: ratios.stackA, kind: .stackA)
        place(groups.b, in: bRect, ratio: ratios.stackB, kind: .stackB)
        return PaneFrames(panes: panes, dividers: dividers)
    }

    /// Converts a divider position (along its drag axis) into a clamped ratio.
    public static func ratio(forDividerAt position: CGFloat, divider: PaneDivider, spacing: CGFloat = defaultSpacing) -> Double {
        let usable = max(divider.trackLength - divider.seam.thickness(along: divider.movesHorizontally), 1)
        let raw = Double((position - divider.trackStart - divider.seam.thickness(along: divider.movesHorizontally) / 2) / usable)
        return PaneRatios.clamp(raw)
    }

    /// Snaps a primary ratio to the fold's position (when known) or to an even split.
    public static func snappedPrimaryRatio(_ ratio: Double, total: CGFloat, fold: FoldGutter?, snap: CGFloat = snapDistance) -> Double {
        guard total > 0 else { return ratio }
        var targets: [Double] = [0.5]
        if let fold { targets.append(Double(fold.position / total)) }
        for target in targets where abs(CGFloat(ratio - target) * total) <= snap {
            return PaneRatios.clamp(target)
        }
        return ratio
    }

    /// The pane to show alone in compact mode when more panes are open than fit.
    public static func focusIndex(selected: Int?, count: Int) -> Int {
        guard count > 0 else { return 0 }
        guard let selected, selected >= 0, selected < count else { return 0 }
        return selected
    }
}

private extension CGRect {
    nonisolated func thickness(along horizontal: Bool) -> CGFloat { horizontal ? width : height }
}
