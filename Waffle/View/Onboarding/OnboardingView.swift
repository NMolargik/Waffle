//
//  OnboardingView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import SwiftUI
import Combine

struct OnboardingView: View {
    @Environment(WaffleCoordinator.self) private var coordinator
    @AppStorage("hasCompletedOnboarding") private var done = false

    @State private var pageIndex: Int = 0
    @Namespace private var hero

    private let pages: [OnboardingPage] = OnboardingPage.all

    var body: some View {
        ZStack {
            // Subtle brand gradient background - lighter for better readability
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

            // Add a light overlay for better card contrast
            Color.white.opacity(0.1)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top controls
                HStack {
                    ProgressPips(count: pages.count, index: pageIndex)
                    Spacer()
                    Button("Skip") {
                        finishAndShowSyrup()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer(minLength: 20)

                // Main card
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 20, y: 10)

                    contentForPage(pages[pageIndex].kind)
                        .padding(24)
                }
                .padding(.horizontal, 20)
                .frame(maxHeight: 620)
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: pageIndex)

                Spacer(minLength: 20)

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

    @ViewBuilder
    private func contentForPage(_ kind: OnboardingPage.Kind) -> some View {
        switch kind {
        case .welcome:
            WelcomeCard()
        case .concept:
            ConceptCard()
        case .selectCell:
            SelectCellCard()
        case .navigate:
            NavigateCard()
        case .gridControls:
            GridControlsCard()
        case .premiumFeatures:
            PremiumFeaturesCard()
        }
    }
}

// MARK: - Model

private struct OnboardingPage: Identifiable {
    enum Kind {
        case welcome
        case concept
        case selectCell
        case navigate
        case gridControls
        case premiumFeatures
    }
    let id = UUID()
    let kind: Kind

    static let all: [OnboardingPage] = [
        .init(kind: .welcome),
        .init(kind: .concept),
        .init(kind: .selectCell),
        .init(kind: .navigate),
        .init(kind: .gridControls),
        .init(kind: .premiumFeatures)
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

// MARK: - Card 1: Welcome

private struct WelcomeCard: View {
    @State private var animate = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon representation
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
                    .foregroundStyle(Color.waffleTertiary)
                    .symbolEffect(.bounce, value: animate)
            }

            VStack(spacing: 12) {
                Text("Welcome to Waffle")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text("The grid-based browser for iPad")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text("Browse multiple websites simultaneously, arranged in a customizable grid layout.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .onAppear { animate = true }
    }
}

private struct FeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.waffleSecondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 90)
    }
}

// MARK: - Card 2: The Concept

private struct ConceptCard: View {
    @State private var highlightedCell = 0
    let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Label("What is Grid Browsing?", systemImage: "lightbulb.fill")
                    .font(.title2.bold())
                    .foregroundStyle(Color.waffleSecondary)

                Text("Think of your browser as a grid of cells, each showing a different website")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Interactive grid demo
            InteractiveGridDemo(highlightedCell: highlightedCell)
                .frame(height: 280)

            VStack(alignment: .leading, spacing: 12) {
                ConceptPoint(
                    number: "1",
                    text: "Each cell is an independent browser"
                )
                ConceptPoint(
                    number: "2",
                    text: "Tap any cell to select and control it"
                )
                ConceptPoint(
                    number: "3",
                    text: "Use the address bar to navigate the selected cell"
                )
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            Spacer()
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                highlightedCell = (highlightedCell + 1) % 4
            }
        }
    }
}

private struct ConceptPoint: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.waffleSecondary, in: Circle())

            Text(text)
                .font(.subheadline)
        }
    }
}

private struct InteractiveGridDemo: View {
    let highlightedCell: Int
    let sites = ["apple.com", "google.com", "github.com", "swift.org"]
    let colors: [Color] = [.blue, .red, .purple, .orange]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { i in
                    CellPreview(
                        site: sites[i],
                        color: colors[i],
                        isSelected: highlightedCell == i
                    )
                }
            }
            HStack(spacing: 8) {
                ForEach(2..<4, id: \.self) { i in
                    CellPreview(
                        site: sites[i],
                        color: colors[i],
                        isSelected: highlightedCell == i
                    )
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct CellPreview: View {
    let site: String
    let color: Color
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Fake address bar
            HStack {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 16, height: 16)
                Text(site)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(6)
            .background(Color.primary.opacity(0.05))

            // Content area
            Rectangle()
                .fill(color.opacity(0.1))
                .overlay(
                    Image(systemName: "globe")
                        .font(.largeTitle)
                        .foregroundStyle(color.opacity(0.3))
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.waffleSecondary : Color.clear, lineWidth: 3)
        )
        .shadow(color: isSelected ? Color.waffleSecondary.opacity(0.4) : .clear, radius: 8)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Card 3: Selecting Cells

private struct SelectCellCard: View {
    @State private var selectedCell = 0
    @State private var showTapHint = true

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Label("Selecting a Cell", systemImage: "hand.tap.fill")
                    .font(.title2.bold())
                    .foregroundStyle(Color.waffleSecondary)

                Text("Tap any cell to select it. The selected cell has a colored border.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Tappable demo grid
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TappableCell(index: 0, selectedCell: $selectedCell, showTapHint: showTapHint)
                    TappableCell(index: 1, selectedCell: $selectedCell, showTapHint: false)
                }
                HStack(spacing: 8) {
                    TappableCell(index: 2, selectedCell: $selectedCell, showTapHint: false)
                    TappableCell(index: 3, selectedCell: $selectedCell, showTapHint: false)
                }
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .frame(height: 240)

            // Explanation
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Selected cell: \(selectedCell + 1)")
                        .font(.subheadline.bold())
                }

                Text("The address bar and navigation controls apply to the selected cell")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
        .onChange(of: selectedCell) { _, _ in
            showTapHint = false
        }
    }
}

