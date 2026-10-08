import SwiftUI
import AppKit

private enum ScheduleDayChoice: String, CaseIterable {
    case today
    case tomorrow
    case custom

    var title: String {
        switch self {
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .custom: return "Select date"
        }
    }
}

struct ContentView: View {
    @ObservedObject var scheduler: ClickScheduler
    @ObservedObject private var permissions = AccessibilityPermissionService.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedPoint: CGPoint?
    @State private var pickerController: CoordinatePickerController?

    @State private var selectedDay: ScheduleDayChoice = .today
    @State private var customDate = Date()

    @State private var hour: Int
    @State private var minute: Int

    init(scheduler: ClickScheduler) {
        self.scheduler = scheduler

        let initial = Date().addingTimeInterval(300)
        let calendar = Calendar.current

        _hour = State(initialValue: calendar.component(.hour, from: initial))
        _minute = State(initialValue: calendar.component(.minute, from: initial))
    }

    var body: some View {
        ZStack {
            ChatGPTTheme.page(colorScheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    headerSection
                    divider
                    targetCard
                    scheduleCard
                    statusCard
                }
                .padding(30)
                .frame(maxWidth: 760)
            }
        }
        .background(ChatGPTTheme.window(colorScheme))
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("Mac Action Scheduler")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(ChatGPTTheme.text(colorScheme))

            Text("Simple native macOS automation.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(ChatGPTTheme.muted(colorScheme))
        }
        .padding(.top, 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(ChatGPTTheme.divider(colorScheme))
            .frame(height: 1)
    }

    private var targetCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionTitle(icon: "scope", text: "Target")

                HStack(spacing: 14) {
                    coordinateField(label: "X:", value: selectedPoint.map { Int($0.x) })
                    coordinateField(label: "Y:", value: selectedPoint.map { Int($0.y) })
                }

                Button {
                    selectPoint()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "cursorarrow.rays")
                            .font(.system(size: 19, weight: .medium))
                        Text("Select Point")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .foregroundStyle(ChatGPTTheme.secondaryText(colorScheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(ChatGPTTheme.secondaryFill(colorScheme))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(ChatGPTTheme.border(colorScheme), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var scheduleCard: some View {
        card {
            VStack(alignment: .leading, spacing: 20) {
                sectionTitle(icon: "clock", text: "Schedule")

                HStack(spacing: 12) {
                    dayPill(.today)
                    dayPill(.tomorrow)
                    dayPill(.custom)
                }

                if selectedDay == .custom {
                    DatePicker(
                        "Date",
                        selection: $customDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                    .foregroundStyle(ChatGPTTheme.text(colorScheme))
                }

                Rectangle()
                    .fill(ChatGPTTheme.divider(colorScheme))
                    .frame(height: 1)

                Text("Time")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(ChatGPTTheme.muted(colorScheme))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)

                HStack(alignment: .center, spacing: 18) {
                    timePicker(
                        value: $hour,
                        range: 0..<24,
                        label: "HOURS"
                    )

                    Text(":")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(ChatGPTTheme.muted(colorScheme))
                        .padding(.top, -8)

                    timePicker(
                        value: $minute,
                        range: 0..<60,
                        label: "MINUTES"
                    )
                }
                .frame(maxWidth: .infinity)

                Button {
                    if permissions.refreshSilently() {
                        if permissions.snapshot.ready {
                            scheduleClick()
                        }
                    } else {
                        permissions.openAccessibilitySettings()
                    }
                } label: {
                    Text(permissions.snapshot.ready ? "Schedule Click" : "Open Permissions")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            canSchedule || !permissions.snapshot.ready
                            ? ChatGPTTheme.primaryText(colorScheme)
                            : ChatGPTTheme.muted(colorScheme)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    canSchedule || !permissions.snapshot.ready
                                    ? ChatGPTTheme.primaryFill(colorScheme)
                                    : ChatGPTTheme.secondaryFill(colorScheme)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(ChatGPTTheme.border(colorScheme), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(permissions.snapshot.ready && !canSchedule)
            }
        }
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            VStack(spacing: 6) {
                Text(scheduleStatusTitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ChatGPTTheme.muted(colorScheme))
                    .textCase(.uppercase)

                Text(scheduleStatusSubtitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ChatGPTTheme.text(colorScheme))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            if scheduler.canCancel {
                Button {
                    cancelActiveSchedule()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ChatGPTTheme.muted(colorScheme))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(ChatGPTTheme.secondaryFill(colorScheme))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ChatGPTTheme.card(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(ChatGPTTheme.border(colorScheme), lineWidth: 1)
                )
        )
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(ChatGPTTheme.card(colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(ChatGPTTheme.border(colorScheme), lineWidth: 1)
                    )
            )
    }

    private func sectionTitle(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(ChatGPTTheme.text(colorScheme))

            Text(text)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ChatGPTTheme.text(colorScheme))
        }
    }

    private func coordinateField(label: String, value: Int?) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(ChatGPTTheme.muted(colorScheme))

            Text(value.map(String.init) ?? "—")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ChatGPTTheme.text(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 68)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ChatGPTTheme.softField(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(ChatGPTTheme.border(colorScheme), lineWidth: 1)
                )
        )
    }

    private func dayPill(_ day: ScheduleDayChoice) -> some View {
        let isSelected = selectedDay == day

        return Button {
            selectedDay = day
        } label: {
            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                }

                Text(day.title)
                    .font(.system(size: 17, weight: .medium))
            }
            .foregroundStyle(
                isSelected
                ? ChatGPTTheme.selectedPillText(colorScheme)
                : ChatGPTTheme.secondaryText(colorScheme)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        isSelected
                        ? ChatGPTTheme.selectedPillFill(colorScheme)
                        : ChatGPTTheme.secondaryFill(colorScheme)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(ChatGPTTheme.border(colorScheme), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func timePicker(
        value: Binding<Int>,
        range: Range<Int>,
        label: String
    ) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Picker("", selection: value) {
                    ForEach(Array(range), id: \.self) { item in
                        Text(String(format: "%02d", item)).tag(item)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 150, height: 58)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ChatGPTTheme.text(colorScheme))
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(ChatGPTTheme.softField(colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(ChatGPTTheme.border(colorScheme), lineWidth: 1)
                        )
                )
            }

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ChatGPTTheme.muted(colorScheme))
                .tracking(0.5)
        }
    }

