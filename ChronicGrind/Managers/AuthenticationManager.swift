//
//  AuthenticationManager.swift
//  ChronicGrind
//
//

import AuthenticationServices
import OSLog
import SwiftUI
import SwiftData




@MainActor @Observable
final class AuthenticationManager {
    // MARK: - Public Observable State
    var currentUser: User?
    var isSignedIn: Bool { currentUser != nil }
    
    // MARK: - Constants
    private let appGroupIdentifier = "group.com.tnt.FitSync"
    private let appleUserIDKey = "appleUserID"
    
    // MARK: - Dependencies
    private let modelContainer: ModelContainer
    private let logger = Logger(
        subsystem: "com.tnt.FitSync2_0",
        category: "Auth"
    )
    
    // MARK: - Shared App Group Defaults
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    // MARK: - Singleton
    static let shared = AuthenticationManager(
        modelContainer: ChronicGrindContainer.container
    )
    
    private init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        restoreSessionFromSharedDefaults()
    }
    
    // MARK: - Session Restore (Fixed guard chaining)
    private func restoreSessionFromSharedDefaults() {
        guard let defaults = sharedDefaults else {
            logger.error("Unable to access shared App Group defaults")
            return
        }
        
        guard let appleUserId = defaults.string(forKey: appleUserIDKey) else {
            print("debug: No Apple User ID in shared defaults: \(defaults.string(forKey: appleUserIDKey).debugDescription)")
            logger.debug("No Apple User ID in shared defaults – user not signed in")
            return
        }
        
        if let user = fetchUser(appleUserId: appleUserId) {
            self.currentUser = user
            logger.info("Session restored from shared defaults for user: \(appleUserId.prefix(8))...")
        } else {
            logger.warning("Apple User ID found in defaults but no matching User – clearing stale ID")
            defaults.removeObject(forKey: appleUserIDKey)
        }
    }
    
    // MARK: - Sign In Completion
    func completeSignIn(with user: User) {
        self.currentUser = user
        
        // Persist Apple User ID to shared App Group
        sharedDefaults?.set(user.appleUserId, forKey: appleUserIDKey)
        logger.info("Apple User ID saved to shared defaults")
        
        // Auto-complete onboarding for fresh users
        if !user.isOnboardingComplete {
            user.isOnboardingComplete = true
            try? ModelContext(modelContainer).save()
        }
    }
    
    // MARK: - Sign Out
    func signOut() {
        sharedDefaults?.removeObject(forKey: appleUserIDKey)
        self.currentUser = nil
        logger.info("User signed out – cleared shared defaults")
    }
    
    // MARK: - Apple Sign In Request Configuration
    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        logger.debug("Configured Sign in with Apple request with scopes")
    }
    
    // MARK: - Apple Sign In Completion
    func handleAuthorizationCompletion(_ credential: ASAuthorizationAppleIDCredential) {
        let appleUserId = credential.user  // Direct assignment—no guard needed
        
        logger.info("Received Apple ID: \(appleUserId.prefix(8))...")
        
        // Fetch existing user or create new one
        if let existingUser = fetchUser(appleUserId: appleUserId) {
            completeSignIn(with: existingUser)
        } else {
            let newUser = createNewUser(appleUserId: appleUserId)
            // Optional: capture name/email if provided (first sign-in only)
            if let fullName = credential.fullName,
               let givenName = fullName.givenName,
               let familyName = fullName.familyName {
                newUser.displayName = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
            }
            if let email = credential.email {
                newUser.email = email
            }
            completeSignIn(with: newUser)
        }
    }
    
    // MARK: - Simulator Bypass
    /// Bypasses real Sign in with Apple when running in simulator.
    /// Creates a consistent debug user and marks onboarding complete.
    /// Safe to call multiple times — idempotent.
    func bypassSignInForSimulator() {
        guard isSimulator else { return }
        
        let debugAppleUserID = "simulator.debug.user.12345"
        
        // Save to shared defaults
        sharedDefaults?.set(debugAppleUserID, forKey: appleUserIDKey)
        
        // Fetch or create debug user
        if let existingUser = fetchUser(appleUserId: debugAppleUserID) {
            existingUser.isOnboardingComplete = true
            self.currentUser = existingUser
            logger.info("Simulator bypass: existing debug user signed in")
            return
        }
        
        // Create new debug user
        let context = ModelContext(modelContainer)
        let debugUser = User(
            appleUserId: debugAppleUserID,
            isOnboardingComplete: true
        )
        context.insert(debugUser)
        
        do {
            try context.save()
            self.currentUser = debugUser
            logger.info("Simulator bypass: new debug user created and signed in")
        } catch {
            logger.error("Simulator bypass failed to save debug user: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helpers
    private func createNewUser(appleUserId: String) -> User {
        let context = ModelContext(modelContainer)
        let newUser = User(appleUserId: appleUserId)
        context.insert(newUser)
        
        do {
            try context.save()
            logger.info("New User created and saved")
        } catch {
            logger.error("Failed to save new User: \(error.localizedDescription)")
        }
        
        return newUser
    }
    
    private func fetchUser(appleUserId: String) -> User? {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { $0.appleUserId == appleUserId }
        )
        
        do {
            let user = try context.fetch(descriptor).first
            if user != nil {
                logger.debug("User fetched successfully from SwiftData")
            } else {
                logger.debug("No User found in SwiftData for Apple User ID: \(appleUserId.prefix(8))...")
            }
            return user
        } catch {
            logger.error("Failed to fetch User from SwiftData: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Simulator Detection
extension AuthenticationManager {
    var isSimulator: Bool {
#if targetEnvironment(simulator)
        return true
#else
        return false
#endif
    }
}
