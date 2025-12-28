//
//  WorkoutCard.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/27/25.
//

//  Displays a visually engaging card summarizing a workout's details in a navigable list, utilizing SwiftData for persistence.
//  The card links to WorkoutDetailView via NavigationLink and supports HealthKit integration for workout data (e.g., lastSessionDuration).
//  HealthKit integration requires the `com.apple.developer.healthkit` entitlement and the following Info.plist entries:
//  - NSHealthShareUsageDescription: Description for accessing HealthKit data.
//  - NSHealthUpdateUsageDescription: Description for updating HealthKit data.
//
//  Accessibility features include comprehensive labels, hints, and traits for VoiceOver support, ensuring compliance with Apple's Human Interface Guidelines (HIG) for accessibility.
//  The card supports dynamic type sizes, reduced motion preferences, and high contrast modes for full accessibility compliance in production-ready apps.
//  All visible text elements are configured to scale with Dynamic Type, and non-essential animations respect the user's Reduce Motion setting.
//  Decorative elements are marked as hidden for accessibility to avoid unnecessary VoiceOver narration.
//
//  For watchOS compatibility (premium version), the layout uses flexible spacing and sizes that adapt to smaller screens. Test on watchOS simulators to ensure no truncation occurs.
//  Conditional compilation (#if os(watchOS)) can be added if premium-specific features or optimizations are needed, but the current implementation is platform-agnostic.

import SwiftUI
import SwiftData

/// A SwiftUI view that displays a workout summary card with navigation to detailed workout information.
/// This view is designed to be used in a list or grid, providing a tappable card that navigates to WorkoutDetailView.
/// It adheres to Apple's accessibility standards by combining child elements for VoiceOver, adding button traits, and providing descriptive labels and hints.
struct WorkoutCard: View {
    // MARK: - Properties
    
    /// The workout object containing details to display.
    /// This is the primary data source for the card's content.
    let workout: Workout
    
    /// Environment object to handle error reporting.
    /// Injected via the environment for centralized error management across the app.
    @Environment(ErrorManager.self) private var errorManager
    
    /// Computed property for the number of exercises in the workout.
    /// Safely handles optional exercises array to avoid runtime errors.
    private var exerciseCount: Int {
        workout.exercises?.count ?? 0
    }
    
    /// Gesture state to track tap interactions for visual feedback.
    /// Used to provide a scale effect on tap, enhancing user interaction feedback.
    @GestureState private var isTapped = false
    
    /// State for animating the icon's pulse effect.
    /// Animates only if Reduce Motion is not enabled, per accessibility guidelines.
    @State private var pulseScale: CGFloat = 1.0
    
    // MARK: - Body
    
    var body: some View {
        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
            VStack(alignment: .leading, spacing: 12) {
                workoutTitle
                exerciseInfo
            }
            .padding(16)
            .background(
                ZStack {
                    // Gradient background for visual appeal
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                (workout.category?.categoryColor.color ?? .gray).opacity(0.3),
                                .clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    // Semi-transparent material effect
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Material.ultraThin)
                        .opacity(0.7)
                    // Border with gradient and shadow
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(LinearGradient(
                            gradient: Gradient(colors: [
                                workout.category?.categoryColor.color ?? .gray,
                                .clear
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ), lineWidth: 1.5)
                        .shadow(color: workout.category?.categoryColor.color ?? .gray, radius: 2)
                }
                .accessibilityHidden(true) // Background is decorative and should not be announced by VoiceOver
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
            .scaleEffect(isTapped ? 0.95 : 1.0) // Scale down on tap for tactile feedback
            .gesture(
                TapGesture()
                    .updating($isTapped) { _, state, _ in
                        state = true
                    }
            )
            // Accessibility for VoiceOver: Combines children for a cohesive announcement, adds button trait, and provides a hint.
            // Ensures the entire card is treated as a single accessible element, per Apple's accessibility best practices.
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Workout: \(workout.title), \(exerciseCount) \(exerciseCount == 1 ? "exercise" : "exercises")\(workout.roundsEnabled && workout.roundsQuantity > 1 ? ", \(workout.roundsQuantity) rounds" : ""), Last session: \(lastSessionTime)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Tap to view workout details")
            .onAppear {
                // Animate pulse effect for icon unless reduced motion is enabled, respecting user accessibility preferences.
                guard !UIAccessibility.isReduceMotionEnabled else { return }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.2
                }
            }
            // Supports high contrast and dark mode adaptations implicitly via system colors and materials.
        }
    }
    
