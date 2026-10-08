import AppKit
import SwiftUI

private enum DateMode {
    case today
    case tomorrow
    case custom
}

struct ContentView: View {
    @ObservedObject var scheduler: ClickScheduler
    @State private var selectedPoint: CGPoint?
    @State private var pickerController: CoordinatePickerController?

    @State private var dateMode: DateMode = .today
    @State private var selectedDate = Date()
    @State private var showCalendar = false
    @State private var openTimePicker: String?

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

            // MARK: Header

            VStack(spacing: 3) {
                Text("Mac Action Scheduler")
                    .font(OpenAIFont.font(.semibold, size: 22))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Text("Simple native macOS automation.")
                    .font(OpenAIFont.font(.regular, size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 8)

            Divider()

            // MARK: Target

            VStack(spacing: 9) {
                Label("Target", systemImage: "scope")
                    .font(OpenAIFont.font(.semibold, size: 15))

                HStack(spacing: 18) {
                    coordinateValue("X", value: selectedPoint?.x)

                    Rectangle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 1, height: 18)

                    coordinateValue("Y", value: selectedPoint?.y)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(Color.primary.opacity(0.055))
                .clipShape(
                    RoundedRectangle(cornerRadius: 10)
                )

                Button {
                    selectPoint()
                } label: {
                    Label(
                        "Select Point",
                        systemImage: "cursorarrow.click.2"
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Color.primary.opacity(0.07))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)

            // MARK: Schedule

            VStack(spacing: 10) {
                Label("Schedule", systemImage: "clock")
                    .font(OpenAIFont.font(.semibold, size: 15))

                HStack(spacing: 7) {
                    datePill("Today", mode: .today)
                    datePill("Tomorrow", mode: .tomorrow)

                    datePill("Select date", mode: .custom)
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

                VStack(spacing: 0) {
                    Text("Time")
                        .font(OpenAIFont.font(.medium, size: 12))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .top, spacing: 8) {
                        timeMenu(
                            value: selectedHour,
                            title: "HOURS",
                            range: 0..<24
                        ) { value in
                            selectedHour = value
                        }

                        Text(":")
                            .font(OpenAIFont.font(.semibold, size: 22))
                            .foregroundStyle(.secondary)
                            .frame(width: 12, height: 34)

                        timeMenu(
                            value: selectedMinute,
                            title: "MINUTES",
                            range: 0..<60
                        ) { value in
                            selectedMinute = value
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .center
                    )
                    .padding(.top, 12)
                }
            }
            .padding(.top, 12)
            .frame(maxWidth: .infinity)

            Spacer(minLength: 8)

            // MARK: Action and Status

            VStack(spacing: 8) {
                Button {
                    scheduleClick()
                } label: {
                    Text("Schedule Click")
                        .font(OpenAIFont.font(.semibold, size: 13))
                        .foregroundStyle(
                            canSchedule ? Color.white : Color.primary
                        )
                        .frame(width: 174, height: 34)
                        .background(
                            canSchedule
                                ? Color.accentColor
                                : Color.primary.opacity(0.10)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canSchedule)
                .padding(.bottom, 16)

                VStack(spacing: 2) {
                    Text(scheduleStatus)
                        .font(OpenAIFont.font(.medium, size: 10))
                        .foregroundStyle(.secondary)

                    Text(schedulePreview)
                        .font(OpenAIFont.font(.medium, size: 12))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.primary.opacity(0.045))
                .clipShape(
                    RoundedRectangle(cornerRadius: 10)
                )
                .overlay(alignment: .trailing) {
                    if scheduler.canCancel {
                        Button {
                            cancelActiveSchedule()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 26, height: 26)
                                .background(Color.primary.opacity(0.07))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Cancel scheduled click")
                        .accessibilityLabel("Cancel scheduled click")
                        .padding(.trailing, 10)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .font(OpenAIFont.font(.regular, size: 14))
        .frame(
            width: 360,
            height: 450,
            alignment: .top
        )
    }

    // MARK: Coordinates

    private func coordinateValue(
        _ axis: String,
        value: CGFloat?
    ) -> some View {
        HStack(spacing: 7) {
            Text("\(axis):")
                .foregroundStyle(.secondary)

            Text(
                value.map {
                    String(Int($0.rounded()))
                } ?? "—"
            )
            .monospacedDigit()
            .font(OpenAIFont.font(.medium, size: 14))
            .frame(minWidth: 44)
        }
    }

    // MARK: Date Selection

    private func datePill(
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
            HStack(spacing: 4) {
                if active {
                    Image(systemName: "checkmark")
                        .font(.system(
                            size: 10,
                            weight: .bold
                        ))
                }

                Text(title)
                    .font(OpenAIFont.font(.medium, size: 12))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .foregroundStyle(
                active ? Color.white : Color.primary
            )
            .background(
                active
                    ? Color.accentColor
                    : Color.primary.opacity(0.055)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Hours / Minutes

    private func timeMenu(
        value: Int,
        title: String,
        range: Range<Int>,
        onSelect: @escaping (Int) -> Void
    ) -> some View {

        let isOpen = Binding<Bool>(
            get: {
                openTimePicker == title
            },
            set: { showing in
                if !showing {
                    openTimePicker = nil
                }
            }
        )

        return VStack(spacing: 4) {

            Button {
                openTimePicker = title
            } label: {
                HStack(spacing: 8) {
                    Text(String(format: "%02d", value))
                        .font(OpenAIFont.font(.medium, size: 22))
                        .monospacedDigit()

                    Image(systemName: "chevron.down")
                        .font(.system(
                            size: 10,
                            weight: .semibold
                        ))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 100, height: 34)
                .background(
                    Color.primary.opacity(0.055)
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .popover(
                isPresented: isOpen,
                arrowEdge: .bottom
            ) {
                ScrollView {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(
                                .fixed(40),
                                spacing: 6
                            ),
                            count: 6
                        ),
                        spacing: 6
                    ) {
                        ForEach(range, id: \.self) { number in
                            Button {
                                onSelect(number)
                                openTimePicker = nil
                            } label: {
                                Text(
                                    String(
                                        format: "%02d",
                                        number
                                    )
                                )
                                .font(
                                    OpenAIFont.font(
                                        .medium,
                                        size: 13
                                    )
                                )
                                .foregroundStyle(
                                    number == value
                                        ? Color.white
                                        : Color.primary
                                )
                                .frame(width: 40, height: 34)
                                .background(
                                    number == value
                                        ? Color.accentColor
                                        : Color.primary.opacity(0.055)
                                )
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 8
                                    )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                }
                .frame(
                    width: 302,
                    height: title == "HOURS" ? 184 : 242
                )
            }

            Text(title)
                .font(OpenAIFont.font(.medium, size: 10))
                .foregroundStyle(.secondary)
        }
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
        selectedPoint != nil && !scheduler.hasPendingClick &&
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

        guard let scheduledDateTime else {
            return "INVALID TIME"
        }

        return scheduledDateTime <= Date()
            ? "TIME HAS PASSED"
            : "NOT SCHEDULED"
    }

    private var schedulePreview: String {
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