    private var scheduledDateTime: Date? {
        let calendar = Calendar.current
        let baseDate: Date

        switch selectedDay {
        case .today:
            baseDate = Date()
        case .tomorrow:
            baseDate = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        case .custom:
            baseDate = customDate
        }

        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = hour
        components.minute = minute
        components.second = 0

        return calendar.date(from: components)
    }

    private var canSchedule: Bool {
        guard let selectedPoint, let scheduledDateTime else { return false }
        return permissions.snapshot.ready &&
        !scheduler.hasPendingClick &&
        ClickTimingPolicy.isInFuture(scheduledDateTime, now: Date()) &&
        MouseClickService.isOnConnectedScreen(selectedPoint)
    }

    private var scheduleStatusTitle: String {
        if !permissions.snapshot.ready {
            return "PERMISSIONS REQUIRED"
        }

        switch scheduler.state {
        case .idle:
            return "READY"
        case .scheduled:
            return "SCHEDULED"
        case .sending:
            return "SENDING CLICK"
        case .sent:
            return "CLICK SENT"
        case .cancelled:
            return "CANCELLED"
        case .missed:
            return "MISSED"
        case .failed:
            return "FAILED"
        }
    }

    private var scheduleStatusSubtitle: String {
        if !permissions.snapshot.ready {
            return permissions.snapshot.missingDescription
        }

        switch scheduler.state {
        case .failed(let message):
            return message
        case .idle:
            return formattedPreview(for: scheduledDateTime)
        default:
            return formattedPreview(for: scheduler.lastJob?.fireDate ?? scheduledDateTime)
        }
    }

    private func formattedPreview(for date: Date?) -> String {
        guard let date else { return "Choose a time" }

        let calendar = Calendar.current
        let time = String(
            format: "%02d:%02d",
            calendar.component(.hour, from: date),
            calendar.component(.minute, from: date)
        )

        if calendar.isDateInToday(date) { return "Today · \(time)" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow · \(time)" }

        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy · HH:mm"
        return formatter.string(from: date)
    }

    private func scheduleClick() {
        guard let point = selectedPoint, let date = scheduledDateTime else { return }
        _ = scheduler.schedule(point: point, at: date)
    }

    private func cancelActiveSchedule() {
        scheduler.cancel()
    }

    private func selectPoint() {
        guard pickerController == nil else { return }

        let mainWindow = NSApp.keyWindow ?? NSApp.mainWindow
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
