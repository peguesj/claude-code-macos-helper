import Foundation

/// Mutates `~/.claude/settings.json` to reflect the active profile.
/// Updates the `env.ANTHROPIC_API_KEY` value and writes a profile-tagged backup.
/// Atomic write via temp+rename so a concurrent `claude` CLI invocation never sees a half file.
struct CLIConfigWriter {
    let configPath: URL
    let backupDir: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        configPath = home.appendingPathComponent(".claude/settings.json")
        backupDir = home.appendingPathComponent(".claude/.claudehelper-backups")
    }

    func applyActiveProfile(_ profile: Profile, apiKey: String) throws {
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        var dict: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: configPath.path) {
            let data = try Data(contentsOf: configPath)
            if !data.isEmpty,
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                dict = obj
                let backupURL = backupDir.appendingPathComponent("settings-pre-\(profile.id.uuidString)-\(Int(Date().timeIntervalSince1970)).json")
                try? data.write(to: backupURL)
            }
        }
        var env = (dict["env"] as? [String: Any]) ?? [:]
        env["ANTHROPIC_API_KEY"] = apiKey
        env["CLAUDEHELPER_ACTIVE_PROFILE"] = profile.name
        env["CLAUDEHELPER_ACTIVE_PROFILE_ID"] = profile.id.uuidString
        dict["env"] = env

        let out = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        let tmpURL = configPath.appendingPathExtension("tmp")
        try out.write(to: tmpURL, options: .atomic)
        _ = try? FileManager.default.replaceItemAt(configPath, withItemAt: tmpURL)
        Log.info("Wrote ~/.claude/settings.json for profile=\(profile.name)")
    }
}
