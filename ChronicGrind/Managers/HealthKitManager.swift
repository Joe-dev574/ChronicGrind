//
//  HealthKitManager.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/4/25.
//

//  Centralized HealthKit manager supporting:
//  • Authorization handling
//  • iPhone (freemium) workout sessions
//  • Premium independent Apple Watch workouts
//  • Live heart rate streaming
//  • Advanced workout metrics (intensity, time-in-zones, Progress Pulse score)
//
//  All public APIs favor modern async/await. Legacy completion-handler methods
//  are retained only where necessary and wrapped with async equivalents.

import Foundation
internal import HealthKit
import OSLog
import SwiftUI
import SwiftData


#if os(watchOS)
import WatchConnectivity  // Optional: for future phone-watch comms if needed

#endif

@MainActor @Observable
final class HealthKitManager {
    // MARK: - SINGLETON
   
    
    
    /// Shared singleton instance.
    static let shared = HealthKitManager()

    
    let healthStore = HKHealthStore()
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.tnt.ChronicGrind", category: "HealthKit")
    
    // MARK: - OBSERVABLE STATE
    var isReadAuthorized = false
    var isWriteAuthorized = false
    var authorizationRequestStatus: HKAuthorizationRequestStatus = .unknown
  
    ///WORKOUT SESSION STATE
    private var workoutSession: HKWorkoutSession?
    
    // iPhone workout
        private var phoneWorkoutBuilder: HKWorkoutBuilder?
        // Watch independent workout (premium)
        private var watchWorkoutSession: HKWorkoutSession?
        #if os(watchOS)
        private var watchWorkoutBuilder: HKWorkoutBuilder?
        #endif
  
    private init() {
        Task {
            await updateAuthorizationStatus()
        }
    }
    
    // MARK: - HealthKit Types (unchanged — perfect)
    private var typesToRead: Set<HKObjectType> {
        Set([
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.bodyMass),
            HKQuantityType(.height),
            HKObjectType.workoutType(),
            HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex)!,
            HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)!
        ])
    }
    private var typesToWrite: Set<HKSampleType> {
        Set([
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
        ])
    }
    
    // MARK: - Authorization
    func updateAuthorizationStatus() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationRequestStatus = .unknown
            isReadAuthorized = false
            isWriteAuthorized = false
            return
        }
        // Accurately check read authorization by attempting a dummy query
        do {
            _ = try await fetchLatestQuantity(typeIdentifier: .height, unit: .meter())
            isReadAuthorized = true
            logger.debug("Read authorization confirmed")
        } catch let error as HKError where error.code == .errorAuthorizationDenied || error.code == .errorAuthorizationNotDetermined {
            isReadAuthorized = false
            logger.warning("Read authorization denied or undetermined")
        } catch {
            logger.error("Read authorization check failed: \(error.localizedDescription)")
            isReadAuthorized = false
        }
        // Write authorization check using non-persistent dummy builder
        do {
            let config = HKWorkoutConfiguration()
            config.activityType = .other  // Neutral type for testing
            config.locationType = .unknown
            let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())
            try await builder.beginCollection(at: Date())
            builder.discardWorkout()  // Discard without saving
            isWriteAuthorized = true
            logger.debug("Write authorization confirmed")
        } catch let error as HKError where error.code == .errorAuthorizationDenied || error.code == .errorAuthorizationNotDetermined {
            isWriteAuthorized = false
            logger.warning("Write authorization denied or undetermined")
        } catch {
            logger.error("Write authorization check failed: \(error.localizedDescription)")
            isWriteAuthorized = false
        }
        
        // Update request status (now integrated)
        do {
            authorizationRequestStatus = try await getRequestStatusForAuthorization()
            logger.debug("Authorization request status updated: \(self.authorizationRequestStatus.rawValue)")
        } catch {
            logger.error("Failed to get authorization request status: \(error.localizedDescription)")
            authorizationRequestStatus = .unknown
        }
    }
    // MARK: GET REQUEST STATUS
    private func getRequestStatusForAuthorization() async throws -> HKAuthorizationRequestStatus {
        try await withCheckedThrowingContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(toShare: typesToWrite, read: typesToRead) { status, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }
    // MARK: REQUEST AUTHORIZATION
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw AppError.healthKitUnavailable
        }
        logger.info("Requesting HealthKit permissions...")
        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
        await updateAuthorizationStatus()
        logger.info("HealthKit permissions requested.")
    }
    func startPhoneWorkoutSession(workout: Workout) async {
            guard let activityType = workout.category?.categoryColor.hkActivityType else { return }
            do {
                let config = HKWorkoutConfiguration()
                config.activityType = activityType
                config.locationType = .unknown
                
                let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())
                try await builder.beginCollection(at: Date())
                phoneWorkoutBuilder = builder
                logger.info("iPhone workout session started")
            } catch {
                logger.error("Failed to start iPhone session: \(error.localizedDescription)")
            }
        }
    func endPhoneWorkoutSession() async {
            guard let builder = phoneWorkoutBuilder else { return }
            do {
                try await endCollectionAsync(builder: builder, endDate: Date())
                let _ = try await finishWorkoutAsync(builder: builder)
                logger.info("iPhone workout session ended")
            } catch {
                logger.error("Failed to end iPhone session: \(error.localizedDescription)")
            }
            phoneWorkoutBuilder = nil
        }
    
    // MARK: - iPhone Live Workout (Freemium)
    func startLiveWorkout_iPhone(
        activityType: HKWorkoutActivityType,
        locationType: HKWorkoutSessionLocationType = .unknown
    ) async throws -> HKWorkoutBuilder {
        guard isWriteAuthorized else {
            throw AppError.healthKitNotAuthorized
        }
        
        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType = locationType
        
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())
        
        //  new async API
        try await builder.beginCollection(at: Date())
        
        logger.info("Live workout started")
        return builder
    }
    
