import SwiftUI
import SwiftData

struct RootView: View {
    enum Screen: Hashable { case today, tasks, routines, setup }

    @State private var selection: Screen = .today

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "sun.horizon.fill", value: Screen.today) {
                TodayView()
            }

            Tab("Tasks", systemImage: "checklist", value: Screen.tasks) {
                TasksView()
            }

            Tab("Routines", systemImage: "repeat", value: Screen.routines) {
                RoutinesView()
            }

            Tab("Setup", systemImage: "slider.horizontal.3", value: Screen.setup) {
                SetupView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            NextUpAccessory { selection = .today }
        }
    }
}

/// The strip above the tab bar always answers the same question: what is the
/// next fixed point, and how long until it.
private struct NextUpAccessory: View {
    @Query private var tasks: [TaskItem]
    @Query private var schedules: [DaySchedule]
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    let onTap: () -> Void

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let plan = PlanBuilder.plan(for: now, schedules: schedules, tasks: tasks)
            let anchor = plan.nextAnchor(after: now)

            Button(action: onTap) {
                HStack(spacing: 8) {
                    Image(systemName: anchor?.symbol ?? "moon.zzz")
                        .foregroundStyle(.secondary)

                    if let anchor {
                        Text(anchor.label)
                            .foregroundStyle(placement == .inline ? .secondary : .primary)
                        Spacer(minLength: 0)
                        Text(countdown(to: anchor.time, from: now))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    } else {
                        Text("Day's done")
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    private func countdown(to time: Date, from now: Date) -> String {
        let minutes = Int(time.timeIntervalSince(now) / 60)
        guard minutes > 0 else { return "now" }
        return "in \(Clock.durationString(minutes))"
    }
}
