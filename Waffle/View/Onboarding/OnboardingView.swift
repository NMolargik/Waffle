//
//  OnboardingView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(WaffleCoordinator.self) private var coordinator
    @AppStorage("hasCompletedOnboarding") private var done = false

    @State private var pageIndex: Int = 0
    @Namespace private var hero

    private let pages: [OnboardingPage] = OnboardingPage.all

    var body: some View {
        ZStack {
            // Neutral, subtle background
            LinearGradient(
                colors: [Color.wafflePrimary, Color.waffleSecondary, Color.waffleTertiary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top controls
                HStack {
                    ProgressPips(count: pages.count, index: pageIndex)
                    Spacer()
                    Button("Skip") {
                        finishAndShowSyrup()
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .glassEffect(.regular.interactive().tint(.red))
                    .tint(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer(minLength: 0)

                // Main card
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)

                    contentForPage(pages[pageIndex].kind)
                        .padding(20)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 740, minHeight: 420)
                .animation(.spring(response: 0.55, dampingFraction: 0.9), value: pageIndex)

                Spacer(minLength: 0)

                // Bottom controls
                HStack {
                    Button {
                        withAnimation {
                            pageIndex = max(0, pageIndex - 1)
                        }
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                        
                    }
                    .disabled(pageIndex == 0)
                    .opacity(pageIndex == 0 ? 0.35 : 1)

                    Spacer()

                    Button {
                        withAnimation {
                            if pageIndex < pages.count - 1 {
                                pageIndex += 1
                            } else {
                                finishAndShowSyrup()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(pageIndex == pages.count - 1 ? "Get Started" : "Next")
                            Image(systemName: pageIndex == pages.count - 1 ? "checkmark.circle.fill" : "chevron.right")
                        }
                        .foregroundStyle(.white)
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .glassEffect(.regular.interactive().tint(.blue))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .onAppear { pageIndex = 0 }
    }
    
    func finishAndShowSyrup() {
        done = true
        coordinator.presentSyrupSheet = true
    }

    @ViewBuilder
    private func contentForPage(_ kind: OnboardingPage.Kind) -> some View {
        switch kind {
        case .welcome:
            WelcomeCard(hero: hero)
                .transition(.opacity.combined(with: .scale))
            
        case .grid:
            GridDemoCard(hero: hero)
                .transition(.opacity.combined(with: .scale))
            
        case .popOut:
            FeatureCard(
                icon: "arrow.up.right.square",
                title: "Pop Out",
                subtitle: "Send any cell to its own window, interact with it like a browswer, then pop it back into the waffle.",
                premium: true,
                heroIconID: "icon-pop",
                heroTitleID: "title-pop",
                hero: hero
            ) {
                PopOutAnimation()
            }
            
        case .rearrange:
            FeatureCard(
                icon: "arrow.left.arrow.right.square",
                title: "Rearrange",
                subtitle: "Drag cells to reorder your grid.",
                premium: true,
                heroIconID: "icon-rearrange",
                heroTitleID: "title-rearrange",
                hero: hero
            ) {
                RearrangeAnimation()
            }
            
        case .presetsBookmarks:
            FeatureCard(
                icon: "square.grid.3x3",
                title: "Presets & Bookmarks",
                subtitle: "Save favorite pages and entire waffle layouts for quick recall.",
                premium: true,
                heroIconID: "icon-presets",
                heroTitleID: "title-presets",
                hero: hero
            ) {
                PresetsBookmarksVisual()
            }
            
        case .fullscreen:
            FeatureCard(
                icon: "arrow.up.left.and.arrow.down.right",
                title: "Fullscreen Focus",
                subtitle: "Maximize a single cell above the waffle to focus in.",
                premium: true,
                heroIconID: "icon-full",
                heroTitleID: "title-full",
                hero: hero
            ) {
                FullscreenAnimation()
            }
        }
    }
}

// MARK: - Model

private struct OnboardingPage: Identifiable {
    enum Kind {
        case welcome
        case grid
        case popOut
        case rearrange
        case presetsBookmarks
        case fullscreen
    }
    let id = UUID()
    let kind: Kind

    static let all: [OnboardingPage] = [
        .init(kind: .welcome),
        .init(kind: .grid),
        .init(kind: .popOut),
        .init(kind: .rearrange),
        .init(kind: .presetsBookmarks),
        .init(kind: .fullscreen)
    ]
}

// MARK: - Shared UI

private struct ProgressPips: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i <= index ? Color.primary.opacity(0.85) : Color.primary.opacity(0.25))
                    .frame(width: i == index ? 22 : 10, height: 6)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: index)
            }
        }
    }
}

private struct RequiresSyrupBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "drop.fill")
            Text("Requires Syrup")
        }
        .font(.footnote.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.15)))
    }
}

private struct CTAGetSyrup: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "cart.fill")
                Text("Get Syrup")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - Cards

private struct WelcomeCard: View {
    let hero: Namespace.ID
    @State private var wave = false

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 40, weight: .bold))
                    .matchedGeometryEffect(id: "icon", in: hero)
                    .symbolEffect(.bounce.byLayer, options: .nonRepeating, value: wave)
                Text("Welcome to Waffle")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .matchedGeometryEffect(id: "title", in: hero)
            }
            .padding(.top, 8)

            Text("Browse multiple websites at once. Arrange your pages in a way that suits you best.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            GridVisual()
                .frame(height: 200)
                .padding(.top, 80)

            Spacer(minLength: 0)
        }
        .onAppear { wave = true }
    }
}

