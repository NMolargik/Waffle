//
//  FoldGeometry.swift
//  WaffleCore
//
//  Turns the rectangle the system reports for the fold into the coordinates the phone
//  layout works in, explicitly rather than by assumption.
//
//  What the SDK documents (iOS 27.1, `ReservedRegion` / `GeometryProxy.reservedRegions`):
//  - `ReservedRegion.frame`: "The rect of the region in the view's coordinate space,
//    including the margins." `margins`: "The margins included in the frame around the rect
//    for interactive content." `isActive`: "Whether the region is active."
//  - `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)`: "Returns the
//    reserved regions for the given kind." It does not say which view's space.
//  So the space is the reading view's own (for a `GeometryProxy`: the reader's local space,
//  origin at the reader's top-left). It is not documented as window or screen space, and the
//  doc says nothing about safe areas.
//
//  The phone layout therefore reads the fold from the same `GeometryReader` it lays out in
//  (which sits inside the safe area, so its origin is the safe area's corner, not the
//  screen's), converts explicitly from that origin to screen coordinates, and gives
//  `PhoneScreenLayout` the screen size with the real safe-area insets. As a guard against the
//  one assumption left (local vs window space), `screenFrame` prefers whichever
//  interpretation lands inside the view. That guard, and the exact margins, need a real
//  iPhone Duo to confirm.
//

import CoreGraphics
import Foundation

nonisolated public enum FoldGeometry {
    /// The fold's rectangle in screen coordinates.
    /// - Parameters:
    ///   - regionFrame: `ReservedRegion.frame` as the SDK returned it.
    ///   - viewSize: the reading view's size.
    ///   - viewOriginInScreen: where the reading view's top-left sits on screen (zero when
    ///     the reading view fills the screen).
    public static func screenFrame(regionFrame: CGRect, viewSize: CGSize, viewOriginInScreen: CGPoint) -> CGRect {
        let tolerance: CGFloat = 1
        let bounds = CGRect(origin: .zero, size: viewSize).insetBy(dx: -tolerance, dy: -tolerance)
        let local = regionFrame
        // Documented: view-local. Guard: a frame that sticks out of the view but fits once the
        // view's origin is removed was in window space.
        if !bounds.contains(local), viewOriginInScreen != .zero {
            let shifted = local.offsetBy(dx: -viewOriginInScreen.x, dy: -viewOriginInScreen.y)
            if bounds.contains(shifted) {
                return shifted.offsetBy(dx: viewOriginInScreen.x, dy: viewOriginInScreen.y)
            }
        }
        return local.offsetBy(dx: viewOriginInScreen.x, dy: viewOriginInScreen.y)
    }

    public static func gutter(regionFrame: CGRect, isActive: Bool, viewSize: CGSize, viewOriginInScreen: CGPoint) -> FoldGutter {
        FoldGutter(
            frame: screenFrame(regionFrame: regionFrame, viewSize: viewSize, viewOriginInScreen: viewOriginInScreen),
            isActive: isActive
        )
    }
}
