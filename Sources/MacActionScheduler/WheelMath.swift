import CoreGraphics

/// Pure, deterministic math backing the inertial time wheel. Extracted so
/// wrap / shortest-offset / momentum / clipping rules are unit-testable
/// without needing SwiftUI or macOS automation permissions.
enum WheelMath {
    /// Wrap any integer into `0 ..< count` (always non-negative).
    static func wrapped(_ value: Int, count: Int) -> Int {
        ((value % count) + count) % count
    }

    /// Shortest signed offset (in rows) from a continuous `position` to the
    /// given integer `index`, in `[-count/2, +count/2]`. Ties resolve toward
    /// the negative side, matching the original cylinder math.
    static func signedOffset(
        from position: CGFloat,
        to index: Int,
        count: Int
    ) -> CGFloat {
        let circumference = CGFloat(count)
        let half = circumference / 2

        var delta = CGFloat(index) - position
        delta = (delta + half)
            .truncatingRemainder(dividingBy: circumference)

        if delta < 0 {
            delta += circumference
        }

        return delta - half
    }

    /// Project a raw flick velocity into a bounded inertial spin (in rows).
    static func momentum(_ raw: CGFloat) -> CGFloat {
        max(-12, min(12, raw)) * 0.82
    }

    /// Indices to instantiate for a bounded cylinder centered on `center`
    /// and spanning ±`radius` rows, wrapped into `0 ..< count`. Order follows
    /// the unwrapped offset sequence so it is stable across wraps.
    static func visibleIndices(
        center: Int,
        radius: Int,
        count: Int
    ) -> [Int] {
        var indices: [Int] = []
        indices.reserveCapacity(radius * 2 + 1)
        for offset in -radius...radius {
            indices.append(wrapped(center + offset, count: count))
        }
        return indices
    }
}
