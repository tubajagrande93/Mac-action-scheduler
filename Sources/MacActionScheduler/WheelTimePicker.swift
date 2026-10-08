import SwiftUI

struct WheelTimePicker: View {
    @Binding var hour: Int
    @Binding var minute: Int

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            InertialWheelColumn(
                value: $hour,
                count: 24,
                title: "HOURS"
            )

            Text(":")
                .font(AppTypography.font(.semibold, size: 21))
                .foregroundStyle(ChatGPTTheme.muted(scheme))
                .frame(width: 12)
                .padding(.bottom, 13)

            InertialWheelColumn(
                value: $minute,
                count: 60,
                title: "MINUTES"
            )
        }
        .frame(maxWidth: .infinity)
    }
}

private struct InertialWheelColumn: View {
    @Binding var value: Int

    let count: Int
    let title: String

    @Environment(\.colorScheme) private var scheme

    @State private var position: CGFloat
    @State private var dragStart: CGFloat?
    @State private var isDragging = false

    private let pitch: CGFloat = 23

    init(
        value: Binding<Int>,
        count: Int,
        title: String
    ) {
        self._value = value
        self.count = count
        self.title = title

        _position = State(
            initialValue: CGFloat(value.wrappedValue)
        )
    }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                SpinningCylinder(
                    position: position,
                    count: count,
                    scheme: scheme,
                    onSelect: selectNumber
                )

                selectionGuides
            }
            .frame(width: 110, height: 86)
            .contentShape(Rectangle())
            .clipped()
            .scaleEffect(isDragging ? 1.06 : 1.0)
            .animation(
                .easeOut(duration: 0.16),
                value: isDragging
            )
            .gesture(dragGesture)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(
                String(format: "%02d", value)
            )
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    advance(1)
                case .decrement:
                    advance(-1)
                @unknown default:
                    break
                }
            }

            Text(title)
                .font(AppTypography.font(.medium, size: 10))
                .foregroundStyle(
                    ChatGPTTheme.muted(scheme)
                )
        }
        .frame(width: 116)
    }

    private var selectionGuides: some View {
        VStack(spacing: 25) {
            Rectangle()
                .fill(ChatGPTTheme.divider(scheme))
                .frame(width: 76, height: 0.5)

            Rectangle()
                .fill(ChatGPTTheme.divider(scheme))
                .frame(width: 76, height: 0.5)
        }
        .allowsHitTesting(false)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { gesture in
                if dragStart == nil {
                    dragStart = position
                    isDragging = true
                }

                let start = dragStart ?? position
                let movement = gesture.translation.height

                // Direct finger/mouse tracking, no easing.
                var transaction = Transaction()
                transaction.disablesAnimations = true

                withTransaction(transaction) {
                    position = start - movement / pitch
                }
            }
            .onEnded { gesture in
                let start = dragStart ?? position

                let current = start
                    - gesture.translation.height / pitch

                let predicted = start
                    - gesture.predictedEndTranslation.height / pitch

                // Project the release velocity into a bounded spin.
                let rawMomentum = predicted - current

                let momentum = WheelMath.momentum(rawMomentum)

                let destination = (
                    current + momentum
                ).rounded()

                let travel = abs(destination - current)

                let duration = min(
                    1.12,
                    0.38 + Double(travel) * 0.065
                )

                dragStart = nil
                isDragging = false

                // Fast start, long deceleration, final snap.
                withAnimation(
                    .timingCurve(
                        0.10,
                        0.84,
                        0.18,
                        1.0,
                        duration: duration
                    )
                ) {
                    position = destination
                }

                value = wrapped(Int(destination))
            }
    }

    private func selectNumber(_ number: Int) {
        guard !isDragging else { return }

        let delta = nearestOffset(to: number)
        guard abs(delta) <= 2 else { return }

        let destination = (
            position + delta
        ).rounded()

        withAnimation(
            .spring(
                response: 0.38,
                dampingFraction: 0.78
            )
        ) {
            position = destination
        }

        value = wrapped(Int(destination))
    }

    private func advance(_ steps: Int) {
        let destination = position.rounded()
            + CGFloat(steps)

        withAnimation(
            .easeOut(duration: 0.24)
        ) {
            position = destination
        }

        value = wrapped(Int(destination))
    }

    private func nearestOffset(to number: Int) -> CGFloat {
        WheelMath.signedOffset(from: position, to: number, count: count)
    }

    private func wrapped(_ number: Int) -> Int {
        WheelMath.wrapped(number, count: count)
    }
}

// Animatable makes the cylinder interpolate its actual
// angular position on every frame, not jump between labels.
private struct SpinningCylinder: View, @MainActor Animatable {
    var position: CGFloat

    let count: Int
    let scheme: ColorScheme
    let onSelect: (Int) -> Void

    var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }

    var body: some View {
        ZStack {
            ForEach(visibleIndices, id: \.self) { index in
                cylinderRow(index)
            }
        }
        .frame(width: 110, height: 86)
        .clipped()
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 0.18),
                    .init(color: .white, location: 0.82),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var visibleIndices: [Int] {
        // Rows become fully transparent at ~3.45 rows from center (opacity
        // `1 - distance * 0.29` clamps to zero), so ±5 covers every row that
        // can be visible while skipping far-off rows the original loop kept
        // alive but painted fully transparent.
        let radius = 5
        return WheelMath.visibleIndices(
            center: WheelMath.wrapped(Int(position.rounded()), count: count),
            radius: radius,
            count: count
        )
    }

    private func cylinderRow(_ index: Int) -> some View {
        let delta = relativePosition(index)
        let distance = abs(delta)

        let angle = Double(delta) * 19.0
        let radians = angle * .pi / 180

        let yOffset = CGFloat(sin(radians) * 67)

        let scale = max(
            CGFloat(0.60),
            1 - distance * 0.12
        )

        let opacity = max(
            CGFloat(0),
            1 - distance * 0.29
        )

        return Text(String(format: "%02d", index))
            .font(AppTypography.font(.medium, size: 22))
            .monospacedDigit()
            .foregroundStyle(
                ChatGPTTheme.text(scheme)
                    .opacity(Double(opacity))
            )
            .scaleEffect(scale)
            .rotation3DEffect(
                .degrees(-angle),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.65
            )
            .offset(y: yOffset)
            .zIndex(Double(10 - distance))
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect(index)
            }
            .allowsHitTesting(distance <= 1.6)
    }

    private func relativePosition(_ index: Int) -> CGFloat {
        WheelMath.signedOffset(from: position, to: index, count: count)
    }
}
