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
