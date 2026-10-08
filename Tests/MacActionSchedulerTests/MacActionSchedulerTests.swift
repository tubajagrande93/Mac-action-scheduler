import Foundation
import Testing
@testable import MacActionScheduler

@Test func futureTimesAccepted() {
    let now = Date(timeIntervalSince1970: 1_000)
    #expect(ClickTimingPolicy.isInFuture(now.addingTimeInterval(60), now: now))
    #expect(!ClickTimingPolicy.isInFuture(now.addingTimeInterval(-1), now: now))
}

@Test func dueAndFreshWindow() {
    let fireDate = Date(timeIntervalSince1970: 1_000)
    #expect(ClickTimingPolicy.isDueAndFresh(fireDate, now: fireDate))
    #expect(ClickTimingPolicy.isDueAndFresh(fireDate, now: fireDate.addingTimeInterval(1)))
    #expect(!ClickTimingPolicy.isDueAndFresh(fireDate, now: fireDate.addingTimeInterval(10)))
    #expect(!ClickTimingPolicy.isDueAndFresh(fireDate, now: fireDate.addingTimeInterval(-5)))
}

@Test func lateWakeCannotClick() {
    let fireDate = Date(timeIntervalSince1970: 1_000)
    let wakeDate = fireDate.addingTimeInterval(3_600)
    #expect(!ClickTimingPolicy.isDueAndFresh(fireDate, now: wakeDate))
}

// MARK: - Timing policy boundaries

@Test func futureThresholdIsExclusive() {
    let now = Date(timeIntervalSince1970: 1_000)
    // Exactly 0.25s ahead is NOT "in the future" (strict `> 0.25`).
    #expect(!ClickTimingPolicy.isInFuture(now.addingTimeInterval(0.25), now: now))
    #expect(ClickTimingPolicy.isInFuture(now.addingTimeInterval(0.26), now: now))
    #expect(!ClickTimingPolicy.isInFuture(now.addingTimeInterval(0.24), now: now))
}

@Test func dueAndFreshBoundaries() {
    let fire = Date(timeIntervalSince1970: 1_000)
    // Fresh at the firing instant and up to exactly 3.0s late.
    #expect(ClickTimingPolicy.isDueAndFresh(fire, now: fire))
    #expect(ClickTimingPolicy.isDueAndFresh(fire, now: fire.addingTimeInterval(3.0)))
    // Just past the 3.0s tolerance is too late.
    #expect(!ClickTimingPolicy.isDueAndFresh(fire, now: fire.addingTimeInterval(3.001)))
    // Up to 0.5s early is tolerated; beyond that it is not yet due.
    #expect(ClickTimingPolicy.isDueAndFresh(fire, now: fire.addingTimeInterval(-0.5)))
    #expect(!ClickTimingPolicy.isDueAndFresh(fire, now: fire.addingTimeInterval(-0.501)))
}

// MARK: - Wheel math

@Test func wheelWrapHandlesNegativesAndOverflow() {
    #expect(WheelMath.wrapped(0, count: 24) == 0)
    #expect(WheelMath.wrapped(23, count: 24) == 23)
    #expect(WheelMath.wrapped(24, count: 24) == 0)
    #expect(WheelMath.wrapped(-1, count: 24) == 23)
    #expect(WheelMath.wrapped(-24, count: 24) == 0)
    #expect(WheelMath.wrapped(120, count: 60) == 0)
    #expect(WheelMath.wrapped(-1, count: 60) == 59)
}

@Test func signedOffsetFindsShortestRoute() {
    // Center is a zero offset.
    #expect(WheelMath.signedOffset(from: 5.0, to: 5, count: 24) == 0)
    #expect(WheelMath.signedOffset(from: 5.0, to: 6, count: 24) == 1)
    #expect(WheelMath.signedOffset(from: 5.0, to: 4, count: 24) == -1)

    // Hour wrap 23 -> 00 and 00 -> 23.
    #expect(WheelMath.signedOffset(from: 23.0, to: 0, count: 24) == 1)
    #expect(WheelMath.signedOffset(from: 0.0, to: 23, count: 24) == -1)

    // Minute wrap 59 -> 00 and 00 -> 59.
    #expect(WheelMath.signedOffset(from: 59.0, to: 0, count: 60) == 1)
    #expect(WheelMath.signedOffset(from: 0.0, to: 59, count: 60) == -1)

    // Continuous (unwrapped) position crossing a boundary.
    #expect(abs(WheelMath.signedOffset(from: 23.7, to: 0, count: 24) - 0.3) < 0.000_001)

    // Exact half-way tie resolves toward the negative side.
    #expect(WheelMath.signedOffset(from: 0.0, to: 12, count: 24) == -12)
}

@Test func momentumIsClampedAndDamped() {
    #expect(WheelMath.momentum(0) == 0)
    #expect(WheelMath.momentum(1) == 0.82)
    #expect(abs(WheelMath.momentum(100) - 9.84) < 0.000_001)
    #expect(abs(WheelMath.momentum(-100) + 9.84) < 0.000_001)
    #expect(abs(WheelMath.momentum(12) - 9.84) < 0.000_001)
    #expect(abs(WheelMath.momentum(-12) + 9.84) < 0.000_001)
}

@Test func visibleIndicesAreUniqueAndWrapped() {
    let aroundZero = WheelMath.visibleIndices(center: 0, radius: 5, count: 24)
    #expect(aroundZero.count == 11)
    #expect(Set(aroundZero).count == aroundZero.count)
    #expect(aroundZero.contains(0))
    #expect(aroundZero.contains(23))  // wrapped from -1
    #expect(aroundZero.contains(5))

    let aroundWrap = WheelMath.visibleIndices(center: 0, radius: 5, count: 60)
    #expect(aroundWrap.count == 11)
    #expect(Set(aroundWrap).count == aroundWrap.count)
    #expect(aroundWrap.contains(59))
    #expect(aroundWrap.contains(0))
    #expect(aroundWrap.contains(5))
}
