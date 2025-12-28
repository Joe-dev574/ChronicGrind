//
//  WorkoutEditView.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/27/25.
//

import SwiftUI
import SwiftData
import Foundation

/// A view for editing the details of an existing workout.
///
/// This view allows users to modify the workout's title, category, rounds, and exercises.
/// Changes are saved to the SwiftData model context upon confirmation.
/// It handles validation and save errors via local alerts, ensuring data integrity.
///
/// - Note: Integrates with the app's core free features for custom workout creation (e.g., "Upper Body A" with exercises/rounds or continuous cardio like "5K Tempo Run").
/// - Important: All fields are accessible with VoiceOver support, including labels and hints for inclusivity.
struct WorkoutEditView: View {
    // MARK: - Environment Properties
    
    /// The SwiftData model context for persisting changes.
    @Environment(\.modelContext) private var context: ModelContext
    
    /// A binding to dismiss the view after successful save.
    @Environment(\.dismiss) private var dismiss
    
    /// The current color scheme (light or dark mode) for adaptive UI.
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Properties
    
    /// The workout being edited.
    let workout: Workout
    
    // MARK: - State Properties
    
    /// The workout title, bound to the text field.
    @State private var title: String
    
    /// The sorted list of exercises for the workout.
    @State private var sortedExercises: [Exercise]
    
    /// The selected category for the workout.
    @State private var selectedCategory: Category?
    
    /// Flag to enable multiple rounds.
    @State private var roundsEnabled: Bool
    
    /// Input string for the number of rounds.
    @State private var roundsQuantityInput: String
    
    /// Flag to show the category picker sheet.
    @State private var showCategoryPicker: Bool = false
    
    /// Flag to present the alert for validation, success, or errors.
    @State private var showAlert: Bool = false
    
    /// Title for alert presentations.
    @State private var alertTitle: String = ""
    
    /// Message for alert presentations.
    @State private var alertMessage: String = ""
    
    // MARK: - Initialization
    
    /// Initializes the view with the workout to edit.
    ///
    /// Prepopulates state properties from the workout model for editing.
    ///
    /// - Parameter workout: The `Workout` object to edit.
    init(workout: Workout) {
        self.workout = workout
        _title = State(initialValue: workout.title)
        _sortedExercises = State(initialValue: workout.sortedExercises)
        _selectedCategory = State(initialValue: workout.category)
        _roundsEnabled = State(initialValue: workout.roundsEnabled)
        _roundsQuantityInput = State(initialValue: String(workout.roundsQuantity))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Title Section
                Section(header: Text("Title")
                    .font(.system(size: 18, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(selectedCategory?.categoryColor.color ?? .secondary)) {
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
                    ForEach($sortedExercises) { $exercise in
                        TextField("Exercise Name", text: $exercise.name)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(.primary)
                            .accessibilityLabel("Exercise name")
                            .accessibilityHint("Enter the name of the exercise")
                    }
                    .onDelete { indices in
                        sortedExercises.remove(atOffsets: indices)
                        updateExerciseOrders()
                    }
                    .onMove(perform: moveExercises)
                    
                    Button("Add Exercise") {
                        let newExercise = Exercise(name: "", order: sortedExercises.count)
                        sortedExercises.append(newExercise)
                    }
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(.blue)
                    .accessibilityLabel("Add exercise")
                    .accessibilityHint("Tap to add a new exercise")
                    .accessibilityAddTraits(.isButton)
                }
            }
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(.blue)
                    .accessibilityLabel("Save workout")
                    .accessibilityHint("Tap to save changes to the workout")
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(.red)
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Tap to discard changes and dismiss")
                }
            }
            // Sheet for selecting category.
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPicker(selectedCategory: $selectedCategory)
                    .accessibilityLabel("Category picker")
                    .accessibilityHint("Select a category for the workout")
            }
            // Local alert for validation, success, and errors.
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Moves exercises in the list and updates their orders.
    ///
    /// - Parameters:
    ///   - source: The source index set for moving.
    ///   - destination: The destination index.
    private func moveExercises(from source: IndexSet, to destination: Int) {
        sortedExercises.move(fromOffsets: source, toOffset: destination)
        updateExerciseOrders()
    }
    
    /// Updates the order property of each exercise based on their current position in the list.
    private func updateExerciseOrders() {
        for (index, exercise) in sortedExercises.enumerated() {
            exercise.order = index
        }
    }
    
    /// Saves changes to the workout and handles validation and errors.
    ///
    /// Validates the title and rounds input, filters valid exercises, updates the model,
    /// and saves the context. Presents alerts for feedback and dismisses the view on success after a short delay.
    @MainActor
    private func save() {
        // Validate title is not empty.
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertTitle = "Validation Error"
            alertMessage = "Workout title cannot be empty."
            showAlert = true
            return
        }
        
        // Validate rounds quantity if enabled.
        if roundsEnabled {
            guard let quantity = Int(roundsQuantityInput), quantity > 0 else {
                alertTitle = "Validation Error"
                alertMessage = "Number of rounds must be a positive integer."
                showAlert = true
                return
            }
        }
        
        // Update workout properties.
        workout.title = title
        workout.category = selectedCategory
        workout.roundsEnabled = roundsEnabled
        workout.roundsQuantity = max(1, Int(roundsQuantityInput) ?? 1)
        
        // Filter out empty exercises and update orders.
        let validExercises = sortedExercises.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        for (index, exercise) in validExercises.enumerated() {
            exercise.order = index
        }
        workout.exercises = validExercises
        
        do {
            try context.save()
            alertTitle = "Workout Saved"
            alertMessage = "Your workout '\(workout.title)' has been successfully updated."
            showAlert = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
            }
        } catch {
            alertTitle = "Save Error"
            alertMessage = "Failed to save workout: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

// MARK: - Extensions

/// Extension for Optional to provide a bound value for bindings.
extension Optional where Wrapped: Hashable {
    /// A bound optional value for use in SwiftUI bindings.
    var bound: Wrapped? {
        get { self }
        set { self = newValue }
    }
}
