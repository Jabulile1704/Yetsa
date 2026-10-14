import SwiftUI
import SwiftData

/// The day as a grouped list. Windows are sections, the scaffold's fixed
/// points are section footers, and the free-time figures sit in the headers
/// where a stock iOS list puts its secondary information.
///
/// Monochrome on purpose. Red appears only where something is genuinely wrong:
/// a morning running late, or a window with nothing left in it.
struct TodayView: View {
    @Query(sort: \TaskItem.createdAt) private var tasks: [TaskItem]
    @Query private var schedules: [DaySchedule]

    @State private var now = Date.now
    @State private var editing: TaskItem?
    @State private var isAdding = false
    @State private var showingRun = false
    @State private var expanded: Set<String> = []
    @State private var openedEarlier: Set<String> = []

    private var calendar: Calendar { Clock.calendar }

    private var plan: DayPlan {
        PlanBuilder.plan(for: now, schedules: schedules, tasks: tasks)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    hero
                        .padding(.top, 14)

                    if !plan.personalWindows.isEmpty {
                        freeStrip
                            .padding(.top, 10)
                    }

                    if !plan.quotaTasks.isEmpty {
                        quotaRow
                            .padding(.top, 10)
                    }

                    if !finishedWindows.isEmpty {
                        earlierSection
                    }

                    ForEach(liveWindows) { window in
                        section(window)
                    }

                    bedtimeFooter
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editing) { TaskFormView(editing: $0) }
            .sheet(isPresented: $isAdding) { TaskFormView(editing: nil) }
            .sheet(isPresented: $showingRun) { MorningRunView() }
            .task {
                while !Task.isCancelled {
                    now = .now
                    try? await Task.sleep(for: .seconds(30))
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Today")
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.9)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                // The hero only offers the run while the door is still ahead of
                // you. Without this the screen is unreachable from half past
                // seven until bedtime.
                Button { showingRun = true } label: {
                    Image(systemName: "sunrise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .background(Color(.tertiarySystemFill), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Morning run")

                Button { isAdding = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .background(Color(.tertiarySystemFill), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add a task")
            }
            .padding(.top, 3)
        }
    }

    private var subtitle: String {
        let date = plan.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
        let all = plan.windows.flatMap(\.tasks)
        guard !all.isEmpty else { return date }
        let done = all.filter { RecurrenceEngine.isSettled($0, on: plan.date, calendar: calendar) }.count
        return "\(date) · \(done) of \(all.count) done"
    }

    // MARK: - Hero

    /// The morning run while it is still ahead of you; otherwise whatever
    /// fixed point is coming next.
    @ViewBuilder private var hero: some View {
        if let run = MorningRun.from(plan), now < run.departure {
            Button { showingRun = true } label: {
                heroBody(
                    symbol: "sunrise",
                    title: "Leave home in \(Clock.durationString(max(0, run.minutesToDeparture(from: now))))",
                    warning: run.slack(from: now) < 0
                        ? "\(Clock.durationString(-run.slack(from: now))) behind"
                        : nil,
                    detail: "Morning run · \(run.doneCount) of \(run.stepCount) done · \(Clock.durationString(run.remainingMinutes)) of work left",
                    done: run.plannedMinutes > 0
                        ? Double(run.plannedMinutes - run.remainingMinutes) / Double(max(1, windowCapacity(.morning)))
                        : 0,
                    pending: Double(run.remainingMinutes) / Double(max(1, windowCapacity(.morning))),
                    chevron: true
                )
            }
            .buttonStyle(.plain)
        } else if let anchor = plan.nextAnchor(after: now) {
            let current = plan.currentWindow(now)
            heroBody(
                symbol: anchor.symbol,
                title: "\(anchor.label) in \(Clock.durationString(max(0, Int(anchor.time.timeIntervalSince(now) / 60))))",
                warning: nil,
                detail: current.map { window in
                    "\(window.kind.label) · \(Clock.durationString(window.minutesLeft(from: now))) left"
                } ?? "Nothing left on the scaffold today",
                done: 0,
                pending: current.map(\.loadFraction) ?? 0,
                chevron: false
            )
        }
    }

    private func heroBody(
        symbol: String,
        title: String,
        warning: String?,
        detail: String,
        done: Double,
        pending: Double,
        chevron: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
                    .frame(width: 18)

                Text(title)
                    .font(.headline)

                Spacer(minLength: 6)

                if let warning {
                    Text(warning)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                }

                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }

            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.leading, 28)
                .padding(.top, 4)

