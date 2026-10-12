import SwiftUI
import SwiftData
import UserNotifications

/// The scaffold lives here. Everything else in the app is derived from it, so
/// this is the only screen that ever needs correcting when life changes shape.
struct SetupView: View {
    @Query private var schedules: [DaySchedule]
    @Environment(\.modelContext) private var modelContext

    @State private var isAuthorized = false

    private var ordered: [DaySchedule] {
        Weekday.orderedMondayFirst.compactMap { weekday in
            schedules.first { $0.weekday == weekday }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ordered) { schedule in
                        NavigationLink {
                            DayScheduleEditor(schedule: schedule)
                        } label: {
                            DayScheduleRow(schedule: schedule)
                        }
                    }
                } header: {
                    Text("Your week")
                } footer: {
                    Text("Windows, budgets and reminders are all worked out from these times. Change a day here and the whole app follows.")
                }

                Section {
                    if !isAuthorized {
                        Button {
                            Task { @MainActor in
                                isAuthorized = await NotificationScheduler.requestAuthorization()
                                if isAuthorized {
                                    await NotificationScheduler.reschedule(schedules: ordered)
                                }
                            }
                        } label: {
                            Label("Turn on reminders", systemImage: "bell.badge")
                        }
                    }

                    ForEach(NotificationKind.allCases) { kind in
                        NotificationToggleRow(kind: kind) {
                            Task { @MainActor in
                                await NotificationScheduler.reschedule(schedules: ordered)
                            }
                        }
                        .disabled(!isAuthorized)
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text(isAuthorized
                         ? "Each reminder is pinned to a point in your day rather than a clock time, so Friday's earlier knock-off needs no separate setting."
                         : "Reminders are off. Turn them on to get the morning run-through and the departure warning.")
                }

                Section {
                    LabeledContent("Stored", value: "On this iPhone only")
                    LabeledContent("Week starts", value: "Monday")
                } header: {
                    Text("About")
                } footer: {
                    Text("Yetsa — Sesotho for \"to do\". No account, no network, nothing leaves the phone.")
                }
            }
            .navigationTitle("Setup")
            .task {
                isAuthorized = await NotificationScheduler.authorizationStatus() == .authorized
                if isAuthorized {
                    await NotificationScheduler.reschedule(schedules: ordered)
                }
            }
        }
    }
}

private struct DayScheduleRow: View {
    let schedule: DaySchedule

    var body: some View {
        HStack {
            Text(schedule.name)

            Spacer()

            if schedule.isWorkday {
                Text("\(Clock.clockString(minutes: schedule.leaveHome, calendar: Clock.calendar)) – \(Clock.clockString(minutes: schedule.knockOff, calendar: Clock.calendar))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Text("Off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DayScheduleEditor: View {
    @Bindable var schedule: DaySchedule

    private var calendar: Calendar { Clock.calendar }

    var body: some View {
        List {
            Section {
                Toggle("A working day", isOn: $schedule.isWorkday)
            } footer: {
                Text(schedule.isWorkday
                     ? "Work blocks, the commute and the lunch window are all laid out."
                     : "The day splits into morning, afternoon and evening instead.")
            }

            Section("Getting up") {
                timeRow("Alarm", \.wake)
                timeRow("Out of bed", \.outOfBed)
            }

            if schedule.isWorkday {
                Section {
                    timeRow("Leave home", \.leaveHome)
                    timeRow("At work", \.arriveWork)
                } header: {
                    Text("Getting there")
                } footer: {
                    Text("The trip home is assumed to take the same \(Clock.durationString(schedule.commuteMinutes)).")
                }

                Section("At work") {
                    timeRow("Lunch", \.lunch)
                    Stepper(value: $schedule.lunchLength, in: 15...120, step: 5) {
                        HStack {
                            Text("Lunch lasts")
                            Spacer()
                            Text(Clock.durationString(schedule.lunchLength))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    timeRow("Knock off", \.knockOff)
                }
            } else {
                Section("Shape of the day") {
                    timeRow("Midday break", \.lunch)
                    timeRow("Evening starts", \.eveningStarts)
                }
            }

            Section {
                timeRow("Bed", \.bedtime)
            } footer: {
                summary
            }
        }
        .navigationTitle(schedule.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            Task { @MainActor in
                await NotificationScheduler.reschedule(schedules: [schedule])
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            if schedule.isWorkday {
                Text("Morning window: \(Clock.durationString(schedule.morningCapacity)) between getting up and the door.")
                Text("Alarm buys you \(Clock.durationString(schedule.snoozeBuffer)) before you have to move.")
                Text("Evening window: \(Clock.durationString(max(0, schedule.bedtime - schedule.homeAgain))) from walking in to lights out.")
            } else {
                Text("A free day: \(Clock.durationString(max(0, schedule.bedtime - schedule.outOfBed))) from getting up to lights out.")
            }
        }
        .font(.caption2)
    }

    private func timeRow(_ label: String, _ keyPath: ReferenceWritableKeyPath<DaySchedule, Int>) -> some View {
        DatePicker(
            label,
            selection: binding(keyPath),
            displayedComponents: .hourAndMinute
        )
    }

    /// Bridges minutes-from-midnight to the date a picker wants.
    private func binding(_ keyPath: ReferenceWritableKeyPath<DaySchedule, Int>) -> Binding<Date> {
        Binding(
            get: { Clock.date(on: .now, minutes: schedule[keyPath: keyPath], calendar: calendar) },
            set: { schedule[keyPath: keyPath] = Clock.minutesFromMidnight($0, calendar: calendar) }
        )
    }
}

private struct NotificationToggleRow: View {
    let kind: NotificationKind
    let onChange: () -> Void

    @AppStorage private var isOn: Bool

    init(kind: NotificationKind, onChange: @escaping () -> Void) {
        self.kind = kind
        self.onChange = onChange
        _isOn = AppStorage(wrappedValue: true, kind.defaultsKey)
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Label(kind.label, systemImage: kind.symbol)
                Text(kind.blurb)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: isOn) { _, _ in onChange() }
    }
}
