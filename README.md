<img src="Icons/WaffleIcon-iOS-Default-1024x1024@1x.png" alt="Waffle" width="128" height="128">

# Waffle

A grid-based web browser for iPad that reimagines how users interact with multiple webpages at once.

## Overview

Unlike traditional tab-based browsers, Waffle organizes pages into a customizable grid. Each cell hosts its own browsing context, allowing users to visually organize workflows, research sets, and dashboards side-by-side. Built with SwiftUI and WebKit for iOS 26, it offers a lightweight, intuitive, and deeply Apple-native browsing experience.

Waffle is designed for:
- **iPad power users** who multitask visually
- **Researchers and developers** who reference multiple sources simultaneously
- **Designers and creatives** who prefer spatial memory over tab stacks

## Features

### Grid Browsing
- Customizable grid layout (up to unlimited rows/columns with premium)
- Independent browsing context per cell with full navigation
- Drag and drop to rearrange cells
- Pop-out windows for focused viewing

### Bookmarks & Presets
- Save and organize bookmarks with drag-to-reorder
- Create presets to save entire grid layouts
- Restore research sessions with one tap

### Safari Integration
- Share extension to save URLs directly into grid cells
- Quick capture from any app via share sheet

### Platform Integration
- **iCloud Sync**: Seamless bookmark and preset sync via CloudKit
- **Multi-Window**: Scene-based architecture with independent grid persistence
- **Fullscreen Mode**: Distraction-free browsing

### Premium Features (Syrup)
- Grid dimensions beyond 2x2
- Grid rearrangement
- Pop-out windows
- Fullscreen mode
- Preset creation

## Requirements

- iPadOS 26.0+
- Xcode 16.0+
- macOS 15.0+ (Sequoia)
- Apple Developer account (for CloudKit capabilities)

## Setup

1. Clone the repository
2. Open `Waffle.xcodeproj` in Xcode
3. Configure signing with your Apple Developer account
4. Update bundle identifiers and iCloud container identifiers
5. Build and run on iPad simulator or device

### Required Capabilities

Enable these in your Xcode project:
- iCloud (CloudKit with private database)
- App Groups

## Architecture

### App Lifecycle

The app uses two window scenes:
- **main**: Primary grid browser interface
- **DetachedWaffleCell**: Pop-out windows for individual cells

### Coordinator Pattern

```
WaffleApp
    └── WaffleCoordinator (@Observable)
            ├── WaffleState (grid state, snapshots)
            └── StoreManager (in-app purchases)
```

### Key Components

| Component | Responsibility |
|-----------|---------------|
| `WaffleCoordinator` | Central coordinator managing state and subscriptions |
| `WaffleState` | Observable grid state with 2D cell array |
| `WaffleCell` | Individual grid cell with WebPage context |
| `StoreManager` | StoreKit 2 subscription management |

### Data Layer

- **SwiftData** with iCloud CloudKit sync for bookmarks and presets
- **AppStorage** for user preferences
- **Codable Snapshots** for grid state persistence

### Data Models

| Model | Description |
|-------|-------------|
| `WaffleCell` | In-memory grid cell with WebPage |
| `Bookmark` | Saved URLs with sortIndex for reordering |
| `Preset` | Saved grid layouts (name, dimensions, URLs) |
| `SearchProvider` | Search engine enum (Google, DuckDuckGo) |

### Key Patterns

- **MVVM with Coordinator**: Views have nested ViewModels, coordinator manages app-wide state
- **Dependency Injection**: Coordinator injected via SwiftUI `@Environment`
- **Feature Gating**: Premium features controlled via `hasSyrup` flag

## Project Structure

```
Waffle/
├── WaffleApp.swift             # App entry point with window scenes
├── WaffleCoordinator.swift     # Central state coordinator
├── WaffleState.swift           # Grid state management
├── Models/
│   ├── WaffleCell.swift        # Grid cell model
│   ├── Bookmark.swift          # SwiftData bookmark
│   └── Preset.swift            # SwiftData preset
├── Views/
│   ├── Main/                   # Primary interface
│   │   ├── MainView.swift      # Root navigation
│   │   ├── SidebarView.swift   # Navigation sidebar
│   │   └── WaffleGridView.swift # Grid container
│   ├── Cell/                   # Cell views
│   │   ├── WaffleCellView.swift
│   │   └── EmptyCellView.swift
│   ├── Settings/               # Preferences
│   └── Syrup/                  # Subscription UI
├── WebKit/                     # WKWebView wrapper
└── Extensions/                 # Utilities

WaffleShareExtension/           # Safari share extension
```

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
