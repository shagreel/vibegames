import Foundation

extension Bundle {

    /// The marketing version, as App Store Connect knows it — "1.0".
    ///
    /// Read from the bundle rather than written down anywhere in the source, so
    /// that what the app says it is cannot disagree with what was installed. The
    /// support page states the same number, and `Tools/check_app_store.py`
    /// compares it against `project.yml`.
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    /// The build number. Two builds can share a version and not a build, which is
    /// why what is on screen is both.
    var buildNumber: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
