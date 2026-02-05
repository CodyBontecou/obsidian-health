# Universal Granular Tracking System

## Overview

Extend Health.md to support **individual timestamped entries** for any health metric, in addition to daily aggregated summaries. Users can opt-in per metric or enable globally.

## Current State

The app already has:
- `HealthMetricDefinition.aggregation: AggregationType` (cumulative, discreteAvg, mostRecent, etc.)
- `MetricSelectionState` for enabling/disabling metrics
- Daily export to a single file per day

## Proposed Architecture

### 1. New Settings Model

```swift
// IndividualTrackingSettings.swift

/// Controls whether individual timestamped files are created for metrics
class IndividualTrackingSettings: ObservableObject, Codable {
    /// Global toggle - master switch for individual tracking
    @Published var globalEnabled: Bool = false
    
    /// Per-metric individual tracking (metric ID → enabled)
    @Published var metricSettings: [String: MetricTrackingConfig] = [:]
    
    /// Default folder for individual entries (relative to export root)
    @Published var defaultFolder: String = "entries"
    
    /// Use category-based subfolders (entries/mood/, entries/exercise/)
    @Published var useCategoryFolders: Bool = true
}

struct MetricTrackingConfig: Codable {
    var trackIndividually: Bool = false
    var customFolder: String? = nil  // Override default folder
}
```

### 2. Aggregation Mapping (Already Exists)

Current `AggregationType` maps perfectly to summary behavior:

| AggregationType | Daily Summary | Example Metrics |
|-----------------|---------------|-----------------|
| `.cumulative` | Sum all entries | steps, calories, water |
| `.discreteAvg` | Average all entries | heart rate, mood valence |
| `.discreteMin` | Minimum value | min heart rate |
| `.discreteMax` | Maximum value | max heart rate |
| `.mostRecent` | Latest entry | weight, blood pressure |
| `.duration` | Total duration | sleep stages |
| `.count` | Count of entries | mindful sessions, symptoms |

### 3. File Structure

```
vault/
├── health/
│   └── 2026-02-05.md                    # Daily summary (aggregated)
│
├── entries/                              # Individual entries root
│   ├── mood/
│   │   ├── 2026_02_05_1030_mood.md
│   │   ├── 2026_02_05_1545_mood.md
│   │   └── 2026_02_05_2100_mood.md
│   │
│   ├── heart/
│   │   ├── 2026_02_05_0800_heart_rate.md
│   │   └── 2026_02_05_1400_heart_rate.md
│   │
│   ├── exercise/
│   │   └── 2026_02_05_0700_workout.md
│   │
│   ├── symptoms/
│   │   └── 2026_02_05_1400_headache.md
│   │
│   └── vitals/
│       └── 2026_02_05_0900_blood_pressure.md
```

### 4. Individual Entry Schema

Generic timestamped entry format:

```yaml
---
date: 2026-02-05
time: "10:30"
datetime: 2026-02-05T10:30:00
type: <category>           # mood, heart, vitals, etc.
metric: <metric_id>        # heart_rate_avg, daily_mood, etc.

# Metric-specific fields
value: <primary_value>
unit: <unit>

# Optional context (varies by metric type)
source: "Apple Watch"
# ... additional metric-specific fields
---

Optional freeform notes.
```

#### Examples by Metric Type

**Mood Entry:**
```yaml
---
date: 2026-02-05
time: "10:30"
datetime: 2026-02-05T10:30:00
type: mindfulness
metric: daily_mood
valence: 0.7
feeling: pleasant
labels:
  - happy
  - calm
associations:
  - work
---
```

**Heart Rate Entry:**
```yaml
---
date: 2026-02-05
time: "14:30"
datetime: 2026-02-05T14:30:00
type: heart
metric: heart_rate
value: 72
unit: bpm
source: "Apple Watch"
context: resting
---
```

**Workout Entry:**
```yaml
---
date: 2026-02-05
time: "07:00"
datetime: 2026-02-05T07:00:00
type: workout
metric: workout
workout_type: Running
duration: 32
duration_unit: min
calories: 287
distance: 5.2
distance_unit: km
---
```

**Symptom Entry:**
```yaml
---
date: 2026-02-05
time: "14:00"
datetime: 2026-02-05T14:00:00
type: symptoms
metric: symptom_headache
severity: moderate
---
```

