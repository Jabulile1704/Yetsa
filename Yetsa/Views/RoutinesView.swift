import SwiftUI
import SwiftData

/// Everything that comes back, grouped by how it comes back. The cadence and
/// the next date are on every row, because the whole point of a routine is
/// trusting it without checking.
struct RoutinesView: View {
    @Query(sort: \TaskItem.createdAt) private var tasks: [TaskItem]
    @Environment(\.modelContext) private var modelContext

    @State private var editing: TaskItem?
    @State private var isAdding = false

    private var calendar: Calendar { Clock.calendar }

    private let order: [RecurrenceKind] = [
        .daily, .weekdays, .weekly, .everyNWeeks, .weeklyQuota, .afterCompletion
    ]

    private var groups: [(kind: RecurrenceKind, tasks: [TaskItem])] {
        let recurring = tasks.filter { $0.recurrence != .once && !$0.isArchived }
        let buckets = Dictionary(grouping: recurring) { $0.recurrence }
        return order.compactMap { kind in
            guard let items = buckets[kind], !items.isEmpty else { return nil }
            return (kind: kind, tasks: items.sorted { $0.createdAt < $1.createdAt })
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if groups.isEmpty {
                    ContentUnavailableView(
                        "No routines yet",
                        systemImage: "repeat",
                        description: Text("Anything that comes back — daily, weekly, every second Saturday, or a count you owe the week — shows up here.")
                    )
                } else {
                    List {
                        ForEach(groups, id: \.kind) { group in
                            Section {
                                ForEach(group.tasks) { task in
                                    RoutineRow(task: task, calendar: calendar) {
                                        editing = task
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            modelContext.delete(task)
                                        }
                                    }
                                }
                            } header: {
                                Label(group.kind.label, systemImage: group.kind.symbol)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Routines")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isAdding = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add a routine")
                }
            }
            .sheet(item: $editing) { TaskFormView(editing: $0) }
            .sheet(isPresented: $isAdding) { TaskFormView(editing: nil) }
        }
    }
}

private struct RoutineRow: View {
    let task: TaskItem
    let calendar: Calendar
    let onTap: () -> Void

    private var isQuota: Bool { task.recurrence == .weeklyQuota }

    private var detail: String {
        var parts = [RecurrenceEngine.cadence(task, calendar: calendar)]

        if isQuota {
            let done = RecurrenceEngine.quotaDone(task, inWeekOf: .now, calendar: calendar)
            parts.append("\(done) done this week")
        } else if RecurrenceEngine.isDue(task, on: .now, calendar: calendar) {
            parts.append("due today")
        } else if let next = RecurrenceEngine.nextDue(task, after: .now, calendar: calendar) {
            parts.append("next \(next.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))")
        }

        if !task.project.isEmpty { parts.append(task.project) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: task.context.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Text(Clock.shortDuration(task.estimateMinutes))
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