            ThinBar(done: done, pending: pending)
                .padding(.leading, 28)
                .padding(.top, 10)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
    }

    private func windowCapacity(_ kind: WindowKind) -> Int {
        plan.window(kind)?.capacityMinutes ?? 0
    }

    // MARK: - Free time

    /// The whole point of the app, in one row: what is actually yours today.
    private var freeStrip: some View {
        HStack(spacing: 0) {
            ForEach(Array(plan.personalWindows.enumerated()), id: \.element.id) { index, window in
                if index > 0 {
                    Divider().frame(height: 34)
                }

                VStack(spacing: 2) {
                    Text(freeText(window))
                        .font(.system(size: 19, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(window.freeMinutes <= 0 ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))

                    Text(window.kind.shortLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 58)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
    }

    private func freeText(_ window: DayWindow) -> String {
        window.isOverbooked
            ? "−" + Clock.shortDuration(-window.freeMinutes)
            : Clock.shortDuration(window.freeMinutes)
    }

    // MARK: - Quotas

    private var quotaRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                Text("Owed this week")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(plan.quotaTasks) { task in
                    let done = RecurrenceEngine.quotaDone(task, inWeekOf: plan.date, calendar: calendar)
                    let target = max(1, task.quotaPerWeek)

                    HStack(spacing: 5) {
                        Text(task.title)
                            .font(.subheadline)
                            .lineLimit(1)

                        ForEach(0..<target, id: \.self) { index in
                            Circle()
                                .fill(index < done ? AnyShapeStyle(.primary) : AnyShapeStyle(Color(.systemGray4)))
                                .frame(width: 7, height: 7)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
    }

    // MARK: - Earlier

    /// A window is finished once it is behind you, or once everything in it is
    /// settled. Either way it stops earning a section of its own.
    private func isFinished(_ window: DayWindow) -> Bool {
        if window.isPast(now) { return true }
        guard !window.tasks.isEmpty else { return false }
        return window.tasks.allSatisfy {
            RecurrenceEngine.isSettled($0, on: plan.date, calendar: calendar)
        }
    }

    private var finishedWindows: [DayWindow] {
        plan.windows.filter { shows($0) && isFinished($0) }
    }

    private var liveWindows: [DayWindow] {
        plan.windows.filter { shows($0) && !isFinished($0) }
    }

    /// Everything behind you, one line each, so the part of the day you can
    /// still do something about starts near the top of the screen.
    private var earlierSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("EARLIER")
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(Array(finishedWindows.enumerated()), id: \.element.id) { index, window in
                    if index > 0 { Divider().padding(.leading, 16) }

                    earlierRow(window)

                    if openedEarlier.contains(window.id) {
                        ForEach(window.tasks) { task in
                            Divider().padding(.leading, 46)
                            TaskRow(task: task, day: plan.date) { editing = task }
                        }
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
        }
    }

    private func earlierRow(_ window: DayWindow) -> some View {
        let isOpen = openedEarlier.contains(window.id)
        let left = window.tasks.filter {
            !RecurrenceEngine.isSettled($0, on: plan.date, calendar: calendar)
        }.count

        return Button {
            withAnimation(.snappy) {
                if isOpen { openedEarlier.remove(window.id) } else { openedEarlier.insert(window.id) }
            }
        } label: {
            HStack(spacing: 8) {
                Text(window.kind.label)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text(Clock.clockString(window.start))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 6)

                Text(earlierStatus(window))
                    .font(.subheadline)
                    .monospacedDigit()
                    // Something left behind in a window that has gone is worth
                    // a touch more weight than a tidy one.
                    .foregroundStyle(left > 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isOpen ? 0 : -90))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func earlierStatus(_ window: DayWindow) -> String {
        let total = window.tasks.count
        guard total > 0 else { return "Nothing planned" }
        let done = window.tasks.filter {
            RecurrenceEngine.isSettled($0, on: plan.date, calendar: calendar)
        }.count
        return done == total ? "\(total) done" : "\(total - done) left"
    }

    // MARK: - Sections

    /// Anything with work in it, plus empty windows big enough to be worth
    /// filling. A blank fifteen-minute commute is just noise.
    private func shows(_ window: DayWindow) -> Bool {
        if !window.isEmpty { return true }
        return !window.kind.isWork && window.capacityMinutes >= 30
    }

    private func section(_ window: DayWindow) -> some View {
        let open = window.tasks.filter { !RecurrenceEngine.isSettled($0, on: plan.date, calendar: calendar) }
        let settled = window.tasks.filter { RecurrenceEngine.isSettled($0, on: plan.date, calendar: calendar) }
        let isOpen = expanded.contains(window.id)

        return VStack(alignment: .leading, spacing: 0) {
            sectionHeader(window)

            VStack(spacing: 0) {
                if open.isEmpty && settled.isEmpty {
                    Text("Nothing planned")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                } else {
                    ForEach(Array(open.enumerated()), id: \.element.id) { index, task in
                        if index > 0 { Divider().padding(.leading, 46) }
                        TaskRow(task: task, day: plan.date) { editing = task }
                    }

                    if !settled.isEmpty {
                        if !open.isEmpty { Divider().padding(.leading, 46) }
                        completedRow(window: window, count: settled.count, isOpen: isOpen)

                        if isOpen {
                            ForEach(settled) { task in
                                Divider().padding(.leading, 46)
                                TaskRow(task: task, day: plan.date) { editing = task }
                            }
                        }
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))

            if let anchor = plan.anchorAfter(window.kind) {
                anchorFooter(anchor)
            }
        }
    }

    private func sectionHeader(_ window: DayWindow) -> some View {
        HStack(spacing: 6) {
            Text("\(window.kind.label.uppercased()) · \(Clock.clockString(window.start))")
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)

            if let kind = armedAlarm(at: window.start) {
                Image(systemName: "alarm")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(kind.label) alarm set")
            }

            Spacer()

            Text(window.kind.isWork
                 ? Clock.durationString(window.capacityMinutes).uppercased()
                 : "\(Clock.durationString(max(0, window.freeMinutes)).uppercased()) FREE")
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(window.isOverbooked ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 6)
    }

    private func completedRow(window: DayWindow, count: Int, isOpen: Bool) -> some View {
        Button {
            withAnimation(.snappy) {
                if isOpen { expanded.remove(window.id) } else { expanded.insert(window.id) }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isOpen ? 0 : -90))
                    .frame(width: 22)

                Text("\(count) completed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func anchorFooter(_ anchor: DayAnchor) -> some View {
        HStack(spacing: 6) {
            if let kind = armedAlarm(at: anchor.time) {
                Image(systemName: "alarm")
                    .font(.system(size: 11))
                    .accessibilityLabel("\(kind.label) alarm set")
            }

            Text("\(Clock.clockString(anchor.time)) \(anchor.label)")
                .font(.footnote)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.top, 7)
    }

    private var bedtimeFooter: some View {
        Group {
            if let bed = plan.bedtime {
                HStack(spacing: 6) {
                    Image(systemName: bed.symbol)
                        .font(.system(size: 11))
                    Text("\(Clock.clockString(bed.time)) \(bed.label)")
                        .font(.footnote)
                }
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.top, 22)
            }
        }
    }

    /// Which alarm, if any, guards this moment — so the row can show a bell.
    private func armedAlarm(at time: Date) -> AlarmKind? {
        guard plan.isWorkday else { return nil }
        let minutes = Clock.minutesFromMidnight(time, calendar: calendar)
        let schedule = PlanBuilder.schedule(for: plan.date, in: schedules, calendar: calendar)

        return AlarmKind.allCases.first { kind in
            kind.isEnabled && kind.applies(to: schedule) && kind.minutes(in: schedule) == minutes
        }
    }
}
