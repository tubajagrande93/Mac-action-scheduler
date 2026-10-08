import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let scheduler = ClickScheduler()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        // Register bundled OpenAI Sans fonts before creating the GUI.
        OpenAIFont.register()

        let contentView = ContentView(scheduler: scheduler)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 450),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        // Fixed-size compact utility window.
        window.styleMask.remove(.resizable)
        window.contentMinSize = NSSize(width: 360, height: 450)
        window.contentMaxSize = NSSize(width: 360, height: 450)

        window.title = "Mac Action Scheduler"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        self.window = window

        // Do not raise the main window over macOS permission dialogs.
        // Request trust only after the application window has been created.
        let permissions = AccessibilityPermissionService.shared
        let ready = permissions.refreshSilently()
        if ready {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Never display our main window over a macOS authorization dialog.
            // System-owned prompts cannot be assigned a level by this app.
            window.orderOut(nil)
            permissions.checkAtStartup()
        }
    }

    func applicationDidBecomeActive(
        _ notification: Notification
    ) {
        // When returning from System Settings, re-evaluate the CURRENT process
        // identity and show the app only after every required permission is ready.
        let permissions = AccessibilityPermissionService.shared
        permissions.applicationBecameActive()
        if permissions.snapshot.ready, let window, !window.isVisible {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if scheduler.hasPendingClick {
            sender.orderOut(nil)
            return false
        }
        return true
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        let permissions = AccessibilityPermissionService.shared
        if permissions.refreshSilently() {
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // A Dock reopen during onboarding must not cover System Settings.
            permissions.openAccessibilitySettings()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        !scheduler.hasPendingClick
    }
}

@MainActor
@main
struct MacActionScheduler {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