    // MARK: - Subviews
    
    /// View for displaying the workout title and category icon.
    /// This subview includes the category icon with pulse animation and the title text, both with accessibility labels.
    private var workoutTitle: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(workout.category?.categoryColor.color ?? .gray)
                .frame(width: 37, height: 37)
                .padding(1)
                .overlay {
                    Image(systemName: workout.category?.symbol ?? "figure.run")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(pulseScale)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
                .padding(.horizontal, 4)
                .accessibilityLabel("Category: \(workout.category?.categoryName ?? "None")")
                .accessibilityHint("Indicates the workout category")
            
            Text(workout.title)
                .font(.headline)
                .fontDesign(.serif)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .shadow(color: .black.opacity(0.4), radius: 1)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3) // Supports extra-large accessibility text sizes
                .padding(.horizontal, 4)
            
            Spacer()
        }
        .padding(.leading, 8)
    }
    
    /// View for displaying exercise count, rounds, and last session time information.
    /// Each label has its own accessibility label for granular VoiceOver support.
    private var exerciseInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("\(exerciseCount) \(exerciseCount == 1 ? "Exercise" : "Exercises")")
            } icon: {
                Image(systemName: "arrow.forward.circle")
                    .accessibilityHidden(true) // Icon is decorative
            }
            .font(.caption)
            .fontDesign(.serif)
            .foregroundStyle(.primary)
            .accessibilityLabel("Exercise count: \(exerciseCount)")
            
            if workout.roundsEnabled && workout.roundsQuantity > 1 {
                Label {
                    Text("\(workout.roundsQuantity) Rounds")
                } icon: {
                    Image(systemName: "repeat")
                        .accessibilityHidden(true) // Icon is decorative
                }
                .font(.caption)
                .fontDesign(.serif)
                .foregroundStyle(.primary)
                .accessibilityLabel("Rounds: \(workout.roundsQuantity)")
            }
            
            Label {
                Text("Last Session: \(lastSessionTime)")
            } icon: {
                Image(systemName: "hourglass.bottomhalf.filled")
                    .accessibilityHidden(true) // Icon is decorative
            }
            .font(.caption)
            .fontDesign(.serif)
            .foregroundStyle(.primary)
            .accessibilityLabel("Last session time: \(lastSessionTime)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Formats the last session duration or returns "N/A" if not available.
    /// This computed property ensures safe handling of zero or negative durations.
    private var lastSessionTime: String {
        guard workout.lastSessionDuration > 0 else {
            return "N/A"
        }
        return formatTime(minutes: workout.lastSessionDuration)
    }
    
    /// Converts minutes to a formatted time string (HH:MM:SS.mmm).
    /// - Parameter minutes: The duration in minutes (Double to support fractional minutes).
    /// - Returns: A formatted string representing the time, with three-digit milliseconds.
    /// This method precisely calculates hours, minutes, seconds, and milliseconds for display.
    private func formatTime(minutes: Double) -> String {
        let totalSeconds = minutes * 60
        let intSeconds = Int(totalSeconds)
        let fractionalSeconds = totalSeconds - Double(intSeconds)
        let milliseconds = Int(fractionalSeconds * 1000)
        let hours = intSeconds / 3600
        let minutesPart = (intSeconds % 3600) / 60
        let secondsPart = intSeconds % 60
        return String(format: "%02d:%02d:%02d.%03d", hours, minutesPart, secondsPart, milliseconds)
    }
}
