import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \TaskItem.createdAt) private var tasks: [TaskItem]
    @Query private var schedules: [DaySchedule]

    @State private var now = Date.now
    @State private var editing: TaskItem?
    @State private var isAdding = false
    @State private var showingRun = false

    private var plan: DayPlan {
        PlanBuilder.plan(for: now, schedules: schedules, tasks: tasks)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        DayHeadline(plan: plan, now: now)

                        if let run = MorningRun.from(plan), now < run.departure {
                            MorningRunCard(run: run, now: now) { showingRun = true }
                        }

                        if !plan.quotaTasks.isEmpty {
                            QuotaStrip(tasks: plan.quotaTasks, day: plan.date)
                        }

                        if !plan.overbookedWindows.isEmpty {
                            OverbookedNote(windows: plan.overbookedWindows)
                        }

                        timeline
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 90)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // Reachable all day, not just before the door — the
                    // sequence is worth checking the night before too.
                    Button { showingRun = true } label: {
                        Image(systemName: "sunrise")
                    }
                    .accessibilityLabel("Morning run")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isAdding = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add a task")
                }
            }
            .sheet(item: $editing) { task in
                TaskFormView(editing: task)
            }
            .sheet(isPresented: $isAdding) {
                TaskFormView(editing: nil)
            }
            .sheet(isPresented: $showingRun) {
                MorningRunView()
            }
            .task {
                while !Task.isCancelled {
                    now = .now
                    try? await Task.sleep(for: .seconds(30))
                }
            }
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(plan.timeline) { entry in
                switch entry {
                case .anchor(let anchor):
                    AnchorRow(
                        anchor: anchor,
                        now: now,
                        snoozeBuffer: anchor.id == "wake" ? plan.snoozeBufferMinutes : 0
                    )
                case .window(let window):
                    WindowCard(window: window, now: now) { editing = $0 }
                }
            }
        }
    }
}

// MARK: - Headline

private struct DayHeadline: View {
    let plan: DayPlan
    let now: Date

    private var calendar: Calendar { Clock.calendar }

    private var settledCount: Int {
        plan.windows.flatMap(\.tasks)
            .filter { RecurrenceEngine.isSettled($0, on: plan.date, calendar: calendar) }
            .count
    }

    private var totalCount: Int {
        plan.windows.flatMap(\.tasks).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.date.formatted(.dateTime.weekday(.wide)))
                .font(.largeTitle.bold())

            Text(plan.date.formatted(.dateTime.day().month(.wide).year()))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    if let current = plan.currentWindow(now) {
                        Chip(
                            text: "\(current.kind.label) · \(Clock.durationString(current.minutesLeft(from: now))) left",
                            symbol: current.kind.symbol
                        )
                    }

                    if let next = plan.nextAnchor(after: now) {
                        let minutes = max(0, Int(next.time.timeIntervalSince(now) / 60))
                        Chip(
                            text: "\(next.label) in \(Clock.durationString(minutes))",
                            symbol: next.symbol,
                            tint: next.isDeparture ? .accentColor : .secondary
                        )
                    }

                    if totalCount > 0 {
                        Chip(text: "\(settledCount) of \(totalCount) done", symbol: "checkmark")
                    }

