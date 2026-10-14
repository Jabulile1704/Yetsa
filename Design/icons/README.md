# App icon — the six concepts

What was explored before the icon was chosen, kept so the reasoning outlives
the conversation it happened in.

All six are monochrome, matching the app: black on white, white on black, and
nothing else. Each is drawn on a 100×100 grid so it scales to any size.

| File | Concept | Verdict |
| --- | --- | --- |
| `01-y-tick.svg` | A Y whose long right arm also reads as a check | **Shipped** |
| `02-day-stacked.svg` | The day as blocks, solid where spoken for, pale where free | Good, less distinct |
| `03-free-time-meters.svg` | Four tracks filled to different levels — the Today strip | Too busy; mush at 29pt |
| `04-sunrise.svg` | Half sun over a line, for the morning run | Warm, but says little about *this* app |
| `05-day-arc.svg` | A ring mostly travelled, with a mark at now | Runner-up; revisit for a widget |
| `06-one-window.svg` | One window, part spoken for | Purest, but too quiet to find |

## Why the Y-tick

It carries two meanings in one stroke — the app's name and the thing the app
does — and it is the only one of the six that survives 29pt intact. It also
pairs with Zaka's coin as a set of marks rather than competing with it.

## These are records, not the source

Editing an SVG here changes nothing about the app. The shipped icon is
generated:

```bash
swift Tools/MakeIcon.swift Yetsa/Assets.xcassets/AppIcon.appiconset
```

`01-y-tick.svg` and `01-y-tick-dark.svg` match what that script writes, centring
included — the coordinates are the drawn path shifted by (−3, −1) grid units,
which is the −30, −10 pixel nudge the generator applies at 1024. Change the
shape in the script, then update those two files to match. The other five are
frozen as they were explored.
