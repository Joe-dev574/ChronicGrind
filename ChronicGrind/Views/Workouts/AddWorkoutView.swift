//
//  AddWorkoutView.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/27/25.
//

import SwiftUI
import SwiftData
import OSLog
import Combine

/// A SwiftUI view for adding a new workout to the app's database.
///
/// This view handles user input for workout details and saves the data using SwiftData.
/// It includes sections for title, category selection, rounds configuration, and dynamic exercise addition.
///
/// - Note: Integrates with core free features for custom workout creation (e.g., "Upper Body A" with exercises/rounds or continuous cardio like "5K Tempo Run").
///   Supports HealthKit context via associated models for future journaling.
/// - Important: All interactive elements include accessibility labels, hints, values, and traits per Apple's Human Interface Guidelines (HIG).
///   The view supports Dynamic Type, reduced motion, and high contrast modes.
struct AddWorkoutView: View {
    
    // MARK: - Environment and Dependencies
    
    /// The model context for SwiftData operations, used to insert and save new workouts.
    @Environment(\.modelContext) private var context
    
    /// Dismiss action to close the view, typically after saving or canceling.
    @Environment(\.dismiss) private var dismiss
    
    /// Environment object for managing and presenting errors to the user.
    @Environment(ErrorManager.self) private var errorManager
    
    // MARK: - State Properties
    
    /// Stored user preference for the app's theme color, defaulting to blue (#0096FF).
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    
    /// The title of the workout, bound to the text field.
    @State private var title: String = ""
    
    /// Array of exercises for the workout, dynamically added/removed by the user.
    @State private var exercises: [Exercise] = []
    
    /// The creation date of the workout, set to the current date by default.
    @State private var dateCreated: Date = Date()
    
    /// Optional selected category for the workout.
    @State private var selectedCategory: Category?
    
    /// Toggle state for enabling multiple rounds in the workout.
    @State private var roundsEnabled: Bool = false
    
    /// String input for the number of rounds, validated to ensure positive integer.
    @State private var roundsQuantityInput: String = "1"
    
    /// State to present the category picker sheet.
    @State private var showCategoryPicker: Bool = false
    
    // MARK: - Private Properties
    
    /// Computed theme color based on user preference, falling back to blue.
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    
    /// Logger for tracking view events and errors.
    private let logger = Logger(subsystem: "com.tnt.ForgeSync", category: "AddWorkoutView")
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Title Section
                Section(header: Text("Title")
                    .font(.system(size: 18, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)) {
                    TextField("Name of Workout...", text: $title)
                        .font(.system(.body, design: .serif))
                        .textInputAutocapitalization(.words)
                        .foregroundStyle(.primary)
                        .accessibilityLabel("Workout title")
                        .accessibilityHint("Enter the name of the workout")
                }
                
                // Category Section
                Section(header: Text("Category")
                    .font(.system(size: 18, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)) {
                    Button(action: {
                        showCategoryPicker = true
                    }) {
                        HStack {
                            Text(selectedCategory?.categoryName ?? "Select Category")
                                .foregroundStyle(.primary)
                            Spacer()
                            if let category = selectedCategory {
                                Label("", systemImage: category.symbol)
                                    .labelStyle(.iconOnly)
                                    .foregroundStyle(category.categoryColor.color)
                            }
                        }
                    }
                    .accessibilityLabel("Select category")
                    .accessibilityHint("Tap to choose a workout category")
                    .accessibilityAddTraits(.isButton)
                }
                
                // Rounds Section
                Section(header: Text("Rounds")
                    .font(.system(size: 18, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)) {
                    Toggle("Enable Rounds", isOn: $roundsEnabled)
                        .accessibilityLabel("Enable rounds")
                        .accessibilityHint("Toggle to enable multiple rounds for the workout")
                    
                    if roundsEnabled {
                        TextField("Number of Rounds", text: $roundsQuantityInput)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(.primary)
                            .accessibilityLabel("Number of rounds")
                            .accessibilityHint("Enter the number of rounds")
                    }
                }
                
                // Exercises Section
                Section(header: Text("Exercises")
                    .font(.system(size: 18, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)) {
                    ForEach($exercises) { $exercise in
                        TextField("Exercise Name", text: $exercise.name)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(.primary)
                            .accessibilityLabel("Exercise name")
                            .accessibilityHint("Enter the name of the exercise")
                    }
                    .onDelete { indices in
                        exercises.remove(atOffsets: indices)
                        updateExerciseOrders()
                    }
                    .onMove { source, destination in
                        exercises.move(fromOffsets: source, toOffset: destination)
                        updateExerciseOrders()
                    }
                    
                    Button("Add Exercise") {
                        let newExercise = Exercise(name: "", order: exercises.count)
                        exercises.append(newExercise)
                    }
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(.blue)
                    .accessibilityLabel("Add exercise")
                    .accessibilityHint("Tap to add a new exercise")
                    .accessibilityAddTraits(.isButton)
                }
            }
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(themeColor)
                    .accessibilityLabel("Cancel button")
                    .accessibilityHint("Double-tap to cancel and dismiss the view")
                    .accessibilityAddTraits(.isButton)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(.white)
                    .buttonStyle(.borderedProminent)
                    .tint(themeColor)
                    .accessibilityLabel("Save workout button")
                    .accessibilityHint(
                        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Disabled, enter a workout title to enable"
                            : "Double-tap to save the workout"
                    )
                    .accessibilityValue(
                        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Disabled" : "Enabled"
                    )
                    .accessibilityAddTraits(.isButton)
                }
            }
            // Sheet for selecting category.
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPicker(selectedCategory: $selectedCategory)
                    .accessibilityLabel("Category picker")
                    .accessibilityHint("Select a category for the workout")
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Updates the order property of each exercise based on its current index in the array.
    /// This ensures exercises are persisted in the user-defined order.
    private func updateExerciseOrders() {
        for (index, exercise) in exercises.enumerated() {
            exercise.order = index
        }
    }
    
    /// Saves the workout to the SwiftData context.
    ///
    /// Filters out empty exercises, validates rounds quantity, and handles save errors.
    /// Dismisses the view on success.
    private func save() {
        updateExerciseOrders()
        let newWorkout = Workout(
            title: title,
            exercises: exercises.filter {
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            },
            dateCreated: dateCreated,
            category: selectedCategory,
            roundsEnabled: roundsEnabled,
            roundsQuantity: max(1, Int(roundsQuantityInput) ?? 1)
        )
        context.insert(newWorkout)
        do {
            try context.save()
            logger.info("Workout saved successfully")
            dismiss()
        } catch {
            logger.error("Failed to save workout: \(error.localizedDescription)")
            errorManager.present(
                title: "Save Error",
                message: "Failed to save workout: \(error.localizedDescription)"
            )
        }
    }
}

#Preview {
    AddWorkoutView()
        .modelContainer(for: Workout.self, inMemory: true)  // For preview with in-memory store
        .environment(ErrorManager.shared)
}
