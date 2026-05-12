import Foundation
import Combine
import AppKit

@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var activeProfile: Profile?

    private let defaults = UserDefaults.standard
    private let profilesKey = "ClaudeHelper.profiles"
    private let activeKey = "ClaudeHelper.activeProfileID"
    private let configWriter = CLIConfigWriter()

    init() { load() }

    private func load() {
        if let data = defaults.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([Profile].self, from: data) {
            profiles = decoded
        }
        if let s = defaults.string(forKey: activeKey),
           let uuid = UUID(uuidString: s),
           let p = profiles.first(where: { $0.id == uuid }) {
            activeProfile = p
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: profilesKey)
        }
        defaults.set(activeProfile?.id.uuidString, forKey: activeKey)
    }

    func save(_ profile: Profile, apiKey: String) throws {
        try KeychainHelper.set(apiKey, service: profile.keychainTag, account: "api_key")
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
        } else {
            profiles.append(profile)
        }
        if activeProfile == nil { try? activate(profileID: profile.id) }
        persist()
    }

    func apiKey(for profile: Profile) -> String? {
        try? KeychainHelper.get(service: profile.keychainTag, account: "api_key")
    }

    func activate(profileID: UUID) throws {
        guard let profile = profiles.first(where: { $0.id == profileID }) else { return }
        activeProfile = profile

        if let idx = profiles.firstIndex(where: { $0.id == profileID }) {
            profiles[idx].lastUsedAt = Date()
        }
        persist()

        if let key = apiKey(for: profile) {
            try configWriter.applyActiveProfile(profile, apiKey: key)
        }

        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("ClaudeHelperProfileChanged"),
            object: profile.id.uuidString,
            userInfo: ["name": profile.name],
            deliverImmediately: true
        )
        Log.info("Activated profile \(profile.name) [\(profile.id.uuidString)]")
    }

    func delete(profileID: UUID) throws {
        guard let profile = profiles.first(where: { $0.id == profileID }) else { return }
        try? KeychainHelper.delete(service: profile.keychainTag, account: "api_key")
        profiles.removeAll { $0.id == profileID }
        if activeProfile?.id == profileID { activeProfile = profiles.first }
        persist()
    }
}
