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

@Suite("PhoneScreenLayout")
struct PhoneScreenLayoutTests {
    private let safe = (top: CGFloat(20), leading: CGFloat(0), bottom: CGFloat(20), trailing: CGFloat(0))

    @Test func compactPortraitStacksAndKeepsTheBarOutOfTheWebContent() {
        let layout = PhoneScreenLayout.compute(size: CGSize(width: 402, height: 874), safe: (59, 0, 34, 0), fold: nil, mode: .compact, deskMode: false)
        #expect(!layout.primaryIsHorizontal)
        let bar = layout.bar!
        #expect(layout.workspace.maxY <= bar.minY)
        #expect(bar.height >= 44)
        #expect(layout.fold == nil)
        #expect(layout.deck == nil)
    }

    @Test func compactLandscapeSitsSideBySide() {
        let layout = PhoneScreenLayout.compute(size: CGSize(width: 874, height: 402), safe: (0, 59, 21, 59), fold: nil, mode: .compact, deskMode: false)
        #expect(layout.primaryIsHorizontal)
        #expect(layout.workspace.width > 600)
    }

    @Test func innerDisplayBarStaysOnOneSideOfAVerticalFold() {
        let size = CGSize(width: 1000, height: 750)
        let fold = FoldGutter(primaryIsHorizontal: true, position: 500, thickness: 20, isActive: true)
        for farSide in [false, true] {
            let layout = PhoneScreenLayout.compute(size: size, safe: safe, fold: fold, mode: .inner, deskMode: false, barOnFarSide: farSide)
            let foldRect = CGRect(x: 490, y: 0, width: 20, height: 750)
            #expect(!layout.bar!.intersects(foldRect))
            #expect(layout.primaryIsHorizontal)
            #expect(layout.workspace.maxY <= layout.bar!.minY)
        }
    }

    @Test func foldIsTranslatedIntoWorkspaceCoordinates() {
        let fold = FoldGutter(primaryIsHorizontal: true, position: 500, thickness: 20, isActive: true)
        let layout = PhoneScreenLayout.compute(size: CGSize(width: 1000, height: 750), safe: (20, 10, 20, 10), fold: fold, mode: .inner, deskMode: false)
        #expect(layout.fold?.position == 500 - layout.workspace.minX)
    }

    @Test func innerDisplayWithoutAReportedFoldFallsBackToTheMiddle() {
        let landscape = PhoneScreenLayout.compute(size: CGSize(width: 1000, height: 750), safe: safe, fold: nil, mode: .inner, deskMode: false)
        #expect(landscape.primaryIsHorizontal)
        #expect(landscape.fold?.isActive == false)
        let portrait = PhoneScreenLayout.compute(size: CGSize(width: 750, height: 1000), safe: safe, fold: nil, mode: .inner, deskMode: false)
        #expect(!portrait.primaryIsHorizontal)
    }

    @Test func deskModePutsPanesAboveTheFoldAndControlsBelow() {
        let fold = FoldGutter(primaryIsHorizontal: false, position: 500, thickness: 16, isActive: true)
        let layout = PhoneScreenLayout.compute(size: CGSize(width: 1000, height: 1000), safe: safe, fold: fold, mode: .inner, deskMode: true)
        let deck = layout.deck!
        #expect(layout.workspace.maxY <= 492)
        #expect(deck.minY >= 508)
        #expect(layout.bar == nil)
        #expect(layout.fold == nil, "panes sit wholly on the upright half")
    }

    @Test func deskModeNeedsAHorizontalFold() {
        let vertical = FoldGutter(primaryIsHorizontal: true, position: 500, thickness: 16, isActive: true)
        let layout = PhoneScreenLayout.compute(size: CGSize(width: 1000, height: 750), safe: safe, fold: vertical, mode: .inner, deskMode: true)
        #expect(layout.deck == nil)
        #expect(layout.bar != nil)
    }

    @Test func deskModeIsInnerDisplayOnly() {
        let fold = FoldGutter(primaryIsHorizontal: false, position: 300, thickness: 8, isActive: true)
        let layout = PhoneScreenLayout.compute(size: CGSize(width: 402, height: 600), safe: safe, fold: fold, mode: .compact, deskMode: true)
        #expect(layout.deck == nil)
    }
}

@Suite("SyrupPitch")
struct SyrupPitchTests {
    @Test func theTriggerLeadsThePhonePitch() {
        #expect(SyrupPitch(trigger: .thirdPane, isInnerDisplay: true).features.first == .morePanes)
        #expect(SyrupPitch(trigger: .secondLayout, isInnerDisplay: false).features.first == .unlimitedLayouts)
        #expect(SyrupPitch(trigger: .deskMode, isInnerDisplay: true).features.first == .deskMode)
    }