#if os(watchOS)
    func startLiveWorkout_Watch(
        activityType: HKWorkoutActivityType,
        locationType: HKWorkoutSessionLocationType = .unknown
    ) async throws -> HKWorkoutSession {
        guard isWriteAuthorized else { throw AppError.healthKitNotAuthorized }
        
        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType = locationType
        
        let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        session.startActivity(with: Date())
        
        logger.info("Watch workout started: \(activityType.rawValue)")
        return session
    }
#endif

    // MARK: - Private async helpers to bridge completion-handler APIs
    private func endCollectionAsync(builder: HKWorkoutBuilder, endDate: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: endDate) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: AppError.unknown(nil))
                }
            }
        }
    }

    private func finishWorkoutAsync(builder: HKWorkoutBuilder) async throws -> HKWorkout {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout, Error>) in
            builder.finishWorkout { workout, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let workout = workout {
                    continuation.resume(returning: workout)
                } else {
                    continuation.resume(throwing: AppError.unknown(nil))
                }
            }
        }
    }

    // MARK: - End Workout
    func endLiveWorkout(
        builder: HKWorkoutBuilder,
        endDate: Date = .now,
        metadata: [String: Any]? = nil
    ) async throws -> HKWorkout {
        try await endCollectionAsync(builder: builder, endDate: endDate)
        let workout = try await finishWorkoutAsync(builder: builder)
        logger.info("Workout saved to HealthKit: \(workout.uuid)")
        return workout
    }
    
#if os(watchOS)
    // MARK: - Watch Independent Workout (Premium)
    func startWatchIndependentWorkoutSession(workout: Workout) async {
        guard let activityType = workout.category?.categoryColor.hkActivityType else { return }
        do {
            let config = HKWorkoutConfiguration()
            config.activityType = activityType
            config.locationType = .unknown
            
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            try await builder.beginCollection(at: Date())
            
            watchWorkoutSession = session
            watchWorkoutBuilder = builder
            session.startActivity(with: Date())
            
            logger.info("Independent Watch HK session started")
        } catch {
            logger.error("Failed to start Watch session: \(error.localizedDescription)")
        }
    }
    func endWatchWorkoutSession() async {
            guard let session = watchWorkoutSession, let builder = watchWorkoutBuilder else { return }
            do {
                try await endCollectionAsync(builder: builder, endDate: Date())
                let _ = try await finishWorkoutAsync(builder: builder)
                session.end()
                logger.info("Independent Watch HK session ended")
            } catch {
                logger.error("Failed to end Watch session: \(error.localizedDescription)")
            }
            watchWorkoutSession = nil
            watchWorkoutBuilder = nil
        }
