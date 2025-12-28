//
//  FitSyncContainer.swift
//  ChronicGrind
//

import SwiftData
import CloudKit
import Foundation

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
            fatalError("Failed to get App Group container URL. Ensure App Groups are configured.")
        }
        
        // Ensure the directory exists
        if !fileManager.fileExists(atPath: groupURL.path) {
            do {
                try fileManager.createDirectory(at: groupURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Failed to create App Group directory: \(error.localizedDescription)")
            }
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
