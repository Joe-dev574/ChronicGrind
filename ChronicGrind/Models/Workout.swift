//
//  Workout.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/15/25.
//

import SwiftUI
import SwiftData
import OSLog
internal import HealthKit

@Model
final class Workout {
    var id: UUID = UUID()
    var title: String = "New Workout"
    var lastSessionDuration: Double  = 0.0
    var dateCreated: Date = Date()
    var dateCompleted: Date? = nil
    
    @Relationship(deleteRule: .nullify)
    var category: Category? = nil
    
    var roundsEnabled: Bool = false
    var roundsQuantity: Int = 1
    var fastestTime: Double? = nil
    var generatedSummary: String? = nil
    
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout)
    var exercises: [Exercise]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \History.workout)
    var history: [History]? = []
    
    @Transient
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.tnt.FitSync2_0",
        category: "Workout"
    )
    
    init(
        title: String = "New Workout",
        exercises: [Exercise] = [],
        lastSessionDuration: Double = 0,
        dateCreated: Date = .now,
        dateCompleted: Date? = nil,
        category: Category? = nil,
        roundsEnabled: Bool = false,
        roundsQuantity: Int = 1
    ) {
        self.title = title
        self.exercises = exercises
        self.lastSessionDuration = lastSessionDuration
        self.dateCreated = dateCreated
        self.dateCompleted = dateCompleted
        self.category = category
        self.roundsEnabled = roundsEnabled
        self.roundsQuantity = roundsQuantity
    }
    
    var sortedExercises: [Exercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }
    
    // MARK: - Personal Best Update
    /// Updates the personal best duration based on the shortest valid session duration in history.
    func updateFastestTime() {
        logger.info("Updating fastest time for workout: \(self.title)")
        
        guard let history = history, !history.isEmpty else {
            fastestTime = nil
            logger.info("Journal entries are empty, fastest time set to nil.")
            return
        }
        
        let allDurations = history.map { $0.lastSessionDuration }
        let validDurations = allDurations.filter { $0 > 0 }
        
        fastestTime = validDurations.min()
        logger.info("Updated fastestTime (minutes): \(String(describing: self.fastestTime))")
    }
    
    // MARK: - Effective Exercises
    /// Computed property to return exercises repeated by rounds.
    var effectiveExercises: [Exercise] {
        if roundsEnabled && roundsQuantity > 1 {
            return Array(repeating: sortedExercises, count: roundsQuantity).flatMap { $0 }
        }
        return sortedExercises
    }
    
    // MARK: - Fastest Duration
    /// The fastest session duration in minutes from the workout’s history.
    var fastestDuration: Double {
        history?.map { $0.lastSessionDuration }.min() ?? 0.0
    }
    
    // MARK: - Default Duration
    /// Returns the default duration for the workout, prioritizing personal best or the fastest duration.
    /// - Returns: The default duration in minutes.
    func getDefaultDuration() -> Double {
        fastestTime ?? fastestDuration
    }
    
    // MARK: - Summary Report
    /// Updates the generated summary based on the workout’s history, providing a detailed and professional overview including key performance metrics.
    /// - Parameter context: The SwiftData model context for persistence.
    func updateGeneratedSummary(context: ModelContext) {
        logger.info("Updating summary for workout: \(self.title)")

        guard let history = history, !history.isEmpty else {
            generatedSummary = nil
            logger.info("Journal entries are empty, generatedSummary set to nil.")
            return
        }

        let totalSessions = history.count
        let averageDurationInMinutes = history.map { $0.lastSessionDuration }.reduce(0.0, +) / Double(totalSessions)
        let averageDurationInSeconds = averageDurationInMinutes * 60

        if averageDurationInSeconds < 0 {
            logger.warning("Invalid average duration: \(averageDurationInSeconds) seconds")
            generatedSummary = nil
            ErrorManager.shared.present(
                title: "Summary Error",
                message: "Unable to generate workout summary due to invalid duration."
            )
            return
        }

        // Calculate additional metrics
        let fastestTimeFormatted = fastestTime.map { formatDuration($0 * 60) } ?? "N/A"
        let exerciseNames = sortedExercises.map { $0.name }.joined(separator: ", ")

        // Construct professional summary
        var summary = "Workout Performance Overview:\n\n"
        summary += "This workout has been completed \(totalSessions) time(s).\n"
        summary += "Average session duration: \(formatDuration(averageDurationInSeconds)).\n"
        summary += "Fastest recorded time: \(fastestTimeFormatted).\n"
        summary += "Exercises included: \(exerciseNames)."

        generatedSummary = summary
        logger.info("Updated generatedSummary: \(self.generatedSummary ?? "nill")")

        if context.hasChanges {
            do {
                try context.save()
                logger.info("Saved ModelContext after updating generatedSummary.")
            } catch {
                logger.error("Failed to save ModelContext after updating generatedSummary: \(error.localizedDescription)")
                ErrorManager.shared.present(
                    title: "Save Error",
                    message: "Failed to save workout summary: \(error.localizedDescription)"
                )
            }
        }
    }
    // MARK: - Helper for Zone Description
    private func zoneDesc(_ zone: Int) -> String {
        switch zone {
        case 1: return "Very Light"
        case 2: return "Light"
        case 3: return "Moderate"
        case 4: return "Hard"
        case 5: return "Maximum"
        default: return "Unknown"
        }
    }
    // MARK: - Duration Formatting
    /// Formats a duration in seconds into a human-readable string.
    /// Examples: 75 -> "1m 15s", 3661 -> "1h 1m 1s"
    private func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m \(secs)s"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

