//
//  ErrorManager.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/4/25.
//

import SwiftUI
import OSLog

// MARK: - App-Specific Errors
enum AppError: LocalizedError {
    case databaseError
    case cloudKitUnavailable
    case healthKitNotAuthorized
    case purchaseFailed
    case unknown(Error?)
    case healthKitUnavailable
    
    var errorDescription: String? {
        switch self {
        case .databaseError:          "Database Error"
        case .cloudKitUnavailable:    "iCloud Unavailable"
        case .healthKitNotAuthorized: "Health Access Required"
        case .purchaseFailed:         "Purchase Failed"
        case .unknown:                "Something Went Wrong"
        case .healthKitUnavailable:   "HealthKit Not Available"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .databaseError:
            "We couldn’t save your workout right now."
        case .cloudKitUnavailable:
            "Your device is offline or iCloud is not available."
        case .healthKitNotAuthorized:
            "FitSync needs Health access to track heart rate, calories, and routes."
        case .purchaseFailed:
            "The purchase could not be completed."
        case .unknown(let error):
            error?.localizedDescription ?? "An unexpected error occurred."
        case .healthKitUnavailable:
            "HealthKit is not supported on this device."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .databaseError, .cloudKitUnavailable:
            "Your data is safe and will sync when possible. Keep training."
        case .healthKitNotAuthorized:
            "Tap below to open Settings and grant access."
        case .purchaseFailed:
            "Try again later or contact support."
        case .unknown:
            "Please try again. Restart the app if needed."
        case .healthKitUnavailable:
            "Some features will be limited without HealthKit."
        }
    }
}

// MARK: - Alert Model
struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryButton: Alert.Button
    let secondaryButton: Alert.Button?
    
    var accessibilityLabel: String { "\(title). \(message)" }
    var accessibilityHint: String {
        secondaryButton != nil ?
            "Double-tap to dismiss or choose action." :
            "Double-tap to dismiss."
    }
}

// MARK: - ErrorManager (2025 @Observable Singleton)
@Observable
public final class ErrorManager {
    static let shared = ErrorManager()
    
    // Public state
    var currentAlert: AppAlert?
    
    // Private state
    private var alertQueue: [AppAlert] = []
    private let logger = Logger(subsystem: "com.tnt.FitSync2_0", category: "ErrorManager")
    
    // MARK: - No init() needed — @Observable generates it
    private init() {}
    
    // MARK: - Present Methods
    func present(
        title: String,
        message: String,
        primaryButton: Alert.Button = .default(Text("OK")),
        secondaryButton: Alert.Button? = nil
    ) {
        let alert = AppAlert(
            title: title,
            message: message,
            primaryButton: primaryButton,
            secondaryButton: secondaryButton
        )
        enqueueOrPresent(alert)
    }
    
    func present(_ error: Error, secondaryButton: Alert.Button? = nil) {
        if let localized = error as? LocalizedError {
            present(localized, secondaryButton: secondaryButton)
        } else {
            present(AppError.unknown(error))
        }
    }
    
    func present(_ error: AppError, secondaryButton: Alert.Button? = nil) {
        present(error as LocalizedError, secondaryButton: secondaryButton)
    }
    
    private func present(_ error: LocalizedError, secondaryButton: Alert.Button? = nil) {
        let title = error.errorDescription ?? "Error"
        var message = error.failureReason ?? "Something went wrong."
        
        if let recovery = error.recoverySuggestion, !recovery.isEmpty {
            message += "\n\n\(recovery)"
        }
        
        let alert = AppAlert(
            title: title,
            message: message,
            primaryButton: .default(Text("OK")),
            secondaryButton: secondaryButton
        )
        enqueueOrPresent(alert)
    }
    
    // MARK: - Dismiss & Queue
    func dismissAlert() {
        logger.info("Alert dismissed")
        if let next = alertQueue.first {
            alertQueue.removeFirst()
            currentAlert = next
        } else {
            currentAlert = nil
        }
    }
    
    private func enqueueOrPresent(_ alert: AppAlert) {
        if currentAlert != nil {
            logger.info("Alert queued: \(alert.title)")
            alertQueue.append(alert)
        } else {
            logger.info("Alert presented: \(alert.title)")
            currentAlert = alert
        }
    }
}

