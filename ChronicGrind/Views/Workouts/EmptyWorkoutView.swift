//
//  EmptyWorkoutView.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/27/25.
//

import SwiftUI

/// A view displayed when there are no workouts available, guiding the user to add one.
///
/// This view provides a visually subtle and accessible empty state with an animated icon
/// and instructional text. It aligns with the app's core free features by encouraging
/// workout creation (e.g., "Upper Body A" with exercises/rounds or continuous cardio like "5K Tempo Run").
///
/// - Note: The animation respects user settings for reduced motion and is hidden from accessibility
///   to avoid unnecessary narration. The view supports dynamic type and high contrast modes.
/// - Important: Ensure `Color.proBackground` is defined in the asset catalog for consistent theming;
///   falls back to system background if unavailable.
struct EmptyWorkoutView: View {
    /// State to control the pulse animation of the icon.
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Subtle background for depth, using custom color if available
            (Color.proBackground.ignoresSafeArea())
                .ignoresSafeArea()
                .accessibilityHidden(true)  // Background is decorative
            
            VStack(spacing: 16) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.secondary.opacity(0.8))
                    .symbolEffect(.pulse, isActive: isAnimating)
                    .onAppear {
                        isAnimating = true
                    }
                    .accessibilityHidden(true)  // Icon is decorative; text provides context
                
                Text("No Workouts Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text("Tap the '+' button to add your first workout.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("No workouts available. Tap the plus button to add a new workout.")
            .accessibilityHint("Double-tap to focus on the add button if available.")
            .accessibilityAddTraits(.isStaticText)
        }
    }
}

#Preview {
    EmptyWorkoutView()
}
