//
//  AuthenticationView.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/27/25.
//

import SwiftUI
import AuthenticationServices
import OSLog

struct AuthenticationView: View {
    @Environment(AuthenticationManager.self) private var auth
    @Environment(ErrorManager.self) private var errorManager
    @Environment(\.colorScheme) private var colorScheme
    
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    private var themeColor: Color { Color(hex: selectedThemeColorData) ?? .blue }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: colorScheme == .dark
                                   ? [Color.black.opacity(0.5), Color.gray.opacity(0.3)]
                                   : [Color.white.opacity(0.9), Color.gray.opacity(0.15)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // App logo / icon
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 80))
                    .foregroundStyle(themeColor)
                    .accessibilityHidden(true)
                
                VStack(spacing: 12) {
                    Text("Welcome to FitSync")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Track workouts, journal progress, and stay consistent — all with complete privacy.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Sign in with Apple button
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        auth.handleSignInWithAppleRequest(request)
                    },
                    onCompletion: { result in
                        Task {
                            await handleSignInResult(result)
                        }
                    }
                )
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .padding(.horizontal, 40)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Privacy & Terms link
                Button {
                    if let url = URL(string: "https://www.fitsynchub.com/english-privacy-policy") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Terms and Privacy Policy")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
                .accessibilityLabel("Terms and Privacy Policy")
                .accessibilityHint("Double-tap to view terms and privacy details")
                .accessibilityAddTraits(.isLink)
            }
            .padding(.vertical, 40)
            .animation(.easeInOut(duration: 0.5), value: true)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("FitSync sign-in screen")
        }
    }
    
    // MARK: - Handle Sign-In Result
    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                auth.handleAuthorizationCompletion(credential)
            } else {
                errorManager.present(
                    title: "Sign-In Error",
                    message: "Received unexpected credential type from Apple."
                )
            }
            
        case .failure(let error):
            // User cancelled – no alert needed
            if (error as? ASAuthorizationError)?.code == .canceled {
                return
            }
            
            errorManager.present(
                title: "Sign-In Failed",
                message: error.localizedDescription
            )
        }
    }
}

#Preview {
    AuthenticationView()
        .environment(AuthenticationManager.shared)
        .environment(ErrorManager.shared)
}

