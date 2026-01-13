import Foundation
import HealthKit

// MARK: - Sleep Data

struct SleepData {
    var totalDuration: TimeInterval = 0
    var deepSleep: TimeInterval = 0
    var remSleep: TimeInterval = 0
    var coreSleep: TimeInterval = 0

    var hasData: Bool {
        totalDuration > 0 || deepSleep > 0 || remSleep > 0 || coreSleep > 0
    }
}

// MARK: - Activity Data

struct ActivityData {
    var steps: Int?
    var activeCalories: Double?
    var exerciseMinutes: Double?
    var flightsClimbed: Int?
    var walkingRunningDistance: Double? // in meters

    var hasData: Bool {
        steps != nil || activeCalories != nil || exerciseMinutes != nil ||
        flightsClimbed != nil || walkingRunningDistance != nil
    }
}

// MARK: - Vitals Data

struct VitalsData {
    var restingHeartRate: Double?
    var hrv: Double? // in milliseconds
    var respiratoryRate: Double?
    var bloodOxygen: Double? // as percentage

    var hasData: Bool {
        restingHeartRate != nil || hrv != nil || respiratoryRate != nil || bloodOxygen != nil
    }
}

// MARK: - Body Data

struct BodyData {
    var weight: Double? // in kg
    var bodyFatPercentage: Double?

    var hasData: Bool {
        weight != nil || bodyFatPercentage != nil
    }
}

// MARK: - Workout Data

struct WorkoutData: Identifiable {
    let id = UUID()
    let workoutType: HKWorkoutActivityType
    let startTime: Date
    let duration: TimeInterval
    let calories: Double?
    let distance: Double? // in meters

    var workoutTypeName: String {
        switch workoutType {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .hiking: return "Hiking"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Strength Training"
        case .coreTraining: return "Core Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climbing"
        case .pilates: return "Pilates"
        case .dance: return "Dance"
        case .cooldown: return "Cooldown"
        case .mixedCardio: return "Mixed Cardio"
        case .socialDance: return "Social Dance"
        case .pickleball: return "Pickleball"
        case .tennis: return "Tennis"
        case .badminton: return "Badminton"
        case .tableTennis: return "Table Tennis"
        case .golf: return "Golf"
        case .soccer: return "Soccer"
        case .basketball: return "Basketball"
        case .baseball: return "Baseball"
        case .softball: return "Softball"
        case .volleyball: return "Volleyball"
        case .americanFootball: return "American Football"
        case .rugby: return "Rugby"
        case .hockey: return "Hockey"
        case .lacrosse: return "Lacrosse"
        case .skatingSports: return "Skating"
        case .snowSports: return "Snow Sports"
        case .waterSports: return "Water Sports"
        case .martialArts: return "Martial Arts"
        case .boxing: return "Boxing"
        case .kickboxing: return "Kickboxing"
        case .wrestling: return "Wrestling"
        case .climbing: return "Climbing"
        case .jumpRope: return "Jump Rope"
        case .mindAndBody: return "Mind & Body"
        case .flexibility: return "Flexibility"
        case .other: return "Other"
        default: return "Workout"
        }
    }
}

// MARK: - Complete Health Data

struct HealthData {
    let date: Date
    var sleep: SleepData = SleepData()
    var activity: ActivityData = ActivityData()
    var vitals: VitalsData = VitalsData()
    var body: BodyData = BodyData()
    var workouts: [WorkoutData] = []

    var hasAnyData: Bool {
        sleep.hasData || activity.hasData || vitals.hasData || body.hasData || !workouts.isEmpty
    }
}

// MARK: - Markdown Export

extension HealthData {
    func toMarkdown() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        var markdown = """
        ---
        date: \(dateString)
        type: health-data
        ---

        # Health Data — \(dateString)

        """

        // Sleep Section
        if sleep.hasData {
            markdown += "\n## Sleep\n\n"
            if sleep.totalDuration > 0 {
                markdown += "- **Total:** \(formatDuration(sleep.totalDuration))\n"
            }
            if sleep.deepSleep > 0 {
                markdown += "- **Deep:** \(formatDuration(sleep.deepSleep))\n"
            }
            if sleep.remSleep > 0 {
                markdown += "- **REM:** \(formatDuration(sleep.remSleep))\n"
            }
            if sleep.coreSleep > 0 {
                markdown += "- **Core:** \(formatDuration(sleep.coreSleep))\n"
            }
        }

        // Activity Section
        if activity.hasData {
            markdown += "\n## Activity\n\n"
            if let steps = activity.steps {
                markdown += "- **Steps:** \(formatNumber(steps))\n"
            }
            if let calories = activity.activeCalories {
                markdown += "- **Active Calories:** \(formatNumber(Int(calories))) kcal\n"
            }
            if let exercise = activity.exerciseMinutes {
                markdown += "- **Exercise:** \(Int(exercise)) min\n"
            }
            if let flights = activity.flightsClimbed {
                markdown += "- **Flights Climbed:** \(flights)\n"
            }
            if let distance = activity.walkingRunningDistance {
                markdown += "- **Distance:** \(formatDistance(distance))\n"
            }
        }

        // Vitals Section
        if vitals.hasData {
            markdown += "\n## Vitals\n\n"
            if let hr = vitals.restingHeartRate {
                markdown += "- **Resting HR:** \(Int(hr)) bpm\n"
            }
            if let hrv = vitals.hrv {
                markdown += "- **HRV:** \(String(format: "%.1f", hrv)) ms\n"
            }
            if let rr = vitals.respiratoryRate {
                markdown += "- **Respiratory Rate:** \(String(format: "%.1f", rr)) breaths/min\n"
            }
            if let spo2 = vitals.bloodOxygen {
                markdown += "- **SpO2:** \(Int(spo2 * 100))%\n"
            }
        }

        // Body Section
        if body.hasData {
            markdown += "\n## Body\n\n"
            if let weight = body.weight {
                markdown += "- **Weight:** \(String(format: "%.1f", weight)) kg\n"
            }
            if let bodyFat = body.bodyFatPercentage {
                markdown += "- **Body Fat:** \(String(format: "%.1f", bodyFat * 100))%\n"
            }
        }

        // Workouts Section
        if !workouts.isEmpty {
            markdown += "\n## Workouts\n"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"

            for (index, workout) in workouts.enumerated() {
                markdown += "\n### \(index + 1). \(workout.workoutTypeName)\n\n"
                markdown += "- **Time:** \(timeFormatter.string(from: workout.startTime))\n"
                markdown += "- **Duration:** \(formatDurationShort(workout.duration))\n"
                if let distance = workout.distance, distance > 0 {
                    markdown += "- **Distance:** \(formatDistance(distance))\n"
                }
                if let calories = workout.calories, calories > 0 {
                    markdown += "- **Calories:** \(Int(calories)) kcal\n"
                }
            }
        }

        return markdown
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func formatDurationShort(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters)) m"
    }
}
