//
//  StatsSection.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/27/25.
//

import SwiftUI
import SwiftData
import OSLog
internal import HealthKit

/// A SwiftUI view displaying user workout statistics, such as total workouts, session durations, and premium metrics.
/// Fetches data from SwiftData and syncs with HealthKit when authorized, focusing on fitness metrics.
/// Complies with App Store guidelines by ensuring robust data handling, accessibility, and HealthKit integration.
struct StatsSectionView: View {
    /// The SwiftData model context for querying workout data.
    @Environment(\.modelContext) private var modelContext
    
    @Environment(History.self) private var history
    
    /// The shared HealthKit manager for accessing health data and authorization status.
    @Environment(HealthKitManager.self) private var healthKitManager
    
    /// The theme color for styling the section header.
    let themeColor: Color
    
    /// Query to fetch all workouts from SwiftData.
    @Query private var workouts: [Workout]
    
    /// Indicates whether statistics are currently loading.
    @State private var isLoading: Bool = false
    
    /// Stores any error message to display via ErrorManager.
    @State private var errorMessage: String?
    
    /// Logger for debugging and monitoring view operations.
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.movesync.default.subsystem", category: "StatsSectionView")
    
    var body: some View {
        Section(header: Text("STATISTICS")
            .font(.system(size: 18, weight: .bold, design: .serif))
            .foregroundStyle(themeColor)
            .accessibilityLabel("Statistics Section")
        ) {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading Statistics...")
                        .fontDesign(.serif)
                        .accessibilityLabel("Loading Statistics")
                    Spacer()
                }
                .padding(.vertical)
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(errorMessage)
                    .accessibilityHint("Check HealthKit authorization or try again later")
            } else if workouts.isEmpty && !healthKitManager.isReadAuthorized {
                Text("No workout data available. Authorize HealthKit or log workouts to see statistics.")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("No workout data available")
                    .accessibilityHint("Authorize HealthKit or log workouts to view statistics")
            } else {
                // Total Workouts
                HStack {
                    Text("Total Workouts")
                        .fontDesign(.serif)
                    Spacer()
                    Text("\(workouts.count)")
                        .foregroundStyle(.secondary)
                        .fontDesign(.serif)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Total Workouts: \(workouts.count)")
                
                // Total Duration
                HStack {
                    Text("Total Duration")
                        .fontDesign(.serif)
                    Spacer()
                    Text(formattedDuration(totalDuration()))
                        .foregroundStyle(.secondary)
                        .fontDesign(.serif)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Total Duration: \(formattedDuration(totalDuration()))")
                
                // Average Workout Duration
                HStack {
                    Text("Average Workout Duration")
                        .fontDesign(.serif)
                    Spacer()
                    Text(formattedDuration(averageDuration()))
                        .foregroundStyle(.secondary)
                        .fontDesign(.serif)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Average Workout Duration: \(formattedDuration(averageDuration()))")
                
                
                
                // Average Intensity Score
                HStack {
                    Text("Average Intensity Score")
                        .fontDesign(.serif)
                    Spacer()
                    Text(formattedIntensityScore(averageIntensityScore()))
                        .foregroundStyle(.secondary)
                        .fontDesign(.serif)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Average Intensity Score: \(formattedIntensityScore(averageIntensityScore()))")
                
                // Dominant Zone Distribution
                HStack {
                    Text("Most Common Heart Rate Zone")
                        .fontDesign(.serif)
                    Spacer()
                    Text(formattedDominantZone(dominantZoneDistribution()))
                        .foregroundStyle(.secondary)
                        .fontDesign(.serif)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Most Common Heart Rate Zone: \(formattedDominantZone(dominantZoneDistribution()))")
            }
        }
                .onAppear {
                    loadStatistics()
                }
                .onChange(of: workouts) { _, _ in
                    loadStatistics()
                }
                .onChange(of: healthKitManager.isReadAuthorized) { _, _ in
                    loadStatistics()
                }
        }
    
    /// Loads workout statistics by syncing HealthKit data into SwiftData if authorized.
    private func loadStatistics() {
        logger.debug("Loading statistics")
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if healthKitManager.isReadAuthorized {
                    let hkWorkouts = try await healthKitManager.fetchWorkoutsFromHealthKit()
                    // Update SwiftData with HealthKit data
                    for hkWorkout in hkWorkouts {
                        // Check if workout already exists to avoid duplicates
                        let existingWorkouts = try modelContext.fetch(FetchDescriptor<Workout>()).filter { $0.title == hkWorkout.description }
                        
                        if existingWorkouts.isEmpty {
                            let workout = Workout(title: hkWorkout.description)
                            workout.lastSessionDuration = hkWorkout.duration / 60 // Convert seconds to minutes
                            let history = History(
                                date: hkWorkout.startDate,
                                lastSessionDuration: hkWorkout.duration / 60
                            )
                            if workout.history == nil { workout.history = [] }
                            workout.history?.append(history)
                            modelContext.insert(workout)
                            logger.debug("Inserted new workout from HealthKit: \(hkWorkout.description)")
                        }
                    }
                    try modelContext.save()
                    logger.info("Synced \(hkWorkouts.count) workouts from HealthKit to SwiftData")
                }
                await MainActor.run {
                    isLoading = false
                    logger.debug("Loaded \(workouts.count) workouts")
                }
            } catch {
                logger.error("Failed to fetch workouts: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Unable to load statistics. Please try again later."
                    ErrorManager.shared.present(
                        title: "Statistics Error",
                        message: "Failed to load workout statistics: \(error.localizedDescription)"
                    )
                }
            }
        }
    }
    
    /// Calculates the total duration from all workout history entries.
    /// - Returns: The total duration in seconds as a `Double`.
    private func totalDuration() -> Double {
        workouts.reduce(into: 0.0) { result, workout in
            result += (workout.history ?? []).reduce(into: 0.0) { historyResult, history in
                historyResult += (history.lastSessionDuration * 60) // Convert minutes to seconds
            }
        }
    }
    
    /// Calculates the average workout duration from all workout history entries.
    /// - Returns: The average duration in seconds as a `Double`.
    private func averageDuration() -> Double {
        let allHistories: [History] = workouts
            .compactMap { $0.history }
            .flatMap { $0 }
        guard !allHistories.isEmpty else { return 0 }
        let totalDuration = allHistories.reduce(into: 0.0) { result, history in
            result += (history.lastSessionDuration * 60) // Convert minutes to seconds
        }
        return totalDuration / Double(allHistories.count)
    }
    
    /// Calculates the average intensity score from all workout history entries (premium feature).
    /// - Returns: The average intensity score as a `Double`, or `nil` if no data.
    private func averageIntensityScore() -> Double? {
        let allHistories: [History] = workouts
            .compactMap { $0.history }
            .flatMap { $0 }
        let validScores = allHistories.compactMap { $0.intensityScore }.filter { $0 > 0 }
        guard !validScores.isEmpty else { return nil }
        let totalScore = validScores.reduce(0.0, +)
        return totalScore / Double(validScores.count)
    }
    
    /// Calculates the most common heart rate zone from all workout history entries (premium feature).
    /// - Returns: The dominant zone as an `Int`, or `nil` if no data.
    private func dominantZoneDistribution() -> Int? {
        let allHistories: [History] = workouts
            .compactMap { $0.history }
            .flatMap { $0 }
        let zoneCounts = allHistories.compactMap { $0.dominantZone }.reduce(into: [Int: Int]()) { counts, zone in
            counts[zone, default: 0] += 1
        }
        return zoneCounts.max(by: { $0.value < $1.value })?.key
    }
    
    /// Formats the duration value for display.
    /// - Parameter duration: The duration in seconds.
    /// - Returns: A formatted string with minutes or "N/A" if zero.
    private func formattedDuration(_ duration: Double) -> String {
        duration > 0 ? String(format: "%.0f min", duration / 60) : "N/A"
    }
    
    /// Formats the intensity score for display.
    /// - Parameter score: The intensity score.
    /// - Returns: A formatted string with the score or "N/A" if nil.
    private func formattedIntensityScore(_ score: Double?) -> String {
        if let score = score, score > 0 {
            return String(format: "%.0f%%", score)
        }
        return "N/A"
    }
    
    /// Formats the dominant zone for display.
    /// - Parameter zone: The dominant zone.
    /// - Returns: A formatted string with the zone or "N/A" if nil.
    private func formattedDominantZone(_ zone: Int?) -> String {
        if let zone = zone, zone >= 1, zone <= 5 {
            return "Zone \(zone)"
        }
        return "N/A"
    }
}