    @Test func everyFeatureIsListedExactlyOnce() {
        for trigger in [SyrupTrigger.general, .thirdPane, .secondLayout, .deskMode] {
            let features = SyrupPitch(trigger: trigger, isInnerDisplay: false).features
            #expect(features.count == 3)
            #expect(Set(features).count == 3)
            #expect(!features.map { "\($0)" }.contains("autoRefresh"), "auto-refresh is free on every device")
        }
    }

    @Test func generalKeepsTheDefaultOrder() {
        #expect(SyrupPitch(trigger: .general, isInnerDisplay: false).features == SyrupFeature.allCases)
        #expect(SyrupPitch(trigger: .general, isInnerDisplay: false).leadFeature == nil)
    }
}

@Suite("PaneFocus")
struct PaneFocusTests {
    @Test func twoPanesStayVisibleWhenTheDuoCloses() {
        // A7c: two panes fit the outer display, so closing the Duo changes nothing.
        #expect(PaneFocus.focusedIndex(count: 2, mode: .compact, isDeskMode: false, isMaximized: false, selected: 1) == nil)
        #expect(PaneFocus.focusedIndex(count: 2, mode: .inner, isDeskMode: false, isMaximized: false, selected: 1) == nil)
    }

    @Test func threeOrFourPanesShowTheSelectedOneOnACompactDisplay() {
        #expect(PaneFocus.focusedIndex(count: 3, mode: .compact, isDeskMode: false, isMaximized: false, selected: 2) == 2)
        #expect(PaneFocus.focusedIndex(count: 4, mode: .compact, isDeskMode: false, isMaximized: false, selected: nil) == 0)
        #expect(PaneFocus.focusedIndex(count: 4, mode: .inner, isDeskMode: false, isMaximized: false, selected: 2) == nil)
    }

    @Test func maximizeFocusesTheSelectedPaneAnywhere() {
        #expect(PaneFocus.focusedIndex(count: 2, mode: .compact, isDeskMode: false, isMaximized: true, selected: 1) == 1)
        #expect(PaneFocus.focusedIndex(count: 4, mode: .inner, isDeskMode: false, isMaximized: true, selected: 3) == 3)
        #expect(PaneFocus.focusedIndex(count: 1, mode: .compact, isDeskMode: false, isMaximized: true, selected: 0) == nil)
    }

    @Test func deskModeAlwaysShowsEveryPane() {
        #expect(PaneFocus.focusedIndex(count: 4, mode: .inner, isDeskMode: true, isMaximized: true, selected: 1) == nil)
    }

    @Test func maximizeIsClearedWhenItCanNoLongerBeUndone() {
        // A7a: entering desk mode while maximized.
        #expect(!PaneFocus.reconciledMaximized(true, count: 3, isDeskMode: true))
        // A7b: the pane count drops to one, so a pane added later does not open alone.
        #expect(!PaneFocus.reconciledMaximized(true, count: 1, isDeskMode: false))
        #expect(PaneFocus.reconciledMaximized(true, count: 2, isDeskMode: false))
        #expect(!PaneFocus.reconciledMaximized(false, count: 2, isDeskMode: false))
    }

    @Test func aSinglePaneSpansTheFoldByDesign() {
        // A18: one page is full screen on the inner display; only multi-pane layouts avoid the fold.
        let size = CGSize(width: 700, height: 600)
        let fold = FoldGutter(primaryIsHorizontal: true, position: 350, thickness: 16, isActive: true)
        let single = PaneFrameCalculator.frames(count: 1, ratios: .default, size: size, primaryIsHorizontal: true, fold: fold)
        #expect(single.panes == [CGRect(origin: .zero, size: size)])
        #expect(single.dividers.isEmpty)
        let two = PaneFrameCalculator.frames(count: 2, ratios: .default, size: size, primaryIsHorizontal: true, fold: fold)
        #expect(two.panes[0].maxX <= 342 && two.panes[1].minX >= 358)
    }
}

@Suite("FoldGeometry production path")
struct FoldGeometryTests {
    // The Duo's inner display, landscape, with a status column of 48 points on the leading
    // side and a home indicator inset at the bottom.
    private let screen = CGSize(width: 1000, height: 750)
    private let safe = (top: CGFloat(0), leading: CGFloat(48), bottom: CGFloat(21), trailing: CGFloat(0))
    // The reported fold, in screen space: a 20-point-wide band centred at x = 500, with margins.
    private let foldOnScreen = CGRect(x: 490, y: 0, width: 20, height: 750)

