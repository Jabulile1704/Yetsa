import SwiftUI
import SwiftData

struct TaskRow: View {
    let task: TaskItem
    let day: Date
    var showsContext: Bool = false
    var showsCadence: Bool = false
    var onEdit: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme

    private var calendar: Calendar { Clock.calendar }
    private var isTicked: Bool { RecurrenceEngine.isTicked(task, on: day, calendar: calendar) }
    private var isSkipped: Bool { RecurrenceEngine.isSkipped(task, on: day, calendar: calendar) }
    private var isSettled: Bool { isTicked || isSkipped }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            tickButton

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .strikethrough(isSettled, color: .secondary)
                    .foregroundStyle(isSettled ? .secondary : .primary)
                    .multilineTextAlignment(.leading)

                if !subtitleParts.isEmpty {
                    Text(subtitleParts.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if task.isBatch {
                    batchProgress
                }
            }

            Spacer(minLength: 4)

            estimateChip
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
        .onTapGesture { onEdit?() }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                RecurrenceEngine.skip(task, on: day, calendar: calendar)
            } label: {
                Label("Skip", systemImage: "arrow.uturn.forward")
            }
            .tint(.orange)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isTicked ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Pieces

    private var tickButton: some View {
        Button {
            withAnimation(.snappy) {
                RecurrenceEngine.toggle(task, on: day, calendar: calendar)
            }
        } label: {
            Image(systemName: tickSymbol)
                .font(.title3)
                .foregroundStyle(isTicked ? Color.accentColor : .secondary)
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isTicked ? "Mark \(task.title) not done" : "Mark \(task.title) done")
    }

    private var tickSymbol: String {
        if isTicked { return "checkmark.circle.fill" }
        if isSkipped { return "minus.circle.fill" }
        return "circle"
    }

    private var subtitleParts: [String] {
        var parts: [String] = []
        if showsContext { parts.append(task.context.tag) }
        if showsCadence { parts.append(RecurrenceEngine.cadence(task, calendar: calendar)) }
        if !task.project.isEmpty { parts.append(task.project) }
        if isSkipped { parts.append("skipped") }
        if task.hasNotes && !showsCadence { parts.append("note") }
        return parts
    }

    private var batchProgress: some View {
        HStack(spacing: 8) {
            ProgressView(value: task.batchFraction)
                .progressViewStyle(.linear)
                .frame(maxWidth: 120)

            Text("\(task.batchDone) of \(task.batchTotal)")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Button {
                advanceBatch()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .disabled(task.batchDone >= task.batchTotal)
            .accessibilityLabel("Log one more for \(task.title)")
        }
    }

    /// The estimate, unless enough real completions disagree with it — then it
    /// shows what the thing actually takes.
    private var estimateChip: some View {
        let measured = RecurrenceEngine.measuredAverage(task)
        let drifted = measured.map { abs($0 - task.estimateMinutes) >= max(5, task.estimateMinutes / 4) } ?? false
        let minutes = drifted ? (measured ?? task.estimateMinutes) : task.estimateMinutes

        return Text(drifted ? "~\(Clock.shortDuration(minutes))" : Clock.shortDuration(minutes))
            .font(.caption2.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(drifted ? Color.orange : .secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.quaternary.opacity(0.5), in: .capsule)
            .help(drifted ? "Your own logs say this takes longer than the estimate" : "")
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
