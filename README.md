# Yetsa

Sesotho for *"to do"*. A personal planner for iPhone, built around the idea
that a day is not an empty list — it is a fixed scaffold with a few free
windows in it, and the only question worth answering is whether what you want
to do actually fits.

Everything is stored on the device. No account, no network, nothing leaves the
phone.

## Running it

Open `Yetsa.xcodeproj` in Xcode and press Run, or from the terminal:

```bash
xcodebuild -project Yetsa.xcodeproj -scheme Yetsa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Requires **iOS 26** or later — the UI is built on Liquid Glass
(`glassEffect`, the glass tab bar and its bottom accessory), which does not
exist on earlier releases.

To put it on your own iPhone you need to sign it: open the project in Xcode,
select the Yetsa target → Signing & Capabilities, and pick your Apple ID team.

## The idea

Most todo apps ask *when?* for every task. Yetsa never asks, because it already
knows the shape of the week. Set your scaffold once — alarm, out of bed, leave
home, arrive, lunch, knock off, bed — and the day falls out of it:

| Window | Monday | What it will take |
| --- | --- | --- |
| Morning at home | 06:30 – 07:30 | `@home`, `@phone` |
| Commute in | 07:30 – 07:45 | `@phone` |
| Work — morning | 07:45 – 13:00 | `@work` |
| Lunch break | 13:00 – 13:45 | `@lunch`, `@errand`, `@phone` |
| Work — afternoon | 13:45 – 16:30 | `@work` |
| Commute home | 16:30 – 16:45 | `@phone`, `@errand` |
| Evening | 16:45 – 22:15 | `@home`, `@phone` |

Friday knocks off at 16:00 and the whole day re-lays itself. Weekends drop the
work blocks and split into morning, afternoon and evening instead.

Every task carries a time estimate, so each window can say the one thing that
matters: **45 min of 1h planned — 15 min free**. Over-fill a window and the bar
turns red and the day tells you before the morning does.

## What's here

| Screen | What it does |
| --- | --- |
| **Today** | The scaffold with your tasks poured into it. Each free window shows its capacity, what is planned against it, and what is left. Anchors sit between the windows as a timeline. |
| **Morning run** | The get-out-the-door sequence as one screen: a countdown to the door, numbered steps, big targets. The number it shows is *slack* — clock left minus work left — so it says "6 min behind" rather than making you do the arithmetic half-awake. Opens from Today any day; read-only when it is not today's. |
| **Tasks** | The one-off pile, grouped by project or cohort. |
| **Routines** | Everything that comes back, grouped by how it comes back, each with its cadence and next date. |
| **Setup** | Your week, one day at a time, and which reminders are on. |

## How it looks

A grouped iOS list, monochrome. Windows are sections, the scaffold's fixed
points are section footers, and the free-time figures sit in the headers where
a stock list puts its secondary information. Under the title sits one row that
answers the only question that matters at a glance — how much of today is
actually yours:

```
15m      15m       45m      0m       4h30
Morning  To work   Lunch    Home     Evening
```

Windows behind you collapse to one line each under **Earlier**, with what you
left in them — `Morning at home 6:30 · 4 left`. Tap one to open it in place.
By the evening that is five lines instead of five sections, so the part of the
day you can still do something about starts near the top of the screen.

There is no colour anywhere except red, and red means something is wrong: a
morning running late, or a window with nothing left in it. Work sections show
their length rather than a free figure, because that time is not yours to
budget and quoting "free" minutes against it would be a lie.

## Recurrence

The part most apps get wrong, and the reason this one exists:

- **Every day** / **Weekdays** / **Weekly** — the ordinary cases.
- **Every few weeks** — anchored to a real date, not counted in days. Laundry
  every second Saturday stays on Saturdays even after you skip one. A plain
  "every 14 days" would quietly drift onto Sundays.
- **A few times a week** — a quota, not a date. "Cook twice this week" is a
  count you owe, shown as a progress pill, never an overdue task.
- **After I last did it** — counts forward from the day you ticked it, for the
  things that are about elapsed time rather than the calendar.

Skipping is its own thing, separate from missing: swipe a task right to skip
it. A skip keeps the rhythm intact and stays out of quota counts.

## Reminders

Pinned to the scaffold rather than to clock times, so Friday's earlier
knock-off needs no second setting:

| Reminder | When |
| --- | --- |
| Morning run-through | 5 min after you get out of bed |
| Leaving in 15 minutes | 15 min before the door, workdays |
| Lunch break starts | At lunch, workdays |
| Knock off | At knock-off, workdays |
| Tomorrow needs | 1h 45 before bed |
| Week review | 30 min before Friday's knock-off |

## Alarms

Reminders are polite: a Focus silences them and a sleeping person ignores them.
Three moments in the week are not negotiable, so those use **AlarmKit** instead
— real alarms that sound through silent mode and through a Focus, the same way
the Clock app's do.

| Alarm | When | Snooze |
| --- | --- | --- |
| Wake up | Your alarm time | Capped at the buffer |
| Leave home | The moment you must be out of the door | No |
| Knock off | End of the working day | No |

Only the wake-up can be snoozed. Snoozing the door just makes you late.

### The snooze runs out

An alarm you can push back forever is not an alarm. The gap between your alarm
and the time you genuinely have to move — 05:45 to 06:30, so forty-five minutes
— is divided into whole snoozes of roughly a quarter of an hour: **three
snoozes of fifteen minutes, landing exactly on 06:30**.

The cap is not enforced by counting taps, which would only work while the app
happened to be running. Switching on the wake-up quietly schedules a second
alarm at your out-of-bed time **with no snooze button on it at all**. Snooze
through the whole buffer and you arrive at an alarm that offers nothing but
Stop. The hard stop has no setting of its own; it comes and goes with the
wake-up, and shows as a bell on the Out of bed row in Today.

Integer division does the work: the snooze chain always lands on the buffer or
just inside it, never past it. A buffer under two minutes gets no snooze button
at all.

Alarms are grouped by time rather than by day, so Monday to Thursday share one
weekly alarm and Friday gets its own because it ends half an hour earlier —
`16:00 Fri · 16:30 Mon–Thu`. That keeps the count down, which matters because
AlarmKit caps how many alarms an app may hold.

All three follow `isWorkday`, so weekends stay quiet unless you mark one as a
working day in Setup. They are off until you switch them on; an app that starts
making noise at 05:45 uninvited is not a good houseguest.

AlarmKit needs iOS 26.1, which is why that is the deployment target.

## Estimate honesty

Completions can record what something really took. Once a task has three
measured completions that disagree with its estimate by a quarter or more, the
row quietly switches to the real number with a `~` in front of it. The budget
corrects itself rather than you having to notice.

## Layout

```
Yetsa/
  Models/      TaskItem, Completion, DaySchedule, and the three enums
               (TaskContext, WindowKind, RecurrenceKind) that drive everything
  Support/     Clock, RecurrenceEngine, DayPlan + DayPlanner, PlanBuilder,
               MorningRun, NotificationScheduler, Seed, Palette
  Views/       RootView, TodayView, MorningRunView, TasksView, RoutinesView,
               SetupView, TaskFormView, TaskRow, BudgetBar
```

`DayPlanner` is the centre of it: it builds the windows from a `DaySchedule`,
asks `RecurrenceEngine` what is due, and pours the tasks in — each one into the
window it asked for, or the first window that will take its context.

## Not in this version

Accounts and sync, sub-tasks and dependencies, calendar import, automatic
scheduling, widgets and Live Activities.
