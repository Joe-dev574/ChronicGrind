//
//  OnboardingFlowView.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/27/25.
//

import SwiftUI
import SwiftData
import OSLog

struct OnboardingFlowView: View {
    @Environment(AuthenticationManager.self) private var auth
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    
    private var themeColor: Color { Color(hex: selectedThemeColorData) ?? .blue }
    private let logger = Logger(subsystem: "com.tnt.ChronicGrind", category: "OnboardingView")
    
    @State private var showPremiumTeaser = false
    
    var body: some View {
        ZStack {
            // Enhanced dark gradient background: light and inviting, not dark
            LinearGradient(
                gradient: Gradient(colors: colorScheme == .dark ? [Color.black.opacity(0.5), Color.gray.opacity(0.3)] : [Color.white.opacity(0.9), Color.gray.opacity(0.15)]),
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Icons row with polished styling and animation
                HStack(spacing: 20) {
                    Image(systemName: "stopwatch.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(themeColor)
                        .shadow(color: .black.opacity(0.1), radius: 4)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(themeColor)
                        .shadow(color: .black.opacity(0.1), radius: 4)
                    Image(systemName: "applewatch")
                        .font(.system(size: 50))
                        .foregroundStyle(themeColor)
                        .shadow(color: .black.opacity(0.1), radius: 4)
                }
                .padding(.bottom, 24)
                .accessibilityHidden(true)
                .scaleEffect(1.0) // Placeholder for animation
                .animation(.easeInOut(duration: 0.6), value: true)
                
                // Welcome text with increased size and Dynamic Type support
                Text("Welcome to FitSync!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(themeColor)
                    .accessibilityHint("Introduction to the FitSync app.")
                
                // Feature list with aligned icons and improved spacing
                VStack(alignment: .leading, spacing: 16) {
                    FeatureItem(icon: "pencil.and.outline", text: "Create custom workouts with splits and rounds.")
                    FeatureItem(icon: "chart.line.uptrend.xyaxis", text: "Track HR zones, calories, and trends privately.")
                    FeatureItem(icon: "applewatch", text: "Upgrade to premium for Apple Watch control.")
                }
                .padding(.horizontal, 40)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("FitSync features: Create custom workouts, track HR zones, and upgrade for Watch control.")
                
                Spacer()
                
                // Get Started button with professional styling
                Button {
                    completeOnboarding()
                    // showPremiumTeaser = true  // Show premium teaser
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
                .accessibilityLabel("Get Started")
                .accessibilityHint("Double-tap to complete onboarding and begin using the app.")
                .accessibilityAddTraits(.isButton)
            }
            .padding(.top, 60)
        }
    }

private func completeOnboarding() {
        Task {
            do {
                await DefaultDataSeeder.ensureDefaults(in: ChronicGrindContainer.container)
                auth.currentUser?.isOnboardingComplete = true
                try context.save()
                logger.info("Onboarding completed and data seeded \(Date())")
                    
            } catch {
                logger.error("Failed to complete onboarding: \(error.localizedDescription)")
            }
        }
    }
}


struct FeatureItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

