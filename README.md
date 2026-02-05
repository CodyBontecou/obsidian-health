# Health.md

[Download on the App Store](https://apps.apple.com/us/app/health-md/id6757763969)

Health.md is an iOS app that exports Apple Health data to your device's filesystem as human‑readable Markdown (or structured JSON/CSV). Your health data stays local and accessible in the Files app or any markdown-compatible app.

## What's Included

- **iOS app (SwiftUI)**: Collects HealthKit metrics and exports them to your device with configurable formats, filenames, and schedules.

## Features

### iOS App
- **HealthKit export** for sleep, activity, vitals, body measurements, and workouts.
- **Manual export** for a date range with progress and error handling.
- **Scheduled exports** (daily or weekly) using Background Tasks + HealthKit background delivery.
- **Export history** with retry support for failed dates.
- **Flexible formats**: Markdown, frontmatter-based Markdown, JSON, or CSV.
- **Custom filename templates** (e.g. `{date}`, `{year}`, `{month}`, `{weekday}`).
- **Folder picker** with optional `Health` subfolder organization.

## Supported Data

- **Sleep**: total, deep, REM, core
- **Activity**: steps, active calories, exercise minutes, flights climbed, walking/running distance
- **Vitals**: resting heart rate, HRV, respiratory rate, blood oxygen
- **Body**: weight, body fat percentage
- **Workouts**: type, start time, duration, calories, distance

## Export Formats

- **Markdown** with optional frontmatter and grouped sections
- **Frontmatter-only** (metrics in YAML frontmatter for querying)
- **JSON** (structured output for analysis)
- **CSV** (one row per metric)

## Individual Entry Tracking

In addition to daily summaries, Health.md can create **individual timestamped files** for specific metrics. This is useful for:

- **Mood tracking**: Each mood entry gets its own file with valence, labels, and associations
- **Workouts**: Each workout saved as a separate file with duration, calories, distance
- **Vitals**: Blood pressure, glucose readings as individual entries

### How to Enable

1. Go to **Settings → Advanced → Individual Entry Tracking**
2. Toggle **Enable Individual Entry Tracking**
3. Select which metrics to track individually (or use "Enable Suggested")
4. Configure folder structure and filename template

### File Structure

```
vault/
├── Health/
│   └── 2026-02-05.md              # Daily summary
└── entries/
    ├── mindfulness/
    │   ├── 2026_02_05_1030_daily_mood.md
    │   └── 2026_02_05_1545_momentary_emotions.md
    ├── workouts/
    │   └── 2026_02_05_0700_workouts.md
    └── vitals/
        └── 2026_02_05_0900_blood_pressure.md
```

### Example Individual Entry

```yaml
---
date: 2026-02-05
time: "10:30"
datetime: 2026-02-05T10:30:00Z
type: mindfulness
metric: daily_mood
value: 0.7
feeling: Pleasant
labels:
  - Happy
  - Calm
associations:
  - Work
---
```

## Getting Started (iOS App)

### Requirements
- macOS with **Xcode**
- iOS device with Health data (HealthKit access is limited in the simulator)

### Run the App
1. Open `HealthMd.xcodeproj` in Xcode.
2. Select a real device, configure signing, and run.
3. On first launch, grant HealthKit permissions.
4. Choose your export folder (accessible via the Files app, iCloud Drive, or any location).
5. Export manually or configure scheduled exports.

### Scheduling Notes
Scheduled exports rely on iOS background task scheduling. If the device is locked, HealthKit data may be protected; the app will send a notification prompting you to tap and retry.

## Project Structure

```
.
├── HealthMd/           # SwiftUI app source
├── HealthMd.xcodeproj/ # Xcode project
```

## Privacy

All exports are written locally to your chosen folder. No health data is sent to external services.
