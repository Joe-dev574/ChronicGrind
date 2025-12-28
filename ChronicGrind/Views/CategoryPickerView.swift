//
//  CategoryPickerView.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/27/25.
//

import SwiftUI
import SwiftData
import OSLog




struct CategoryPicker: View {
    /// The selected category, bound to update the parent view’s state.
    @Binding var selectedCategory: Category?
    
    /// The environment’s dismiss action to close the view.
    @Environment(\.dismiss) private var dismiss
    
    /// Query to fetch all categories from SwiftData, sorted by name.
    @Query(sort: \Category.categoryName, order: .forward) private var categories: [Category]
    
    /// Logger for debugging and monitoring view operations.
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.ChronicGrind.default.subsystem", category: "CategoryPicker")
    
    /// Defines adaptive grid columns for a responsive layout.
    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 12)
    ]
    
    var body: some View {
        ZStack {
            Color.proBackground.ignoresSafeArea()
            NavigationStack {
                ScrollView {
                    if categories.isEmpty {
                        Text("No categories available")
                            .font(.system(size: 15, weight: .regular, design: .serif))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                            .accessibilityLabel("No categories available")
                            .accessibilityHint("No workout categories found. Try adding a category or contact support.")
                    } else {
                        LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
                            ForEach(categories) { category in
                                categoryCell(category)
                                    .onTapGesture {
                                        selectedCategory = category
                                        logger.debug("Selected category: \(category.categoryName)")
                                        dismiss()
                                    }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }
                .navigationTitle("Select a Category")
                .accessibilityLabel("Select a Workout Category")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            logger.debug("Dismissed CategoryPicker")
                            dismiss()
                        }
                        .accessibilityLabel("Done")
                        .accessibilityHint("Dismiss the category picker")
                    }
                }
                .onAppear {
                    logger.debug("CategoryPicker appeared with \(categories.count) categories")
                }
            }
        }
    }
    /// Creates a cell for a category, displaying its icon, name, and color.
    /// - Parameter category: The category to display.
    /// - Returns: A view representing the category cell.
    private func categoryCell(_ category: Category) -> some View {
        VStack(spacing: 8) {
            Image(systemName: category.symbol)
                .font(.title2)
                .foregroundStyle(category.categoryColor.color)
                .frame(width: 40, height: 40)
            Text(category.categoryName)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.grayBack.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(category.categoryColor.color.opacity(0.3), lineWidth: 3)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Select \(category.categoryName)")
        .accessibilityHint("Double-tap to choose \(category.categoryName) as the workout category")
        .accessibilityAddTraits(.isButton)
    }
}


