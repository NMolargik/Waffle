# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Waffle is a grid-based web browser for iPad (also runs on Mac and Apple Vision as "Designed for iPad"), built with SwiftUI and the native WebKit-for-SwiftUI APIs (`WebView`/`WebPage`). Users browse multiple webpages simultaneously in a customizable grid instead of tabs. SwiftData + CloudKit private-database sync for the library (bookmarks/presets); StoreKit 2 one-time purchase ("Syrup") for premium features.

The app is a **thin app target on top of an SPM umbrella package** (`Packages/Waffle`) of layered, single-responsibility modules — the same clean architecture as Stork/SCOUT. Dependencies point **inward**: features depend on the design system and core; data implements core's protocols; **core depends on nothing** (Foundation + SwiftData only).

## Build & Run

**Open `Waffle.xcworkspace`** (not the bare `.xcodeproj`) — it resolves the local package. No external dependencies. Built against the iOS 27 SDK (Xcode 27 beta). If `xcodebuild` fails with a CommandLineTools error, prefix commands with `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`.

**Swift 6 language mode**, MainActor default isolation everywhere: the app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; package targets use `swiftSettings: [.defaultIsolation(MainActor.self)]`. Pure value types used from nonisolated contexts (`GridLayout`, `AddressNormalizer`, `DeepLink`, `AppConfiguration`, `Snapshot`, …) are marked `nonisolated` explicitly. `#MemberImportVisibility` is on: every file must import the module that defines any member it uses (e.g. `import WebKit` for `WebPage.title`, `import os` for `Log`).

Fast iteration — the package builds and tests on the macOS host, simulator-free (`WebPage` compiles on macOS, so even `GridModel` tests run on the host):
```
cd Packages/Waffle && swift build && swift test          # domain/data/features/composition logic
```
Verify iOS UI compiles (feature view files are gated `#if os(iOS)`):
```
xcodebuild build -scheme WaffleComposition -destination 'generic/platform=iOS Simulator'
```
Build the whole app:
```
xcodebuild -workspace Waffle.xcworkspace -scheme Waffle \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
```

## Architecture — `Packages/Waffle`

```
        ┌──────────── Waffle (app target — thin) ─────────────┐
        │ WaffleApp (@main) builds SessionController · Intents │
        │ (entities/queries) · seam impls · WaffleCommands     │
        └───────────────────────┬──────────────────────────────┘
                                │ hosts RootView, registers session
        ┌───────────────────────▼──────────────────────────────┐
        │ WaffleComposition — SessionController (composition    │
        │ root: gating, deep links, window count) + RootView/   │
        │ MainView + view-model factories                       │
        └──┬───────────────────────────────────┬────────────────┘
   ┌───────▼──────────┐   ┌────────────────┐   ┌▼───────────────┐
   │ WaffleFeature*   │   │ WaffleServices │   │ WaffleData     │
   │ Grid · Sidebar · │   │ StoreManager   │   │ Default*Repo · │
   │ Settings ·       │   │ (StoreKit 2 =  │   │ WaffleStore    │
   │ Onboarding ·     │   │ Entitlement-   │   │ (CloudKit,     │
   │ Syrup            │   │ Providing) ·   │   │ graceful       │
   │ (views + models) │   │ ReviewRequester│   │ degradation)   │
   └───┬──────────┬───┘   └───────┬────────┘   └───────┬────────┘
       │ uses     │ uses          │ implements         │ implements
   ┌───▼──────┐ ┌─▼───────────────▼─────────────────────▼───────┐
   │ WaffleDS │ │ WaffleCore (pure domain)                       │
   │ colors · │ │ @Model types · domain (GridLayout/Address-     │
   │ button   │ │ Normalizer/SearchProvider/…) · DeepLink ·      │
   │ styles · │ │ repository & use-case PROTOCOLS ·              │
   │ Error-   │ │ LibraryChangeCenter · seams · Log              │
   │ Handler  │ │                                                │
   └──────────┘ └────────────────────────────────────────────────┘
```

