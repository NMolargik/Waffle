//
//  PaneLayoutTests.swift
//  WaffleCoreTests
//
//  Pane placement around the fold, compact limits, and free/paid gating for iPhone and Duo.
//

import CoreGraphics
import Testing
@testable import WaffleCore

@Suite("PaneLayout")
struct PaneLayoutTests {
    private let innerLandscape = CGSize(width: 1000, height: 750)
    private let innerPortrait = CGSize(width: 750, height: 1000)

    // MARK: - Mode & limits

    @Test func regularRegularIsInnerDisplay() {
        #expect(PaneMode.resolve(horizontalRegular: true, verticalRegular: true) == .inner)
        // Plus/Max phones in landscape are regular width but compact height.
        #expect(PaneMode.resolve(horizontalRegular: true, verticalRegular: false) == .compact)
        #expect(PaneMode.resolve(horizontalRegular: false, verticalRegular: true) == .compact)
    }

    @Test func compactAllowsTwoPanesEvenWithSyrup() {
        #expect(PaneLimits.allowedMax(for: .compact, isSyrupEnabled: true) == 2)
        #expect(PaneLimits.allowedMax(for: .compact, isSyrupEnabled: false) == 2)
    }

    @Test func innerDisplayFreeTwoPaidFour() {
        #expect(PaneLimits.allowedMax(for: .inner, isSyrupEnabled: false) == 2)
        #expect(PaneLimits.allowedMax(for: .inner, isSyrupEnabled: true) == 4)
    }

    @Test func thirdPaneNeedsSyrupOnInnerDisplay() {
        #expect(PaneLimits.addPane(currentCount: 1, mode: .inner, isSyrupEnabled: false) == .allowed)
        #expect(PaneLimits.addPane(currentCount: 2, mode: .inner, isSyrupEnabled: false) == .needsSyrup)
        #expect(PaneLimits.addPane(currentCount: 2, mode: .inner, isSyrupEnabled: true) == .allowed)
        #expect(PaneLimits.addPane(currentCount: 4, mode: .inner, isSyrupEnabled: true) == .atDeviceLimit)
    }

    @Test func compactThirdPaneIsADeviceLimitNotAPaywall() {
        #expect(PaneLimits.addPane(currentCount: 2, mode: .compact, isSyrupEnabled: true) == .atDeviceLimit)
        #expect(PaneLimits.addPane(currentCount: 2, mode: .compact, isSyrupEnabled: false) == .atDeviceLimit)
    }

    @Test func freePlanKeepsOneSavedLayout() {
        #expect(PaneLimits.canSaveLayout(existingCount: 0, isSyrupEnabled: false))
        #expect(!PaneLimits.canSaveLayout(existingCount: 1, isSyrupEnabled: false))
        #expect(PaneLimits.canSaveLayout(existingCount: 25, isSyrupEnabled: true))
    }

    @Test func entitlementMaxIgnoresDisplay() {
        #expect(PaneLimits.entitlementMax(isSyrupEnabled: false) == 2)
        #expect(PaneLimits.entitlementMax(isSyrupEnabled: true) == 4)
    }

    // MARK: - Preset down-conversion

    @Test func largeIPadGridOpensItsFirstPanes() {
        // A 3x3 iPad preset on a regular iPhone opens two panes, not an error.
        let saved = PaneLimits.savedSlotCount(paneCount: 0, rows: 3, cols: 3)
        #expect(saved == 9)
        #expect(PaneLimits.openablePaneCount(saved: saved, mode: .compact, isSyrupEnabled: true) == 2)
        #expect(PaneLimits.openablePaneCount(saved: saved, mode: .inner, isSyrupEnabled: true) == 4)
        #expect(PaneLimits.openablePaneCount(saved: saved, mode: .inner, isSyrupEnabled: false) == 2)
    }

    @Test func smallPresetsOpenFully() {
        #expect(PaneLimits.openablePaneCount(saved: 1, mode: .compact, isSyrupEnabled: false) == 1)
        #expect(PaneLimits.openablePaneCount(saved: 3, mode: .inner, isSyrupEnabled: true) == 3)
    }

    @Test func paneLayoutsOpenAsSmallGridsOnIPad() {
        #expect(PaneLimits.gridShape(forPaneCount: 1) == (1, 1))
        #expect(PaneLimits.gridShape(forPaneCount: 2) == (1, 2))
        #expect(PaneLimits.gridShape(forPaneCount: 3) == (2, 2))
        #expect(PaneLimits.gridShape(forPaneCount: 4) == (2, 2))
        #expect(PaneLimits.savedSlotCount(paneCount: 3, rows: 2, cols: 2) == 3)
    }

    // MARK: - Ratios

