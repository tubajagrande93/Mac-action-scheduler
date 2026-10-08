import AppKit
import Combine
import Foundation

struct ClickJob {
    let id: UUID
    let point: CGPoint
    let fireDate: Date
}

enum ClickTimingPolicy {
    static let lateTolerance: TimeInterval = 3.0

    static func isInFuture(_ date: Date, now: Date) -> Bool {
        date.timeIntervalSince(now) > 0.25
    }

    static func isDueAndFresh(_ date: Date, now: Date) -> Bool {
        let lateness = now.timeIntervalSince(date)
        return lateness >= -0.5 && lateness <= lateTolerance
    }
}

@MainActor
final class ClickScheduler: NSObject, ObservableObject {
    enum State {
        case idle
        case scheduled
        case sending
        case sent
        case cancelled
        case missed
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var activeJob: ClickJob?
    @Published private(set) var lastJob: ClickJob?

    private var timer: Timer?

    var hasPendingClick: Bool {
        activeJob != nil
    }

    var canCancel: Bool {
        activeJob != nil && {
            if case .scheduled = state { return true }
            return false
        }()
    }

    @discardableResult
    func schedule(point: CGPoint, at date: Date) -> Bool {
        guard activeJob == nil else { return false }

        guard ClickTimingPolicy.isInFuture(date, now: Date()) else {
            lastJob = nil
            state = .failed("Selected time has passed")
            return false
        }

        guard MouseClickService.isOnConnectedScreen(point) else {
            lastJob = nil
            state = .failed("Target is outside connected displays")
            return false
        }

        guard AccessibilityPermissionService.shared.requireForScheduling() else {
            lastJob = nil
            state = .failed("Accessibility permission required")
            return false
        }

        let job = ClickJob(id: UUID(), point: point, fireDate: date)
        let newTimer = Timer(
            fireAt: date,
            interval: 0,
            target: self,
            selector: #selector(timerFired(_:)),
            userInfo: nil,
            repeats: false
        )

        timer = newTimer
        activeJob = job
        lastJob = job
        state = .scheduled
        RunLoop.main.add(newTimer, forMode: .common)
        return true
    }

    func cancel() {
        guard canCancel else { return }
        timer?.invalidate()
        timer = nil
        activeJob = nil
        state = .cancelled
    }

    @objc private func timerFired(_ firedTimer: Timer) {
        guard timer === firedTimer, let job = activeJob else { return }
        timer?.invalidate()
        timer = nil

        guard ClickTimingPolicy.isDueAndFresh(job.fireDate, now: Date()) else {
            finish(.missed)
            return
        }

        guard AccessibilityPermissionService.shared.canExecuteClick() else {
            finish(.failed("Accessibility permission was revoked"))
            return
        }

        guard MouseClickService.isOnConnectedScreen(job.point) else {
            finish(.failed("Target display is unavailable"))
            return
        }

        state = .sending

        // Remove our own window from the target point and restore focus to
        // the underlying app before sending the mouse event.
        NSApp.hide(nil)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard let self, self.activeJob?.id == job.id else { return }

            guard ClickTimingPolicy.isDueAndFresh(job.fireDate, now: Date()) else {
                self.finish(.missed)
                return
            }

            guard AccessibilityPermissionService.shared.canExecuteClick() else {
                self.finish(.failed("Accessibility permission was revoked"))
                return
            }

            guard MouseClickService.isOnConnectedScreen(job.point) else {
                self.finish(.failed("Target display is unavailable"))
                return
            }

            let posted = await MouseClickService.postLeftClick(at: job.point)
            self.finish(
                posted ? .sent : .failed("Could not create mouse events")
            )
        }
    }

    private func finish(_ result: State) {
        guard let job = activeJob else { return }
        lastJob = job
        activeJob = nil
        timer?.invalidate()
        timer = nil
        state = result
    }
}
