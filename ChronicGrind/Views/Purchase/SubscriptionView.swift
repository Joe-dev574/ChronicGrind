//
//  SubscriptionView.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/27/25.
//

import SwiftUI
import StoreKit
import Combine
import Foundation
import OSLog


struct SubscriptionView: View {
    // View model encapsulates StoreKit 2 logic for subscriptions.
    @Environment(PurchaseManager.self) private var purchaseManager
    // Controls presentation of the system manage subscriptions sheet (iOS 16+)
    @State private var showManageSubscriptions = false

    var body: some View {
        ZStack {
            Color.proBackground
                .ignoresSafeArea()
            NavigationStack {
                ScrollView {
                    VStack(spacing: 15) {
                        VStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundStyle(.tint)
                            Text("Premium Subscription")
                                .font(.title2).bold()
                                .multilineTextAlignment(.center)
                            Text("Subscribe to unlock advanced features.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 12)
                        
                        // Feature gating: sample feature when not subscribed; advanced when active.
                        Group {
                            if purchaseManager.isSubscribed {
                                AdvancedFeatureView()
                                    .transition(.opacity.combined(with: .scale))
                                    .accessibilityLabel("Advanced features (subscribed)")
                            } else {
                                BenefitsView()
                                    .padding(7)
                                    .accessibilityLabel("Premium benefits (not subscribed)")
                            }
                        }
                        .animation(.snappy, value: purchaseManager.isSubscribed)
                        
                        // Product row, subscribe button, restore/manage actions, and status output.
                        VStack(spacing: 12) {
                            if let product = purchaseManager.product {
                                // Status row with price.
                                HStack(spacing: 8) {
                                    Image(systemName: purchaseManager.isSubscribed ? "checkmark.seal.fill" : "crown")
                                        .foregroundStyle(purchaseManager.isSubscribed ? .green : .secondary)
                                    Text(purchaseManager.isSubscribed ? "Active Subscription" : "Not Subscribed")
                                        .font(.subheadline)
                                        .foregroundStyle(purchaseManager.isSubscribed ? .green : .secondary)
                                    Spacer()
                                    Text(product.displayPrice)
                                        .font(.headline)
                                        .monospacedDigit()
                                        .foregroundStyle(.primary)
                                }
                                
                                // Start the StoreKit 2 subscription purchase flow.
                                Button {
                                    Task { await purchaseManager.purchase() }
                                } label: {
                                    HStack {
                                        Image(systemName: purchaseManager.isSubscribed ? "checkmark" : "crown.fill")
                                        Text(purchaseManager.isSubscribed ? "Subscribed" : "Upgrade to Premium")
                                    }
                                    .padding(7)
                                    .fontDesign(.serif)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(purchaseManager.isSubscribed || purchaseManager.isPurchasing)
                                .opacity(purchaseManager.isSubscribed || purchaseManager.isPurchasing ? 0.7 : 1)
                                
                                if purchaseManager.isPurchasing {
                                    ProgressView("Processing…")
                                        .progressViewStyle(.circular)
                                }
                                
                                if let message = purchaseManager.message {
                                    Text(message)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .fontDesign(.serif)
                        .padding()
                    }
                    .navigationTitle("Subscription")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { refreshButton } }
                    .ifAvailableManageSubscriptionsSheet(isPresented: $showManageSubscriptions)
                }
            }
        }
    }
    // Simple refresh button to re-fetch product and subscription status.
    private var refreshButton: some View {
        Button {
            Task { await purchaseManager.refresh() }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .help("Refresh product and entitlement state")
    }
}


/// Visible when not subscribed. Lists premium benefits as a teaser.
private struct BenefitsView: View {
    private let benefits: [String] = [
        "Independent Watch App: Operates fully without iPhone nearby.",
        "Mirrored Session Screen: Identical, elegant workout view on Watch.",
        "Quick Exercise Advance: Use Digital Crown or tap to proceed; instantly logs split time.",
        "Live Heart Rate: Real-time monitoring via complication.",
        "Seamless Sync: Ends workout on Watch to sync data to phone, creating editable journal entry."
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Premium Benefits")
                .font(.headline)
            ForEach(benefits, id: \.self) { benefit in
                HStack(alignment: .top) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(benefit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .padding(.horizontal)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.quaternary, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Premium benefits")
    }
}

/// Visible when the subscription is active. A simple animated card.
private struct AdvancedFeatureView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Gradient(colors: [.indigo, .blue, .teal]))
                .hueRotation(.degrees(animate ? 60 : 0))
                .frame(height: 220)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                        Text("Advanced Features Unlocked")
                            .font(.title3).bold()
                            .foregroundStyle(.white)
                        Text("Thanks for subscribing! ✨")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Advanced features unlocked")
    }
}

private extension View {
    @ViewBuilder
    func ifAvailableManageSubscriptionsSheet(isPresented: Binding<Bool>) -> some View {
        if #available(iOS 16.0, *) {
            self.manageSubscriptionsSheet(isPresented: isPresented)
        } else {
            self
        }
    }
}

