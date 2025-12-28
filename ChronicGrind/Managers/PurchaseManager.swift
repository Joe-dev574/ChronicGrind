//
//  PurchaseManager.swift
//  ChronicGrind
//
//  Updated by Grok on 12/22/25
//

import StoreKit
import OSLog
import SwiftUI

#if os(watchOS)
import WatchKit
#endif

/// Centralized manager for the FitSync Premium subscription ("FitSync Watch").
/// Handles product loading, purchasing, status checking, restoration, and cross-app (iPhone ↔ Watch) premium syncing.
///
/// Premium status is shared safely via App Group UserDefaults so the independent Watch app
/// can correctly gate the full Watch experience without crashing the iPhone app.
@Observable
@MainActor
final class PurchaseManager {
    // MARK: - Shared Instance
    static let shared = PurchaseManager()
    
    // MARK: - Configuration
    private let subscriptionProductIdentifier = "417.12.25" // Your actual product ID
    private let appGroupID = "group.com.tnt.FitSync"
    
    // MARK: - Observable State
    var product: Product?
    var isSubscribed: Bool = false
    var isPurchasing: Bool = false
    var message: String?
    
    // MARK: - Private
    private let logger = Logger(subsystem: "com.tnt.ChronicGrindShared", category: "PurchaseManager")
    private nonisolated var transactionListenerTask: Task<Void, Never>?
    
    private init() {
        Task { await refresh() }
        listenForTransactions()
    }
    
    deinit {
        transactionListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    func refresh() async {
        await loadProduct()
        await refreshSubscriptionStatus()
    }
    
    private func loadProduct() async {
        message = nil
        do {
            let products = try await Product.products(for: [subscriptionProductIdentifier])
            self.product = products.first
        } catch {
            message = "Failed to load product: \(error.localizedDescription). Retrying..."
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2s delay
            // Retry once
            let products = try? await Product.products(for: [subscriptionProductIdentifier])
            self.product = products?.first
        }
    }
    
    func purchase() async {
        guard let product else {
            message = "No product available"
            return
        }
        isPurchasing = true
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshSubscriptionStatus()
                case .unverified:
                    message = "Purchase unverified"
                }
            case .userCancelled:
                message = "Purchase cancelled"
            case .pending:
                message = "Purchase pending"
            @unknown default:
                message = "Unknown purchase result"
            }
        } catch {
            message = "Purchase failed: \(error.localizedDescription)"
        }
        isPurchasing = false
    }
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
        } catch {
            message = "Restore failed: \(error.localizedDescription)"
        }
    }
    
    private func refreshSubscriptionStatus() async {
        // Check app group first (for Watch sync)
        let appGroupDefaults: UserDefaults? = {
            if let defaults = UserDefaults(suiteName: appGroupID) {
                return defaults
            } else {
                logger.warning("App group defaults unavailable; falling back to standard.")
                return .standard  // Fallback to prevent crashes
            }
        }()
        let isPremium = appGroupDefaults?.bool(forKey: "isPremium") ?? false
        self.isSubscribed = isPremium
        
        // Verify with StoreKit
        if let result = await Transaction.latest(for: subscriptionProductIdentifier) {
            switch result {
            case .verified(let transaction):
                let notRevoked = (transaction.revocationDate == nil)
                let notExpired = transaction.expirationDate.map { $0 > Date() } ?? true
                self.isSubscribed = notRevoked && notExpired
            case .unverified:
                self.isSubscribed = false
            }
        } else {
            self.isSubscribed = false
        }
        
        // Sync back to app group (iOS only)
        await syncPremiumStatusToAppGroup(self.isSubscribed)
    }
    
    // MARK: - Private Helpers
    /// Syncs premium status to app group UserDefaults (iOS only).
    /// The Watch reads this flag to enable full independent features.
    private func syncPremiumStatusToAppGroup(_ premium: Bool) async {
        #if os(iOS)
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            logger.error("Failed to access app group UserDefaults")
            return
        }
        defaults.set(premium, forKey: "isPremium")
        defaults.synchronize()
        logger.info("Premium status synced to app group: \(premium)")
        #endif
    }
    
    /// Background listener for transaction updates (renewals, refunds, etc.)
    private func listenForTransactions() {
        transactionListenerTask?.cancel()
        transactionListenerTask = Task.detached { [subscriptionProductIdentifier] in
            for await update in Transaction.updates {
                switch update {
                case .verified(let transaction) where transaction.productID == subscriptionProductIdentifier:
                    await transaction.finish()
                    await self.refreshSubscriptionStatus()
                default:
                    break
                }
            }
        }
    }
}
