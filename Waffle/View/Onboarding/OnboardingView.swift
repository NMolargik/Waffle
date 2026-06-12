//
//  OnboardingView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import SwiftUI

/// First-run tour. Every page mirrors the real main window — the same
/// toolbar controls, grid selection glow, sidebar sections, and Syrup gates
/// the user will see immediately after finishing.
struct OnboardingView: View {
    @Environment(WaffleCoordinator.self) private var coordinator
    @AppStorage("hasCompletedOnboarding") private var done = false

    @State private var pageIndex: Int = 0

    private let pages: [OnboardingPage] = OnboardingPage.all

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.wafflePrimary.opacity(0.6),
                    Color.waffleSecondary.opacity(0.4),
                    Color.waffleTertiary.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top controls
                HStack {
                    ProgressPips(count: pages.count, index: pageIndex)
                    Spacer()
                    Button(String(localized: "Skip")) {
                        finishAndShowSyrup()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .accessibilityHint(Text("Skips the tour"))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer(minLength: 16)

                // Main card
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 20, y: 10)

                    ScrollView {
                        contentForPage(pages[pageIndex].kind)
                            .padding(24)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: 700, maxHeight: 640)
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: pageIndex)

                Spacer(minLength: 16)

                // Bottom controls
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.4)) {
                            pageIndex = max(0, pageIndex - 1)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(pageIndex == 0 ? 0.4 : 0.9))
                    }
                    .disabled(pageIndex == 0)

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.4)) {
                            if pageIndex < pages.count - 1 {
                                pageIndex += 1
                            } else {
                                finishAndShowSyrup()
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(pageIndex == pages.count - 1 ? "Get Started" : "Next")
                            Image(systemName: pageIndex == pages.count - 1 ? "checkmark.circle.fill" : "chevron.right")
                        }
                        .font(.headline)
                        .foregroundStyle(Color.waffleTertiary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.wafflePrimary, in: Capsule())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private func finishAndShowSyrup() {
        done = true
        coordinator.presentSyrupSheet = true
    }

    @ContentBuilder
    private func contentForPage(_ kind: OnboardingPage.Kind) -> some View {
        switch kind {
        case .welcome:
            WelcomeCard()
        case .grid:
            GridCard()
        case .toolbar:
            ToolbarCard()
        case .gridMenu:
            GridMenuCard()
        case .library:
            LibraryCard()
        case .syrup:
            SyrupCard()
        }
    }
}

// MARK: - Model

private struct OnboardingPage: Identifiable {
    enum Kind {
        case welcome
        case grid
        case toolbar
        case gridMenu
        case library
        case syrup
    }
    let id = UUID()
    let kind: Kind

    static let all: [OnboardingPage] = [
        .init(kind: .welcome),
        .init(kind: .grid),
        .init(kind: .toolbar),
        .init(kind: .gridMenu),
        .init(kind: .library),
        .init(kind: .syrup)
    ]
}

// MARK: - Progress Indicator

private struct ProgressPips: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i <= index ? Color.white : Color.white.opacity(0.3))
                    .frame(width: i == index ? 24 : 8, height: 6)
            }
        }
        .animation(.spring(response: 0.4), value: index)
    }
}

// MARK: - Shared Pieces

private struct CardHeader: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: 8) {
            Label(title, systemImage: icon)
                .font(.title2.bold())
                .foregroundStyle(Color.waffleSecondary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

/// A faithful miniature of the real grid toolbar: back/forward, reload +
/// address capsule, and the grid menu button.
private struct MockToolbar: View {
    let address: String

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "chevron.backward")
                Image(systemName: "chevron.forward")
            }
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.secondary)

                Text(verbatim: address)
                    .font(.subheadline)
                    .lineLimit(1)
                    .contentTransition(.numericText())

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(.thinMaterial, in: Capsule())

            Image(systemName: "square.grid.3x3.fill")
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// A tappable miniature waffle cell with the app's real selection treatment:
/// an accent stroke with a soft glow, just like the grid.
private struct MockCell: View {
    let site: String
    let icon: String
    let tint: Color
    let isSelected: Bool
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            ZStack {
                LinearGradient(
                    colors: [Color.wafflePrimary.opacity(0.5), Color.waffleSecondary.opacity(0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(tint)
                    Text(verbatim: site)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                    .shadow(color: isSelected ? Color.accentColor.opacity(0.5) : .clear, radius: 8)
                    .padding(1)
            }
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }
}

private struct DemoSite {
    let address: String
    let icon: String
    let tint: Color

    static let samples: [DemoSite] = [
        .init(address: "apple.com", icon: "applelogo", tint: .primary),
        .init(address: "news.com", icon: "newspaper.fill", tint: .red),
        .init(address: "mail.com", icon: "envelope.fill", tint: .blue),
        .init(address: "video.com", icon: "play.rectangle.fill", tint: .purple)
    ]
}

// MARK: - Card 1: Welcome

private struct WelcomeCard: View {
    @State private var animate = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(
                        colors: [Color.wafflePrimary, Color.waffleSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.waffleSecondary.opacity(0.5), radius: 20)

                Image("waffleImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
                    .foregroundStyle(Color.waffleTertiary)
                    .symbolEffect(.bounce, value: animate)
            }
            .padding(.top, 12)

            VStack(spacing: 12) {
                Text("Welcome to Waffle")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text("Browse the web in a grid, not in tabs")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text("Waffle shows several webpages at once, side by side in a grid of cells. Keep your mail, news, scores, and video in view at the same time — no tab switching.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Tiny preview of what's coming
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.waffleSecondary.opacity(0.3))
                        .frame(width: 42, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(i == 0 ? Color.accentColor : .clear, lineWidth: 2)
                        )
                }
            }
            .padding(.bottom, 8)
        }
        .onAppear { animate = true }
    }
}