                    if !plan.isWorkday {
                        Chip(text: "No work today", symbol: "sun.max")
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Morning run card

private struct MorningRunCard: View {
    let run: MorningRun
    let now: Date
    let onTap: () -> Void

    private var slack: Int { run.slack(from: now) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Morning run", systemImage: "sunrise.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text("Leave home in \(Clock.durationString(max(0, run.minutesToDeparture(from: now))))")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()

                HStack(spacing: 6) {
                    Text("\(run.doneCount) of \(run.stepCount) done")
                    Text("·")
                    Text("\(Clock.durationString(run.remainingMinutes)) of work left")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(run.status(from: now))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(slack < 0 ? .red : (run.isComplete ? .green : .secondary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quotas

private struct QuotaStrip: View {
    let tasks: [TaskItem]
    let day: Date

    private var calendar: Calendar { Clock.calendar }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Owed this week")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(tasks) { task in
                        QuotaPill(task: task, day: day, calendar: calendar)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct QuotaPill: View {
    let task: TaskItem
    let day: Date
    let calendar: Calendar

    private var done: Int { RecurrenceEngine.quotaDone(task, inWeekOf: day, calendar: calendar) }
    private var target: Int { max(1, task.quotaPerWeek) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            HStack(spacing: 4) {
                ForEach(0..<target, id: \.self) { index in
                    Circle()
                        .fill(index < done ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: 7, height: 7)
                }

                Text("\(done) of \(target)")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

// MARK: - Overbooked

private struct OverbookedNote: View {
    let windows: [DayWindow]

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 3) {
                Text(windows.count == 1 ? "One window does not fit" : "\(windows.count) windows do not fit")
                    .font(.caption.weight(.semibold))

                Text(windows.map { "\($0.kind.label) is \(Clock.durationString(-$0.freeMinutes)) over" }
                    .joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

// MARK: - Anchors and windows

private struct AnchorRow: View {
    let anchor: DayAnchor
    let now: Date
    let snoozeBuffer: Int

    @Environment(\.colorScheme) private var scheme

    private var isPast: Bool { now >= anchor.time }

    var body: some View {
        HStack(spacing: 10) {
            Text(Clock.clockString(anchor.time))
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .frame(width: 58, alignment: .trailing)

            Image(systemName: anchor.symbol)
                .font(.caption)
                .frame(width: 16)

            Text(anchor.label)
                .font(.caption.weight(anchor.isDeparture ? .semibold : .regular))

            if snoozeBuffer > 0 {
                Text("\(Clock.durationString(snoozeBuffer)) before you must move")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(
            isPast
                ? AnyShapeStyle(.tertiary)
                : AnyShapeStyle(anchor.isDeparture ? Color.accentColor : Palette.anchorTint(scheme))
        )
        .padding(.leading, 2)
    }
}

private struct WindowCard: View {
    let window: DayWindow
    let now: Date
    let onEdit: (TaskItem) -> Void

    @Environment(\.colorScheme) private var scheme

    private var tint: Color { Palette.window(window.kind, scheme) }
    private var isCurrent: Bool { window.isCurrent(now) }
    /// Work blocks and commutes are scaffolding, not budget. They stay slim.
    private var isCompact: Bool { window.kind.isWork || window.kind.isCommute }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            // An empty window needs no bar — the line below says it better.
            if !isCompact, !window.isEmpty {
                budget
            }

            if window.isEmpty {
                if !isCompact {
                    Text("Nothing planned · \(Clock.durationString(window.capacityMinutes)) wide open")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(window.tasks) { task in
                        TaskRow(
                            task: task,
                            day: window.date,
                            showsContext: window.kind == .evening || window.kind == .afternoon
                        ) {
                            onEdit(task)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(isCompact ? 11 : 14)
        .glassEffect(.regular, in: .rect(cornerRadius: isCompact ? 16 : 22))
        .overlay {
            if isCurrent {
                RoundedRectangle(cornerRadius: isCompact ? 16 : 22)
                    .strokeBorder(tint.opacity(0.55), lineWidth: 1.5)
            }
        }
        .opacity(window.isPast(now) && window.isEmpty ? 0.55 : 1)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: window.kind.symbol)
                .font(.caption)
                .foregroundStyle(tint)

            Text(window.kind.label)
                .font(isCompact ? .caption.weight(.medium) : .subheadline.weight(.semibold))

            if isCurrent {
                Text("now")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tint.opacity(0.15), in: .capsule)
            }

            Spacer(minLength: 4)

            Text("\(Clock.clockString(window.start)) – \(Clock.clockString(window.end))")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private var budget: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("\(Clock.durationString(window.plannedMinutes)) of \(Clock.durationString(window.capacityMinutes)) planned")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Spacer(minLength: 4)

                Text(window.isOverbooked
                     ? "\(Clock.durationString(-window.freeMinutes)) over"
                     : "\(Clock.durationString(window.freeMinutes)) free")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.load(window.loadFraction, scheme))
            }

            BudgetBar(fraction: window.loadFraction)
        }
    }
}
