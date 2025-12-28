//
//  WorkoutSessionViewModel.swift
//  ChronicGrind
//
//  Updated for premium Watch integration on 12/22/25
//

import SwiftUI
import SwiftData
internal import HealthKit
import OSLog

#if os(watchOS)
import WatchKit
#endif

/// ViewModel for managing an active workout session on both iPhone and Apple Watch.
/// Shared logic lives here. Watch-specific premium features are gated with platform checks
/// and the shared PurchaseManager.isSubscribed flag (synced via app group).
///

extension Notification.Name {
    static let workoutDidComplete = Notification.Name("workoutDidComplete")
}

@Observable
@MainActor
final class WorkoutSessionViewModel {
    private let logger = Logger(
        subsystem: "com.tnt.FitSyncShared",
        category: "WorkoutSession"
    )

    // MARK: - Dependencies (injected after init)
    let workout: Workout
    var modelContext: ModelContext?
    var purchaseManager: PurchaseManager?
    var healthKitManager: HealthKitManager?
    var authenticationManager: AuthenticationManager?
    var errorManager: ErrorManager?
    var dismissAction: () -> Void = {}

    // MARK: - Published State (visible to SwiftUI views)
    var secondsElapsed: Double = 0.0
    var currentExerciseIndex: Int = 0
    var currentRound: Int = 1
    var isRunning: Bool = false
    var hasStarted: Bool = false
    var currentHeartRate: Double = 0.0
    var caloriesBurned: Double = 0.0
    var distanceMeters: Double = 0.0
    var dominantZone: Int?

    // MARK: - Derived UI State
    var displayedDuration: TimeInterval { secondsElapsed }
    
    var currentExerciseText: String {
        if let exercise = currentExercise {
            return exercise.name
        }
        return workout.sortedExercises.isEmpty ? "Timing general activity..." : "Transition"
    }
    
    // MARK: - Crown Support (Floating-Point for Digital Crown precision)
    var crownAccumulator: Double = 0.0

    var isPaused: Bool { !isRunning }

    var isCompleting: Bool = false

    var showMetrics: Bool {
        currentHeartRate > 0 || dominantZone != nil
    }
    
    // MARK: - Derived Computed Properties (exposed to View)
    var roundsEnabled: Bool {
        workout.roundsEnabled
    }

    var totalExercises: Int {
        workout.sortedExercises.count
    }

    var currentExercise: Exercise? {
        guard !workout.sortedExercises.isEmpty,
              currentExerciseIndex < workout.sortedExercises.count
        else { return nil }
        return workout.sortedExercises[currentExerciseIndex]
    }
    
    var showSecondaryEndButton: Bool {
        hasStarted && !isCompleting
    }

    var primaryButtonText: String {
        isRunning ? "Next" : "Start Workout"
    }

    var primaryButtonAction: () async -> Void {
        isRunning ? { await self.nextExercise() } : { await self.startWorkout() }
    }

    var primaryButtonAccessibilityID: String { "primaryWorkoutButton" }
    
    var primaryButtonAccessibilityHint: String {
        isRunning ? "Advance to the next exercise" : "Begin the workout session"
    }

    // Optional metric placeholders — implement as needed
    var intensityScore: Double? { nil }
    var progressPulseScore: Double? { nil }
    
    // MARK: - Private State
    private var heartRateTask: Task<Void, Never>?
    private var tickerTask: Task<Void, Never>?
    private var workoutStartDate: Date?
    private var currentExerciseStartDate: Date?
    private var accumulatedSplitTimes: [SplitTime] = []

    // MARK: - Init
    init(workout: Workout) {
        self.workout = workout
    }
    
    // MARK: - Lifecycle
    func onAppear() {
        // Dependencies are injected in view's .onAppear — no additional work needed here
    }

    func onDisappear() {
        if isRunning {
            endWorkoutSession()
        }
    }
    
    // MARK: - Public API

    /// Starts the workout session. Behaviour differs slightly between iPhone and premium Watch.
    func startWorkout() async {
        hasStarted = true
        isRunning = true
        secondsElapsed = 0.0
        workoutStartDate = Date()
        currentExerciseStartDate = Date()
        crownAccumulator = Double(currentExerciseIndex)
        startTimer()

        // HealthKit session – always start on iPhone, only on Watch if premium
        #if os(watchOS)
        if purchaseManager?.isSubscribed == true {
            await healthKitManager?.startWatchIndependentWorkoutSession(
                workout: workout
            )
            startLiveHeartRateUpdates()
        }
        #else
        await healthKitManager?.startPhoneWorkoutSession(workout: workout)
        #endif
        startLiveHeartRateUpdates()
    }

