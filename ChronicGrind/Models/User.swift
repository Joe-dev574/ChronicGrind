//
//  User.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/4/25.
//

import SwiftData


// For HKBiologicalSex mapping and health metric context

/// A SwiftData model representing a user's onboarding status and essential profile details.
/// Focuses on privacy: stores Apple ID, onboarding status, and optional identity details.
@Model
final class User {
    // MARK: - Properties
    var appleUserId: String = ""  // Unique identifier from Sign in with Apple (mandatory)
    var isOnboardingComplete: Bool = false  // Tracks if onboarding (permissions, setup) is done
    // Optional identity/profile details
    var email: String?
    var displayName: String?
    // Relationship to health metrics (one-to-one)
    var healthMetrics: HealthMetrics?
    // MARK: - Initialization
    /// Designated initializer that ensures all stored properties are initialized.
    init(
        appleUserId: String,
        email: String? = nil,
        isOnboardingComplete: Bool = false,
        displayName: String? = nil
    ) {
        self.appleUserId = appleUserId
        self.email = email
        self.isOnboardingComplete = isOnboardingComplete
        self.displayName = displayName
    }
}
