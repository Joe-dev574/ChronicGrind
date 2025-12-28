//
//  WorkoutList.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/27/25.
//

/// A view that displays a list of workouts or an empty state if no workouts exist.
/// Supports swipe-to-delete functionality and integrates with SwiftData for data management.
/// Ensures accessibility with VoiceOver support and dynamic backgrounds for light and dark modes.
import SwiftUI
import SwiftData

struct WorkoutList: View {
    let workouts: [Workout]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Group {
            if workouts.isEmpty {
                EmptyState()
            } else {
                workoutList
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workout list")
        .accessibilityHint("List of your workouts, swipe left to delete")
    }
    
    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(workouts[index])
        }
    }

    @ViewBuilder
    private func EmptyState() -> some View {
        VStack { EmptyWorkoutView() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.proBackground)
    }
//MARK:  WORKOUT LIST
    private var workoutList: some View {
        List {
            ForEach(workouts) { workout in
                NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                    WorkoutRow(workout: workout)
                }
            }
            .onDelete(perform: delete)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}
//MARK: WORKOUT ROW
private struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        WorkoutCard(workout: workout)
            .accessibilityElement()
            .accessibilityLabel("Workout: \(workout.title)")
            .accessibilityHint("Double-tap to view details for \(workout.title)")
            .accessibilityAddTraits(.isButton)
    }
}
