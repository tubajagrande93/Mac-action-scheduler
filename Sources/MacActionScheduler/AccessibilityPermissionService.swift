import AppKit
import ApplicationServices
import Combine
import CoreGraphics

struct PermissionSnapshot: Equatable {
    let accessibility: Bool
    let postEvents: Bool

    var ready: Bool { accessibility && postEvents }

    var missingDescription: String {
        switch (accessibility, postEvents) {
        case (false, false):
            return "Accessibility + Click access missing"
        case (false, true):
            return "Accessibility access missing"
        case (true, false):
            return "Mouse click access missing"
        case (true, true):
            return "Permissions granted"
        }
    }
}

@MainActor
final class AccessibilityPermissionService: ObservableObject {
    static let shared = AccessibilityPermissionService()

    @Published private(set) var snapshot = PermissionSnapshot(
        accessibility: false,
        postEvents: false
    )

    private var requestedAccessibility = false
    private var requestedPostEvents = false

    private init() {}

    // Truthfully records BOTH results from the current signed process.
    // Does not interpret the System Settings toggle as authorization.
    @discardableResult
    func refreshSilently() -> Bool {
        let current = PermissionSnapshot(
            accessibility: AXIsProcessTrusted(),
            postEvents: CGPreflightPostEventAccess()
        )
        if current != snapshot {
            snapshot = current
            recordDiagnostics(current)
        }
        return current.ready
    }

    // Diagnostic keys are written only when the observed permission state
    // changes, so rapid preflight checks no longer rewrite UserDefaults on
    // every call. `AXIsProcessTrusted()` / `CGPreflightPostEventAccess()`
    // remain the authoritative source; these keys exist for support debugging.
    private func recordDiagnostics(_ current: PermissionSnapshot) {
        let defaults = UserDefaults.standard
        defaults.set(current.accessibility, forKey: "MAS_AXTrusted")
        defaults.set(current.postEvents, forKey: "MAS_PostEventGranted")
        defaults.set(Date().timeIntervalSince1970, forKey: "MAS_LastCheckUnix")
        defaults.set(Bundle.main.bundleIdentifier ?? "unknown", forKey: "MAS_BundleID")
    }

    func checkAtStartup() {
        guard !refreshSilently() else { return }
        requestNextMissingPermission()
    }

    func applicationBecameActive() {
        let previouslyGrantedAX = snapshot.accessibility
        let ready = refreshSilently()
        if !ready && !previouslyGrantedAX && snapshot.accessibility {
            // The user returned with AX granted: request post-event access,
            // if it still needs a separate confirmation.
            requestNextMissingPermission()
        }
    }

    // At most ONE new system request per pass. Never stack AX + CG
    // permission requests and an NSAlert in the same launch.
    private func requestNextMissingPermission() {
        guard !snapshot.ready else { return }

        if !snapshot.accessibility && !requestedAccessibility {
            requestedAccessibility = true
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            return
        }

        if snapshot.accessibility && !snapshot.postEvents && !requestedPostEvents {
            requestedPostEvents = true
            _ = CGRequestPostEventAccess()
        }
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    @discardableResult
    func requireForScheduling() -> Bool {
        guard refreshSilently() else {
            requestNextMissingPermission()
            openAccessibilitySettings()
            return false
        }
        return true
    }

    func canExecuteClick() -> Bool {
        refreshSilently()
    }
}