### WaffleCore (pure — Foundation + SwiftData only, host-tested)
- **Models** (`@Model`): `Bookmark`, `Preset`. CloudKit-friendly (defaults on all properties, no unique constraints).
- **Domain** (`nonisolated`): `GridLayout` (pure grid math incl. `moved(fromOffsets:toOffset:)`/`movedItems(_:withIDs:before:)`/`swapped`), `AddressNormalizer`, `SearchProvider`, `URLDisplayFormatter`, `AppConfiguration` (free/premium grid limits), `Snapshot`, `RearrangeCell`, `DeepLink` (testable `init?(url:)`).
- **Services (protocols only)**: `BookmarkRepository`/`PresetRepository` + single-verb use-cases (`LoadBookmarks`, `FindBookmark`, `AddBookmark`, `UpdateBookmark`, `DeleteBookmark`, `MoveBookmarks`, `DeleteAllBookmarks`, `NormalizeBookmarkOrder`; `LoadPresets`, `FindPreset`, `SavePreset`, `OverwritePreset`, `RenamePreset`, `DeletePreset`, `DeleteAllPresets` — each a `protocol` + `…UseCase` struct with `callAsFunction`). Nothing outside the composition root touches a repository directly — always go through a use-case (even App Intents).
- **Typed errors**: the persistence boundary declares `throws(PersistenceError)` (`.fetchFailed`/`.saveFailed`) — new repository/use-case methods must keep the typed signature so callers catch a concrete, `Equatable` error.
- **Change stream**: `LibraryChangeCenter` + `ObserveLibraryChanges` — repositories notify after every successful write; screens/Spotlight observe one multicast `AsyncStream`. Never add per-screen refresh callbacks.
- **Seams**: `KeyValueStoring` (+`UserDefaults` conformance), `ReviewRequesting`, `LibraryIndexing` (Spotlight — impl app-side), `EntitlementProviding` (`isPurchased` — makes Syrup gating testable without StoreKit), `PresetDonating` (Siri donation — impl app-side), `BrowsingActivityAnnotating` (Handoff app-entity tag — impl app-side).
- `Log` — `os.Logger` per category. **Never `print`.** Files calling `Log` need their own `import os`.

### WaffleData (persistence impl, depends on Core)
`DefaultBookmarkRepository` (owns sortIndex assignment + normalization, trims/validates input, returns nil for un-bookmarkable input), `DefaultPresetRepository` (name-defaulting for quick saves), `WaffleStore.makeContainer(inMemory:)` — **preserves the graceful CloudKit → local → in-memory degradation** (container id `iCloud.com.molargiksoftware.Waffle`; no fatalError on CloudKit failure). Repositories notify the change center after every successful save and never touch presentation.

### WaffleServices (depends on Core)
`StoreManager` (StoreKit 2, product `syrup_2_99`, conforms to `EntitlementProviding`, localized error strings), `AppStoreReviewRequester`.

