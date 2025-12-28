//
//  ChronicGrindContainer.swift
//  ChronicGrind
//

import SwiftData
import CloudKit
import Foundation
import OSLog




final class ChronicGrindContainer {
    static let container: ModelContainer = {
        let appGroupDefaults = UserDefaults(suiteName: "group.com.tnt.ChronicGrind") ?? .standard
        let isPremium = appGroupDefaults.bool(forKey: "isPremium")
        
        let schema = Schema([
            User.self,
            HealthMetrics.self,
            Category.self,
            Workout.self,
            SplitTime.self,
            History.self,
            Exercise.self
        ])
        
        let fileManager = FileManager.default
        guard let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.tnt.ChronicGrind") else {
            Logger(subsystem: "com.tnt.ChronicGrind", category: "Container").error("Failed to get App Group URL. Using fallback.")
            let fallbackURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("ChronicGrind.store")
            let config = ModelConfiguration(url: fallbackURL, allowsSave: true, cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: [config])
        }
        
        // Ensure directory exists
        if !fileManager.fileExists(atPath: groupURL.path) {
            try? fileManager.createDirectory(at: groupURL, withIntermediateDirectories: true)
        }
        
        let storeURL = groupURL.appendingPathComponent("ChronicGrind.store")
        
        let modelConfiguration: ModelConfiguration
        if isPremium {
            modelConfiguration = ModelConfiguration(
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .private("iCloud.com.tnt.ChronicGrind")
            )
        } else {
            modelConfiguration = ModelConfiguration(
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
        }
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error.localizedDescription)")
        }
    }()
    
    private init() {}
}
