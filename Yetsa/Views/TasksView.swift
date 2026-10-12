import SwiftUI
import SwiftData

/// The one-off pile. Anything that repeats lives under Routines instead, so
/// this list stays short enough to be worth reading.
struct TasksView: View {
    @Query(sort: \TaskItem.createdAt) private var tasks: [TaskItem]
    @Environment(\.modelContext) private var modelContext

    @State private var search = ""
    @State private var showingDone = false
    @State private var editing: TaskItem?
    @State private var isAdding = false

    private var calendar: Calendar { Clock.calendar }

    private var oneOffs: [TaskItem] {
        tasks.filter { $0.recurrence == .once && !$0.isArchived }
    }

    private var matching: [TaskItem] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let pool = showingDone ? oneOffs : oneOffs.filter { $0.completions.isEmpty }
        guard !query.isEmpty else { return pool }
        return pool.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.project.localizedCaseInsensitiveContains(query)
                || $0.notes.localizedCaseInsensitiveContains(query)
        }
    }

    /// Grouped by project, Inbox first, then alphabetically.
    private var groups: [(name: String, tasks: [TaskItem])] {
        let buckets = Dictionary(grouping: matching) { $0.project.isEmpty ? "Inbox" : $0.project }
        return buckets
            .map { (name: $0.key, tasks: $0.value.sorted(by: Self.byDueDate)) }
            .sorted { lhs, rhs in
                if lhs.name == "Inbox" { return true }
                if rhs.name == "Inbox" { return false }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private static func byDueDate(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case (let a?, let b?): return a < b
        case (nil, _?): return false
        case (_?, nil): return true
        default: return lhs.createdAt < rhs.createdAt
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()

                if groups.isEmpty {
                    ContentUnavailableView(
                        search.isEmpty ? "Nothing on the pile" : "No match",
                        systemImage: search.isEmpty ? "checkmark.circle" : "magnifyingglass",
                        description: Text(search.isEmpty
                            ? "One-off tasks land here. Repeating ones live under Routines."
                            : "Nothing here matches that.")
                    )
                } else {
                    List {
                        ForEach(groups, id: \.name) { group in
                            Section(group.name) {
                                ForEach(group.tasks) { task in
                                    TaskRow(
                                        task: task,
                                        day: task.lastCompletedAt ?? .now,
                                        showsContext: true
                                    ) {
                                        editing = task
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            modelContext.delete(task)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Tasks")
            .searchable(text: $search, prompt: "Search tasks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isAdding = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add a task")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingDone.toggle()
                    } label: {
                        Image(systemName: showingDone ? "eye" : "eye.slash")
                    }
                    .accessibilityLabel(showingDone ? "Hide finished tasks" : "Show finished tasks")
                }
            }
            .sheet(item: $editing) { TaskFormView(editing: $0) }
            .sheet(isPresented: $isAdding) { TaskFormView(editing: nil) }
        }
    }
}
