import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class AccessibilityPermissionService {

    static let shared = AccessibilityPermissionService()

    private(set) var granted = false
    private var didRequest = false
    private var didShowSetup = false

    private init() {}

    // MARK: - Silent permission preflight

    @discardableResult
    func refreshSilently() -> Bool {
        let accessibility = AXIsProcessTrusted()
        let postEvents = CGPreflightPostEventAccess()

        granted = accessibility && postEvents
        return granted
    }

    // MARK: - Application startup

    func checkAtStartup(in window: NSWindow) {
        // Already approved: absolutely no UI.
        guard !refreshSilently() else {
            print("PERMISSIONS: READY")
            return
        }

        print("PERMISSIONS: ACCESS REQUIRED")

        requestMissingPermissions()

        // Give macOS a chance to show its native prompt.
        // No polling or busy-wait loop.
        Task { @MainActor [weak self, weak window] in
            try? await Task.sleep(for: .seconds(1.5))

            guard let self,
                  let window,
                  !self.refreshSilently()
            else {
                return
            }

            self.presentSetupSheet(in: window)
        }
    }

    // MARK: - Native macOS permission requests

    private func requestMissingPermissions() {
        guard !didRequest else { return }
        didRequest = true

        if !CGPreflightPostEventAccess() {
            print("REQUEST: CoreGraphics Post Event Access")
            _ = CGRequestPostEventAccess()
        }

        if !AXIsProcessTrusted() {
            print("REQUEST: Accessibility")

            // Stable CoreFoundation option key.
            // Avoid Swift 6 concurrency access to the C global.
            let options = [
                "AXTrustedCheckOptionPrompt": true
            ] as CFDictionary

            _ = AXIsProcessTrustedWithOptions(options)
        }
    }

    // MARK: - Guaranteed onboarding fallback

    private func presentSetupSheet(in window: NSWindow) {
        guard !didShowSetup,
              !refreshSilently()
        else {
            return
        }

        didShowSetup = true

        let alert = NSAlert()
        alert.alertStyle = .informational

        alert.messageText =
            "Accessibility Access Required"

        alert.informativeText = """
        Mac Action Scheduler needs permission to \
        control your Mac before it can execute \
        scheduled mouse clicks.

        Enable access in System Settings > \
        Privacy & Security.

        No mouse actions will be executed \
        without your permission.
        """

        alert.addButton(
            withTitle: "Open Privacy Settings"
        )

        alert.addButton(
            withTitle: "Later"
        )

        alert.beginSheetModal(for: window) {
            [weak self] response in

            guard response == .alertFirstButtonReturn else {
                return
            }

            Task { @MainActor [weak self] in
                self?.openAccessibilitySettings()
            }
        }
    }

    // MARK: - Settings navigation

    func openAccessibilitySettings() {
        let pane = AXIsProcessTrusted()
            ? "Privacy_PostEvent"
            : "Privacy_Accessibility"

        let base =
            "x-apple.systempreferences:" +
            "com.apple.preference.security?"

        guard let url = URL(string: base + pane) else {
            return
        }

        if !NSWorkspace.shared.open(url),
           let fallback = URL(
                string: base + "Privacy_Accessibility"
           ) {
            NSWorkspace.shared.open(fallback)
        }
    }

    // MARK: - Scheduler guards

    @discardableResult
    func requireForScheduling() -> Bool {
        guard refreshSilently() else {
            openAccessibilitySettings()
            return false
        }

        return true
    }

    func canExecuteClick() -> Bool {
        refreshSilently()
    }
}