#endif
    
    // MARK:  SAVE WORKOUT
    func saveWorkout(_ workout: Workout, history: History, samples: [HKSample]) async throws -> Bool {
        guard  isWriteAuthorized else {
            logger.error("Cannot save workout: HealthKit authorization denied.")
            throw AppError.healthKitNotAuthorized
        }
        
        guard history.lastSessionDuration > 0 else {
            logger.error("Invalid workout duration: \(history.lastSessionDuration)")
            throw HealthKitError.invalidWorkoutDuration
        }
        
        let config = HKWorkoutConfiguration()
        // Dynamic activity type from workout category (improved integration)
        config.activityType = workout.category?.categoryColor.hkActivityType ?? .other
        config.locationType = .indoor  // Default; adjust if needed
        
        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: config,
            device: .local()
        )
        
        try await builder.beginCollection(at: history.date)
        try await builder.addSamples(samples)
        
        let metadata: [String: Any] = ["workoutTitle": workout.title]
        try await builder.addMetadata(metadata)
        
        try await endCollectionAsync(builder: builder, endDate: history.date.addingTimeInterval(history.lastSessionDuration * 60))
        
        let _ = try await builder.finishWorkout()
        logger.info("Workout saved successfully with title: \(workout.title)")
        return true
    }

    func streamHeartRate() -> AsyncThrowingStream<HKQuantitySample, Error> {
            AsyncThrowingStream { continuation in
                guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
                    continuation.finish(throwing: HKError(.errorInvalidArgument))
                    return
                }
                
                let query = HKObserverQuery(sampleType: hrType, predicate: nil) { [weak self] query, completion, error in
                    if let error = error {
                        continuation.finish(throwing: error)
                        return
                    }
                    
                    let sampleQuery = HKAnchoredObjectQuery(type: hrType, predicate: nil, anchor: nil, limit: 1) { _, samples, _, _, error in
                        if let error = error {
                            continuation.yield(with: .failure(error))
                            return
                        }
                        if let sample = samples?.first as? HKQuantitySample {
                            continuation.yield(sample)
                        }
                        completion()
                    }
                    self?.healthStore.execute(sampleQuery)
                }
                
                healthStore.execute(query)
                healthStore.enableBackgroundDelivery(for: hrType, frequency: .immediate) { _, _ in }
                
                continuation.onTermination = { [weak self] _ in
                    self?.healthStore.disableBackgroundDelivery(for: hrType, withCompletion: { _, _ in })
                }
            }
        }

}


// MARK: - Health Metrics Fetching Extension
extension HealthKitManager {
    // MARK:  FETCH HEALTH METRICS
    func fetchHealthMetrics() async throws -> (weight: Double?, height: Double?, maxHR: Double?) {
        let weight = try await fetchLatestQuantity(typeIdentifier: .bodyMass, unit: .gramUnit(with: .kilo))
        let height = try await fetchLatestQuantity(typeIdentifier: .height, unit: .meter())
        var maxHR: Double? = nil
        if let ageComponents = try? healthStore.dateOfBirthComponents(),
           let ageDate = Calendar.current.date(from: ageComponents),
           let age = Calendar.current.dateComponents([.year], from: ageDate, to: Date()).year {
            maxHR = 220.0 - Double(age)
        }
        return (weight, height, maxHR)
    }

