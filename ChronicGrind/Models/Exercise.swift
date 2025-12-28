//
//  Exercise.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/4/25.
//

import SwiftData
import Foundation

@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = "New Exercise"
    var order: Int = 0
    
    // CloudKit-safe to-many relationship with proper inverse
    @Relationship(deleteRule: .cascade)
    var splitTimes: [SplitTime]? = []
    
    // Optional: link back to parent workout (not required for now)
    var workout: Workout?
    
    init(name: String = "New Exercise", order: Int = 0) {
        self.name = name
        self.order = order
    }
}
