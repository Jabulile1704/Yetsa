import SwiftUI
import SwiftData

/// One screen, big targets, one number. Built to be used standing up with a
/// towel in one hand, so nothing here needs reading carefully.
struct MorningRunView: View {
    @Query(sort: \TaskItem.createdAt) private var tasks: [TaskItem]
    @Query private var schedules: [DaySchedule]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var now = Date.now

    private var calendar: Calendar { Clock.calendar }

    private var run: MorningRun? {
        MorningRun.upcoming(from: now, schedules: schedules, tasks: tasks)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if let run {
                    content(run)
                } else {
                    ContentUnavailableView(
                        "No morning run today",
                        systemImage: "sunrise",
                        description: Text("Mark a few weekday tasks as part of the morning run and they will line up here.")
                    )
                }
            }
            .navigationTitle("Morning run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                while !Task.isCancelled {
                    now = .now
                    try? await Task.sleep(for: .seconds(15))
                }
            }
        }
    }

    /// The morning window on the run's own day.
    private func windowMinutes(_ run: MorningRun) -> Int {
        let schedule = PlanBuilder.schedule(for: run.day, in: schedules, calendar: calendar)
        return schedule.morningCapacity
    }

    private func content(_ run: MorningRun) -> some View {
        let minutesLeft = max(0, run.minutesToDeparture(from: now))
        let slack = run.slack(from: now)

        // Within three hours the countdown is the point. Further out it is
        // just a review of the sequence, so the racing numbers go away.
        let isImminent = minutesLeft <= 180

        return ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    if !run.isToday {
                        Text(run.dayLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 2)
                    }

                    Text(isImminent ? "\(minutesLeft)" : Clock.durationString(minutesLeft))
                        .font(.system(size: isImminent ? 76 : 54, weight: .bold))
                        .tracking(-2)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(minutesLeft)))

                    Text(isImminent
                         ? (minutesLeft == 1 ? "minute until you leave" : "minutes until you leave")
                         : "until you leave at \(Clock.clockString(run.departure))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if isImminent {
                        Text(run.status(from: now))
                            .font(.headline)
                            // Behind is the only state worth colouring. Being
                            // on time is the normal case, not an achievement.
                            .foregroundStyle(slack < 0 ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                            .padding(.top, 6)
                    } else {
                        Text("\(Clock.durationString(run.plannedMinutes)) of steps in a \(Clock.durationString(windowMinutes(run))) window")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                    }
                }
                .padding(.top, 10)

                VStack(spacing: 10) {
                    ForEach(Array(run.tasks.enumerated()), id: \.element.id) { index, task in
                        StepRow(task: task, day: run.day, number: index + 1, isTickable: run.isToday)
                    }
                }

                if run.isToday {
                    Text("\(Clock.durationString(run.remainingMinutes)) of work left, \(Clock.durationString(minutesLeft)) of clock.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                } else {
                    Text("Ticking opens on the day itself.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
            .animation(.snappy, value: run.doneCount)
        }
        .scrollIndicators(.hidden)
    }
}

private struct StepRow: View {
    let task: TaskItem
    let day: Date
    let number: Int
    var isTickable: Bool = true

    @Environment(\.colorScheme) private var scheme

    private var calendar: Calendar { Clock.calendar }
    private var isDone: Bool { RecurrenceEngine.isSettled(task, on: day, calendar: calendar) }

    var body: some View {
        Button {
            withAnimation(.snappy) {
                RecurrenceEngine.toggle(task, on: day, calendar: calendar)
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    if isDone {
                        Circle().fill(.primary)
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color(.systemBackground))
                    } else {
                        Circle().strokeBorder(Color(.systemGray3), lineWidth: 1.6)
                        Text("\(number)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 34, height: 34)

                Text(task.title)
                    .font(.body.weight(.medium))
                    .strikethrough(isDone, color: .secondary)
                    .foregroundStyle(isDone ? .secondary : .primary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 4)

                Text(Clock.shortDuration(task.estimateMinutes))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!isTickable)
    }
}
