# Use cases

Two actors. The person, and the system — because a good deal of what Yetsa does
happens while nobody is holding the phone.

```mermaid
flowchart LR
    USER(("Jabulile<br/>facilitator"))
    SYS(("iOS<br/>time and location"))

    subgraph Daily
        UC1["See what today holds"]
        UC2["Tick or skip a task"]
        UC3["Run the morning sequence"]
        UC4["Review what is owed this week"]
    end

    subgraph Managing
        UC5["Add or edit a task"]
        UC6["Set how a task repeats"]
        UC7["Work a countable pile"]
        UC8["Browse the routines"]
    end

    subgraph Configuring
        UC9["Shape the week"]
        UC10["Choose reminders"]
        UC11["Choose alarms"]
        UC12["Set the workplace circle"]
    end

    subgraph Unattended
        UC13["Sound a wake, door or knock-off alarm"]
        UC14["Deliver a scaffold reminder"]
        UC15["Deliver the morning quote"]
        UC16["Notice arrival at work"]
    end

    USER --> UC1
    USER --> UC2
    USER --> UC3
    USER --> UC4
    USER --> UC5
    USER --> UC6
    USER --> UC7
    USER --> UC8
    USER --> UC9
    USER --> UC10
    USER --> UC11
    USER --> UC12

    SYS --> UC13
    SYS --> UC14
    SYS --> UC15
    SYS --> UC16

    UC9 -.->|reshapes| UC1
    UC9 -.->|retimes| UC13
    UC9 -.->|retimes| UC14
    UC12 -.->|enables| UC16
    UC16 -.->|records real arrival| UC1
```

## The ones worth spelling out

### See what today holds
The home screen. Windows as sections, scaffold points as footers, and a strip
of free-time figures so the evening is visible without scrolling. Windows
already behind you collapse to one line each.

### Run the morning sequence
An ordered checklist measured against the door rather than the clock. The
number it reports is **slack** — time left minus work left — so it says "2 min
behind" instead of making you do the arithmetic half awake.

### Set how a task repeats
Seven kinds. The two that matter are **every few weeks**, anchored to a real
date so skipping one does not shift the weekday, and **a few times a week**,
which is a count owed rather than a date missed.

### Shape the week
The single screen everything else derives from. Change Friday's knock-off and
the windows, the budgets, the reminders and the alarms all follow. This is why
it is the only screen that ever needs correcting when life changes shape.

### Sound an alarm
Three: wake, leave home, knock off. Only the wake-up can be snoozed, and the
snooze is capped — switching it on also schedules an unsnoozable alarm at the
out-of-bed time, so the chain cannot run past the buffer.

### Notice arrival at work
A geofence round the workplace. Crossing in records the real arrival and says
how it compared to the assumption on the scaffold. Working days only, once a
day, silent.

## Out of scope, deliberately

No accounts, no sharing, no sync, no collaboration. One person, one phone. The
moment any of those arrive, so does a server, and the app stops being something
that works on a plane.