### WaffleDesignSystem (depends on Core)
Brand colors in code on `ShapeStyle where Self == Color` (`wafflePrimary` #F1E094, `waffleSecondary` #DFA656, `waffleTertiary` #44201A); `WaffleButtonStyles` (`.wafflePrimary`/`.waffleSecondary`/`.waffleDestructive`/`.waffleIcon`), `AlignedIconLabelStyle`; `ErrorHandler` (@Observable, presentation-only: `currentError` alert + `toastMessage`, `showPersistenceError(_:)`) with the `.toast(message:onDismiss:)`/`.errorAlert(_:)` modifiers.

### WaffleFeature* (one per area, depend on Core + DesignSystem [+ Services])
- **Grid** — `WaffleCell` (in-memory cell wrapping a `WebPage` — WebKit-coupled, so it lives here, NOT Core), `GridModel` (grid/selection/pop-out/address state + **debounced snapshot persistence** via `KeyValueStoring`: `persistDebounced`/`persistNow`/`restoreFromSnapshotIfAvailable`; cell navigation reports via `noteAddressChange(for:)`), `WaffleGridView`, `EmptyCellView`, `FullScreenCellView`, `AddressBarView`, `DetachedWaffleCellView`, `RearrangeWaffleView`.
- **Sidebar** — `SidebarModel` (bookmarks/presets via use-cases, search filter, `canReorderBookmarks` only when unfiltered, typed-error surfacing) + `SidebarView`/lists/headers. Grid interplay and Syrup gating arrive as injected closures from composition.
- **Settings** — `SettingsModel` (delete-all + DEBUG example seeding through use-cases) + `SettingsView` (search engine picker, Syrup status, about links open in-app).
- **Onboarding** — self-contained tour; `onFinished` closure presents the Syrup sheet.
- **Syrup** — `SyrupView` takes the `StoreManager` directly; purchase/restore/close via closures.

Views are `#if os(iOS)`-gated; models stay cross-platform so `swift test` runs on the host over **fake use-case conformances** (no `ModelContainer`, no simulator).

### WaffleComposition (top of graph — the composition root)
`SessionController` (`@MainActor @Observable`) builds the whole graph in `init` (container → change center → repositories → use-cases → `StoreManager`) and owns the app-wide policy the old `WaffleCoordinator` held:
- **Entitlement gating**: `isSyrupEnabled` via `EntitlementProviding` (injectable fake in tests), `canUseRearrange/Popout/Fullscreen/MakePresets`, `maxRows/maxCols` from `AppConfiguration`.
- **Gated actions**: `applyPreset` (donates via `PresetDonating`), `setGridSize`, `bookmarkSelectedPage`, `saveCurrentGridAsPreset`; single Syrup source of truth `presentSyrupSheet`/`requestSyrup()`.
- **Deep links**: `handle(_:)` routes `DeepLink` through use-cases (missing item → toast).
- **`mainWindowCount`** (one-primary-window WebKit rule, runtime-only) and the shared `GridModel`.
- Spotlight: observes the library change stream and calls the `LibraryIndexing` seam; `reindexLibrary()` seeds at launch.
- Factories: `makeSidebarModel()`, `makeSettingsModel()`.

`RootView` (primary-window claim → onboarding → `MainView`; extra windows get `ExtraWindowView`) and `MainView` (split view, toolbar, sheets, Handoff user activity) live here.

### App target (`Waffle/`) — thin
`WaffleApp` builds `SessionController(presetDonator:indexer:activityAnnotator:)`, registers it with `AppDependencyManager` for App Intents, hosts the two scenes (`WindowGroup(id: "main")` + `WindowGroup(id: "DetachedWaffleCell", for: WaffleCell.self)` with `DetachedCellSceneHost`), review-prompt-at-5th-launch, `onOpenURL` → `DeepLink` → `session.handle`. Plus `WaffleCommands` (menu bar) and `Intents/`:
- `PresetEntity`/`BookmarkEntity` (AppEntity + IndexedEntity; queries read via `@Dependency var session` + use-cases), intents (`OpenPresetIntent`, `OpenBookmarkIntent`, `SetGridSizeIntent`, `BookmarkCurrentPageIntent`), `WaffleShortcuts`.
- Seam impls: `CoreSpotlightIndexer: LibraryIndexing`, `WafflePresetDonator: PresetDonating`, `BrowsingActivityAnnotator: BrowsingActivityAnnotating` (AppIntents entity types can't live in the package).

The package products are linked in `project.pbxproj` (`packageProductDependencies` + `XCSwiftPackageProductDependency` + `XCLocalSwiftPackageReference`, deterministic `DEC0DE…` IDs); the app folder is folder-synchronized and contains only the shell.

## Rules that keep this clean

- Views never see SwiftData: no `@Query`, no `modelContext`. All library reads/writes go through use-cases; view models surface typed failures via `ErrorHandler` — never swallow errors with `try?` on user-initiated writes.
- Grid math goes in `GridLayout` (Core), never inline in models/views.
- **One primary main window.** A `WebPage` crashes WebKit when hosted by two `WebView`s, and every main window shares the same `GridModel` — so `RootView` claims `session.mainWindowCount` (runtime-only, never persisted) and extra main windows show `ExtraWindowView`. Never call `openWindow(id: "main")` without checking `mainWindowCount == 0` first.
- The 50–200ms `Task.sleep` dances around pop-out/fullscreen teardown are deliberate WebKit animation-race workarounds; don't "simplify" them away.
- Entitlement gating lives on `SessionController` only; feature views receive `isSyrupEnabled`/`requestSyrup` as injected values/closures.
- No singletons; no `print` outside previews (use `Log.*`).

## Deep Links (`waffle://`)

`waffle://preset/<uuid>`, `waffle://bookmark/<uuid>`, `waffle://grid/<rows>x<cols>`, `waffle://open?url=<https url>`. Parsing is pure (`DeepLink.init?(url:)`, Core-tested), routing is `SessionController.handle(_:)` (Composition-tested).

## Testing

- Swift Testing (`@Suite`, `@Test`, `#expect`). The real suite is in `Packages/Waffle/Tests` (`swift test`, host, simulator-free): `WaffleCoreTests`, `WaffleDataTests` (repository behavior), `WaffleFeatureGridTests` (`GridModel` over `FakeKeyValueStore`), `WaffleFeatureSidebarTests` (view model over fake use-cases), `WaffleCompositionTests` (gating + deep links over a fake `EntitlementProviding`). `WaffleTests` (app target, hosted) covers only app glue (App Shortcuts surface, URL-scheme routing) — **hosted tests must not create SwiftData containers**: the running app already owns a CloudKit-backed container for the same `@Model` classes, and opening a second one in-process crashes SwiftData.
- **Suites that create SwiftData containers are `.serialized` and use a unique on-disk temp store per test** (`ModelConfiguration(url: URL.temporaryDirectory…, cloudKitDatabase: .none)`) — parallel in-memory containers share a /dev/null SQLite identity and crash the host.
- New logic goes into Core (pure) first with tests, then a repository/use-case in Data, then the feature view model with its own fake-driven tests.

## Localization

- Languages: en (source), es, fr-CA, ja via `Waffle/Localizable.xcstrings`. **Never translate the brand names "Waffle" and "Syrup".**
- **Policy for package strings:** SwiftUI's key-based initializers resolve in `Bundle.main` at runtime, so translations for strings rendered by package modules live in the **app target's** `Waffle/Localizable.xcstrings` — by design. Those entries are pinned `extractionState: "manual"` + `shouldGenerateSymbol: false`; `STRING_CATALOG_GENERATE_SYMBOLS = NO` everywhere (case-colliding keys like "Delete All Bookmarks"/"Delete All Bookmarks?" fail symbol generation).
- **After adding user-facing strings to package code:** add the key + es/fr-CA/ja translations to `Waffle/Localizable.xcstrings` by hand, then run `python3 Scripts/pin_package_strings.py` — it pins package-referenced entries, rescues stale ones, and reports package literals missing from the catalog.
- **Don't reword existing keys casually** — the English literal *is* the catalog key; changing one character orphans three translations.
- Custom view props holding UI literals must be `LocalizedStringKey`, not `String`. Preview-only strings use `Text(verbatim:)` so they stay out of the catalog.

## Premium (Syrup)

One-time purchase, StoreKit 2 product `syrup_2_99`. Gates: rearrange, pop-out, fullscreen, preset creation/application, grids beyond 2x2 (premium max 4x4). Limits in `AppConfiguration` (Core); gating on `SessionController`; purchase state via the `EntitlementProviding` seam.

## CloudKit

Container `iCloud.com.molargiksoftware.Waffle` (private DB), SwiftData sync for `Bookmark`/`Preset`. CloudKit-compatible model rules: defaults on all non-optional attributes, no unique constraints. `WaffleStore` degrades gracefully — CloudKit → local → in-memory, no fatalError.

## Gotchas

- `ModelContext` does not retain its `ModelContainer` — repositories hold the container.
- `WebPage.title` is non-optional in the iOS 27 SDK.
- `@ContentBuilder` is the iOS 27 spelling of `@ViewBuilder` (typealias). `@ToolbarContentBuilder` is a different type — leave it alone.
- The rearrange sheet uses iOS 27 `reorderContainer(for:)` + `.reorderable()`; deployment target is 27.0. Package platforms use string initializers (`.iOS("27.0"), .macOS("27.0")`) because PackageDescription has no `.v27` enum case; the macOS floor exists for host `swift test`.
- The debounced snapshot persistence in `GridModel` is deliberate — don't add extra persist calls in views; lifecycle changes call `persistNow()` from `MainView`.
