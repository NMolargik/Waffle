//
//  AppGlueTests.swift
//  WaffleTests
//
//  App-target glue only: the real suite lives in Packages/Waffle/Tests (host-run via
//  `swift test`). Here we cover what only exists in the app target — the App Shortcuts
//  surface and the URL-scheme wiring the app's onOpenURL relies on.
//
//  Deliberately no SwiftData here: the hosted app already owns a CloudKit-backed
//  container for Bookmark/Preset, and opening a second container for the same models
//  in-process crashes SwiftData. Entity mapping is covered indirectly by the package's
//  repository/composition suites.
//

import AppIntents
import Foundation
import Testing
import WaffleCore
@testable import Waffle

@Suite("App glue")
@MainActor
struct AppGlueTests {

    @Test("All four intents are surfaced as App Shortcuts")
    func shortcutsCoverEveryIntent() {
        let shortcuts = WaffleShortcuts.appShortcuts
        #expect(shortcuts.count == 4)
    }

    @Test("The waffle:// scheme parses into every deep-link route")
    func urlSchemeRoutes() throws {
        let id = UUID()
        #expect(DeepLink(url: URL(string: "waffle://preset/\(id.uuidString)")!) == .openPreset(id))
        #expect(DeepLink(url: URL(string: "waffle://bookmark/\(id.uuidString)")!) == .openBookmark(id))
        #expect(DeepLink(url: URL(string: "waffle://grid/2x3")!) == .setGrid(rows: 2, cols: 3))
        #expect(DeepLink(url: URL(string: "waffle://open?url=https://apple.com")!) == .openURL(URL(string: "https://apple.com")!))
        #expect(DeepLink(url: URL(string: "https://apple.com")!) == nil)
    }
}
