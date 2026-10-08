import AppKit

@MainActor
final class CoordinatePickerController {
    private var windows: [CoordinateOverlayWindow] = []
    private var keyMonitor: Any?
    private var completion: ((CGPoint?) -> Void)?
    private var isFinished = false

    func start(completion: @escaping (CGPoint?) -> Void) {
        guard windows.isEmpty else { return }

        self.completion = completion
        isFinished = false

        guard let primaryScreen = NSScreen.screens.first else {
            finish(with: nil)
            return
        }

        let primaryTop = primaryScreen.frame.maxY

        for screen in NSScreen.screens {
            let window = CoordinateOverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )

            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary
            ]

            let overlay = CoordinateOverlayView(frame: NSRect(
                origin: .zero,
                size: screen.frame.size
            ))

            overlay.onSelect = { [weak self] appKitPoint in
                let cgPoint = CGPoint(
                    x: appKitPoint.x,
                    y: primaryTop - appKitPoint.y
                )
                self?.finish(with: cgPoint)
            }

            window.contentView = overlay
            windows.append(window)
            window.orderFrontRegardless()
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            if event.keyCode == 53 {
                self?.finish(with: nil)
                return nil
            }
            return event
        }

        windows.first?.makeKeyAndOrderFront(nil)
        PrecisionCursor.cursor.push()
    }

    private func finish(with point: CGPoint?) {
        guard !isFinished else { return }
        isFinished = true

        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }

        for window in windows {
            window.orderOut(nil)
        }

        windows.removeAll()
        NSCursor.pop()

        let callback = completion
        completion = nil
        callback?(point)
    }
}

@MainActor
final class CoordinateOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class CoordinateOverlayView: NSView {
    var onSelect: ((CGPoint) -> Void)?

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.38).setFill()
        bounds.fill()
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }

        let screenPoint = window.convertPoint(
            toScreen: event.locationInWindow
        )

        onSelect?(screenPoint)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: PrecisionCursor.cursor)
    }
}
