import AppKit

@MainActor
enum PrecisionCursor {
    static let cursor: NSCursor = {
        let size = NSSize(width: 56, height: 56)
        let image = NSImage(size: size)

        image.lockFocus()

        let center = NSPoint(x: 28, y: 28)

        func circle(_ radius: CGFloat, width: CGFloat) {
            let path = NSBezierPath(
                ovalIn: NSRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            )
            path.lineWidth = width
            path.stroke()
        }

        NSColor.black.withAlphaComponent(0.85).setStroke()
        circle(15, width: 4.5)

        NSColor.white.setStroke()
        circle(15, width: 1.5)

        NSColor.white.withAlphaComponent(0.8).setStroke()
        circle(7, width: 0.8)

        let segments: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (28, 2, 28, 11),
            (28, 45, 28, 54),
            (2, 28, 11, 28),
            (45, 28, 54, 28)
        ]

        for (x1, y1, x2, y2) in segments {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x1, y: y1))
            path.line(to: NSPoint(x: x2, y: y2))

            path.lineCapStyle = .round

            NSColor.black.setStroke()
            path.lineWidth = 4
            path.stroke()

            NSColor.white.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }

        NSColor(
            calibratedRed: 0.47,
            green: 0.78,
            blue: 1.0,
            alpha: 1
        ).setFill()

        NSBezierPath(
            ovalIn: NSRect(x: 26, y: 26, width: 4, height: 4)
        ).fill()

        image.unlockFocus()

        return NSCursor(
            image: image,
            hotSpot: center
        )
    }()
}