private struct GridDemoCard: View {
    let hero: Namespace.ID
    @State private var pulse = false
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.split.3x3")
                    .font(.system(size: 34, weight: .semibold))
                    .matchedGeometryEffect(id: "icon-grid", in: hero)
                Text("Grid Browsing")
                    .font(.title2.bold())
                    .matchedGeometryEffect(id: "title-grid", in: hero)
            }
            Text("Open several sites at once. Each tile is an independent browser. Tap one to control it.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
            
            GridVisual(highlightIndex: pulse ? 3 : 1)
                .frame(height: 210)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
            
            Spacer()
        }
        .onAppear { pulse = true }
    }
}

private struct FeatureCard<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let premium: Bool
    let heroIconID: String
    let heroTitleID: String
    let hero: Namespace.ID
    @ViewBuilder var content: Content
    @Environment(WaffleCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .semibold))
                    .matchedGeometryEffect(id: heroIconID, in: hero)
                Text(title)
                    .font(.title2.bold())
                    .matchedGeometryEffect(id: heroTitleID, in: hero)
                if premium {
                    RequiresSyrupBadge()
                }
            }

            Text(subtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()

            content
                .frame(minHeight: 200)
            
            Spacer()
        }
    }
}

private struct SyrupInfoCard: View {
    let isPurchased: Bool
    let onGetSyrup: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 34, weight: .bold))
                Text("Syrup")
                    .font(.title2.bold())
            }

            Text("Syrup unlocks premium features:")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(symbol: "square.grid.3x3", text: "Larger grids")
                FeatureRow(symbol: "arrow.up.right.square", text: "Pop-out windows")
                FeatureRow(symbol: "arrow.up.left.and.arrow.down.right", text: "Fullscreen focus")
                FeatureRow(symbol: "square.and.arrow.down", text: "Save and update Presets")
                FeatureRow(symbol: "arrow.left.arrow.right.square", text: "Rearrange grid")
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.1)))

            if isPurchased {
                Label("Thanks for purchasing Syrup!", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                CTAGetSyrup { onGetSyrup() }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
            Text(text)
            Spacer()
        }
    }
}

// MARK: - Visuals and Animations

private struct GridVisual: View {
    var highlightIndex: Int? = nil
    var body: some View {
        let items = Array(0..<12)
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items, id: \.self) { i in
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.waffleSecondary.opacity(i == highlightIndex ? 0.35 : 0.0), lineWidth: 5)
                    )
                    .frame(height: 80)
                    .shadow(color: .black.opacity(0.06), radius: i == highlightIndex ? 6 : 2, x: 0, y: 1)
            }
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.08)))
    }
}

private struct PopOutAnimation: View {
    @State private var fly = false
    var body: some View {
        ZStack {
            GridVisual()
                .frame(height: 200)
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.5), lineWidth: 2))
                .frame(width: 200, height: 100)
                .shadow(radius: 2)
                .offset(x: fly ? 120 : 0, y: fly ? -80 : 0)
                .animation(.spring(response: 0.7, dampingFraction: 0.75).repeatForever(autoreverses: true), value: fly)
        }
        .onAppear { fly = true }
    }
}

private struct FullscreenAnimation: View {
    @State private var expand = false
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.primary.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.25), lineWidth: 2)
            )
            .frame(height: expand ? 240 : 160)
            .animation(.spring(response: 0.7, dampingFraction: 0.75).repeatForever(autoreverses: true), value: expand)
            .onAppear { expand = true }
    }
}

private struct PresetsBookmarksVisual: View {
    @State private var blink = false
    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.06))
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "bookmark.fill")
                        Text("Bookmarks")
                    }
                    .font(.headline)
                )
                .frame(width: 160, height: 120)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(blink ? 0.45 : 0.2), lineWidth: 2))
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: blink)

            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.06))
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "square.grid.3x3")
                        Text("Presets")
                    }
                    .font(.headline)
                )
                .frame(width: 160, height: 120)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.2), lineWidth: 2))
        }
        .onAppear { blink = true }
    }
}

private struct RearrangeAnimation: View {
    // A 3x3 demo grid
    @State private var items: [Int] = Array(0..<9)
    @State private var dragIndex: Int = 0
    @State private var phase: Int = 0
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items, id: \.self) { item in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(item == items[dragIndex] ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.18), lineWidth: item == items[dragIndex] ? 3 : 2)
                        )
                        .frame(height: 56)
                        .overlay(Text("\(item)").foregroundStyle(.secondary))
                        .scaleEffect(item == items[dragIndex] ? 1.06 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: dragIndex)
                }
            }
            .frame(height: 200)
            .onAppear {
                // Loop a simulated drag that moves the selected tile forward through the array,
                // with others shifting into place.
                Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                        let next = (dragIndex + 1) % items.count
                        items.move(fromOffsets: IndexSet(integer: dragIndex), toOffset: next > dragIndex ? next + 1 : next)
                        dragIndex = next
                        phase += 1
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(WaffleCoordinator(store: StoreManager()))
}