    @Test func ratiosClampAndRoundTrip() {
        let ratios = PaneRatios(primary: 0.05, stackA: 0.95, stackB: 0.4)
        #expect(ratios.primary == PaneRatios.minimum)
        #expect(ratios.stackA == PaneRatios.maximum)
        #expect(PaneRatios(array: ratios.array) == ratios)
        #expect(PaneRatios(array: []) == .default)
        #expect(PaneRatios(array: [.nan, 0.3]).primary == 0.5)
    }

    // MARK: - Frames

    @Test func singlePaneFillsTheArea() {
        let frames = PaneFrameCalculator.frames(count: 1, ratios: .default, size: innerLandscape, primaryIsHorizontal: true)
        #expect(frames.panes == [CGRect(origin: .zero, size: innerLandscape)])
        #expect(frames.dividers.isEmpty)
    }

    @Test func twoPanesFollowTheRatio() {
        let ratios = PaneRatios(primary: 0.3)
        let frames = PaneFrameCalculator.frames(count: 2, ratios: ratios, size: innerLandscape, primaryIsHorizontal: true)
        #expect(frames.panes.count == 2)
        #expect(abs(frames.panes[0].width - 0.3 * 996) < 0.01)
        #expect(frames.panes[0].maxX + 4 == frames.panes[1].minX)
        #expect(frames.panes[1].maxX == 1000)
        #expect(frames.dividers.count == 1)
        #expect(frames.dividers[0].kind == .primary)
        #expect(!frames.dividers[0].isLocked)
    }

    @Test func twoPanesStackWhenThePrimaryAxisIsVertical() {
        let frames = PaneFrameCalculator.frames(count: 2, ratios: .default, size: innerPortrait, primaryIsHorizontal: false)
        #expect(frames.panes[0].width == 750)
        #expect(frames.panes[1].minY > frames.panes[0].maxY)
        #expect(frames.panes[1].maxY == 1000)
    }

    @Test func activeFoldPinsTheSeamAndNoPaneStraddlesIt() {
        // Skewed ratio is ignored: the fold wins. Gutter is the fold's width.
        let fold = FoldGutter(primaryIsHorizontal: true, position: 500, thickness: 20, isActive: true)
        let frames = PaneFrameCalculator.frames(count: 4, ratios: PaneRatios(primary: 0.25), size: innerLandscape, primaryIsHorizontal: true, fold: fold)
        let foldRect = CGRect(x: 490, y: 0, width: 20, height: 750)
        for pane in frames.panes {
            #expect(!pane.intersects(foldRect), "pane \(pane) straddles the fold")
        }
        #expect(frames.dividers[0].isLocked)
        #expect(frames.panes[0].maxX == 490)
        #expect(frames.panes[1].minX == 510)
    }

    @Test func horizontalFoldSplitsTopAndBottom() {
        let fold = FoldGutter(primaryIsHorizontal: false, position: 500, thickness: 16, isActive: true)
        let frames = PaneFrameCalculator.frames(count: 3, ratios: .default, size: innerPortrait, primaryIsHorizontal: false, fold: fold)
        let foldRect = CGRect(x: 0, y: 492, width: 750, height: 16)
        #expect(frames.panes.allSatisfy { !$0.intersects(foldRect) })
        // One pane above the fold, two side by side below.
        #expect(frames.panes[0].width == 750)
        #expect(frames.panes[1].minY == frames.panes[2].minY)
        #expect(frames.panes[1].maxX < frames.panes[2].minX)
    }

    @Test func foldAlongTheOtherAxisDoesNotLockThisLayout() {
        // A horizontal fold must not pin a layout whose groups sit left/right.
        let fold = FoldGutter(primaryIsHorizontal: false, position: 375, thickness: 10, isActive: true)
        let frames = PaneFrameCalculator.frames(count: 2, ratios: PaneRatios(primary: 0.3), size: innerLandscape, primaryIsHorizontal: true, fold: fold)
        #expect(!frames.dividers[0].isLocked)
    }

    @Test func inactiveFoldLeavesRatiosFree() {
        let fold = FoldGutter(primaryIsHorizontal: true, position: 500, thickness: 20, isActive: false)
        let frames = PaneFrameCalculator.frames(count: 2, ratios: PaneRatios(primary: 0.7), size: innerLandscape, primaryIsHorizontal: true, fold: fold)
        #expect(frames.panes[0].width > 600)
        #expect(!frames.dividers[0].isLocked)
    }

    @Test func threePanesPutOneOnASideAndTwoStackedOnTheOther() {
        let frames = PaneFrameCalculator.frames(count: 3, ratios: PaneRatios(stackB: 0.4), size: innerLandscape, primaryIsHorizontal: true)
        #expect(frames.panes[0].height == 750)
        #expect(frames.panes[1].minX == frames.panes[2].minX)
        #expect(frames.panes[1].height < frames.panes[2].height)
        #expect(frames.dividers.map(\.kind) == [.primary, .stackB])
    }