// MARK: - Card 2: The Grid

private struct GridCard: View {
    @State private var selectedIndex = 0

    var body: some View {
        VStack(spacing: 20) {
            CardHeader(
                icon: "square.grid.2x2.fill",
                title: "This Is Your Waffle",
                subtitle: "Every cell is a full browser. Tap a cell below to select it — just like in the app."
            )

            VStack(spacing: 10) {
                // The address bar follows the selection, exactly like the real toolbar.
                MockToolbar(address: DemoSite.samples[selectedIndex].address)

                VStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(0..<2, id: \.self) { col in
                                let i = row * 2 + col
                                MockCell(
                                    site: DemoSite.samples[i].address,
                                    icon: DemoSite.samples[i].icon,
                                    tint: DemoSite.samples[i].tint,
                                    isSelected: selectedIndex == i,
                                    onTap: { selectedIndex = i }
                                )
                                .frame(height: 110)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                ConceptPoint(number: "1", text: "The selected cell glows with a colored border")
                ConceptPoint(number: "2", text: "The address bar always shows the selected cell's page")
                ConceptPoint(number: "3", text: "Back, forward, and reload act on the selected cell")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct ConceptPoint: View {
    let number: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: number)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.waffleSecondary, in: Circle())

            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Card 3: The Toolbar

private struct ToolbarCard: View {
    var body: some View {
        VStack(spacing: 20) {
            CardHeader(
                icon: "magnifyingglass",
                title: "Search and Navigate",
                subtitle: "The toolbar at the top of the window drives whichever cell is selected"
            )

            MockToolbar(address: String(localized: "Search or enter a URL"))

            VStack(alignment: .leading, spacing: 14) {
                ToolbarTip(
                    icon: "keyboard",
                    text: "Type a web address — or anything else, and Waffle searches for it"
                )
                ToolbarTip(
                    icon: "chevron.backward",
                    text: "The back and forward buttons step through the selected cell's history"
                )
                ToolbarTip(
                    icon: "arrow.clockwise",
                    text: "Reload refreshes just the selected cell"
                )
                ToolbarTip(
                    icon: "gearshape.fill",
                    text: "Pick your search engine in Settings, in the sidebar"
                )
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            // Keyboard shortcuts, as on iPad with a hardware keyboard.
            VStack(spacing: 8) {
                Text("With a keyboard attached")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    ShortcutBadge(keys: "⌘[", label: "Back")
                    ShortcutBadge(keys: "⌘]", label: "Forward")
                    ShortcutBadge(keys: "⌘R", label: "Reload")
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct ToolbarTip: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.waffleSecondary)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
        }
    }
}

private struct ShortcutBadge: View {
    let keys: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: 4) {
            Text(verbatim: keys)
                .font(.subheadline.monospaced().bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Card 4: The Grid Menu

private struct GridMenuCard: View {
    @State private var rows = 2
    @State private var cols = 2

    var body: some View {
        VStack(spacing: 20) {
            CardHeader(
                icon: "square.grid.3x3.fill",
                title: "Shape Your Grid",
                subtitle: "The grid button in the toolbar adds and removes rows and columns. Try it here."
            )

            // The same actions the real grid menu offers.
            VStack(spacing: 0) {
                MenuRow(icon: "rectangle.split.1x2.fill", title: "Add Row") {
                    rows = min(rows + 1, AppConfiguration.maxPremiumRows)
                }
                MenuRow(icon: "rectangle.split.1x2", title: "Subtract Row") {
                    rows = max(rows - 1, 1)
                }
                Divider().padding(.horizontal)
                MenuRow(icon: "square.split.2x1.fill", title: "Add Column") {
                    cols = min(cols + 1, AppConfiguration.maxPremiumCols)
                }
                MenuRow(icon: "square.split.2x1", title: "Subtract Column") {
                    cols = max(cols - 1, 1)
                }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            MiniGridPreview(rows: rows, cols: cols)
                .frame(width: 170, height: 150)

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.waffleSecondary)
                    Text("Free grids go up to \(AppConfiguration.maxFreeRows)×\(AppConfiguration.maxFreeCols)")
                        .font(.subheadline)
                }
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(Color.waffleTertiary)
                    Text("Syrup unlocks up to \(AppConfiguration.maxPremiumRows)×\(AppConfiguration.maxPremiumCols)")
                        .font(.subheadline)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct MenuRow: View {
    let icon: String
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Image(systemName: icon)
                    .foregroundStyle(Color.waffleSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct MiniGridPreview: View {
    let rows: Int
    let cols: Int

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: 4) {
                    ForEach(0..<cols, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.waffleSecondary.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.waffleSecondary.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .animation(.spring(response: 0.3), value: rows)
        .animation(.spring(response: 0.3), value: cols)
    }
}

// MARK: - Card 5: Bookmarks & Presets

private struct LibraryCard: View {
    var body: some View {
        VStack(spacing: 20) {
            CardHeader(
                icon: "sidebar.left",
                title: "Your Library",
                subtitle: "The sidebar keeps bookmarks and presets, synced with iCloud across your devices"
            )

            // Bookmarks section, mirroring the sidebar.
            VStack(alignment: .leading, spacing: 12) {
                Label("Bookmarks", systemImage: "bookmark.fill")
                    .font(.headline)
                    .foregroundStyle(Color.waffleSecondary)

                LibraryPoint(
                    icon: "square.and.arrow.down.fill",
                    text: "Quick Save bookmarks the page in the selected cell"
                )
                LibraryPoint(
                    icon: "hand.tap.fill",
                    text: "Tap a bookmark to open it in the selected cell"
                )
                LibraryPoint(
                    icon: "hand.draw.fill",
                    text: "Or drag a bookmark onto any cell to open it there"
                )
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            // Presets section, mirroring the sidebar.
            VStack(alignment: .leading, spacing: 12) {
                Label("Presets", systemImage: "square.grid.3x3.fill")
                    .font(.headline)
                    .foregroundStyle(Color.waffleSecondary)

                LibraryPoint(
                    icon: "square.and.arrow.down.fill",
                    text: "A preset saves your whole grid — size and every page in it"
                )
                LibraryPoint(
                    icon: "arrow.right",
                    text: "Tap a preset to bring that entire layout back in one go"
                )
                LibraryPoint(
                    icon: "sparkles",
                    text: "Great for routines: a morning news grid, a work grid, a game-day grid"
                )
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.waffleSecondary)
                Text("Search at the top of the sidebar finds any bookmark or preset")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct LibraryPoint: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.waffleSecondary)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Card 6: Syrup

private struct SyrupCard: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.title2)
                        .foregroundStyle(Color.waffleTertiary)
                    Text("Pour On the Syrup")
                        .font(.title2.bold())
                }

                Text("Waffle is free to use in a \(AppConfiguration.maxFreeRows)×\(AppConfiguration.maxFreeCols) grid. A one-time Syrup purchase unlocks everything else.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                PremiumFeatureRow(
                    icon: "rectangle.split.3x3",
                    title: "Larger Grids",
                    description: "Grow your waffle up to \(AppConfiguration.maxPremiumRows)×\(AppConfiguration.maxPremiumCols) cells"
                )
                PremiumFeatureRow(
                    icon: "rectangle.on.rectangle",
                    title: "Pop Out",
                    description: "Detach a cell into its own window, then pop it back into the grid"
                )
                PremiumFeatureRow(
                    icon: "arrow.up.left.and.arrow.down.right",
                    title: "Fullscreen",
                    description: "Temporarily focus on a single cell, then jump back to the grid"
                )
                PremiumFeatureRow(
                    icon: "arrow.left.arrow.right.square",
                    title: "Rearrange",
                    description: "Drag cells into a new order from the grid menu"
                )
                PremiumFeatureRow(
                    icon: "square.grid.3x3",
                    title: "Presets",
                    description: "Save grid layouts and restore them anytime"
                )
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            Text("You'll see Syrup right after this tour — and anytime later in Settings")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct PremiumFeatureRow: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.waffleSecondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "drop.fill")
                .font(.caption)
                .foregroundStyle(Color.waffleTertiary.opacity(0.6))
        }
    }
}

#Preview {
    OnboardingView()
        .environment(PreviewSupport.makeCoordinator())
}
