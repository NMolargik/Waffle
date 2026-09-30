// swift-tools-version: 6.2
import PackageDescription

// The Waffle umbrella package: layered, single-responsibility modules the thin app
// target composes. Dependencies point inward — features depend on the design system and
// core; data implements core's protocols; core depends on nothing. The macOS floor
// exists only so `swift test` runs on the host; the app ships iPad-only.

let package = Package(
    name: "Waffle",
    defaultLocalization: "en",
    platforms: [.iOS("27.0"), .macOS("27.0")],

    products: [
        .library(name: "WaffleCore",             targets: ["WaffleCore"]),
        .library(name: "WaffleData",             targets: ["WaffleData"]),
        .library(name: "WaffleServices",         targets: ["WaffleServices"]),
        .library(name: "WaffleDesignSystem",     targets: ["WaffleDesignSystem"]),
        .library(name: "WaffleFeatureGrid",      targets: ["WaffleFeatureGrid"]),
        .library(name: "WaffleFeatureSidebar",   targets: ["WaffleFeatureSidebar"]),
        .library(name: "WaffleFeatureSettings",  targets: ["WaffleFeatureSettings"]),
        .library(name: "WaffleFeatureOnboarding", targets: ["WaffleFeatureOnboarding"]),
        .library(name: "WaffleFeatureSyrup",     targets: ["WaffleFeatureSyrup"]),
        .library(name: "WaffleComposition",      targets: ["WaffleComposition"]),
    ],

    // Approachable concurrency: every module defaults to the MainActor, matching the
    // app's SWIFT_DEFAULT_ACTOR_ISOLATION. Pure helpers opt out with `nonisolated`.
    targets: [
        .target(
            name: "WaffleCore",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "WaffleData",
            dependencies: ["WaffleCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "WaffleServices",
            dependencies: ["WaffleCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "WaffleDesignSystem",
            dependencies: ["WaffleCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "WaffleFeatureGrid",
            dependencies: ["WaffleCore", "WaffleDesignSystem"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "WaffleFeatureSidebar",
            dependencies: ["WaffleCore", "WaffleDesignSystem"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "WaffleFeatureSettings",
            dependencies: ["WaffleCore", "WaffleDesignSystem", "WaffleServices"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "WaffleFeatureOnboarding",
            dependencies: ["WaffleCore", "WaffleDesignSystem"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "WaffleFeatureSyrup",
            dependencies: ["WaffleCore", "WaffleDesignSystem", "WaffleServices"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "WaffleComposition",
            dependencies: [
                "WaffleCore", "WaffleData", "WaffleServices", "WaffleDesignSystem",
                "WaffleFeatureGrid", "WaffleFeatureSidebar", "WaffleFeatureSettings",
                "WaffleFeatureOnboarding", "WaffleFeatureSyrup",
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),

        .testTarget(
            name: "WaffleCoreTests",
            dependencies: ["WaffleCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "WaffleDataTests",
            dependencies: ["WaffleData"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "WaffleFeatureGridTests",
            dependencies: ["WaffleFeatureGrid"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "WaffleFeatureSidebarTests",
            dependencies: ["WaffleFeatureSidebar"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "WaffleCompositionTests",
            dependencies: ["WaffleComposition"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
