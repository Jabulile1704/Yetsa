# Contributing to Yetsa

Yetsa is a personal planner, and for now it has one developer. These notes
exist so the rules the repository enforces are written down somewhere other
than a settings page, and so a second developer — or the same one in six
months — can work out what the gates are for.

## The shape of a change

1. Branch from `main`.
2. Make the change, and add or adjust tests for anything in `Yetsa/Support`
   or `Yetsa/Models`. Those two folders hold the logic the app is actually
   wrong or right about: recurrence, window budgets, snooze arithmetic,
   export. The views are checked by looking at them on a phone.
3. Open a pull request using the template.
4. Both checks must go green, then merge.

Commit messages explain *why*. The diff already says what changed.

## What `main` enforces

Branch protection on `main` is set so that:

- **"Build and test" and "Lint" must pass** before a pull request can merge,
  and the branch must be up to date with `main` first.
- **Force pushes and branch deletion are refused.**
- **History stays linear** — merges are squash or rebase, never a merge
  commit. This keeps the log readable and keeps every commit attributable to
  one author.
- **Conversation resolution is required**, so review comments cannot be
  merged past silently.

Two things it deliberately does *not* do:

- **Reviews are not required.** A solo repository cannot approve its own
  pull requests, so requiring an approval would mean nothing could ever
  merge.
- **Administrators are not included.** The repository owner can still push
  straight to `main`; git prints a "bypassed rule violations" notice when
  that happens, which is the point — the bypass is visible rather than
  silent. Day-to-day work should still go through a branch.

## The checks

**Build and test** (`.github/workflows/ci.yml`) builds the app and runs the
XCTest suite on the newest iPhone simulator the runner offers, resolved at
run time rather than hardcoded, because the runner image's simulator list
changes without warning.

**Lint** runs SwiftLint against `.swiftlint.yml`. The config has two tiers
on purpose:

- *Warnings* are advice. Long lines, a long file, a function with too many
  parameters. They appear in the job's annotations and do not fail it.
- *Errors* are a gate. A line past 160 characters, a file past 800 lines, or
  one of SwiftLint's own error-severity rules. These stop the job.

If an error-severity rule is wrong about a particular line, fix the line so
the question does not arise, or argue it out in the config with a comment
saying why. Do not silence a rule in passing.

## Releasing

Releases are tags. `.github/workflows/release.yml` refuses a tag whose name
disagrees with `MARKETING_VERSION` in the project, so the two cannot drift:

```
# bump MARKETING_VERSION in Yetsa.xcodeproj, move the CHANGELOG entry out
# of Unreleased, commit, then:
git tag v1.0.1 && git push origin v1.0.1
```

The workflow re-runs the tests, builds a Release simulator binary, takes the
release notes from that version's `CHANGELOG.md` section, and publishes the
GitHub release.

## Where things live

| Path | What it is |
| --- | --- |
| `Yetsa/Models/` | SwiftData models and the small value types around them |
| `Yetsa/Support/` | The engine: planning, recurrence, alarms, notifications, location, export |
| `Yetsa/Views/` | SwiftUI screens |
| `YetsaTests/` | XCTest suites for the engine |
| `Docs/` | Architecture, ERD, use cases |
| `Design/icons/` | Icon source SVGs, shipped and archived |
| `Tools/` | `MakeIcon.swift`, which renders the app icon PNGs |

`Docs/Architecture.md` is the place to start if you want to know why the app
is built around a scaffold of fixed anchors with windows between them.
