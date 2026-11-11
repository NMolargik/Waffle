//
//  SettingsView.swift
//  WaffleFeatureSettings
//
//  Search engine, Syrup status, destructive data actions, and about links. Data actions
//  go through `SettingsModel`; Syrup gating and in-app link opening are injected.
//

#if os(iOS)
import SwiftUI
import WaffleCore
import WaffleDesignSystem

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    private let model: SettingsModel
    private let isSyrupEnabled: Bool
    private let requestSyrup: () -> Void
    /// Loads a URL into the selected grid cell (the app browses its own links).
    private let openInApp: (String) -> Void
    private let contentBlocking: ContentBlockingSettingsBinding
    /// iPhone and iPhone Duo: panes and layouts instead of cells and presets, "Done" to close,
    /// and a Restore Purchases row. The iPad keeps its wording.
    private let usesPaneWording: Bool
    /// Phone only: restores purchases, returning whether Syrup is now owned.
    private let restorePurchases: (() async -> Bool)?

    @AppStorage("searchProvider") private var searchProviderRawValue: String = SearchProvider.google.rawValue
    @State private var showDeleteBookmarksConfirm = false
    @State private var showDeletePresetsConfirm = false
    @State private var restoreMessage: LocalizedStringKey?
    @State private var isRestoring = false

    public init(
        model: SettingsModel,
        isSyrupEnabled: Bool,
        requestSyrup: @escaping () -> Void,
        openInApp: @escaping (String) -> Void,
        usesPaneWording: Bool = false,
        restorePurchases: (() async -> Bool)? = nil,
        contentBlocking: ContentBlockingSettingsBinding
    ) {
        self.usesPaneWording = usesPaneWording
        self.restorePurchases = restorePurchases
        self.contentBlocking = contentBlocking
        self.model = model
        self.isSyrupEnabled = isSyrupEnabled
        self.requestSyrup = requestSyrup
        self.openInApp = openInApp
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return String(localized: "Version \(version) (\(build))")
    }

    private func syrupRow(stacked: Bool) -> some View {
        let name = Label(String(localized: "Syrup"), systemImage: "drop.fill")
            .foregroundStyle(.primary)
        let status = HStack(spacing: 6) {
            if isSyrupEnabled {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("Purchased. Thank you!")
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "cart")
                    .foregroundStyle(.waffleTertiary)
                Text("Not Purchased")
                    .foregroundStyle(.secondary)
            }
        }
        return Group {
            if stacked {
                VStack(alignment: .leading, spacing: 6) {
                    name
                    HStack {
                        status
                        Spacer(minLength: 0)
                        if !isSyrupEnabled {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            } else {
                HStack {
                    name
                    Spacer()
                    status
                    if !isSyrupEnabled {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        if !isSyrupEnabled {
                            requestSyrup()
                        }
                    } label: {
                        // At accessibility text sizes the status drops under the name
                        // instead of wrapping letter by letter.
                        ViewThatFits(in: .horizontal) {
                            syrupRow(stacked: false)
                            syrupRow(stacked: true)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSyrupEnabled) // Prevent interaction when already purchased
                    .accessibilityHint(isSyrupEnabled ? Text("") : Text("Opens the Syrup purchase sheet"))

                    if let restorePurchases, !isSyrupEnabled {
                        Button {
                            Task {
                                isRestoring = true
                                let restored = await restorePurchases()
                                isRestoring = false
                                restoreMessage = restored ? "Syrup restored. Thank you!" : "No earlier purchase was found"
                            }
                        } label: {
                            HStack {
                                Label("Restore Purchases", systemImage: "arrow.clockwise")
                                    .foregroundStyle(.primary)
                                if isRestoring {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isRestoring)
                        if let restoreMessage {
                            Text(restoreMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(String(localized: "Search")) {
                    Picker(String(localized: "Default Search Engine"), selection: $searchProviderRawValue) {
                        ForEach(SearchProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle(isOn: contentBlocking.isEnabled) {
                        Label(String(localized: "Block Ads, Trackers & Cookie Banners"), systemImage: "shield.lefthalf.filled")
                    }
                    ForEach(contentBlocking.exceptionHosts, id: \.self) { host in
                        Text(verbatim: host)
                    }
                    .onDelete { offsets in
                        for index in offsets { contentBlocking.removeException(contentBlocking.exceptionHosts[index]) }
                    }
                } header: {
                    Text("Content Blocking")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        if usesPaneWording {
                            Text("Applies to every pane. To change it for one pane or site, open ••• then This Page then Content Blocking. Sites listed here are never blocked.")
                        } else {
                            Text("Applies to every cell. Override it for a single cell or site from the cell's context menu. Sites listed here are never blocked.")
                        }
                        if !contentBlocking.listTitles.isEmpty {
                            Text("Filter lists: \(listNames) (easylist.to), licensed CC BY-SA 3.0 and CC BY 3.0.")
                        }
                    }
                }

                Section(String(localized: "Data")) {
                    Button(role: .destructive) {
                        showDeletePresetsConfirm = true
                    } label: {
                        Text(LocalizedStringKey(usesPaneWording ? "Delete All Layouts" : "Delete All Presets"))
                    }
                    Button(role: .destructive) {
                        showDeleteBookmarksConfirm = true
                    } label: {
                        Text("Delete All Bookmarks")
                    }
                }

                Section(String(localized: "About")) {
                    HStack {
                        Text("Waffle")
                        Spacer()
                        Text(appVersionString)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        openLink("https://www.linkedin.com/in/nicholas-molargik/")
                    } label: {
                        HStack {
                            Text("Developer")
                            Spacer()
                            Text(verbatim: "Nicholas Molargik")
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        openLink("https://molargiksoftware.com")
                    } label: {
                        HStack {
                            Text("Company")
                            Spacer()
                            Text(verbatim: "Molargik Software LLC")
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                }

                #if DEBUG
                Section(String(localized: "Debug")) {
                    Button {
                        model.addExampleData()
                    } label: {
                        Label(String(localized: "Add Example Bookmarks & Presets"), systemImage: "plus.square.on.square")
                    }
                }
                #endif
            }
            .navigationTitle(Text("Settings"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(usesPaneWording ? String(localized: "Done") : String(localized: "Close")) {
                        dismiss()
                    }
                }
            }
            .alert(Text("Delete All Bookmarks?"), isPresented: $showDeleteBookmarksConfirm) {
                Button(String(localized: "Cancel"), role: .cancel) { }
                Button(String(localized: "Delete"), role: .destructive) {
                    model.deleteAllBookmarks()
                }
            } message: {
                Text("This action will permanently remove all bookmarks.")
            }
            .alert(Text(LocalizedStringKey(usesPaneWording ? "Delete All Layouts?" : "Delete All Presets?")), isPresented: $showDeletePresetsConfirm) {
                Button(String(localized: "Cancel"), role: .cancel) { }
                Button(String(localized: "Delete"), role: .destructive) {
                    model.deleteAllPresets()
                }
            } message: {
                Text(LocalizedStringKey(usesPaneWording ? "This action will permanently remove all layouts." : "This action will permanently remove all presets."))
            }
        }
    }

    private var listNames: String {
        contentBlocking.listTitles.formatted(.list(type: .and))
    }

    private func openLink(_ urlString: String) {
        openInApp(urlString)
        dismiss()
    }
}
#endif

