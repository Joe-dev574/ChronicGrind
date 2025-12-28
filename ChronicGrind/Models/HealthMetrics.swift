//
//  HealthMetrics.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/6/25.
//

import SwiftUI
import SwiftData
import PhotosUI
import OSLog

/// Represents a single progress selfie taken by the user.
struct ProgressSelfie: Identifiable, Codable, Hashable {
    let id: UUID
    var imageData: Data
    var dateAdded: Date
    /// Formatted display name for the selfie, e.g., "May '25".
    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"
        return formatter.string(from: dateAdded)
    }
    init(id: UUID = UUID(), imageData: Data, dateAdded: Date = Date()) {
        self.id = id
        self.imageData = imageData
        self.dateAdded = dateAdded
    }
}

/// A SwiftData model representing a user's health metrics and additional profile details.
/// This model is linked to the User model via a one-to-one relationship for modularity and privacy.
@Model
final class HealthMetrics {
    // MARK: - Properties
    // Health Metrics
    var weight: Double?  // in kilograms
    var height: Double?  // in meters
    var age: Int?
    var restingHeartRate: Double?  // in beats per minute
    var maxHeartRate: Double?  // in beats per minute. Can be user-entered or estimated.
    var biologicalSexString: String?  // Storing HKBiologicalSex.description or a custom string
    // Options: "Male", "Female", "Other", "Not Set"
    // Additional Profile Details
    var fitnessGoal: String?
    @Attribute(.externalStorage) var profileImageData: Data?
    var progressSelfies: [ProgressSelfie] = []
    // Relationship back to User (one-to-one)
    var user: User?
    // MARK: - Initialization
    /// Designated initializer that ensures all stored properties are initialized.
    init(
        weight: Double? = nil,
        height: Double? = nil,
        age: Int? = nil,
        restingHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        biologicalSexString: String? = nil,
        fitnessGoal: String? = "General Fitness",
        profileImageData: Data? = nil,
        progressSelfies: [ProgressSelfie] = []
    ) {
        self.weight = weight
        self.height = height
        self.age = age
        self.restingHeartRate = restingHeartRate
        self.maxHeartRate = maxHeartRate
        self.biologicalSexString = biologicalSexString
        self.fitnessGoal = fitnessGoal
        self.profileImageData = profileImageData
        self.progressSelfies = progressSelfies
    }
}

