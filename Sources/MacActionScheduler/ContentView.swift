import AppKit
import SwiftUI

private enum DateMode {
    case today
    case tomorrow
    case custom
}

struct ContentView: View {
    @ObservedObject var scheduler: ClickScheduler
    @ObservedObject private var permissions = AccessibilityPermissionService.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedPoint: CGPoint?
    @State private var pickerController: CoordinatePickerController?

    @State private var dateMode: DateMode = .today
    @State private var selectedDate = Date()
    @State private var showCalendar = false

    @State private var selectedHour: Int
    @State private var selectedMinute: Int

    init(scheduler: ClickScheduler) {
        self.scheduler = scheduler

        let initial = Date().addingTimeInterval(300)
        let calendar = Calendar.current

        _selectedHour = State(
            initialValue: calendar.component(.hour, from: initial)
        )
        _selectedMinute = State(
            initialValue: calendar.component(.minute, from: initial)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 3) {
                Text("Mac Action Scheduler")
                    .font(AppTypography.font(.semibold, size: 22))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .foregroundStyle(ChatGPTTheme.text(colorScheme))

                Text("Simple native macOS automation.")
                    .font(AppTypography.font(.regular, size: 12))
                    .foregroundStyle(ChatGPTTheme.muted(colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 8)

            Divider()
                .overlay(ChatGPTTheme.divider(colorScheme))

            // Target
            VStack(spacing: 10) {
                Label("Target", systemImage: "scope")
                    .font(AppTypography.font(.semibold, size: 15))
                    .foregroundStyle(ChatGPTTheme.text(colorScheme))

                HStack(spacing: 20) {
                    coordinateValue("X", value: selectedPoint?.x)

                    Rectangle()
                        .fill(ChatGPTTheme.divider(colorScheme))
                        .frame(width: 1, height: 16)

                    coordinateValue("Y", value: selectedPoint?.y)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 26)

                Button {
                    selectPoint()
                } label: {
                    Label("Select Point", systemImage: "cursorarrow.click")
                        .font(AppTypography.font(.medium, size: 15))
                        .foregroundStyle(ChatGPTTheme.text(colorScheme))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)

            // Schedule
            VStack(spacing: 10) {
                Label("Schedule", systemImage: "clock")
                    .font(AppTypography.font(.semibold, size: 15))
                    .foregroundStyle(ChatGPTTheme.text(colorScheme))

                HStack(spacing: 16) {
                    dateTab("Today", mode: .today)
                    dateTab("Tomorrow", mode: .tomorrow)

                    dateTab("Select date", mode: .custom)
                        .popover(
                            isPresented: $showCalendar,
                            arrowEdge: .bottom
                        ) {
                            DatePicker(
                                "Choose date",
                                selection: $selectedDate,
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .padding(14)
                            .onChange(of: selectedDate) { _, _ in
                                showCalendar = false
                            }
                        }
                }

                Text("Time")
                    .font(AppTypography.font(.medium, size: 12))
                    .foregroundStyle(ChatGPTTheme.muted(colorScheme))
                    .padding(.top, 2)

                WheelTimePicker(
                    hour: $selectedHour,
                    minute: $selectedMinute
                )
                .padding(.top, -2)
            }
            .padding(.top, 12)

            Spacer(minLength: 6)

            // Action button
            Button {
                if permissions.refreshSilently() {
                    scheduleClick()
                } else {
                    permissions.openAccessibilitySettings()
                }
            } label: {
                Text(permissions.snapshot.ready ? "Schedule Click" : "Open Permissions")
                    .font(AppTypography.font(.semibold, size: 13))
                    .foregroundStyle(
                        (permissions.snapshot.ready && !canSchedule)
                        ? ChatGPTTheme.disabledText(colorScheme)
                        : ChatGPTTheme.actionText(colorScheme)
                    )
                    .frame(width: 182, height: 34)
                    .background(
                        (permissions.snapshot.ready && !canSchedule)
                        ? ChatGPTTheme.disabledSurface(colorScheme)
                        : ChatGPTTheme.actionSurface(colorScheme)
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(permissions.snapshot.ready && !canSchedule)

            Spacer(minLength: 10)

            // Status
            VStack(spacing: 2) {
                Text(scheduleStatus)
                    .font(AppTypography.font(.medium, size: 10))
                    .foregroundStyle(ChatGPTTheme.muted(colorScheme))

                Text(schedulePreview)
                    .font(AppTypography.font(.medium, size: 12))
                    .foregroundStyle(ChatGPTTheme.text(colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .overlay(alignment: .trailing) {
                if scheduler.canCancel {
                    Button {
                        cancelActiveSchedule()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(ChatGPTTheme.muted(colorScheme))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 10)
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .font(AppTypography.font(.regular, size: 14))
        .foregroundStyle(ChatGPTTheme.text(colorScheme))
        .frame(width: 360, height: 450, alignment: .top)
        .background(ChatGPTTheme.page(colorScheme))
    }

    // MARK: Coordinates

    private func coordinateValue(
        _ axis: String,
        value: CGFloat?
    ) -> some View {
        HStack(spacing: 6) {
            Text("\(axis):")
                .foregroundStyle(ChatGPTTheme.muted(colorScheme))

            Text(
                value.map {
                    String(Int($0.rounded()))
                } ?? "—"
            )
            .monospacedDigit()
            .font(AppTypography.font(.medium, size: 14))
            .foregroundStyle(ChatGPTTheme.text(colorScheme))
            .frame(minWidth: 42)
        }
    }

    // MARK: Date tabs

    private func dateTab(
        _ title: String,
        mode: DateMode
    ) -> some View {
        let active = dateMode == mode

        return Button {
            dateMode = mode

            switch mode {
            case .today:
                selectedDate = Date()
                showCalendar = false

            case .tomorrow:
                selectedDate = Calendar.current.date(
                    byAdding: .day,
                    value: 1,
                    to: Date()
                ) ?? Date()
                showCalendar = false

            case .custom:
                showCalendar = true
            }
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    if active {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                    }

                    Text(title)
                        .font(AppTypography.font(.medium, size: 12))
                        .lineLimit(1)
                }
                .foregroundStyle(
                    active
                    ? ChatGPTTheme.selectedText(colorScheme)
                    : ChatGPTTheme.muted(colorScheme)
                )

                Rectangle()
                    .fill(
                        active
                        ? ChatGPTTheme.selectedUnderline(colorScheme)
                        : Color.clear
                    )
                    .frame(height: 1.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 24)
        }
        .buttonStyle(.plain)
    }

    // MARK: Date Calculation

    private var effectiveDate: Date {
        switch dateMode {
        case .today:
            return Date()

        case .tomorrow:
            return Calendar.current.date(
                byAdding: .day,
                value: 1,
                to: Date()
            ) ?? Date()

        case .custom:
            return selectedDate
        }
    }

    private var scheduledDateTime: Date? {
        Calendar.current.date(
            bySettingHour: selectedHour,
            minute: selectedMinute,
            second: 0,
            of: effectiveDate
        )
    }

    private var canSchedule: Bool {
        selectedPoint != nil &&
        !scheduler.hasPendingClick &&
        (scheduledDateTime.map { ClickTimingPolicy.isInFuture($0, now: Date()) } ?? false)
    }

    private var scheduleStatus: String {
        switch scheduler.state {
        case .scheduled: return "SCHEDULED"
        case .sending: return "SENDING CLICK"
        case .sent: return "CLICK SENT"
        case .cancelled: return "CANCELLED"
        case .missed: return "MISSED (MAC WAS ASLEEP)"
        case .failed: return "FAILED"
        case .idle: break
        }

        if !permissions.snapshot.ready {
            return "PERMISSIONS REQUIRED"
        }

        guard let scheduledDateTime else {
            return "INVALID TIME"
        }

        return scheduledDateTime <= Date()
            ? "TIME HAS PASSED"
            : "NOT SCHEDULED"
    }

    private var schedulePreview: String {
        if case .idle = scheduler.state, !permissions.snapshot.ready {
            return permissions.snapshot.missingDescription
        }

        if let job = scheduler.lastJob, shouldShowLastJob {
            let calendar = Calendar.current
            let date = job.fireDate

            let label: String
            if calendar.isDateInToday(date) {
                label = "Today"
            } else if calendar.isDateInTomorrow(date) {
                label = "Tomorrow"
            } else {
                label = date.formatted(
                    .dateTime.day().month(.abbreviated).year()
                )
            }

            let time = String(
                format: "%02d:%02d",
                calendar.component(.hour, from: date),
                calendar.component(.minute, from: date)
            )

            return "\(label) · \(time)"
        }

        let time = String(
            format: "%02d:%02d",
            selectedHour,
            selectedMinute
        )

        switch dateMode {
        case .today:
            return "Today · \(time)"

        case .tomorrow:
            return "Tomorrow · \(time)"

        case .custom:
            let date = selectedDate.formatted(
                .dateTime.day().month(.abbreviated).year()
            )
            return "\(date) · \(time)"
        }
    }

    // MARK: Schedule Engine

    private var shouldShowLastJob: Bool {
        if case .idle = scheduler.state { return false }
        return true
    }

    private func scheduleClick() {
        guard let point = selectedPoint, let time = scheduledDateTime else { return }
        _ = scheduler.schedule(point: point, at: time)
    }

    private func cancelActiveSchedule() {
        scheduler.cancel()
    }

    // MARK: Coordinate Picker

    private func selectPoint() {
        guard pickerController == nil else { return }

        let mainWindow = NSApp.keyWindow
        let controller = CoordinatePickerController()

        pickerController = controller
        mainWindow?.orderOut(nil)

        controller.start { point in
            if let point {
                selectedPoint = point
            }

            pickerController = nil

            mainWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
