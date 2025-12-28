//
//  ChronicGrindApp.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/27/25.
//

import SwiftUI
import SwiftData
/// The main entry point for the ChronicGrind iOS app.
///
/// This struct configures the app's scene, injects shared environment objects and values,
/// and applies user preferences such as appearance settings. It serves as the root of the
/// SwiftUI view hierarchy and ensures proper integration with SwiftData, HealthKit, and other managers.
///
/// - Note: This app uses Sign in with Apple for authentication, HealthKit for fitness data,
///   and iCloud for premium sync features. Ensure entitlements are configured for HealthKit,
///   CloudKit, In-App Purchases, and App Groups.
/// - Important: The app supports both free and premium tiers, with the Apple Watch app
///   available only to premium subscribers.
@main
struct ChronicGrindApp: App {
    /// The user's preferred appearance setting (system, light, or dark), stored persistently.
    @AppStorage("appearanceSetting") private var appearanceSetting: AppearanceSetting = .system
    
    /// Shared SwiftData container for the app.
    private let container: ModelContainer = ChronicGrindContainer.container
    init() {
        // Seed default categories asynchronously on launch without capturing self in Task
        let container = self.container
        Task {
            await DefaultDataSeeder.ensureDefaults(in: container)
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(AuthenticationManager.shared)
                .environment(HealthKitManager.shared)
                .environment(PurchaseManager.shared)
                .environment(ErrorManager.shared)
                .modelContainer(container)
                .preferredColorScheme(appearanceSetting.colorScheme)
        }
    }
}
/// Enum representing the user's appearance preferences.
///
/// This enum maps to SwiftUI's ColorScheme for easy application in views.
enum AppearanceSetting: String, Codable {
    case system
    case light
    case dark
    /// The corresponding ColorScheme for the appearance setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil  // Follows system setting
        case .light: return .light
        case .dark: return .dark
        }
    }
}
