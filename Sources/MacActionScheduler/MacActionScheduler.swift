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
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        window.delegate = self

        self.window = window

        NSApp.activate(ignoringOtherApps: true)

        // Preflight before any automation can be scheduled.
        AccessibilityPermissionService.shared.checkAtStartup(in: window)
    }

    func applicationDidBecomeActive(
        _ notification: Notification
    ) {
        // Refresh silently when returning from System Settings.
        AccessibilityPermissionService.shared.refreshSilently()
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
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
