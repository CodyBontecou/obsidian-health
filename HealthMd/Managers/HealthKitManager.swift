import Foundation
import HealthKit
import Combine
import os.log

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    private let logger = Logger(subsystem: "com.healthexporter", category: "HealthKitManager")

    /// Active observer queries for background delivery
    private var observerQueries: [HKObserverQuery] = []

    /// Callback triggered when background delivery receives new data
    var onBackgroundDelivery: (() -> Void)?

    @Published var isAuthorized = false
    @Published var authorizationStatus: String = "Not Connected"

    // MARK: - Error Types

    enum HealthKitError: LocalizedError {
        case dataNotAvailable
        case notAuthorized
        case dataProtectedWhileLocked

        var errorDescription: String? {
            switch self {
            case .dataNotAvailable:
                return "Health data is not available on this device"
            case .notAuthorized:
                return "Health data access not authorized. Please grant permissions in Settings."
            case .dataProtectedWhileLocked:
                return "Health data is unavailable while the device is locked. Please unlock your device."
            }
        }
    }

    // MARK: - Health Data Types

    private var allReadTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()

        // Sleep
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }

        // Activity
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let activeCalories = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeCalories)
        }
        if let basalCalories = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
            types.insert(basalCalories)
        }
        if let exerciseMinutes = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exerciseMinutes)
        }
        if let standHours = HKQuantityType.quantityType(forIdentifier: .appleStandTime) {
            types.insert(standHours)
        }
        if let flights = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) {
            types.insert(flights)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let cycling = HKQuantityType.quantityType(forIdentifier: .distanceCycling) {
            types.insert(cycling)
        }
        if let swimming = HKQuantityType.quantityType(forIdentifier: .distanceSwimming) {
            types.insert(swimming)
        }
        if let strokes = HKQuantityType.quantityType(forIdentifier: .swimmingStrokeCount) {
            types.insert(strokes)
        }
        if let pushCount = HKQuantityType.quantityType(forIdentifier: .pushCount) {
            types.insert(pushCount)
        }

        // Heart
        if let restingHR = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHR)
        }
        if let walkingHR = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage) {
            types.insert(walkingHR)
        }
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }

        // Vitals
        if let respiratoryRate = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) {
            types.insert(respiratoryRate)
        }
        if let bloodOxygen = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
            types.insert(bloodOxygen)
        }
        if let bodyTemp = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) {
            types.insert(bodyTemp)
        }
        if let bloodPressureSystolic = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic) {
            types.insert(bloodPressureSystolic)
        }
        if let bloodPressureDiastolic = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) {
            types.insert(bloodPressureDiastolic)
        }
        if let bloodGlucose = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) {
            types.insert(bloodGlucose)
        }

        // Body
        if let weight = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(weight)
        }
        if let height = HKQuantityType.quantityType(forIdentifier: .height) {
            types.insert(height)
        }
        if let bmi = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) {
            types.insert(bmi)
        }
        if let bodyFat = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.insert(bodyFat)
        }
        if let leanBodyMass = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) {
            types.insert(leanBodyMass)
        }
        if let waist = HKQuantityType.quantityType(forIdentifier: .waistCircumference) {
            types.insert(waist)
        }

        // Nutrition
        if let dietaryEnergy = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            types.insert(dietaryEnergy)
        }
        if let protein = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            types.insert(protein)
        }
        if let carbs = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            types.insert(carbs)
        }
        if let fat = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) {
            types.insert(fat)
        }
        if let saturatedFat = HKQuantityType.quantityType(forIdentifier: .dietaryFatSaturated) {
            types.insert(saturatedFat)
        }
        if let fiber = HKQuantityType.quantityType(forIdentifier: .dietaryFiber) {
            types.insert(fiber)
        }
        if let sugar = HKQuantityType.quantityType(forIdentifier: .dietarySugar) {
            types.insert(sugar)
        }
        if let sodium = HKQuantityType.quantityType(forIdentifier: .dietarySodium) {
            types.insert(sodium)
        }
        if let cholesterol = HKQuantityType.quantityType(forIdentifier: .dietaryCholesterol) {
            types.insert(cholesterol)
        }
        if let water = HKQuantityType.quantityType(forIdentifier: .dietaryWater) {
            types.insert(water)
        }
        if let caffeine = HKQuantityType.quantityType(forIdentifier: .dietaryCaffeine) {
            types.insert(caffeine)
        }

        // Mindfulness
        if let mindful = HKCategoryType.categoryType(forIdentifier: .mindfulSession) {
            types.insert(mindful)
        }

        // Mobility
        if let walkingSpeed = HKQuantityType.quantityType(forIdentifier: .walkingSpeed) {
            types.insert(walkingSpeed)
        }
        if let stepLength = HKQuantityType.quantityType(forIdentifier: .walkingStepLength) {
            types.insert(stepLength)
        }
        if let doubleSupport = HKQuantityType.quantityType(forIdentifier: .walkingDoubleSupportPercentage) {
            types.insert(doubleSupport)
        }
        if let asymmetry = HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage) {
            types.insert(asymmetry)
        }
        if let stairAscent = HKQuantityType.quantityType(forIdentifier: .stairAscentSpeed) {
            types.insert(stairAscent)
        }
        if let stairDescent = HKQuantityType.quantityType(forIdentifier: .stairDescentSpeed) {
            types.insert(stairDescent)
        }
        if let sixMinWalk = HKQuantityType.quantityType(forIdentifier: .sixMinuteWalkTestDistance) {
            types.insert(sixMinWalk)
        }

        // Hearing
        if let headphoneAudio = HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure) {
            types.insert(headphoneAudio)
        }
        if let environmentalSound = HKQuantityType.quantityType(forIdentifier: .environmentalAudioExposure) {
            types.insert(environmentalSound)
        }

        // Workouts
        types.insert(HKObjectType.workoutType())

        return types
    }

    // MARK: - Authorization

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            authorizationStatus = "Health data not available"
            return
        }

        try await healthStore.requestAuthorization(toShare: [], read: allReadTypes)
        isAuthorized = true
        authorizationStatus = "Connected"
    }

    /// Checks if HealthKit data can be accessed in the current context (background or foreground)
    /// Note: For read-only apps, we cannot check authorization status because Apple hides it for privacy.
    /// authorizationStatus(for:) only reports WRITE permission status, not READ permission status.
    /// We simply verify HealthKit is available and let the queries run - if access is denied,
    /// the queries will return empty results (which is indistinguishable from no data).
    private func checkAuthorizationForBackgroundAccess() throws {
        guard isHealthDataAvailable else {
            throw HealthKitError.dataNotAvailable
        }
        // For read-only access, we cannot determine if the user granted permission.
        // Apple intentionally hides this for privacy - denied access looks like empty data.
        // Just proceed with queries; they will return empty results if access is denied.
    }

    // MARK: - Background Delivery

    /// Data types to monitor for background delivery (most likely to trigger daily exports)
    private var backgroundDeliveryTypes: [HKSampleType] {
        var types: [HKSampleType] = []

        // Sleep analysis - triggers when sleep data syncs (usually morning)
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.append(sleepType)
        }

        // Steps - triggers frequently throughout the day
        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.append(stepsType)
        }

        return types
    }

    /// Enables background delivery for key health data types
    /// Call this after authorization is granted
    func enableBackgroundDelivery() async {
        guard isHealthDataAvailable else {
            logger.warning("Health data not available, skipping background delivery setup")
            return
        }

        for sampleType in backgroundDeliveryTypes {
            do {
                // Use .hourly frequency to balance reliability with battery
                try await healthStore.enableBackgroundDelivery(for: sampleType, frequency: .hourly)
                logger.info("Enabled background delivery for \(sampleType.identifier)")
            } catch {
                logger.error("Failed to enable background delivery for \(sampleType.identifier): \(error.localizedDescription)")
            }
        }
    }

    /// Disables all background delivery
    func disableBackgroundDelivery() async {
        do {
            try await healthStore.disableAllBackgroundDelivery()
            logger.info("Disabled all background delivery")
        } catch {
            logger.error("Failed to disable background delivery: \(error.localizedDescription)")
        }
    }

    /// Sets up observer queries for background delivery
    /// These queries will wake the app when new health data arrives
    func setupObserverQueries() {
        // Remove any existing queries first
        stopObserverQueries()

        for sampleType in backgroundDeliveryTypes {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] query, completionHandler, error in
                guard let self = self else {
                    completionHandler()
                    return
                }

                if let error = error {
                    self.logger.error("Observer query error for \(sampleType.identifier): \(error.localizedDescription)")
                    completionHandler()
                    return
                }

                self.logger.info("Background delivery triggered for \(sampleType.identifier)")

                // Notify that new data is available
                Task { @MainActor in
                    self.onBackgroundDelivery?()
                }

                // Important: Must call completion handler
                completionHandler()
            }

            healthStore.execute(query)
            observerQueries.append(query)
            logger.info("Started observer query for \(sampleType.identifier)")
        }
    }

    /// Stops all observer queries
    func stopObserverQueries() {
        for query in observerQueries {
            healthStore.stop(query)
        }
        observerQueries.removeAll()
        logger.info("Stopped all observer queries")
    }

    // MARK: - Fetch All Health Data

    func fetchHealthData(for date: Date) async throws -> HealthData {
        var healthData = HealthData(date: date)

        // Check authorization before attempting to query
        // This is especially important in background contexts
        try checkAuthorizationForBackgroundAccess()

        do {
            // Fetch all data concurrently
            async let sleepData = fetchSleepData(for: date)
            async let activityData = fetchActivityData(for: date)
            async let heartData = fetchHeartData(for: date)
            async let vitalsData = fetchVitalsData(for: date)
            async let bodyData = fetchBodyData(for: date)
            async let nutritionData = fetchNutritionData(for: date)
            async let mindfulnessData = fetchMindfulnessData(for: date)
            async let mobilityData = fetchMobilityData(for: date)
            async let hearingData = fetchHearingData(for: date)
            async let workoutsData = fetchWorkouts(for: date)

            healthData.sleep = try await sleepData
            healthData.activity = try await activityData
            healthData.heart = try await heartData
            healthData.vitals = try await vitalsData
            healthData.body = try await bodyData
            healthData.nutrition = try await nutritionData
            healthData.mindfulness = try await mindfulnessData
            healthData.mobility = try await mobilityData
            healthData.hearing = try await hearingData
            healthData.workouts = try await workoutsData

            return healthData
        } catch {
            // If we get an error that suggests data protection (device locked),
            // throw a more specific error
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("protected") ||
               errorMessage.contains("authorization") ||
               errorMessage.contains("not authorized") {
                logger.error("HealthKit query failed (likely device locked): \(error.localizedDescription)")
                throw HealthKitError.dataProtectedWhileLocked
            }
            throw error
        }
    }

    // MARK: - Sleep Data

    private func fetchSleepData(for date: Date) async throws -> SleepData {
        var sleepData = SleepData()

        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return sleepData
        }

        // Get sleep samples for the night ending on the selected date
        // Sleep typically spans midnight, so we look from 6pm the day before to 12pm on the selected date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let sleepWindowStart = calendar.date(byAdding: .hour, value: -6, to: startOfDay)!
        let sleepWindowEnd = calendar.date(byAdding: .hour, value: 12, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: sleepWindowStart, end: sleepWindowEnd)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        let samples = try await descriptor.result(for: healthStore)

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)

            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                sleepData.deepSleep += duration
                sleepData.totalDuration += duration
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                sleepData.remSleep += duration
                sleepData.totalDuration += duration
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                sleepData.coreSleep += duration
                sleepData.totalDuration += duration
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                sleepData.totalDuration += duration
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                sleepData.awakeTime += duration
            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                sleepData.inBedTime += duration
            default:
                break
            }
        }

        return sleepData
    }

    // MARK: - Activity Data

    private func fetchActivityData(for date: Date) async throws -> ActivityData {
        var activityData = ActivityData()

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)

        // Steps
        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let stepsDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: stepsType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await stepsDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                activityData.steps = Int(sum.doubleValue(for: .count()))
            }
        }

        // Active Calories
        if let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let caloriesDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: caloriesType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await caloriesDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                activityData.activeCalories = sum.doubleValue(for: .kilocalorie())
            }
        }

        // Basal Energy Burned
        if let basalType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
            let basalDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: basalType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await basalDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                activityData.basalEnergyBurned = sum.doubleValue(for: .kilocalorie())
            }
        }

        // Exercise Minutes
        if let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            let exerciseDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: exerciseType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await exerciseDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                activityData.exerciseMinutes = sum.doubleValue(for: .minute())
            }
        }

        // Stand Time (converted to hours)
        if let standType = HKQuantityType.quantityType(forIdentifier: .appleStandTime) {
            let standDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: standType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await standDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                let minutes = sum.doubleValue(for: .minute())
                activityData.standHours = Int(minutes / 60)
            }
        }

        // Flights Climbed
        if let flightsType = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) {
            let flightsDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: flightsType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await flightsDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                activityData.flightsClimbed = Int(sum.doubleValue(for: .count()))
            }
        }

        // Walking/Running Distance
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            let distanceDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: distanceType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await distanceDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                activityData.walkingRunningDistance = sum.doubleValue(for: .meter())
            }
        }

        // Cycling Distance
        if let cyclingType = HKQuantityType.quantityType(forIdentifier: .distanceCycling) {
            let cyclingDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: cyclingType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await cyclingDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                activityData.cyclingDistance = sum.doubleValue(for: .meter())
            }
        }

        // Swimming Distance
        if let swimmingType = HKQuantityType.quantityType(forIdentifier: .distanceSwimming) {
            let swimmingDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: swimmingType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await swimmingDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                activityData.swimmingDistance = sum.doubleValue(for: .meter())
            }
        }

        // Swimming Strokes
        if let strokesType = HKQuantityType.quantityType(forIdentifier: .swimmingStrokeCount) {
            let strokesDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: strokesType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await strokesDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                activityData.swimmingStrokes = Int(sum.doubleValue(for: .count()))
            }
        }

        // Wheelchair Push Count
        if let pushType = HKQuantityType.quantityType(forIdentifier: .pushCount) {
            let pushDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: pushType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await pushDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                activityData.pushCount = Int(sum.doubleValue(for: .count()))
            }
        }

        return activityData
    }

    // MARK: - Heart Data

    private func fetchHeartData(for date: Date) async throws -> HeartData {
        var heartData = HeartData()

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)

        // Resting Heart Rate
        if let hrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            let hrDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: hrType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: 1
            )
            if let sample = try await hrDescriptor.result(for: healthStore).first {
                heartData.restingHeartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            }
        }

        // Walking Heart Rate Average
        if let walkingHRType = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage) {
            let walkingHRDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: walkingHRType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: 1
            )
            if let sample = try await walkingHRDescriptor.result(for: healthStore).first {
                heartData.walkingHeartRateAverage = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            }
        }

        // Heart Rate (average, min, max for the day)
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            let avgDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: heartRateType, predicate: predicate),
                options: [.discreteAverage, .discreteMin, .discreteMax]
            )
            if let result = try await avgDescriptor.result(for: healthStore) {
                if let avg = result.averageQuantity() {
                    heartData.averageHeartRate = avg.doubleValue(for: HKUnit(from: "count/min"))
                }
                if let min = result.minimumQuantity() {
                    heartData.heartRateMin = min.doubleValue(for: HKUnit(from: "count/min"))
                }
                if let max = result.maximumQuantity() {
                    heartData.heartRateMax = max.doubleValue(for: HKUnit(from: "count/min"))
                }
            }
        }

        // HRV
        if let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            let hrvDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: hrvType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: 1
            )
            if let sample = try await hrvDescriptor.result(for: healthStore).first {
                heartData.hrv = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
            }
        }

        return heartData
    }

    // MARK: - Vitals Data

    private func fetchVitalsData(for date: Date) async throws -> VitalsData {
        var vitalsData = VitalsData()

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)

        // Respiratory Rate
        if let rrType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) {
            let rrDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: rrType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: 1
            )
            if let sample = try await rrDescriptor.result(for: healthStore).first {
                vitalsData.respiratoryRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            }
        }

        // Blood Oxygen (SpO2)
        if let spo2Type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
            let spo2Descriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: spo2Type, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: 1
            )
            if let sample = try await spo2Descriptor.result(for: healthStore).first {
                vitalsData.bloodOxygen = sample.quantity.doubleValue(for: .percent())
            }
        }

        // Body Temperature
        if let tempType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) {
            let tempDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: tempType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: 1
            )
            if let sample = try await tempDescriptor.result(for: healthStore).first {
                vitalsData.bodyTemperature = sample.quantity.doubleValue(for: .degreeCelsius())
            }
        }

        // Blood Pressure Systolic
        if let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic) {
            let systolicDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: systolicType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: 1
            )
            if let sample = try await systolicDescriptor.result(for: healthStore).first {
                vitalsData.bloodPressureSystolic = sample.quantity.doubleValue(for: .millimeterOfMercury())
            }
        }

        // Blood Pressure Diastolic
        if let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) {
            let diastolicDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: diastolicType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: 1
            )
            if let sample = try await diastolicDescriptor.result(for: healthStore).first {
                vitalsData.bloodPressureDiastolic = sample.quantity.doubleValue(for: .millimeterOfMercury())
            }
        }

        // Blood Glucose
        if let glucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) {
            let glucoseDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: glucoseType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: 1
            )
            if let sample = try await glucoseDescriptor.result(for: healthStore).first {
                vitalsData.bloodGlucose = sample.quantity.doubleValue(for: HKUnit(from: "mg/dL"))
            }
        }

        return vitalsData
    }

    // MARK: - Body Data

    private func fetchBodyData(for date: Date) async throws -> BodyData {
        var bodyData = BodyData()

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)

        // Weight
        if let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            let weightDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: weightType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: 1
            )
            if let sample = try await weightDescriptor.result(for: healthStore).first {
                bodyData.weight = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            }
        }

        // Height
        if let heightType = HKQuantityType.quantityType(forIdentifier: .height) {
            let heightDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: heightType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: 1
            )
            if let sample = try await heightDescriptor.result(for: healthStore).first {
                bodyData.height = sample.quantity.doubleValue(for: .meter())
            }
        }

        // BMI
        if let bmiType = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) {
            let bmiDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: bmiType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: 1
            )
            if let sample = try await bmiDescriptor.result(for: healthStore).first {
                bodyData.bmi = sample.quantity.doubleValue(for: .count())
            }
        }

        // Body Fat Percentage
        if let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) {
            let bodyFatDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: bodyFatType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: 1
            )
            if let sample = try await bodyFatDescriptor.result(for: healthStore).first {
                bodyData.bodyFatPercentage = sample.quantity.doubleValue(for: .percent())
            }
        }

        // Lean Body Mass
        if let leanType = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) {
            let leanDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: leanType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: 1
            )
            if let sample = try await leanDescriptor.result(for: healthStore).first {
                bodyData.leanBodyMass = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            }
        }

        // Waist Circumference
        if let waistType = HKQuantityType.quantityType(forIdentifier: .waistCircumference) {
            let waistDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: waistType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: 1
            )
            if let sample = try await waistDescriptor.result(for: healthStore).first {
                bodyData.waistCircumference = sample.quantity.doubleValue(for: .meter())
            }
        }

        return bodyData
    }

    // MARK: - Nutrition Data

    private func fetchNutritionData(for date: Date) async throws -> NutritionData {
        var nutritionData = NutritionData()

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)

        // Dietary Energy
        if let energyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            let energyDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: energyType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await energyDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                nutritionData.dietaryEnergy = sum.doubleValue(for: .kilocalorie())
            }
        }

        // Protein
        if let proteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            let proteinDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: proteinType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await proteinDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                nutritionData.protein = sum.doubleValue(for: .gram())
            }
        }

        // Carbohydrates
        if let carbsType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            let carbsDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: carbsType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await carbsDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                nutritionData.carbohydrates = sum.doubleValue(for: .gram())
            }
        }

        // Fat
        if let fatType = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) {
            let fatDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: fatType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await fatDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                nutritionData.fat = sum.doubleValue(for: .gram())
            }
        }

        // Saturated Fat
        if let satFatType = HKQuantityType.quantityType(forIdentifier: .dietaryFatSaturated) {
            let satFatDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: satFatType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await satFatDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                nutritionData.saturatedFat = sum.doubleValue(for: .gram())
            }
        }

        // Fiber
        if let fiberType = HKQuantityType.quantityType(forIdentifier: .dietaryFiber) {
            let fiberDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: fiberType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await fiberDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                nutritionData.fiber = sum.doubleValue(for: .gram())
            }
        }

        // Sugar
        if let sugarType = HKQuantityType.quantityType(forIdentifier: .dietarySugar) {
            let sugarDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: sugarType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await sugarDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                nutritionData.sugar = sum.doubleValue(for: .gram())
            }
        }

        // Sodium
        if let sodiumType = HKQuantityType.quantityType(forIdentifier: .dietarySodium) {
            let sodiumDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: sodiumType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await sodiumDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                nutritionData.sodium = sum.doubleValue(for: HKUnit(from: "mg"))
            }
        }

        // Cholesterol
        if let cholesterolType = HKQuantityType.quantityType(forIdentifier: .dietaryCholesterol) {
            let cholesterolDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: cholesterolType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await cholesterolDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                nutritionData.cholesterol = sum.doubleValue(for: HKUnit(from: "mg"))
            }
        }

        // Water
        if let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) {
            let waterDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: waterType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await waterDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                nutritionData.water = sum.doubleValue(for: .liter())
            }
        }

        // Caffeine
        if let caffeineType = HKQuantityType.quantityType(forIdentifier: .dietaryCaffeine) {
            let caffeineDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: caffeineType, predicate: predicate),
                options: .cumulativeSum
            )
            if let result = try await caffeineDescriptor.result(for: healthStore),
               let sum = result.sumQuantity() {
                nutritionData.caffeine = sum.doubleValue(for: HKUnit(from: "mg"))
            }
        }

        return nutritionData
    }

    // MARK: - Mindfulness Data

    private func fetchMindfulnessData(for date: Date) async throws -> MindfulnessData {
        var mindfulnessData = MindfulnessData()

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)

        // Mindful Sessions
        if let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) {
            let mindfulDescriptor = HKSampleQueryDescriptor(
                predicates: [.categorySample(type: mindfulType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.startDate)]
            )
            let samples = try await mindfulDescriptor.result(for: healthStore)

            if !samples.isEmpty {
                mindfulnessData.mindfulSessions = samples.count
                let totalMinutes = samples.reduce(0.0) { total, sample in
                    total + sample.endDate.timeIntervalSince(sample.startDate) / 60
                }
                mindfulnessData.mindfulMinutes = totalMinutes
            }
        }

        return mindfulnessData
    }

    // MARK: - Mobility Data

    private func fetchMobilityData(for date: Date) async throws -> MobilityData {
        var mobilityData = MobilityData()

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)

        // Walking Speed
        if let walkingSpeedType = HKQuantityType.quantityType(forIdentifier: .walkingSpeed) {
            let walkingSpeedDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: walkingSpeedType, predicate: predicate),
                options: .discreteAverage
            )
            if let result = try await walkingSpeedDescriptor.result(for: healthStore),
               let avg = result.averageQuantity() {
                mobilityData.walkingSpeed = avg.doubleValue(for: HKUnit.meter().unitDivided(by: .second()))
            }
        }

        // Walking Step Length
        if let stepLengthType = HKQuantityType.quantityType(forIdentifier: .walkingStepLength) {
            let stepLengthDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: stepLengthType, predicate: predicate),
                options: .discreteAverage
            )
            if let result = try await stepLengthDescriptor.result(for: healthStore),
               let avg = result.averageQuantity() {
                mobilityData.walkingStepLength = avg.doubleValue(for: .meter())
            }
        }

        // Walking Double Support Percentage
        if let doubleSupportType = HKQuantityType.quantityType(forIdentifier: .walkingDoubleSupportPercentage) {
            let doubleSupportDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: doubleSupportType, predicate: predicate),
                options: .discreteAverage
            )
            if let result = try await doubleSupportDescriptor.result(for: healthStore),
               let avg = result.averageQuantity() {
                mobilityData.walkingDoubleSupportPercentage = avg.doubleValue(for: .percent())
            }
        }

        // Walking Asymmetry Percentage
        if let asymmetryType = HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage) {
            let asymmetryDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: asymmetryType, predicate: predicate),
                options: .discreteAverage
            )
            if let result = try await asymmetryDescriptor.result(for: healthStore),
               let avg = result.averageQuantity() {
                mobilityData.walkingAsymmetryPercentage = avg.doubleValue(for: .percent())
            }
        }

        // Stair Ascent Speed
        if let ascentType = HKQuantityType.quantityType(forIdentifier: .stairAscentSpeed) {
            let ascentDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: ascentType, predicate: predicate),
                options: .discreteAverage
            )
            if let result = try await ascentDescriptor.result(for: healthStore),
               let avg = result.averageQuantity() {
                mobilityData.stairAscentSpeed = avg.doubleValue(for: HKUnit.meter().unitDivided(by: .second()))
            }
        }

        // Stair Descent Speed
        if let descentType = HKQuantityType.quantityType(forIdentifier: .stairDescentSpeed) {
            let descentDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: descentType, predicate: predicate),
                options: .discreteAverage
            )
            if let result = try await descentDescriptor.result(for: healthStore),
               let avg = result.averageQuantity() {
                mobilityData.stairDescentSpeed = avg.doubleValue(for: HKUnit.meter().unitDivided(by: .second()))
            }
        }

        // Six Minute Walk Test Distance
        if let sixMinType = HKQuantityType.quantityType(forIdentifier: .sixMinuteWalkTestDistance) {
            let sixMinDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: sixMinType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: 1
            )
            if let sample = try await sixMinDescriptor.result(for: healthStore).first {
                mobilityData.sixMinuteWalkDistance = sample.quantity.doubleValue(for: .meter())
            }
        }

        return mobilityData
    }

    // MARK: - Hearing Data

    private func fetchHearingData(for date: Date) async throws -> HearingData {
        var hearingData = HearingData()

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)

        // Headphone Audio Exposure
        if let headphoneType = HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure) {
            let headphoneDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: headphoneType, predicate: predicate),
                options: .discreteAverage
            )
            if let result = try await headphoneDescriptor.result(for: healthStore),
               let avg = result.averageQuantity() {
                hearingData.headphoneAudioLevel = avg.doubleValue(for: .decibelAWeightedSoundPressureLevel())
            }
        }

        // Environmental Audio Exposure
        if let envType = HKQuantityType.quantityType(forIdentifier: .environmentalAudioExposure) {
            let envDescriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: envType, predicate: predicate),
                options: .discreteAverage
            )
            if let result = try await envDescriptor.result(for: healthStore),
               let avg = result.averageQuantity() {
                hearingData.environmentalSoundLevel = avg.doubleValue(for: .decibelAWeightedSoundPressureLevel())
            }
        }

        return hearingData
    }

    // MARK: - Workouts

    private func fetchWorkouts(for date: Date) async throws -> [WorkoutData] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        let samples = try await descriptor.result(for: healthStore)

        return samples.map { workout in
            WorkoutData(
                workoutType: workout.workoutActivityType,
                startTime: workout.startDate,
                duration: workout.duration,
                calories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                distance: workout.totalDistance?.doubleValue(for: .meter())
            )
        }
    }
}
