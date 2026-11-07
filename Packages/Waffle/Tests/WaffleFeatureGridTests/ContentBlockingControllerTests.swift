import Foundation
import Testing
import WaffleCore
@testable import WaffleFeatureGrid

private final class Store: KeyValueStoring {
    var values: [String: Any] = [:]
    func data(forKey k: String) -> Data? { values[k] as? Data }
    func string(forKey k: String) -> String? { values[k] as? String }
    func bool(forKey k: String) -> Bool { values[k] as? Bool ?? false }
    func integer(forKey k: String) -> Int { values[k] as? Int ?? 0 }
    func set(_ v: Any?, forKey k: String) { values[k] = v }
    func removeObject(forKey k: String) { values[k] = nil }
}

@Suite("ContentBlockingController")
struct ContentBlockingControllerTests {
    @Test func defaultsOnAndPersistsToggle() {
        let store = Store()
        let first = ContentBlockingController(defaults: store, compilesRules: false)
        #expect(first.isGloballyEnabled)
        first.isGloballyEnabled = false
        #expect(!ContentBlockingController(defaults: store, compilesRules: false).isGloballyEnabled)
    }

    @Test func exceptionsPersistAndNormalize() {
        let store = Store()
        let first = ContentBlockingController(defaults: store, compilesRules: false)
        first.addException(for: "https://www.Example.com/page")
        first.addException(for: "example.com")
        #expect(first.exceptionHosts == ["example.com"])
        let second = ContentBlockingController(defaults: store, compilesRules: false)
        #expect(second.hasException(for: "https://m.example.com"))
        second.removeException(host: "example.com")
        #expect(!second.hasException(for: "https://example.com"))
    }

    @Test func modePersistsInSnapshot() {
        let model = GridModel(defaults: Store(), blocksContent: false)
        model.makeInitialItem()
        let cell = model.waffleRows[0][0]
        model.setContentBlockingMode(.off, for: cell)
        let snap = model.makeSnapshot()
        #expect(snap.contentBlockingModes == [ContentBlockingMode.off.rawValue])
        let restored = GridModel(defaults: Store(), blocksContent: false)
        restored.apply(snapshot: snap)
        #expect(restored.waffleRows[0][0].contentBlockingMode == .off)
    }

    @Test func bundledListsDecompressAndParse() async throws {
        let manifest = try await ContentBlockingController.loadManifest()
        #expect(manifest.lists.count == 3)
        for entry in manifest.lists {
            let json = try await ContentBlockingController.loadRuleJSON(id: entry.id)
            let rules = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]]
            #expect((rules?.count ?? 0) > 1000)
        }
    }
}
