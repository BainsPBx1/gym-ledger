# Gym Ledger

A local-first gym & nutrition tracker. **No accounts, no cloud, no login — your
data never leaves your phone.** Flutter, iOS + Android.

The aesthetic is *gym ledger meets arcade scoreboard*: cream ledger paper with
ruled lines, chunky borders and rubber-stamp CTAs in light mode; a near-black
CRT with scanlines, glowing amber and rust-red negatives in dark mode. Both
modes share identical structure — dark is a re-skin, not a different app.

## Features

**Onboarding** — first launch goes straight into 3 quick questions (goal:
cut/bulk/maintain, activity level, current weight) that auto-calculate
calorie/macro targets. Editable any time in *More › Targets*.

**Nutrition** — no pre-loaded food database; every food is user-created.
- Barcode scan is a **local key only** — never looked up externally. Known
  code → instant log; unknown code → new-food form keyed to it.
- Nutrition label photo → **on-device OCR** (ML Kit, fully offline) extracts
  calories/macros into an editable confirmation form before saving.
- Meal photo matching: snap a meal you've logged before; an on-device
  perceptual hash (dHash) finds look-alike prior entries and auto-fills
  nutrients.
- Daily view shows calories and protein/carbs/fat against target, plus a
  tally-mark logging streak.

**Workouts** — user-built templates (e.g. Push/Pull/Legs), switchable in one
tap. Each template holds an ordered exercise list with per-exercise rest
timers. Set weights pre-fill from the last session. **A saved set is locked
permanently** — enforced in the UI, the DAO (insert-only), *and* SQLite
triggers. Full-screen rest countdown with +15s, skip, and next-exercise
preview.

**PRs** — separate from set logging: exercise, weight, date, optional
photo/video. Celebratory full-screen stamp on save; scoreboard-style Hall of
Fame, most recent at the top.

**Monthly graph** (the signature screen) — calories/macros and workout
consistency in one view. Days with no log at all dip **below the center
baseline** as rust-red negative bars, visibly distinct from days logged but
off target. Pixel display face for the big numbers.

**Reminders, not location** — no location permission, no geofencing. Recurring
gym windows (e.g. 5–7 PM Mon/Wed/Fri); if no workout has started by the nudge
point, a local notification fires. Snooze re-fires later the same day.

**Storage management** — breakdown screen (meals / workouts / photos / PR
media), photo compression on save (≤1280 px JPEG q80), auto-archival of
meal-level detail older than 12 months into monthly summaries (workouts and
PRs stay detailed forever), and manual JSON/CSV export with a gentle backup
nudge when the last export is >30 days old.

**Privacy** — contextual permissions only (camera at scan time, notifications
when a gym window is created, biometrics when the app lock is toggled). The
Android manifest deliberately omits `INTERNET`.

## Getting started

Prereqs: [Flutter](https://docs.flutter.dev/get-started/install) on the
`stable` channel. This repo was built and tested against Flutter 3.44 /
Dart 3.12.

```sh
flutter pub get
flutter analyze       # clean
flutter test          # 34 unit + widget tests
```

### Run on a device

```sh
# Android (needs Android Studio / SDK + a device or emulator)
flutter run

# Release APK
flutter build apk

# iOS (needs a Mac with Xcode)
flutter build ios
```

Fonts (IBM Plex Sans, Space Mono, VT323 — OFL-licensed) are bundled in
`assets/fonts`, so the app is fully offline from first launch.

## Architecture

```
lib/
  data/        SQLite schema (db.dart), typed DAOs, models
  logic/       targets calc, monthly stats/streaks, archival, dHash
  services/    OCR, photos, notifications, export, storage, biometrics
  state/       Riverpod providers
  theme/       ledger/scoreboard palettes + type (grotesk / mono / pixel)
  widgets/     stamp buttons, ledger cards, tally marks, pixel numbers
  screens/     onboarding, today, workout, graph, PRs, more
```

- **Storage**: SQLite via `sqflite` with a hand-written typed DAO layer
  (the "Drift or equivalent"); raw SQL powers the monthly aggregates and
  streak queries. Tests run against `sqflite_common_ffi` in memory.
- **Set immutability** is defense-in-depth: no edit UI, no update/delete DAO
  method, and `BEFORE UPDATE`/`BEFORE DELETE` triggers on `set_logs` that
  abort the statement.
- **Targets formula** (only 3 onboarding inputs by design): maintenance =
  bodyweight × 26/31/35/40 kcal/kg by activity; cut −20%, bulk +10%; protein
  2.2 g/kg cutting / 1.8 g/kg otherwise; fat 25% of calories; carbs the rest.
- **Meal photo matching** is a 64-bit dHash + Hamming distance (≤12 =
  candidate match), computed entirely on-device.

## Deliberately out of scope

No accounts, no cloud sync/backend/telemetry, no Bluetooth, no Health app /
Health Connect sync, no pre-seeded food or exercise databases, and no editing
of a set after it's saved.
