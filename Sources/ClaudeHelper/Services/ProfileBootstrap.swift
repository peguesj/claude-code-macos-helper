import Foundation

/// First-launch bootstrap: when no profiles exist, auto-create a "Default" profile
/// from any API key found in `~/.claude/settings.json` or the `ANTHROPIC_API_KEY` env var.
@MainActor
enum ProfileBootstrap {
    static func ensureDefaultProfile(store: ProfileStore) async {
        guard store.profiles.isEmpty else {
            Log.info("Bootstrap: \(store.profiles.count) profile(s) already present — skipping")
            return
        }

        guard let key = discoverAPIKey(), key.hasPrefix("sk-ant-") || key.contains("anthropic") || key.count > 20 else {
            Log.info("Bootstrap: no API key found in ~/.claude/settings.json or env — staying empty")
            return
        }

        let probed = await probeOrganization(key: key)
        let profile = Profile(
            name: probed?.displayName ?? "Default",
            plan: Plan(kind: probed?.planKind ?? .max5x),
            accentHex: "#CC785C"
        )

        do {
            try store.save(profile, apiKey: key)
            try store.activate(profileID: profile.id)
            Log.info("Bootstrap: created Default profile (\(profile.name) · \(profile.plan.displayName))")
        } catch {
            Log.error("Bootstrap save failed: \(error.localizedDescription)")
        }
    }

    /// Discovers a Claude credential to bootstrap the Default profile from, in order:
    ///   1. `~/.claude/settings.json` `env.ANTHROPIC_API_KEY`
    ///   2. `ANTHROPIC_API_KEY` environment variable
    ///   3. macOS Keychain `Claude Code-credentials` (the OAuth access token used by Claude Code Max plans)
    static func discoverAPIKey() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let settingsURL = home.appendingPathComponent(".claude/settings.json")
        if let data = try? Data(contentsOf: settingsURL),
           let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           let env = obj["env"] as? [String: Any],
           let key = env["ANTHROPIC_API_KEY"] as? String,
           !key.isEmpty {
            Log.info("Bootstrap: found ANTHROPIC_API_KEY in ~/.claude/settings.json")
            return key
        }
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            Log.info("Bootstrap: using ANTHROPIC_API_KEY from environment")
            return envKey
        }
        // Skip the keychain read in screenshot mode to avoid potential ACL hangs in headless contexts.
        if ProcessInfo.processInfo.environment["CLAUDEHELPER_SCREENSHOT_MODE"] != "1",
           let oauth = readClaudeCodeOAuthAccessToken() {
            Log.info("Bootstrap: using Claude Code OAuth access token from Keychain")
            return oauth
        }
        return nil
    }

    /// Reads `Claude Code-credentials` keychain item (OAuth) and returns the accessToken if present.
    private static func readClaudeCodeOAuthAccessToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String:                kSecClassGenericPassword,
            kSecAttrService as String:          "Claude Code-credentials",
            kSecReturnData as String:           true,
            kSecMatchLimit as String:           kSecMatchLimitOne,
            kSecUseAuthenticationUI as String:  kSecUseAuthenticationUISkip
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let oauth = obj["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String,
              !token.isEmpty else {
            switch status {
            case errSecSuccess:           break
            case errSecItemNotFound:      break  // user doesn't use Claude Code OAuth
            case errSecInteractionNotAllowed: Log.info("Bootstrap: Claude Code keychain exists but ACL blocks read (different signing identity) — user can add a profile manually")
            default:                      Log.warn("Bootstrap: keychain status \(status) for Claude Code-credentials")
            }
            return nil
        }
        return token
    }

    private struct OrgProbeResult {
        let displayName: String?
        let planKind: Plan.Kind?
    }

    /// Best-effort probe of /v1/organizations to label the profile.
    /// Falls back to `nil` (and Default / Max 5×) on any failure or 401/404.
    private static func probeOrganization(key: String) async -> OrgProbeResult? {
        struct Org: Decodable {
            let name: String?
            let display_name: String?
            let plan: String?
        }
        struct OrgList: Decodable { let data: [Org]? }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/organizations")!)
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 4.0

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return nil
        }
        guard let list = try? JSONDecoder().decode(OrgList.self, from: data),
              let org = list.data?.first else {
            return nil
        }
        let kind = planKindFromString(org.plan)
        return OrgProbeResult(
            displayName: org.display_name ?? org.name,
            planKind: kind
        )
    }

    private static func planKindFromString(_ s: String?) -> Plan.Kind? {
        guard let s = s?.lowercased() else { return nil }
        if s.contains("enterprise") { return .enterprise }
        if s.contains("team")       { return .team }
        if s.contains("max") && s.contains("20") { return .max20x }
        if s.contains("max")        { return .max5x }
        if s.contains("pro")        { return .pro }
        if s.contains("free")       { return .free }
        return nil
    }
}
