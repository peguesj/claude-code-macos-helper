import Foundation
import WebKit

/// One non-persistent `WKWebsiteDataStore` per profile UUID, holding claude.ai cookies in isolation.
@MainActor
final class SessionStore {
    static let shared = SessionStore()

    private var stores: [UUID: WKWebsiteDataStore] = [:]

    func dataStore(for profileID: UUID) -> WKWebsiteDataStore {
        if let existing = stores[profileID] { return existing }
        let store: WKWebsiteDataStore
        if #available(macOS 14.0, *) {
            store = WKWebsiteDataStore(forIdentifier: profileID)
        } else {
            store = WKWebsiteDataStore.nonPersistent()
        }
        stores[profileID] = store
        return store
    }

    /// Removes claude.ai cookies/storage for a profile.
    func clear(profileID: UUID) async {
        let store = dataStore(for: profileID)
        let types: Set<String> = [
            WKWebsiteDataTypeCookies,
            WKWebsiteDataTypeLocalStorage,
            WKWebsiteDataTypeSessionStorage,
            WKWebsiteDataTypeIndexedDBDatabases
        ]
        let records = await store.dataRecords(ofTypes: types)
        let claude = records.filter { $0.displayName.contains("claude.ai") || $0.displayName.contains("anthropic.com") }
        await store.removeData(ofTypes: types, for: claude)
    }
}
