import Foundation

enum AppInfo {
    /// Display name from the bundle, so renaming the app only touches the build script.
    static let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Awake"
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
}
