//
//  ContentView.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/27/25.
//

import SwiftUI
import SwiftData
import OSLog

struct ContentView: View {
    @Environment(AuthenticationManager.self) private var auth
    private let logger = Logger(subsystem: "com.tnt.ForgeSync", category: "ContentView")
    
    @State private var isLoading = true  // Added for brief auth check delay
    
    
    var body: some View {
        NavigationStack {
                    Group {
                        if isLoading {
                            ProgressView("Loading...")
                                .accessibilityLabel("Loading app content")
                        } else {
                            if auth.isSignedIn {
                                if auth.currentUser?.isOnboardingComplete == true {
                                    WorkoutListScreen()
                                        .onAppear {
                                            logger.info("[ContentView] Navigated to WorkoutListScreen at \(Date())")
                                        }
                                } else {
                                    OnboardingFlowView()
                                        .onAppear {
                                            logger.info("[ContentView] Navigated to OnboardingView at \(Date())")
                                        }
                                }
                            } else {
                                AuthenticationView()
                                    .onAppear {
                                        logger.info("[ContentView] Navigated to AuthenticationView at \(Date())")
                                    }
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("FitSync main navigation")
                    .accessibilityHint("Sign in or complete onboarding to access workouts")
                }
                .onAppear {
                    // Simulate brief delay for auth restore (adjust as needed)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isLoading = false
                    }
                }
            }
        }