### 5. Daily Summary Integration

When individual tracking is enabled, the daily file references the entries:

```yaml
---
date: 2026-02-05
# ... aggregated metrics

# Summary from individual entries
mood_average_valence: 0.65
mood_entry_count: 3
heart_rate_samples: 12
symptom_occurrences:
  - headache
  - fatigue
---
```

### 6. UI Design

#### Settings Hierarchy

```
Export Settings
├── Individual Entry Tracking
│   ├── [Toggle] Enable Detailed Tracking (Global)
│   ├── Default Folder: [entries]
│   ├── [Toggle] Organize by Category
│   │
│   └── Per-Metric Settings (expandable when global ON)
│       ├── Mindfulness
│       │   ├── [Toggle] Daily Mood
│       │   ├── [Toggle] Momentary Emotions
│       │   └── [Toggle] Mindful Sessions
│       ├── Heart
│       │   ├── [Toggle] Heart Rate
│       │   └── [Toggle] HRV
│       ├── Symptoms
│       │   └── [Toggle] All Symptoms
│       └── ... other categories
```

#### Quick Actions

- **"Track All"** - Enable individual tracking for all metrics
- **"Track None"** - Disable all individual tracking
- **"Suggested"** - Enable for commonly tracked metrics (mood, symptoms, workouts)

### 7. Implementation Phases

#### Phase 1: Core Infrastructure
1. Add `IndividualTrackingSettings` model
2. Create `IndividualEntryExporter` class
3. Add settings persistence
4. Build settings UI

#### Phase 2: Export Integration
1. Modify `HealthKitManager` to capture individual samples with timestamps
2. Create individual entry file writer
3. Update daily export to calculate aggregates from entries
4. Add filename templating for individual entries

#### Phase 3: Polish
1. Entry count badges in UI
2. Preview of individual entry format
3. Migration for existing users
4. Documentation

### 8. Settings Storage

```swift
// Keys for UserDefaults
private let individualTrackingKey = "export.individualTracking"
private let globalEnabledKey = "export.individualTracking.globalEnabled"
private let metricSettingsKey = "export.individualTracking.metricSettings"
```

### 9. File Naming Convention

Pattern: `{YYYY}_{MM}_{DD}_{HHMM}_{metric_id}.md`

Examples:
- `2026_02_05_1030_daily_mood.md`
- `2026_02_05_1400_heart_rate.md`
- `2026_02_05_0700_workout.md`

Configurable via template: `{date}_{time}_{metric}`

### 10. Backwards Compatibility

- Default: Individual tracking OFF (existing behavior)
- Only affects future exports when enabled
- Daily summary files unchanged in structure
- No breaking changes for existing vault exports

## Implementation Status

### ✅ Phase 1: Core Infrastructure (Complete)
- `IndividualTrackingSettings` model
- Settings persistence
- `IndividualTrackingView` UI

### ✅ Phase 2: Export Integration (Complete)
- `IndividualEntryExporter` class
- State of Mind, Workouts, BP, Glucose, Weight support
- VaultManager integration

### ✅ Phase 3: Polish (Complete)
- Export modal preview section
- Badge counts in settings UI
- Documentation

## Supported Metrics

Currently, the following metrics support individual entry export:

| Metric | Timestamp Source | Fields Captured |
|--------|-----------------|-----------------|
| Daily Mood | HealthKit State of Mind | valence, feeling, labels, associations |
| Momentary Emotions | HealthKit State of Mind | valence, feeling, labels, associations |
| Workouts | HealthKit Workout | type, duration, calories, distance |
| Blood Pressure | Daily (needs enhancement) | systolic, diastolic |
| Blood Glucose | Daily (needs enhancement) | value, unit |
| Weight | Daily (needs enhancement) | value, unit |

## Future Enhancements

1. **Enhanced HealthKit queries**: Fetch individual samples with real timestamps for metrics like blood pressure, glucose (currently uses daily date)
2. **Obsidian wikilinks**: Option to add `[[entry links]]` in daily summary
3. **Retention policy**: Auto-cleanup of old individual entries
4. **Batch individual fetching**: More efficient querying for large date ranges
