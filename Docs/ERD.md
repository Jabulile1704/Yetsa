# Entity relationship diagram

Four entities in a local SwiftData store. One relationship.

```mermaid
erDiagram
    TASK_ITEM ||--o{ COMPLETION : "has"

    TASK_ITEM {
        string   title
        string   notes
        int      estimateMinutes "every task carries one"
        string   contextRaw      "home work lunch errand phone anywhere"
        string   preferredWindowRaw "empty means wherever it fits"
        date     dueDate         "one-offs only"
        date     createdAt
        bool     isArchived
        string   recurrenceRaw   "once daily weekdays weekly everyNWeeks weeklyQuota afterCompletion"
        int      recurrenceWeekday "1 Sun to 7 Sat, 0 when not applicable"
        int      recurrenceInterval "weeks, or days for afterCompletion"
        date     recurrenceAnchor "what everyNWeeks counts from"
        int      quotaPerWeek
        string   project         "cohort or module"
        int      batchTotal      "0 means not a countable pile"
        int      batchDone
        date     lastCompletedAt
        bool     isMorningRun
        int      morningRunOrder
    }

    COMPLETION {
        date     completedAt "when it was tapped"
        date     forDay      "the day it counts towards"
        int      actualMinutes "0 when unmeasured"
        bool     wasSkipped  "a skip, not a miss"
    }

    DAY_SCHEDULE {
        int      weekday PK "unique, 1 Sun to 7 Sat"
        bool     isWorkday
        int      wake          "minutes from midnight"
        int      outOfBed
        int      leaveHome
        int      arriveWork
        int      lunch
        int      lunchLength
        int      knockOff
        int      eveningStarts
        int      bedtime
    }

    WORK_PLACE {
        double   latitude
        double   longitude
        double   radius   "metres, 100 minimum"
        bool     isSet
        string   name
        date     lastArrival
    }
```

## Why it is shaped this way

**`TaskItem` → `Completion` is the only relationship**, cascade delete, with
`Completion.task` as the inverse. Everything about history lives in completions
rather than as flags on the task, which is what makes "how many times did I
cook this week" and "what does this actually take" answerable.

**`forDay` is separate from `completedAt`.** Ticking last night's dishes at
00:20 belongs to yesterday. Without the split, every late tick would break a
streak.

**`wasSkipped` is not a deletion.** A skipped laundry Saturday keeps the
fortnightly rhythm intact and stays out of quota counts. Three states —
untouched, done, skipped — not two.

**`DaySchedule` has exactly seven rows**, one per weekday, enforced by
`@Attribute(.unique)` on `weekday`. They are seeded on first launch and only
ever edited.

**`WorkPlace` has at most one row**, created lazily the first time Setup is
opened, so an install that never uses the geofence carries no location data at
all.

**Enums are stored as raw strings**, not integers, with a `stored(_:)` fallback
on each. A value that is no longer recognised degrades to a sensible default
rather than crashing or silently becoming the wrong case.

**Everything has a default value.** SwiftData needs them for lightweight
migration, so a new field can be added without a migration plan.