    private func panesInScreenSpace(layout: PhoneScreenLayout, count: Int) -> [CGRect] {
        PaneFrameCalculator.frames(
            count: count, ratios: .default, size: layout.workspace.size,
            primaryIsHorizontal: layout.primaryIsHorizontal, fold: layout.fold
        ).panes.map { $0.offsetBy(dx: layout.workspace.minX, dy: layout.workspace.minY) }
    }

    @Test func aFullScreenReaderNeedsNoConversion() {
        let frame = FoldGeometry.screenFrame(regionFrame: foldOnScreen, viewSize: screen, viewOriginInScreen: .zero)
        #expect(frame == foldOnScreen)
    }

    @Test func panesAvoidTheFoldWithNonZeroSafeAreaInsets() {
        let gutter = FoldGeometry.gutter(regionFrame: foldOnScreen, isActive: true, viewSize: screen, viewOriginInScreen: .zero)
        let layout = PhoneScreenLayout.compute(size: screen, safe: safe, fold: gutter, mode: .inner, deskMode: false)
        #expect(layout.workspace.minX == 48 + PhoneScreenLayout.margin, "the status column is respected")
        for count in 2...4 {
            let panes = panesInScreenSpace(layout: layout, count: count)
            for pane in panes { #expect(!pane.intersects(foldOnScreen), "pane \(pane) crosses the fold with \(count) panes") }
        }
    }

    @Test func aReaderInsideTheSafeAreaIsConvertedByItsOrigin() {
        // A reader that starts after the status column reports the fold in its own space.
        let origin = CGPoint(x: 48, y: 0)
        let readerSize = CGSize(width: 952, height: 729)
        let local = foldOnScreen.offsetBy(dx: -origin.x, dy: -origin.y)
        let converted = FoldGeometry.screenFrame(regionFrame: local, viewSize: readerSize, viewOriginInScreen: origin)
        #expect(converted == foldOnScreen)
    }

    @Test func aWindowSpaceFrameIsRecognisedAndNotShiftedTwice() {
        // If the SDK actually returned window space, the frame sticks out of the reader once
        // the origin is added; the guard keeps it where it is.
        let origin = CGPoint(x: 48, y: 0)
        let readerSize = CGSize(width: 450, height: 729)   // local reading (470...490) would overflow the reader
        let windowSpace = CGRect(x: 470, y: 0, width: 20, height: 729)
        let converted = FoldGeometry.screenFrame(regionFrame: windowSpace, viewSize: readerSize, viewOriginInScreen: origin)
        #expect(converted == windowSpace)
    }

    @Test func innerDisplayBarIsOnlyConfinedWhileTheFoldIsActive() {
        // A9: flat (inactive) or no fold: the bar spans the display; partially open: one side.
        let inactive = FoldGutter(primaryIsHorizontal: true, position: 500, thickness: 20, isActive: false)
        let flat = PhoneScreenLayout.compute(size: screen, safe: safe, fold: inactive, mode: .inner, deskMode: false)
        let none = PhoneScreenLayout.compute(size: screen, safe: safe, fold: nil, mode: .inner, deskMode: false)
        let fullWidth = screen.width - safe.leading - safe.trailing - 2 * PhoneScreenLayout.margin
        #expect(flat.bar!.width == min(fullWidth, PhoneScreenLayout.maxBarWidth))
        #expect(none.bar!.width == flat.bar!.width)
        let active = FoldGutter(primaryIsHorizontal: true, position: 500, thickness: 20, isActive: true)
        let folded = PhoneScreenLayout.compute(size: screen, safe: safe, fold: active, mode: .inner, deskMode: false)
        #expect(folded.bar!.width < flat.bar!.width)
        #expect(!folded.bar!.intersects(foldOnScreen))
    }
}

@Suite("FoldableDevice")
struct FoldableDeviceTests {
    @Test func theDuoIsRecognisedByModelIdentifier() {
        #expect(FoldableDevice.isFoldable(modelIdentifier: "iPhone19,4"))
        #expect(!FoldableDevice.isFoldable(modelIdentifier: "iPhone18,1"))
        #expect(!FoldableDevice.isFoldable(modelIdentifier: ""))
    }

    @Test func limitMessageDependsOnTheDevice() {
        #expect(FoldableDevice.limitMessage(mode: .compact, isFoldable: true) == .unfoldToAddMore)
        #expect(FoldableDevice.limitMessage(mode: .compact, isFoldable: false) == .phoneFitsTwo)
        #expect(FoldableDevice.limitMessage(mode: .inner, isFoldable: true) == .displayFits(4))
    }
}