private struct TappableCell: View {
    let index: Int
    @Binding var selectedCell: Int
    let showTapHint: Bool

    var isSelected: Bool { selectedCell == index }
    let colors: [Color] = [.blue, .green, .purple, .orange]

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedCell = index
            }
        } label: {
            RoundedRectangle(cornerRadius: 12)
                .fill(colors[index].opacity(0.15))
                .overlay(
                    VStack {
                        Text("Cell \(index + 1)")
                            .font(.headline)
                            .foregroundStyle(colors[index])

                        if showTapHint {
                            HStack(spacing: 4) {
                                Image(systemName: "hand.tap.fill")
                                Text("Tap me!")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.waffleSecondary : Color.clear, lineWidth: 3)
                )
                .shadow(color: isSelected ? Color.waffleSecondary.opacity(0.4) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card 4: Navigation

private struct NavigateCard: View {
    @State private var urlText = "apple.com"
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Label("Navigating", systemImage: "globe")
                    .font(.title2.bold())
                    .foregroundStyle(Color.waffleSecondary)

                Text("Use the address bar to visit websites in the selected cell")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Mock toolbar
            VStack(spacing: 16) {
                // Address bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    Text(urlText)
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.thinMaterial, in: Capsule())
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            // Tips
            VStack(alignment: .leading, spacing: 12) {
                NavigationTip(icon: "keyboard", text: "Type a URL or search term in the address bar")
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            Spacer()
        }
    }
}

private struct MockToolbarButton: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.waffleSecondary)
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: Circle())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct NavigationTip: View {
    let icon: String
    let text: String

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

// MARK: - Card 5: Grid Controls

private struct GridControlsCard: View {
    @State private var rows = 2
    @State private var cols = 2

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Label("Customize Your Grid", systemImage: "square.grid.3x3")
                    .font(.title2.bold())
                    .foregroundStyle(Color.waffleSecondary)

                Text("Add or remove rows and columns to fit your workflow")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Interactive grid resizer
            HStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Rows")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Stepper("", value: $rows, in: 1...4)
                        .labelsHidden()
                    Text("\(rows)")
                        .font(.title2.bold())
                }

                // Mini grid preview
                MiniGridPreview(rows: rows, cols: cols)
                    .frame(width: 160, height: 160)

                VStack(spacing: 8) {
                    Text("Cols")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Stepper("", value: $cols, in: 1...4)
                        .labelsHidden()
                    Text("\(cols)")
                        .font(.title2.bold())
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            // Info
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.waffleSecondary)
                    Text("Free: Up to \(AppConfiguration.maxFreeRows)x\(AppConfiguration.maxFreeCols)")
                        .font(.subheadline)
                }
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(Color.waffleTertiary)
                    Text("With Syrup: Up to \(AppConfiguration.maxPremiumRows)x\(AppConfiguration.maxPremiumCols)")
                        .font(.subheadline)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
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

// MARK: - Card 6: Premium Features

private struct PremiumFeaturesCard: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.title2)
                        .foregroundStyle(Color.waffleTertiary)
                    Text("Unlock with Syrup")
                        .font(.title2.bold())
                }

                Text("Get even more out of Waffle with these premium features")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                PremiumFeatureRow(
                    icon: "rectangle.on.rectangle",
                    title: "Pop Out",
                    description: "Detach any cell into its own window"
                )
                PremiumFeatureRow(
                    icon: "arrow.up.left.and.arrow.down.right",
                    title: "Fullscreen",
                    description: "Focus on a single cell temporarily"
                )
                PremiumFeatureRow(
                    icon: "arrow.left.arrow.right.square",
                    title: "Rearrange",
                    description: "Drag cells to reorder your grid"
                )
                PremiumFeatureRow(
                    icon: "square.grid.3x3",
                    title: "Presets",
                    description: "Save and restore entire grid layouts"
                )
                PremiumFeatureRow(
                    icon: "rectangle.split.3x3",
                    title: "Larger Grids",
                    description: "Up to \(AppConfiguration.maxPremiumRows)x\(AppConfiguration.maxPremiumCols) cells"
                )
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            Text("You'll see Syrup options after completing this tour")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

private struct PremiumFeatureRow: View {
    let icon: String
    let title: String
    let description: String

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
        .environment(WaffleCoordinator(store: StoreManager()))
}
