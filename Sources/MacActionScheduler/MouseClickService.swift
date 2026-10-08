import AppKit
import CoreGraphics

@MainActor
enum MouseClickService {
    static func isOnConnectedScreen(_ point: CGPoint) -> Bool {
        guard let primary = NSScreen.screens.first else { return false }
        let appKitPoint = CGPoint(x: point.x, y: primary.frame.maxY - point.y)
        return NSScreen.screens.contains { $0.frame.contains(appKitPoint) }
    }

    // Returning true means both CGEvents were created and posted,
    // not that the receiving application acted on the click.
    static func postLeftClick(at point: CGPoint) -> Bool {
        guard isOnConnectedScreen(point) else { return false }
        guard let down = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        ), let up = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { return false }

        CGWarpMouseCursorPosition(point)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }
}
