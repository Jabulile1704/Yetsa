import SwiftUI
import SwiftData

/// One row of a grouped list. Monochrome by design: a tick is a filled circle,
/// an estimate is grey text, and the only colour in the whole screen is kept
/// for things that are actually wrong.
struct TaskRow: View {
    let task: TaskItem
    let day: Date
    var showsContext: Bool = false
    var showsCadence: Bool = false
    var onEdit: (() -> Void)?

    @Environment(\.modelContext) private var modelContext

    private var calendar: Calendar { Clock.calendar }
    private var isTicked: Bool { RecurrenceEngine.isTicked(task, on: day, calendar: calendar) }
    private var isSkipped: Bool { RecurrenceEngine.isSkipped(task, on: day, calendar: calendar) }
    private var isSettled: Bool { isTicked || isSkipped }

    var body: some View {
        // Two separate buttons rather than a row-wide tap gesture: a gesture on
        // the row swallows the tick, so the circle opened the editor instead of
        // ticking the task.
        HStack(spacing: 0) {
            tickButton

            Button {
                onEdit?()
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(task.title)
                            .font(.body)
                            .strikethrough(isSettled, color: .secondary)
                            .foregroundStyle(isSettled ? .secondary : .primary)
                            .multilineTextAlignment(.leading)

                        if task.isBatch {
                            batchLine
                        } else if let detail = subtitle {
                            Text(detail)
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer(minLength: 8)

                    Text(estimateText)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(isSettled ? .tertiary : .secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 2)
        .padding(.trailing, 14)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                RecurrenceEngine.skip(task, on: day, calendar: calendar)
            } label: {
                Label("Skip", systemImage: "arrow.uturn.forward")
            }
            .tint(.secondary)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if task.isBatch {
                Button {
                    advanceBatch()
                } label: {
                    Label("One more", systemImage: "plus")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isTicked ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Pieces

    private var tickButton: some View {
        Button {
            withAnimation(.snappy) {
                RecurrenceEngine.toggle(task, on: task.recurrence == .once ? .now : day, calendar: calendar)
            }
        } label: {
            ZStack {
                if isTicked {
                    Circle().fill(.primary)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(.systemBackground))
                } else if isSkipped {
                    Circle().fill(.tertiary)
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(.systemBackground))
                } else {
                    Circle().strokeBorder(Color(.systemGray3), lineWidth: 1.6)
                }
            }
            .frame(width: 22, height: 22)
            // An unfilled Circle only hit-tests its stroke, so without a
            // content shape the tappable area is the 1.6pt ring. Padded out to
            // a 44pt target while the ring stays 22.
            .frame(width: 44, height: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isTicked ? "Mark \(task.title) not done" : "Mark \(task.title) done")
    }

    private var subtitle: String? {
        var parts: [String] = []
        if showsContext { parts.append(task.context.tag) }
        if showsCadence { parts.append(RecurrenceEngine.cadence(task, calendar: calendar)) }
        if !task.project.isEmpty { parts.append(task.project) }
        if isSkipped { parts.append("skipped") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var batchLine: some View {
        HStack(spacing: 8) {
            ThinBar(done: task.batchFraction, height: 3)
                .frame(width: 92)

            Text(batchText)
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    private var batchText: String {
        var text = "\(task.batchDone) of \(task.batchTotal)"
        if !task.project.isEmpty { text += " · \(task.project)" }
        return text
    }

    /// The estimate, unless enough real completions disagree with it — then it
    /// shows what the thing actually takes, marked with a tilde.
    private var estimateText: String {
        let measured = RecurrenceEngine.measuredAverage(task)
        let drifted = measured.map { abs($0 - task.estimateMinutes) >= max(5, task.estimateMinutes / 4) } ?? false
        let minutes = drifted ? (measured ?? task.estimateMinutes) : task.estimateMinutes
        return drifted ? "~\(Clock.shortDuration(minutes))" : Clock.shortDuration(minutes)
    }

    private func advanceBatch() {
        withAnimation(.snappy) {
            task.batchDone = min(task.batchTotal, task.batchDone + 1)
            if task.batchDone >= task.batchTotal, !isTicked {
                RecurrenceEngine.toggle(task, on: day, calendar: calendar)
            }
        }
    }
}