    @Test func fourPanesAreRowMajorLikeTheIPadGrid() {
        let horizontal = PaneFrameCalculator.frames(count: 4, ratios: .default, size: innerLandscape, primaryIsHorizontal: true)
        // Pane 0 top-left, 1 top-right, 2 bottom-left, 3 bottom-right.
        #expect(horizontal.panes[0].minY == horizontal.panes[1].minY)
        #expect(horizontal.panes[2].minY > horizontal.panes[0].minY)
        #expect(horizontal.panes[1].minX > horizontal.panes[0].minX)
        let vertical = PaneFrameCalculator.frames(count: 4, ratios: .default, size: innerPortrait, primaryIsHorizontal: false)
        #expect(vertical.panes[0].minY == vertical.panes[1].minY)
        #expect(vertical.panes[2].minY > vertical.panes[0].minY)
        #expect(vertical.panes[1].minX > vertical.panes[0].minX)
    }

    @Test func panesNeverOverlapOrLeaveTheArea() {
        let bounds = CGRect(origin: .zero, size: innerLandscape).insetBy(dx: -0.001, dy: -0.001)
        for count in 1...4 {
            for horizontal in [true, false] {
                let frames = PaneFrameCalculator.frames(count: count, ratios: PaneRatios(primary: 0.35, stackA: 0.6, stackB: 0.25), size: innerLandscape, primaryIsHorizontal: horizontal)
                #expect(frames.panes.count == count)
                for (i, pane) in frames.panes.enumerated() {
                    #expect(bounds.contains(pane))
                    for other in frames.panes[(i + 1)...] {
                        #expect(pane.intersection(other).width <= 0.001 || pane.intersection(other).height <= 0.001)
                    }
                }
            }
        }
    }

    // MARK: - Dragging

    @Test func draggingADividerMapsBackToItsRatio() {
        let ratios = PaneRatios(primary: 0.35)
        let frames = PaneFrameCalculator.frames(count: 2, ratios: ratios, size: innerLandscape, primaryIsHorizontal: true)
        let divider = frames.dividers[0]
        let center = divider.seam.midX
        #expect(abs(PaneFrameCalculator.ratio(forDividerAt: center, divider: divider) - 0.35) < 0.001)
        #expect(PaneFrameCalculator.ratio(forDividerAt: -500, divider: divider) == PaneRatios.minimum)
        #expect(PaneFrameCalculator.ratio(forDividerAt: 5000, divider: divider) == PaneRatios.maximum)
    }

    @Test func stackDividersMapBackToo() {
        let frames = PaneFrameCalculator.frames(count: 3, ratios: PaneRatios(stackB: 0.7), size: innerLandscape, primaryIsHorizontal: true)
        let divider = frames.dividers[1]
        #expect(abs(PaneFrameCalculator.ratio(forDividerAt: divider.seam.midY, divider: divider) - 0.7) < 0.001)
    }

    @Test func primarySnapsToTheFoldAndTheMiddle() {
        let fold = FoldGutter(primaryIsHorizontal: true, position: 400, thickness: 0, isActive: false)
        #expect(PaneFrameCalculator.snappedPrimaryRatio(0.41, total: 1000, fold: fold) == 0.4)
        #expect(PaneFrameCalculator.snappedPrimaryRatio(0.51, total: 1000, fold: fold) == 0.5)
        #expect(PaneFrameCalculator.snappedPrimaryRatio(0.7, total: 1000, fold: fold) == 0.7)
    }

    // MARK: - Fold geometry

    @Test func tallRegionIsAVerticalFold() {
        let fold = FoldGutter(frame: CGRect(x: 490, y: 0, width: 20, height: 750), isActive: true)
        #expect(fold.primaryIsHorizontal)
        #expect(fold.position == 500)
        #expect(fold.thickness == 20)
    }

    @Test func wideRegionIsAHorizontalFold() {
        let fold = FoldGutter(frame: CGRect(x: 0, y: 480, width: 750, height: 16), isActive: true)
        #expect(!fold.primaryIsHorizontal)
        #expect(fold.position == 488)
    }

    @Test func fallbackFoldRunsThroughTheMiddle() {
        #expect(FoldGutter.centered(in: innerLandscape).primaryIsHorizontal)
        #expect(!FoldGutter.centered(in: innerPortrait).primaryIsHorizontal)
        #expect(FoldGutter.centered(in: innerPortrait).position == 500)
    }

    @Test func focusFallsBackToTheFirstPane() {
        #expect(PaneFrameCalculator.focusIndex(selected: 2, count: 3) == 2)
        #expect(PaneFrameCalculator.focusIndex(selected: 5, count: 3) == 0)
        #expect(PaneFrameCalculator.focusIndex(selected: nil, count: 3) == 0)
    }
}
