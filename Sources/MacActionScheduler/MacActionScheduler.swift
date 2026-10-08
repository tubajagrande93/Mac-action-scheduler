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
            // Visible when the user switches back to the app, but not key/front.
            window.orderFront(nil)
            permissions.checkAtStartup()
        }
    }

    func applicationDidBecomeActive(
        _ notification: Notification
    ) {
        // Refresh silently when returning from System Settings.
        AccessibilityPermissionService.shared.applicationBecameActive()
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
