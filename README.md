<img src="Icons/WaffleIcon-iOS-Default-1024x1024@1x.png" alt="Waffle" width="128" height="128">

# Waffle

A grid-based web browser for iPad that reimagines how users interact with multiple webpages at once.

## Overview

Unlike traditional tab-based browsers, Waffle organizes pages into a customizable grid. Each cell hosts its own browsing context, allowing users to visually organize workflows, research sets, and dashboards side-by-side. Built with SwiftUI and the native WebKit-for-SwiftUI APIs (`WebView`/`WebPage`) for iOS 27, it offers a lightweight, intuitive, and deeply Apple-native browsing experience.

Waffle is designed for:
- **iPad power users** who multitask visually
- **Researchers and developers** who reference multiple sources simultaneously
- **Designers and creatives** who prefer spatial memory over tab stacks

## Features

### Grid Browsing
- Customizable grid layout — free up to 2×2, up to 4×4 with Syrup
- Independent browsing context per cell with full navigation, address bar, and per-cell reload
- Rearrange sheet with drag-to-reorder and tap-to-swap
- Pop-out cells into their own windows, fullscreen a single cell
- Grid state persists automatically (debounced snapshots) and restores on launch

### Bookmarks & Presets
- Save and organize bookmarks with drag-to-reorder, search, and drag-onto-a-cell
- Create presets to save entire grid layouts — size and every page in it
- Restore research sessions with one tap

### Platform Integration
- **iCloud Sync**: Bookmarks and presets sync via CloudKit (private database)
- **Siri & Shortcuts**: App Intents for opening presets/bookmarks, resizing the grid, and bookmarking the current page — donated so Siri learns your routines
- **Spotlight**: Presets and bookmarks are semantically indexed
- **Handoff**: The page you're browsing follows you across devices
- **Deep links**: `waffle://preset/<uuid>`, `waffle://bookmark/<uuid>`, `waffle://grid/<rows>x<cols>`, `waffle://open?url=…`
- **Menu bar & keyboard**: Full command menus and shortcuts with a hardware keyboard
- **Localization**: English, Spanish, French (Canada), and Japanese

### Premium (Syrup)
One-time purchase, shared with your family via Family Sharing. Unlocks:
- Grid dimensions beyond 2×2 (up to 4×4)
- Grid rearrangement
- Pop-out windows
- Fullscreen mode
- Preset creation and application

## Requirements

- iPadOS 27.0+ (also runs on Mac and Apple Vision as "Designed for iPad")
- Xcode 27 beta (iOS 27 SDK)
- Apple Developer account (for CloudKit capabilities)

## Setup

1. Clone the repository
2. **Open `Waffle.xcworkspace`** (not the bare `.xcodeproj`) — it resolves the local Swift package
3. Configure signing with your Apple Developer account
4. Update the bundle identifier and iCloud container identifier
5. Build and run on an iPad simulator or device

### Required Capabilities

- iCloud (CloudKit with private database)

## Architecture

Waffle is a **thin app target on top of an SPM umbrella package** (`Packages/Waffle`) of layered, single-responsibility modules. Dependencies point inward: features depend on the design system and core; data implements core's protocols; core depends on nothing.

```
Waffle (app target — thin shell)
    └── WaffleComposition        SessionController (composition root) + RootView/MainView
            ├── WaffleFeature*   Grid · Sidebar · Settings · Onboarding · Syrup
            ├── WaffleServices   StoreManager (StoreKit 2) · review requester
            ├── WaffleData       SwiftData repositories · CloudKit store
            ├── WaffleDesignSystem  brand colors · button styles · error/toast UI
            └── WaffleCore       models · domain logic · protocols · seams (pure)
```

### Key Components

| Component | Responsibility |
|-----------|---------------|
| `SessionController` | Composition root: builds the dependency graph, owns Syrup gating, deep-link routing, and the one-primary-window rule |
| `GridModel` | Observable grid state (cells, selection, pop-out) with debounced snapshot persistence |
| `WaffleCell` | Individual grid cell wrapping a `WebPage` |
| `BookmarkRepository` / `PresetRepository` | Protocol boundaries over SwiftData, consumed through single-verb use-cases with typed errors |
| `StoreManager` | StoreKit 2 purchase/restore; feature gating flows through an `EntitlementProviding` seam |

### Key Patterns

- **Repositories + use-cases**: views never touch SwiftData; every read/write goes through a single-verb use-case (`LoadBookmarks`, `SavePreset`, …) with typed `throws(PersistenceError)`
- **Observable view models over protocol seams**: each feature screen is backed by a cross-platform `@Observable` model, unit-tested on macOS against in-memory fakes — no simulator required
- **Change stream**: one multicast `AsyncStream` notifies screens and the Spotlight indexer after every successful write, including CloudKit imports
- **Graceful persistence degradation**: CloudKit → local-only → in-memory, never a launch crash

### Data Models

| Model | Description |
|-------|-------------|
| `Bookmark` | Saved URL with `sortIndex` for reordering (SwiftData, CloudKit-synced) |
| `Preset` | Saved grid layout — name, dimensions, URLs (SwiftData, CloudKit-synced) |
| `Snapshot` | Codable grid-state capture for automatic persistence |
| `SearchProvider` | Search engine enum (Google, DuckDuckGo) |

## Project Structure

```
Waffle.xcworkspace              # Open this
├── Waffle/                     # Thin app target
│   ├── WaffleApp.swift         # Two window scenes, session wiring
│   ├── WaffleCommands.swift    # Menu bar commands
│   └── Intents/                # App Intents, entities, Spotlight indexer
├── Packages/Waffle/            # The real app (SPM umbrella package)
│   ├── Sources/
│   │   ├── WaffleCore/         # Models, domain, protocols, seams
│   │   ├── WaffleData/         # SwiftData repositories, CloudKit store
│   │   ├── WaffleServices/     # StoreKit 2
│   │   ├── WaffleDesignSystem/ # Colors, styles, error surfaces
│   │   ├── WaffleFeatureGrid/  # Grid, cells, address bar, rearrange
│   │   ├── WaffleFeatureSidebar/    # Bookmarks & presets
│   │   ├── WaffleFeatureSettings/
│   │   ├── WaffleFeatureOnboarding/
│   │   ├── WaffleFeatureSyrup/
│   │   └── WaffleComposition/  # SessionController, RootView, MainView
│   └── Tests/                  # Host-run suite (swift test, no simulator)
├── WaffleTests/                # App-glue tests (hosted)
└── Scripts/                    # Localization pinning tooling
```

## Testing

The bulk of the suite lives in the package and runs on the Mac host in seconds — no simulator:

```sh
cd Packages/Waffle && swift test
```

Domain, repositories, feature view models (over fake use-cases), and composition policy (Syrup gating, deep links) are all covered there. The hosted `WaffleTests` target covers app-target glue only.

## Privacy

Waffle is designed with privacy in mind:
- All data stored in your private iCloud container
- No browsing history sent to third parties
- No analytics or tracking
- Local-first architecture

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Molargik Software LLC
