//
//  WorkoutSessionView.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/27/25.
//

import SwiftUI
import SwiftData
internal import HealthKit
import Combine

/// A SwiftUI view that manages and displays an active workout session.
/// This view handles UI for timing, exercise display, and completion controls, integrating with WorkoutSessionViewModel.
/// Accessibility: All interactive elements have labels, hints, and traits for VoiceOver support.
struct WorkoutSessionView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(AuthenticationManager.self) private var authenticationManager
    @Environment(ErrorManager.self) private var errorManager
    let workout: Workout
    // MARK: - StateObject
    @State private var viewModel: WorkoutSessionViewModel
    @AccessibilityFocusState private var isExerciseNameFocused: Bool
    /// Initializes the view with the workout model.
    /// - Parameter workout: The Workout instance to display.
    init(workout: Workout) {
        self.workout = workout
        self._viewModel = State(wrappedValue: WorkoutSessionViewModel(workout: workout))
    }
    // MARK: - Body
    var body: some View {
        ZStack {
            Color.proBackground2
                .ignoresSafeArea()
                .accessibilityHidden(true)  // Background is decorative, hidden from accessibility
            VStack(spacing: 16) {
                Text(workout.title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.top, 16)
                    .accessibilityLabel("Workout title: \(workout.title)")
                if let category = workout.category {
                    HStack {
                        Label(category.categoryName, systemImage: category.symbol)
                            .font(.title3)
                            .foregroundStyle(category.categoryColor.color)
                            .accessibilityLabel("Category: \(category.categoryName)")
                        if viewModel.currentHeartRate > 0 {
                            Text("\(Int(viewModel.currentHeartRate)) BPM")
                                .font(.title3)
                                .foregroundStyle(.pink)
                                .accessibilityLabel("Current heart rate: \(Int(viewModel.currentHeartRate)) beats per minute")
                        }
                    }
                    .padding(.bottom, 4)
                }
                if !workout.sortedExercises.isEmpty {
                    Text(viewModel.currentExerciseText)
                        .font(.title3.bold())
                        .foregroundColor(.red)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .accessibilityFocused($isExerciseNameFocused)  // Focuses on current exercise for accessibility
                        .accessibilityLabel("Current exercise")
                        .accessibilityValue(viewModel.currentExerciseText)
                } else {
                    Text("Timing general activity...")
                        .font(.title3.bold())
                        .foregroundColor(.red)
                }
                VStack(spacing: 4) {  // Group timer and rounds with closer spacing
                    GeometryReader { geometry in
                        Text(
                            formattedTime(viewModel.displayedDuration)
                        )
                        .font(
                            .system(
                                size: min(geometry.size.width / 10, 40),
                                design: .monospaced
                            ).bold()
                        )
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.proBackground.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityValue(
                            "Workout duration: \(formattedTime(viewModel.displayedDuration))"
                        )
                        .accessibilityAddTraits(.updatesFrequently)  // Indicates dynamic content for VoiceOver
                    }
                    .frame(height: 80)
                    if workout.roundsEnabled && workout.roundsQuantity > 1 {
                        Label(
                            "Round \(viewModel.currentRound) of \(workout.roundsQuantity)",
                            systemImage: "repeat"
                        )
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Current round")
                        .accessibilityValue("\(viewModel.currentRound) of \(workout.roundsQuantity)")
                    }
                }
                if viewModel.showMetrics {
                    MetricsView(
                        intensityScore: viewModel.intensityScore,
                        progressPulseScore: viewModel.progressPulseScore,
                        dominantZone: viewModel.dominantZone
                    )
                }
                Button(action: {
                    Task { await viewModel.primaryButtonAction() }
                }) {
                    Text(viewModel.primaryButtonText)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(viewModel.isCompleting || (viewModel.hasStarted && viewModel.isPaused))
                .accessibilityIdentifier(viewModel.primaryButtonAccessibilityID)
                .accessibilityHint(viewModel.primaryButtonAccessibilityHint)
               
                Button(action: viewModel.togglePause) {
                    Text(viewModel.isPaused ? "Resume" : "Pause")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(viewModel.isCompleting || !viewModel.hasStarted)
                .accessibilityIdentifier("pauseResumeButton")
                .accessibilityHint(
                    viewModel.isPaused
                        ? "Resumes the workout timer"
                        : "Pauses the workout timer"
                )
                if viewModel.showSecondaryEndButton {
                    Button("End Workout Early") {
                        Task {
                            await viewModel.completeWorkout(early: true)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding(.top, 15)
                    .disabled(viewModel.isCompleting)
                    .accessibilityIdentifier("endWorkoutEarlyButton")
                    .accessibilityHint("Ends the workout session prematurely")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.7))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .accessibilityHidden(true)  // Background is decorative
            )
            .padding(.horizontal, 8)
            // Loading indicator overlay during completion
            if viewModel.isCompleting {
                ProgressView("Completing Workout...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Workout completion in progress")
                    .accessibilityHint("Please wait while the workout is saved")
            }
        }
        .onAppear {
            viewModel.modelContext = modelContext
            viewModel.purchaseManager = purchaseManager
            viewModel.healthKitManager = healthKitManager
            viewModel.authenticationManager = authenticationManager
            viewModel.errorManager = errorManager
            viewModel.dismissAction = { dismiss() }
            viewModel.onAppear()
            isExerciseNameFocused = true  // Sets initial accessibility focus
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onReceive(
            Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        ) { _ in
            // Optional: Can be used for periodic metric refreshes if needed; currently unused
        }
    }
    
    private func formattedTime(_ seconds: TimeInterval) -> String {
        let intVal = Int(seconds)
        let h = intVal / 3600
        let m = (intVal % 3600) / 60
        let s = intVal % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}
// MARK: - Metrics View
/// A subview displaying calculated workout metrics like intensity and heart rate zones.
/// Accessibility: Each metric has a label for VoiceOver readability.
private struct MetricsView: View {
    let intensityScore: Double?
    let progressPulseScore: Double?
    let dominantZone: Int?
    var body: some View {
        VStack(spacing: 4) {
            if let intensityScore {
                let val = Int(intensityScore)
                Text("Intensity: \(val)%")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .accessibilityLabel(
                        "Workout intensity: \(val) percent"
                    )
            }
            if let progressPulseScore {
                let val = Int(progressPulseScore)
                Text("Progress Pulse: \(val)")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .accessibilityLabel("Progress pulse score: \(val)")
            }
            if let zone = dominantZone {
                Text("Zone: \(zone) (\(zoneDescription(zone)))")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .accessibilityLabel(
                        "Dominant heart rate zone: \(zone), \(zoneDescription(zone))"
                    )
            }
        }
        .padding(.top, 4)
    }
    /// Provides a descriptive string for the heart rate zone.
    /// - Parameter zone: The zone number (1-5).
    /// - Returns: A human-readable description.
    private func zoneDescription(_ zone: Int) -> String {
        switch zone {
        case 1: return "Very Light"
        case 2: return "Light"
        case 3: return "Moderate"
        case 4: return "Hard"
        case 5: return "Maximum"
        default: return "Unknown"
        }
    }
}
