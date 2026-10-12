import SwiftUI
import SwiftData

struct TaskFormView: View {
    let editing: TaskItem?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var notes: String
    @State private var estimate: Int
    @State private var context: TaskContext
    @State private var preferredWindow: WindowKind?
    @State private var recurrence: RecurrenceKind
    @State private var weekday: Int
    @State private var interval: Int
    @State private var anchor: Date
    @State private var quota: Int
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var project: String
    @State private var batchTotal: Int
    @State private var isMorningRun: Bool
    @State private var showingDeleteConfirmation = false

    init(editing: TaskItem?) {
        self.editing = editing
        let calendar = Clock.calendar

        _title = State(initialValue: editing?.title ?? "")
        _notes = State(initialValue: editing?.notes ?? "")
        _estimate = State(initialValue: editing?.estimateMinutes ?? 15)
        _context = State(initialValue: editing?.context ?? .home)
        _preferredWindow = State(initialValue: editing?.preferredWindow)
        _recurrence = State(initialValue: editing?.recurrence ?? .once)
        _weekday = State(initialValue: {
            let stored = editing?.recurrenceWeekday ?? 0
            return stored == 0 ? calendar.component(.weekday, from: .now) : stored
        }())
        _interval = State(initialValue: editing?.recurrenceInterval ?? 2)
        _anchor = State(initialValue: editing?.recurrenceAnchor ?? calendar.startOfDay(for: .now))
        _quota = State(initialValue: editing?.quotaPerWeek ?? 2)
        _dueDate = State(initialValue: editing?.dueDate ?? calendar.startOfDay(for: .now))
        _hasDueDate = State(initialValue: editing?.dueDate != nil || editing == nil)
        _project = State(initialValue: editing?.project ?? "")
        _batchTotal = State(initialValue: editing?.batchTotal ?? 0)
        _isMorningRun = State(initialValue: editing?.isMorningRun ?? false)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What needs doing", text: $title, axis: .vertical)

                    Stepper(value: $estimate, in: 5...480, step: 5) {
                        HStack {
                            Text("Takes")
                            Spacer()
                            Text(Clock.durationString(estimate))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Every task carries an estimate so a window can tell you whether the day actually fits.")
                }

                Section("Where") {
                    Picker("Context", selection: $context) {
                        ForEach(TaskContext.allCases) { option in
                            Label(option.label, systemImage: option.symbol).tag(option)
                        }
                    }

                    Picker("Window", selection: $preferredWindow) {
                        Text("Wherever it fits").tag(WindowKind?.none)
                        ForEach(WindowKind.allCases) { kind in
                            Text(kind.label).tag(WindowKind?.some(kind))
                        }
                    }
                }

                Section {
                    Picker("Repeats", selection: $recurrence) {
                        ForEach(RecurrenceKind.allCases) { kind in
                            Label(kind.label, systemImage: kind.symbol).tag(kind)
                        }
                    }

                    if recurrence.needsWeekday {
                        Picker("On", selection: $weekday) {
                            ForEach(Weekday.orderedMondayFirst, id: \.self) { day in
                                Text(Weekday.name(day)).tag(day)
                            }
                        }
                    }

                    if recurrence == .everyNWeeks {
                        Stepper(value: $interval, in: 1...8) {
                            HStack {
                                Text("Every")
                                Spacer()
                                Text(interval == 1 ? "week" : "\(interval) weeks")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        DatePicker("Counting from", selection: $anchor, displayedComponents: .date)
                    }

                    if recurrence == .weeklyQuota {
                        Stepper(value: $quota, in: 1...14) {
                            HStack {
                                Text("Times a week")
                                Spacer()
                                Text("\(quota)")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if recurrence == .afterCompletion {
                        Stepper(value: $interval, in: 1...365) {
                            HStack {
                                Text("Days after the last time")
                                Spacer()
                                Text("\(interval)")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if recurrence == .once {
                        Toggle("Has a date", isOn: $hasDueDate)
                        if hasDueDate {
                            DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                        }
                    }
                } header: {
                    Text("When")
                } footer: {
                    Text(recurrence.blurb)
                }

                Section("Extras") {
                    TextField("Project or cohort", text: $project)

                    Stepper(value: $batchTotal, in: 0...500, step: 1) {
                        HStack {
                            Text("Countable pile")
                            Spacer()
                            Text(batchTotal == 0 ? "No" : "\(batchTotal) items")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle("Part of the morning run", isOn: $isMorningRun)
                }

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                if let editing {
                    Section {
                        if let measured = RecurrenceEngine.measuredAverage(editing) {
                            HStack {
                                Text("Actually takes")
                                Spacer()
                                Text(Clock.durationString(measured))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Text("Done")
                            Spacer()
                            Text("\(editing.realCompletions.count) times")
                                .foregroundStyle(.secondary)
                        }

                        if let next = RecurrenceEngine.nextDue(editing, after: .now, calendar: Clock.calendar) {
                            HStack {
                                Text("Next")
                                Spacer()
                                Text(next.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section {
                        Button("Delete task", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "New task" : "Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .confirmationDialog(
                "Delete this task and its history?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { delete() }
                Button("Keep it", role: .cancel) {}
            }
        }
    }

    private func save() {
        let task = editing ?? TaskItem(title: "")
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.notes = notes
        task.estimateMinutes = estimate
        task.context = context
        task.preferredWindow = preferredWindow
        task.recurrence = recurrence
        task.recurrenceWeekday = recurrence.needsWeekday ? weekday : 0
        task.recurrenceInterval = interval
        task.recurrenceAnchor = recurrence == .everyNWeeks ? Clock.calendar.startOfDay(for: anchor) : nil
        task.quotaPerWeek = quota
        task.dueDate = (recurrence == .once && hasDueDate) ? Clock.calendar.startOfDay(for: dueDate) : nil
        task.project = project.trimmingCharacters(in: .whitespacesAndNewlines)
        task.batchTotal = batchTotal
        task.batchDone = min(task.batchDone, batchTotal)
        task.isMorningRun = isMorningRun

        if editing == nil {
            modelContext.insert(task)
        }
        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        if let editing {
            modelContext.delete(editing)
            try? modelContext.save()
        }
        dismiss()
    }
}
