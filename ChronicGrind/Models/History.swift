//
//  History.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/4/25.
//

import SwiftUI
import SwiftData
import Foundation

@Model
final class History {
    var id: UUID = UUID()
    var date: Date = Date()
    var lastSessionDuration: Double = 0.0
    var notes: String?
    var exercisesCompleted: [Exercise] = []
   
    
    @Relationship(deleteRule: .cascade)
    var splitTimes: [SplitTime]? = []
    
    @Relationship(deleteRule: .nullify)
    var workout: Workout?
    
    var intensityScore: Double?
    var progressPulseScore: Double?
    var dominantZone: Int?
    
    init(
        date: Date = .now,
        lastSessionDuration: Double = 0,
        notes: String? = nil,
        exercisesCompleted: [Exercise] = [],
        splitTimes: [SplitTime] = [],
        intensityScore: Double? = nil,
        progressPulseScore: Double? = nil,
        dominantZone: Int? = nil
    ) {
        self.date = date
        self.lastSessionDuration = lastSessionDuration
        self.notes = notes
        self.exercisesCompleted = exercisesCompleted
        self.splitTimes = splitTimes
        self.intensityScore = intensityScore
        self.progressPulseScore = progressPulseScore
        self.dominantZone = dominantZone
    }
    // MARK: - Computed Display Properties (Usable in #Predicate)
        
        /// Full formatted duration (e.g., "45:32" or "1:23:45")
        var formattedDuration: String {
            let seconds = lastSessionDuration * 60 // Convert minutes to seconds
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = seconds < 3600 ? [.minute, .second] : [.hour, .minute, .second]
            formatter.unitsStyle = .positional
            formatter.zeroFormattingBehavior = .pad
            return formatter.string(from: seconds) ?? "00:00"
        }
        
        /// Concise duration for compact displays (e.g., "45.3m", "1.2h", "32.1s")
        var formattedDurationConcise: String {
            let seconds = lastSessionDuration * 60
            if seconds < 60 {
                return String(format: "%.1fs", seconds)
            } else if seconds < 3600 {
                return String(format: "%.1fm", seconds / 60)
            } else {
                return String(format: "%.1fh", seconds / 3600)
            }
        }
        
        /// Short time string (e.g., "2:30 PM")
        var shortTime: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        
        /// Medium date string (e.g., "Dec 23, 2025")
        var mediumDate: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
        
        /// Combined date and time for list headers (e.g., "Dec 23, 2025 · 2:30 PM")
        var dateAndTime: String {
            "\(mediumDate) · \(shortTime)"
        }
    }
