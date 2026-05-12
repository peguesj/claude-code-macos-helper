import Foundation

extension Bundle {
    var shortVersionString: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0-dev"
    }
    var buildNumber: String {
        (infoDictionary?["CFBundleVersion"] as? String) ?? "0"
    }
}