    // MARK: CALCULATE TIME IN ZONES
    func calculateTimeInZones(dateInterval: DateInterval, maxHeartRate: Double?, completion: @escaping ([Int: Double]?, Int?, Error?) -> Void) {
        guard let maxHR = maxHeartRate, HKHealthStore.isHealthDataAvailable() else {
            logger.error("HealthKit unavailable or invalid inputs")
            completion(nil, nil, HealthKitError.healthDataUnavailable)
            return
        }
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            logger.error("Heart rate quantity type unavailable")
            completion(nil, nil, HealthKitError.heartRateDataUnavailable)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: dateInterval.start, end: dateInterval.end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: hrType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            if let error = error {
                self?.logger.error("Failed to fetch HR samples: \(error.localizedDescription)")
                completion(nil, nil, error)
                return
            }

            guard let hrSamples = samples as? [HKQuantitySample], !hrSamples.isEmpty else {
                self?.logger.info("No HR samples found for interval")
                completion(nil, nil, nil)
                return
            }

            var timeInZones: [Int: Double] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
            var previousDate = dateInterval.start
            var totalTime: Double = 0

            for sample in hrSamples {
                let hr = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                let duration = sample.endDate.timeIntervalSince(previousDate)
                totalTime += duration

                let percentage = hr / maxHR
                let zone: Int
                if percentage < 0.6 { zone = 1 }
                else if percentage < 0.7 { zone = 2 }
                else if percentage < 0.8 { zone = 3 }
                else if percentage < 0.9 { zone = 4 }
                else { zone = 5 }

                timeInZones[zone, default: 0] += duration
                previousDate = sample.endDate
            }

            // Dominant zone: The one with max time
            let dominantZone = timeInZones.max(by: { $0.value < $1.value })?.key

            self?.logger.info("Calculated time in zones: \(timeInZones), Dominant: \(dominantZone ?? -1)")
            completion(timeInZones, dominantZone, nil)
        }
        healthStore.execute(query)
    }
    
    // MARK: - FETCH LATEST QUANTITY
    func fetchLatestQuantity(typeIdentifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let sample = samples?.first as? HKQuantitySample,
                   sample.quantity.is(compatibleWith: unit) {
                    continuation.resume(returning: sample.quantity.doubleValue(for: unit))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    // MARK:  FETCH WORKOUTS
    func fetchWorkoutsFromHealthKit() async throws -> [HKWorkout] {
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
    }
   
    // MARK: RESTING HEART RATE
    func fetchLatestRestingHeartRate(completion: @escaping (Double?, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.error("HealthKit is not available on this device")
            completion(nil, HealthKitError.healthDataUnavailable)
            return
        }
        
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            logger.error("Resting heart rate type is not available")
            completion(nil, HealthKitError.heartRateDataUnavailable)
            return
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            if let error = error {
                self?.logger.error("Failed to fetch resting heart rate: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                self?.logger.info("No resting heart rate samples found")
                completion(nil, nil)
                return
            }
            
            let heartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            self?.logger.info("Fetched resting heart rate: \(heartRate) bpm")
            completion(heartRate, nil)
        }
        
        logger.debug("Executing resting heart rate query")
        healthStore.execute(query)
    }
    // MARK: CALCULATE PROGRESS PULSE SCORE
    public func calculateProgressPulseScore(fastestTime: Double,
                                            currentDuration: Double,
                                            workoutsPerWeek: Int,
                                            targetWorkoutsPerWeek: Int,
                                            dominantZone: Int?) -> Double? {
        logger.info("[HealthKitManager] calculateProgressPulseScore called.")
        var score = 50.0
        
        if currentDuration <= fastestTime && fastestTime > 0{
            score += 15
            logger.debug("[ProgressPulse] Beat or matched PR: +15 points. Current: \(currentDuration), PB: \(fastestTime)")
        } else {
            logger.debug("[ProgressPulse] Slower than PR. Current: \(currentDuration), PB: \(fastestTime)")
        }
        
        let frequencyPoints = Double(min(workoutsPerWeek, targetWorkoutsPerWeek) * 5)
        score += frequencyPoints
        logger.debug("[ProgressPulse] Frequency points: +\(frequencyPoints) (Workouts this week: \(workoutsPerWeek), Target: \(targetWorkoutsPerWeek))")
        
        if let zone = dominantZone {
            if zone >= 4 {
                score += 10
                logger.debug("[ProgressPulse] High intensity (Zone \(zone)): +10 points")
            } else if zone == 3 {
                score += 5
                logger.debug("[ProgressPulse] Moderate intensity (Zone \(zone)): +5 points")
            } else {
                logger.debug("[ProgressPulse] Low intensity (Zone \(zone)): +0 points")
            }
        } else {
            logger.debug("[ProgressPulse] Dominant zone not available: +0 points for intensity.")
        }
        
        let finalScore = min(max(score, 0), 100)
        logger.info("[HealthKitManager] Progress Pulse score calculated: \(finalScore)")
        return finalScore
    }
    
    public func calculateProgressPulseScoreAsync(fastestTime: Double,
                                                     currentDuration: Double,
                                                     workoutsPerWeek: Int,
                                                     targetWorkoutsPerWeek: Int,
                                                     dominantZone: Int?) async -> Double {
        return calculateProgressPulseScore(fastestTime: fastestTime,
                                               currentDuration: currentDuration,
                                               workoutsPerWeek: workoutsPerWeek,
                                               targetWorkoutsPerWeek: targetWorkoutsPerWeek,
                                                 dominantZone: dominantZone) ?? 50
        }
    
    // MARK: INTENSITY SCORE
    func calculateIntensityScore(dateInterval: DateInterval, restingHeartRate: Double?, completion: @escaping (Double?, Error?) -> Void) {
        guard let restingHR = restingHeartRate, HKHealthStore.isHealthDataAvailable(), let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            logger.error("HealthKit unavailable or invalid inputs")
            completion(nil, HealthKitError.healthDataUnavailable)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: dateInterval.start, end: dateInterval.end, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: hrType, quantitySamplePredicate: predicate, options: .discreteAverage) { [weak self] _, result, error in
            if let error = error {
                self?.logger.error("Failed to fetch average HR: \(error.localizedDescription)")
                completion(nil, error)
                return
            }

            guard let averageHR = result?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) else {
                self?.logger.info("No average HR data available")
                completion(nil, nil)
                return
            }

            Task { [weak self] in
                guard let self = self else { completion(nil, nil); return }
                do {
                    let (_, _, maxHR) = try await self.fetchHealthMetrics()
                    guard let maxHR = maxHR else {
                        completion(nil, HealthKitError.noMaxHeartRateData)
                        return
                    }
                    let intensity = ((averageHR - restingHR) / (maxHR - restingHR)) * 100
                    let clampedIntensity = max(0, min(100, intensity))
                    self.logger.info("Calculated intensity score: \(clampedIntensity)")
                    completion(clampedIntensity, nil)
                } catch {
                    self.logger.error("Failed to fetch health metrics: \(error.localizedDescription)")
                    completion(nil, error)
                }
            }
        }
        healthStore.execute(query)
    }
    
    // MARK: - Async Wrappers (Added for centralization and async/await support)
    func fetchLatestRestingHeartRateAsync() async -> Double? {
        await withCheckedContinuation { continuation in
            fetchLatestRestingHeartRate { restingHR, error in
                if let error = error {
                    self.logger.error("Failed to fetch resting HR asynchronously: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: restingHR)
                }
            }
        }
    }
  
    public func calculateIntensityScoreAsync(dateInterval: DateInterval, restingHeartRate: Double?) async -> Double? {
        await withCheckedContinuation { continuation in
            calculateIntensityScore(dateInterval: dateInterval, restingHeartRate: restingHeartRate) { score, error in
                if let error = error {
                    self.logger.error("Failed to calculate intensity score asynchronously: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: score)
                }
            }
        }
    }
    // MARK: - Time in Heart Rate Zones
    func calculateTimeInZonesAsync(dateInterval: DateInterval, maxHeartRate: Double?) async -> ([Int: Double]?, Int?) {
        await withCheckedContinuation { continuation in
            calculateTimeInZones(dateInterval: dateInterval, maxHeartRate: maxHeartRate) { timeInZones, dominantZone, error in
                if let error = error {
                    self.logger.error("Failed to calculate time in zones asynchronously: \(error.localizedDescription)")
                    continuation.resume(returning: (nil, nil))
                } else {
                    continuation.resume(returning: (timeInZones, dominantZone))
                }
            }
        }
    }
    // In HealthKitManager.swift, add to the extension:
    func fetchMaxHeartRateAsync() async throws -> Double? {
        let (_, _, maxHR) = try await fetchHealthMetrics()
        return maxHR
    }
}