    /// Advances to the next exercise/round. Records split time and plays haptic on premium Watch.
    /// Automatically completes the workout if this advance reaches the end.
    func nextExercise() async {
        guard isRunning else { return }

        // Record split time for the just-completed exercise
        if let start = currentExerciseStartDate {
            let duration = Date().timeIntervalSince(start)
            let split = SplitTime(
                durationInSeconds: duration,
                order: currentExerciseIndex
            )
            accumulatedSplitTimes.append(split)
        }

        // Haptic feedback – only on premium Watch
        #if os(watchOS)
        if purchaseManager?.isSubscribed == true {
            WKInterfaceDevice.current().play(.click)
        }
        #endif

        // Advance logic
        if roundsEnabled {
            if currentExerciseIndex + 1 < totalExercises {
                currentExerciseIndex += 1
            } else {
                // End of round
                currentExerciseIndex = 0
                if currentRound < workout.roundsQuantity {
                    currentRound += 1
                } else {
                    // Workout complete
                    await completeWorkout()
                    return
                }
            }
        } else {
            if currentExerciseIndex + 1 < totalExercises {
                currentExerciseIndex += 1
            } else {
                await completeWorkout()
                return
            }
        }
        
        crownAccumulator = Double(currentExerciseIndex)
        currentExerciseStartDate = Date()
    }

    func togglePause() {
        isRunning.toggle()
        if isRunning {
            workoutStartDate = Date().addingTimeInterval(-secondsElapsed)
            let pausedDuration = Date().timeIntervalSince(currentExerciseStartDate ?? Date())
            currentExerciseStartDate = Date().addingTimeInterval(-pausedDuration)
            startTimer()
        } else {
            tickerTask?.cancel()
            tickerTask = nil
        }
    }

    /// Completes the workout, saves data, writes to HealthKit (platform-appropriate), and posts notification.
    func completeWorkout(early: Bool = false) async {
        isCompleting = true
        isRunning = false
        tickerTask?.cancel()
        tickerTask = nil

        guard let startDate = workoutStartDate else { return }
        let totalDuration = Date().timeIntervalSince(startDate)

        // Create History entry
        let history = History(
            date: Date(),
            lastSessionDuration: totalDuration / 60.0,  // stored in minutes
            splitTimes: accumulatedSplitTimes
        )
        history.workout = workout

        // Save to SwiftData
        if let context = modelContext {
            context.insert(history)
            do {
                try context.save()
                logger.info("Workout history saved to SwiftData")
            } catch {
                logger.error(
                    "Failed to save history: \(error.localizedDescription)"
                )
                errorManager?.present(error)
            }
        }

        #if os(watchOS)
        if purchaseManager?.isSubscribed == true {
            await healthKitManager?.endWatchWorkoutSession()
        }
        #else
        await healthKitManager?.endPhoneWorkoutSession()
        #endif

        NotificationCenter.default.post(name: .workoutDidComplete, object: nil)
        dismissAction()
        isCompleting = false
    }

    /// Ends the session early (user taps "End Workout")
    func endWorkoutSession() {
        isRunning = false
        tickerTask?.cancel()
        tickerTask = nil

        #if os(watchOS)
        if purchaseManager?.isSubscribed ?? false {
            Task { await healthKitManager?.endWatchWorkoutSession() }
        }
        #else
        Task { await healthKitManager?.endPhoneWorkoutSession() }
        #endif
    }

    // MARK: - START TIMER
    private func startTimer() {
        // Cancel any existing ticker
        tickerTask?.cancel()
        tickerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let clock = ContinuousClock()
            while !Task.isCancelled, self.isRunning {
                if let start = self.workoutStartDate {
                    self.secondsElapsed = Date().timeIntervalSince(start)
                }
                try? await clock.sleep(for: .milliseconds(100))
            }
        }
    }
    
    // MARK: - START LIVE HEART RATE UPDATES
    func startLiveHeartRateUpdates() {
        heartRateTask?.cancel()
        heartRateTask = Task { @MainActor in
            guard let manager = healthKitManager else { return }
            do {
                for try await sample in manager.streamHeartRate() {
                    let bpm = sample.quantity.doubleValue(
                        for: .count().unitDivided(by: .minute())
                    )
                    currentHeartRate = bpm

                    if let maxHR = try await manager.fetchMaxHeartRateAsync() {
                        dominantZone = Self.calculateHeartRateZone(
                            hr: bpm,
                            maxHR: maxHR
                        )
                    }
                }
            } catch {
                logger.error("HR stream error: \(error.localizedDescription)")
            }
        }
    }

    private static func calculateHeartRateZone(hr: Double, maxHR: Double) -> Int {
        let percent = hr / maxHR
        switch percent {
        case ..<0.6: return 1
        case 0.6..<0.7: return 2
        case 0.7..<0.8: return 3
        case 0.8..<0.9: return 4
        default: return 5
        }
    }

    // MARK: - Distance Estimation Fallback (used when no GPS data)
    private func estimateDistance(
        for categoryColor: CategoryColor,
        durationMinutes: Double
    ) -> Double {
        let hours = durationMinutes / 60.0
        switch categoryColor {
        case .RUN: return hours * 8000.0
        case .WALK: return hours * 5000.0
        case .HIKING: return hours * 4000.0
        case .CYCLING: return hours * 20000.0
        case .SWIMMING: return hours * 1500.0
        case .ROWING: return hours * 6000.0
        default: return 0.0
        }
    }
}
