//
//  PaneWorkspaceView.swift
//  WaffleFeatureGrid
//
//  The iPhone / iPhone Duo counterpart of `WaffleGridView`: two to four live panes with
//  draggable dividers. Every pane stays in one stable ZStack (identity = its cell) and is
//  merely re-framed, so changing layout, maximizing, or folding the Duo never re-hosts a
//  WebView and never reloads a page.
//

#if os(iOS)
import SwiftUI
import WebKit
import WaffleCore
import WaffleDesignSystem

public struct PaneWorkspaceView: View {
    let model: GridModel
    /// Groups A and B sit side by side (true) or stacked (false).
    let primaryIsHorizontal: Bool
    /// The fold in this view's coordinates; panes never cross it while it is active.
    let fold: FoldGutter?
    /// When set, this pane fills the workspace and the others are tucked away (not unloaded).
    let focusedPaneID: UUID?
    var cornerRadius: CGFloat = 14
    /// Starts another pane (the empty-pane card offers it while only one is open).
    var onAddPane: (() -> Void)?

    @State private var isDragging = false

    public init(
        model: GridModel,
        primaryIsHorizontal: Bool,
        fold: FoldGutter?,
        focusedPaneID: UUID? = nil,
        cornerRadius: CGFloat = 14,
        onAddPane: (() -> Void)? = nil
    ) {
        self.model = model
        self.primaryIsHorizontal = primaryIsHorizontal
        self.fold = fold
        self.focusedPaneID = focusedPaneID
        self.cornerRadius = cornerRadius
        self.onAddPane = onAddPane
    }

    public var body: some View {
        GeometryReader { geometry in
            let panes = model.panes
            let frames = PaneFrameCalculator.frames(
                count: panes.count,
                ratios: model.paneRatios,
                size: geometry.size,
                primaryIsHorizontal: primaryIsHorizontal,
                fold: fold
            )
            let full = CGRect(origin: .zero, size: geometry.size)

            ZStack(alignment: .topLeading) {
                ForEach(Array(panes.enumerated()), id: \.element.id) { index, cell in
                    let isFocused = focusedPaneID == cell.id
                    let isHidden = focusedPaneID != nil && !isFocused
                    let frame = focusedPaneID != nil ? full : (index < frames.panes.count ? frames.panes[index] : full)

                    WaffleCellContainer(
                        waffleCell: cell,
                        model: model,
                        cornerRadius: cornerRadius,
                        requestPopBack: {},
                        isPhonePane: true,
                        paneCount: panes.count,
                        onAddPane: onAddPane
                    )
                    .frame(width: max(frame.width, 1), height: max(frame.height, 1))
                    .offset(x: frame.minX, y: frame.minY)
                    .opacity(isHidden ? 0 : 1)
                    .allowsHitTesting(!isHidden)
                    .accessibilityHidden(isHidden)
                    .zIndex(isFocused ? 1 : 0)
                }

                if focusedPaneID == nil {
                    ForEach(Array(frames.dividers.enumerated()), id: \.offset) { _, divider in
                        PaneDividerHandle(
                            divider: divider,
                            onDrag: { position in drag(divider, to: position) },
                            onEnd: { isDragging = false },
                            onReset: { reset(divider) },
                            onNudge: { delta in nudge(divider, by: delta) }
                        )
                    }
                }
            }
            .coordinateSpace(.named("paneWorkspace"))
            .animation(isDragging ? nil : .snappy(duration: 0.28), value: frames)
            .animation(.snappy(duration: 0.28), value: focusedPaneID)
        }
    }

    // MARK: - Divider editing

    private func currentRatio(_ kind: PaneDividerKind) -> Double {
        switch kind {
        case .primary: model.paneRatios.primary
        case .stackA: model.paneRatios.stackA
        case .stackB: model.paneRatios.stackB
        }
    }

    private func setRatio(_ ratio: Double, for kind: PaneDividerKind) {
        var ratios = model.paneRatios
        switch kind {
        case .primary: ratios.primary = PaneRatios.clamp(ratio)
        case .stackA: ratios.stackA = PaneRatios.clamp(ratio)
        case .stackB: ratios.stackB = PaneRatios.clamp(ratio)
        }
        if ratios != model.paneRatios { model.paneRatios = ratios }
    }

    private func drag(_ divider: PaneDivider, to position: CGFloat) {
        guard !divider.isLocked else { return }
        isDragging = true
        var ratio = PaneFrameCalculator.ratio(forDividerAt: position, divider: divider)
        if divider.kind == .primary {
            ratio = PaneFrameCalculator.snappedPrimaryRatio(ratio, total: divider.trackLength, fold: fold)
        } else if abs(ratio - 0.5) * Double(divider.trackLength) < Double(PaneFrameCalculator.snapDistance) {
            ratio = 0.5
        }
        setRatio(ratio, for: divider.kind)
    }

    private func reset(_ divider: PaneDivider) {
        guard !divider.isLocked else { return }
        setRatio(0.5, for: divider.kind)
    }

    private func nudge(_ divider: PaneDivider, by delta: Double) {
        guard !divider.isLocked else { return }
        setRatio(currentRatio(divider.kind) + delta, for: divider.kind)
    }
}

/// A draggable seam with a 44-point touch target and a small visible grabber.
private struct PaneDividerHandle: View {
    let divider: PaneDivider
    let onDrag: (CGFloat) -> Void
    let onEnd: () -> Void
    let onReset: () -> Void
    let onNudge: (Double) -> Void

    private let touch: CGFloat = 44

    var body: some View {
        let seam = divider.seam
        let horizontal = divider.movesHorizontally

        ZStack {
            Color.clear
            if !divider.isLocked {
                Capsule()
                    .fill(.regularMaterial)
                    .overlay(Capsule().stroke(Color.waffleTertiary.opacity(0.5), lineWidth: 0.5))
                    .frame(width: horizontal ? 6 : 40, height: horizontal ? 40 : 6)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            }
        }
        .frame(
            width: horizontal ? touch : max(seam.width, touch),
            height: horizontal ? max(seam.height, touch) : touch
        )
        .contentShape(Rectangle())
        .position(x: seam.midX, y: seam.midY)
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .named("paneWorkspace"))
                .onChanged { value in
                    onDrag(horizontal ? value.location.x : value.location.y)
                }
                .onEnded { _ in onEnd() }
        )
        .onTapGesture(count: 2, perform: onReset)
        .accessibilityElement()
        .accessibilityLabel(Text("Pane divider"))
        .accessibilityHint(Text(divider.isLocked
            ? LocalizedStringKey("Fixed at the fold")
            : LocalizedStringKey("Adjust to resize panes. Double tap to reset to an even split")))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onNudge(0.05)
            case .decrement: onNudge(-0.05)
            @unknown default: break
            }
        }
        .allowsHitTesting(!divider.isLocked)
    }
}
#endif
