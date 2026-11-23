import Foundation
import SwiftData
import UserNotifications

/// Getting your history out, and getting rid of it.
///
/// Yetsa keeps everything on one device with no account behind it, so the only
/// copy of a year's routines is the one on the phone. Deleting the app takes it
/// with them. These two are the answer to that: take it with you, or destroy it
/// deliberately rather than by accident.
enum DataExport {

    // MARK: - Shapes written to disk

    private struct Archive: Encodable {
        let app = "Yetsa"
        let formatVersion = 1
        let exportedAt: Date
        let week: [Day]
        let workplace: Place?
        let tasks: [Task]
    }

    private struct Day: Encodable {
        let weekday: Int
        let isWorkday: Bool
        let wake, outOfBed, leaveHome, arriveWork: Int
        let lunch, lunchLength, knockOff, eveningStarts, bedtime: Int
    }

    private struct Place: Encodable {
        let name: String
        let latitude, longitude, radius: Double
        let lastArrival: Date?
    }

    private struct Task: Encodable {
        let title: String
        let notes: String
        let estimateMinutes: Int
        let context: String
        let preferredWindow: String?
        let project: String
        let recurrence: String
        let recurrenceWeekday: Int?
        let recurrenceInterval: Int?
        let recurrenceAnchor: Date?
        let quotaPerWeek: Int?
        let dueDate: Date?
        let batchTotal: Int?
        let batchDone: Int?
        let isMorningRun: Bool
        let createdAt: Date
        let completions: [Tick]
    }

    private struct Tick: Encodable {
        let forDay: Date
        let completedAt: Date
        let actualMinutes: Int?
        let skipped: Bool
    }

    // MARK: - JSON

    /// Everything, faithfully. Dates as ISO 8601 so another tool can read it.
    static func json(
        tasks: [TaskItem],
        schedules: [DaySchedule],
        place: WorkPlace?
    ) throws -> Data {
        let archive = Archive(
            exportedAt: .now,
            week: schedules
                .sorted { $0.weekday < $1.weekday }
                .map {
                    Day(weekday: $0.weekday, isWorkday: $0.isWorkday,
                        wake: $0.wake, outOfBed: $0.outOfBed,
                        leaveHome: $0.leaveHome, arriveWork: $0.arriveWork,
                        lunch: $0.lunch, lunchLength: $0.lunchLength,
                        knockOff: $0.knockOff, eveningStarts: $0.eveningStarts,
                        bedtime: $0.bedtime)
                },
            workplace: place.flatMap { p in
                p.isSet ? Place(name: p.name, latitude: p.latitude,
                                longitude: p.longitude, radius: p.radius,
                                lastArrival: p.lastArrival) : nil
            },
            tasks: tasks
                .sorted { $0.createdAt < $1.createdAt }
                .map { task in
                    Task(
                        title: task.title,
                        notes: task.notes,
                        estimateMinutes: task.estimateMinutes,
                        context: task.contextRaw,
                        preferredWindow: task.preferredWindowRaw.isEmpty ? nil : task.preferredWindowRaw,
                        project: task.project,
                        recurrence: task.recurrenceRaw,
                        recurrenceWeekday: task.recurrenceWeekday == 0 ? nil : task.recurrenceWeekday,
                        recurrenceInterval: task.recurrence == .everyNWeeks || task.recurrence == .afterCompletion
                            ? task.recurrenceInterval : nil,
                        recurrenceAnchor: task.recurrenceAnchor,
                        quotaPerWeek: task.recurrence == .weeklyQuota ? task.quotaPerWeek : nil,
                        dueDate: task.dueDate,
                        batchTotal: task.batchTotal == 0 ? nil : task.batchTotal,
                        batchDone: task.batchTotal == 0 ? nil : task.batchDone,
                        isMorningRun: task.isMorningRun,
                        createdAt: task.createdAt,
                        completions: task.completions
                            .sorted { $0.forDay < $1.forDay }
                            .map {
                                Tick(forDay: $0.forDay, completedAt: $0.completedAt,
                                     actualMinutes: $0.actualMinutes == 0 ? nil : $0.actualMinutes,
                                     skipped: $0.wasSkipped)
                            }
                    )
                }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }

    // MARK: - CSV

    /// The tick history, flat, for a spreadsheet. One row per completion,
    /// oldest first.
    static func completionsCSV(tasks: [TaskItem], calendar: Calendar) -> String {
        var rows = ["Date,Task,Project,Context,Estimate (min),Actual (min),Skipped"]

        let ticks = tasks.flatMap { task in
            task.completions.map { (task, $0) }
        }.sorted { $0.1.forDay < $1.1.forDay }

        let dayFormat = Date.FormatStyle(date: .numeric, time: .omitted)
            .year(.defaultDigits).month(.twoDigits).day(.twoDigits)
            .locale(Locale(identifier: "en_US_POSIX"))

        for (task, tick) in ticks {
            let date = tick.forDay.formatted(dayFormat)
            rows.append([
                escape(date),
                escape(task.title),
                escape(task.project),
                escape(task.context.tag),
                String(task.estimateMinutes),
                tick.actualMinutes == 0 ? "" : String(tick.actualMinutes),
                tick.wasSkipped ? "Yes" : "No"
            ].joined(separator: ","))
        }

        return rows.joined(separator: "\n") + "\n"
    }

    /// Commas, quotes and newlines inside a field would otherwise break the
    /// row, so anything containing them is quoted and its quotes doubled.
    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - Files

    /// Writes into the temporary directory and hands back the URL, which is
    /// what a share sheet wants.
    static func write(_ contents: Data, named name: String) throws -> URL {
        let url = URL.temporaryDirectory.appending(path: name)
        try contents.write(to: url, options: .atomic)
        return url
    }

    static func filename(extension ext: String, on date: Date = .now) -> String {
        let stamp = date.formatted(
            Date.FormatStyle(date: .numeric, time: .omitted)
                .year(.defaultDigits).month(.twoDigits).day(.twoDigits)
                .locale(Locale(identifier: "en_US_POSIX"))
        ).replacingOccurrences(of: "/", with: "-")
        return "Yetsa-\(stamp).\(ext)"
    }

    // MARK: - Erasing

    /// Removes everything the person has put in, cancels anything scheduled,
    /// and puts the app back to how it was on first launch.
    ///
    /// This is the local equivalent of deleting an account: Yetsa has no
    /// account to delete, because it has no server. Everything it knows is on
    /// this device, and this is the switch that destroys it.
    @MainActor
    static func eraseEverything(in context: ModelContext) {
        for task in (try? context.fetch(FetchDescriptor<TaskItem>())) ?? [] {
            context.delete(task)
        }
        for tick in (try? context.fetch(FetchDescriptor<Completion>())) ?? [] {
            context.delete(tick)
        }
        for schedule in (try? context.fetch(FetchDescriptor<DaySchedule>())) ?? [] {
            context.delete(schedule)
        }
        for place in (try? context.fetch(FetchDescriptor<WorkPlace>())) ?? [] {
            context.delete(place)
        }
        try? context.save()

        // Nothing scheduled should outlive the data it was built from.
        AlarmScheduler.cancelAll()
        LocationService.shared.stopMonitoring()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let defaults = UserDefaults.standard
        for kind in AlarmKind.allCases { defaults.removeObject(forKey: kind.defaultsKey) }
        for kind in NotificationKind.allCases { defaults.removeObject(forKey: kind.defaultsKey) }

        // Back to first-launch: the starter scaffold is ours, not theirs.
        Seed.installIfNeeded(context)
    }
}
