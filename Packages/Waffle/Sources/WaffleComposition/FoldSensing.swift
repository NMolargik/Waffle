//
//  FoldSensing.swift
//  WaffleComposition
//
//  Reads the iPhone Duo's fold and hinge from the iOS 27.1 SDK:
//  `GeometryProxy.reservedRegions(kind: .division, options: .includeInactive)` for the
//  fold's rectangle and `View.onHingeChange` for open/half-open/closed. Both are
//  `anyAppleOS 27.1`, so every use is behind an availability check; earlier systems and
//  ordinary iPhones simply report no fold and get the size-class layout.
//

#if os(iOS)
import SwiftUI
import WaffleCore

/// What the system says about the fold right now, independent of SDK types.
struct FoldReading: Equatable {
    /// The fold's rectangle in the reading view's coordinates.
    var frame: CGRect
    /// True only while the device is partially open (the system's definition).
    var isActive: Bool

    var gutter: FoldGutter { FoldGutter(frame: frame, isActive: isActive) }
}

enum HingeSummary: Equatable {
    case unknown, closed, partiallyOpen, fullyOpen
}

enum FoldSensing {
    /// The fold's rectangle, including while inactive (device flat), or nil on devices
    /// without a fold or systems older than 27.1.
    @MainActor
    static func reading(in proxy: GeometryProxy) -> FoldReading? {
        #if DEBUG
        if let simulated = DebugFoldSimulation.reading(in: proxy.size) { return simulated }
        #endif
        if #available(iOS 27.1, *) {
            guard let region = proxy.reservedRegions(kind: .division, options: .includeInactive).first else { return nil }
            return FoldReading(frame: region.frame, isActive: region.isActive)
        }
        return nil
    }
}

/// Publishes hinge status changes into a binding. A no-op before iOS 27.1.
struct HingeObserver: ViewModifier {
    @Binding var status: HingeSummary

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, new in
                status = Self.summary(of: new)
            }
        } else {
            content
        }
    }

    @available(iOS 27.1, *)
    private static func summary(of context: DeviceHingeContext) -> HingeSummary {
        guard let hinge = context.hinge else { return .unknown }
        switch hinge.status {
        case .closed: return .closed
        case .partiallyOpen: return .partiallyOpen
        case .fullyOpen: return .fullyOpen
        default: return .unknown
        }
    }
}

extension View {
    func observingHinge(_ status: Binding<HingeSummary>) -> some View {
        modifier(HingeObserver(status: status))
    }
}

#if DEBUG
import WaffleFeatureGrid

/// Debug builds can open panes from launch arguments (`-WaffleDebugPanes "url,url"`,
/// `-WaffleDebugRatios "0.4,0.5,0.6"`) so simulator screenshots need no taps. Bypasses gating.
enum DebugPaneSeeding {
    @MainActor
    static func applyIfRequested(to grid: GridModel) {
        guard let list = UserDefaults.standard.string(forKey: "WaffleDebugPanes") else { return }
        let urls = list.split(separator: ",").map(String.init)
        guard !urls.isEmpty else { return }
        let ratios = (UserDefaults.standard.string(forKey: "WaffleDebugRatios") ?? "")
            .split(separator: ",").compactMap { Double($0) }
        grid.applyPaneLayout(urls: urls, ratios: PaneRatios(array: ratios))
    }
}

/// Simulators can't fold, so Debug builds accept `-WaffleSimulateFold vertical|horizontal|desk`
/// to exercise the half-folded layout paths. Compiled out of Release builds.
enum DebugFoldSimulation {
    static var mode: String? { UserDefaults.standard.string(forKey: "WaffleSimulateFold") }

    static func reading(in size: CGSize) -> FoldReading? {
        guard let mode else { return nil }
        let thickness: CGFloat = 16
        switch mode {
        case "vertical":
            return FoldReading(frame: CGRect(x: size.width / 2 - thickness / 2, y: 0, width: thickness, height: size.height), isActive: true)
        case "horizontal", "desk":
            return FoldReading(frame: CGRect(x: 0, y: size.height / 2 - thickness / 2, width: size.width, height: thickness), isActive: true)
        default:
            return nil
        }
    }

    static var hinge: HingeSummary? {
        switch mode {
        case "desk", "vertical", "horizontal": .partiallyOpen
        default: nil
        }
    }
}
#endif
#endif
