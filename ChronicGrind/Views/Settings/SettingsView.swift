//
//  SettingsView.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/27/25.
//

/// The settings screen for MoveSync, allowing users to configure preferences, manage account settings, and access support resources.
/// Integrates with SwiftData for category data, HealthKit for sync settings, and StoreKit for app rating.
/// Ensures accessibility for VoiceOver users and complies with App Store guidelines for production deployment.
import SwiftUI
import SwiftData
import StoreKit


//MARK: APPEARANCE SETTING
/// An enumeration of appearance settings for the app’s color scheme, used in the settings picker.
/// Conforms to `CaseIterable` and `Identifiable` for SwiftUI picker compatibility.
enum AppAppearanceSetting: String, CaseIterable, Identifiable {
    case system = "System Default"
    case light = "Light Mode"
    case dark = "Dark Mode"
    
    var id: String { self.rawValue }
    
    var displayAppearance: String {
        return self.rawValue
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
}



/// A SwiftUI view that presents the settings interface for FitSync.
/// Organizes preferences into sections for general settings, notifications, HealthKit sync, account, about, support, and app rating.
/// Uses `@AppStorage` for persistent settings and integrates with authentication, HealthKit, and notification managers.
struct SettingsView: View {
    //MARK: PROPERTIES
    /// The environment variable to dismiss the view.
    @Environment(\.dismiss) private var dismiss
    
    /// The HealthKit manager for syncing workout data.
    @Environment(HealthKitManager.self) private var healthKitManager
    
    @Environment(\.requestReview) private var requestReview
    
    
    @Environment(PurchaseManager.self) private var purchaseManager
    
    /// The SwiftData model context for querying categories.
    @Environment(\.modelContext) private var modelContext
    
    
    /// The authentication manager for accessing the current user.
    @Environment(AuthenticationManager.self) private var authManager
    
    /// The error manager for displaying alerts.
    @Environment(ErrorManager.self) private var errorManager
    
    /// Query to fetch all categories, used in settings (e.g., default category picker).
    @Query private var categories: [Category]
    
    /// Persisted setting for enabling/disabling HealthKit synchronization.
    @AppStorage("isHealthKitSyncEnabled") private var isHealthKitSyncEnabled: Bool = true
    
    /// Persisted ID of the default workout category.
    @AppStorage("defaultCategoryID") private var defaultCategoryID: String?
    
    /// Persisted hex string for the user’s selected theme color.
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    
//    /// Persisted unit system (metric or imperial) for measurements.
//    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .metric
    
    /// Persisted appearance setting (system, light, or dark) for the app’s color scheme.
    @AppStorage("appearanceSetting") private var appearanceSetting: AppAppearanceSetting = .system
    
    /// State to show an alert for HealthKit authorization errors.
    @State private var showAuthorizationError: Bool = false
    
    /// State to show a confirmation alert for sign-out.
    @State private var showSignOutConfirmation: Bool = false
 
    /// Persisted raw value for the unit system (metric or imperial) for measurements.
    @AppStorage("unitSystem") private var unitSystemRaw: String = "Metric"

    /// Computed unit system enum, mapped from the stored raw value.
    private var unitSystem: UnitSystem {
        get { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
        set { unitSystemRaw = newValue.rawValue }
    }
      
    
    
    /// Binding for the theme color picker, converting hex string to `Color` and back.
    private var currentColorForPicker: Binding<Color> {
        Binding(
            get: { Color(hex: selectedThemeColorData) ?? .blue },
            set: { newValue in
                selectedThemeColorData = newValue.hex
            }
        )
    }
    
    /// The computed theme color, derived from the stored hex string or defaulting to blue.
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    //MARK:  MAIN BODY
    var body: some View {
        // Main container with gradient background
        ZStack {
            Color.proBackground.ignoresSafeArea()
            // Navigation stack for settings form
            NavigationStack {
                Form {
                    premiumSection
                    generalSection
                    healthKitSyncSection
                    supportSection
                    rateAppSection
                    aboutSection
                    accountSection
                }
                .scrollContentBackground(.hidden)
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.proBackground, for: .navigationBar)
                .tint(themeColor)
            }
        }
    }
    private var premiumSection: some View {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.white)
                        Text("Premium Subscription")
                            .font(.title3)
                            .fontWeight(.medium)
                            .fontDesign(.serif)
                            .foregroundStyle(.white)
                    }
                    Text("Unlock advanced features like a full independent Watch app.")
                        .font(.subheadline)
                        .fontDesign(.serif)
                        .foregroundStyle(.white)
                    if purchaseManager.isSubscribed {
                        Text("You are Subscribed")
                            .font(.headline)
                            .fontDesign(.serif)
                            .foregroundStyle(themeColor)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        NavigationLink(destination: SubscriptionView()) {
                            Text("Subscribe to Premium")
                                .font(.headline)
                                .fontDesign(.serif)
                                .foregroundStyle(themeColor)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .accessibilityLabel("Subscribe to Premium")
                        .accessibilityHint("Navigate to purchase premium subscription")
                    }
                }
                .padding()
                .background(themeColor.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } header: {
                Text("Premium")
                    .font(.title3)
                    .fontWeight(.medium)
                    .fontDesign(.serif)
                    .foregroundStyle(themeColor)
                    .accessibilityAddTraits(.isHeader)
            }
        }    //MARK: GENERAL SECTION
    /// General settings section for theme color, appearance, and units.
    private var generalSection: some View {
        Section {
            // Theme color picker
            HStack {
                ZStack{
                    Rectangle()
                        .fill(themeColor)
                        .frame(width: 35, height: 35)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Image(systemName: "paintbrush")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.white)
                }
                ColorPicker("System Theme Color", selection: currentColorForPicker)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("themeColorPicker")
                    .accessibilityLabel("Theme color")
                    .accessibilityHint("Select a color to customize the app's appearance")
            }
            HStack {
                ZStack{
                    Rectangle()
                        .fill(.primary)
                        .frame(width: 35, height: 35)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Image(systemName: "sun.max")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.grayText)
                }
                // Appearance picker
                Picker("Appearance", selection: $appearanceSetting) {
                    ForEach(AppAppearanceSetting.allCases) { setting in
                        Text(setting.displayAppearance).tag(setting)
                    }
                }
            }
            .foregroundStyle(.primary)
            .accessibilityIdentifier("appearancePicker")
            .accessibilityLabel("Appearance mode")
            .accessibilityHint("Select the app's appearance: light, dark, or system default.")
            
            
            // MARK:  Units picker
            HStack {
                ZStack {
                    Rectangle()
                        .fill(themeColor)
                        .frame(width: 35, height: 35)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Image(systemName: "lines.measurement.horizontal")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.white)
                }
                Picker("Units of Measure", selection: $unitSystemRaw) {  // Bind to raw for @AppStorage compatibility
                    ForEach(UnitSystem.allCases) { system in
                        Text(system.displayName).tag(system.rawValue)  // Use rawValue as tag
                    }
                }
            }
            .foregroundStyle(.primary)
            .accessibilityIdentifier("unitSystemPicker")
            .accessibilityLabel("Units of measure")
            .accessibilityHint("Select your preferred units for weight and height.")
            
        } header: {
            Text("General")
                .font(.title3)
                .fontWeight(.medium)
                .fontDesign(.serif)
                .foregroundStyle(themeColor)
                .dynamicTypeSize(.medium)
                .accessibilityAddTraits(.isHeader)
        }
    }
    
    // MARK: HealthKit SECTION
    private var healthKitSyncSection: some View {
        Section(content: {
            Toggle(isOn: $isHealthKitSyncEnabled){
                HStack {
                    ZStack{
                        Rectangle()
                            .fill(.red)
                            .frame(width: 35, height: 35)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Image(systemName: "heart")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.white)
                    }
                    Text("Enable HealthKit Sync")
                        .foregroundStyle(.primary)
                        .fontDesign(.serif)
                }
            }
            .foregroundStyle(.primary)
            .accessibilityLabel("HealthKit sync")
            .accessibilityHint(isHealthKitSyncEnabled ? "Disable HealthKit synchronization" : "Enable HealthKit synchronization")
            .accessibilityValue(isHealthKitSyncEnabled ? "On" : "Off")
            
            // MARK: HEALTHKIT ENABLED
            if isHealthKitSyncEnabled && !healthKitManager.isReadAuthorized && !healthKitManager.isWriteAuthorized {
                            Button("Grant HealthKit Permission") {
                                Task {
                                    do {
                                        try await healthKitManager.requestAuthorization()
                                    } catch {
                                        showAuthorizationError = true
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .fontDesign(.serif)
                            .foregroundStyle(.primary)
                            .accessibilityLabel("Grant HealthKit permission")
                            .accessibilityHint("Double-tap to request HealthKit permissions")
                            .accessibilityAddTraits(.isButton)
                            .padding(.vertical, 2)
                            .padding(.bottom, 4)
                
            } else if isHealthKitSyncEnabled && healthKitManager.isReadAuthorized {
                Text("HealthKit sync is enabled.")
                    .font(.body)
                    .fontDesign(.serif)
                    .foregroundStyle(.green)
            } else if !isHealthKitSyncEnabled && healthKitManager.isReadAuthorized{
                Text("HealthKit sync is disabled.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fontDesign(.serif)
            }
        }, header: {
            Text("HealthKit Sync")
                .font(.title3)
                .fontWeight(.medium)
                .fontDesign(.serif)
                .foregroundStyle(themeColor)
                .dynamicTypeSize(.medium)
                .accessibilityAddTraits(.isHeader)
        })
        
        // MARK:  HealthKit authorization alert
        .alert("Authorization Required", isPresented: $showAuthorizationError) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { showAuthorizationError = false }
        } message: {
            Text("Please grant HealthKit permission in Settings to enable syncing.")
                .accessibilityLabel("HealthKit authorization required")
        } .fontDesign(.serif)
    }
    
    // MARK:  MARK: Account settings section for signing out.
    private var accountSection: some View {
        Section {
            HStack {
                ZStack{
                    Rectangle()
                        .fill(.green)
                        .frame(width: 35, height: 35)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Image(systemName: "person.circle")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.white)
                }
                Text("Account Sign Out")
                    .foregroundStyle(.primary)
                    .fontDesign(.serif)
                Spacer( )
                Button("Sign Out", role: .destructive) {
                    showSignOutConfirmation = true
                }
                .fontDesign(.serif)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Sign out")
            .accessibilityHint("Double-tap to sign out of the app")
            .accessibilityAddTraits(.isButton)
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out?")
                    .accessibilityLabel("Sign out confirmation")
            }
        } header: {
            Text("Account")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(themeColor)
                .dynamicTypeSize(.medium)
                .accessibilityAddTraits(.isHeader)
        }
        
    }
    
    // MARK:  Support section with contact and bug report links.
    private var supportSection: some View {
        Section {
            // Contact support link
            HStack {
                ZStack{
                    Rectangle()
                        .fill(.blue)
                        .frame(width: 35, height: 35)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Image(systemName: "envelope")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.white)
                }
                Link("Contact Support or Request Feature", destination: URL(string: "mailto:support@FitSynchub.com")!)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("contactSupportLink")
                    .accessibilityLabel("Contact support")
                    .accessibilityHint("Send an email to the support team")
            }
            // Report a bug link
            HStack {
                ZStack{
                    Rectangle()
                        .fill(.blue)
                        .frame(width: 35, height: 35)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Image(systemName: "ant.fill")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.white)
                }
                Link("Report a Bug", destination: URL(string: "mailto:support@MoveSynchub.com")!)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("reportBugLink")
                    .accessibilityLabel("Report a bug")
                    .accessibilityHint("Open a form to report a bug")
            }
            .fontDesign(.serif)
        } header: {
            Text("Support")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(themeColor)
                .dynamicTypeSize(.medium)
                .accessibilityAddTraits(.isHeader)
        } .fontDesign(.serif)
    }
    
    // MARK:  About section with app version and legal links.
    private var aboutSection: some View {
        Section {
            HStack{
                // MARK:  Privacy policy link
                ReusableLinkView(iconName: "hand.raised", linkText: "Privacy & Security Policy", destinationURL: URL(string: "https://www.google.com/legal/privacy/policy/html/gpc.html")!, accessibilityIdentifier: "Privacy Policy Link", accessibilityLabel: "Privacy Policy", accessibilityHint: "Open the apps Privacy policy.")
            }
            
            // MARK:  App version info
            HStack {
                ZStack{
                    Rectangle()
                        .fill(.green)
                        .frame(width: 35, height: 35)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Image(systemName: "info.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.white)
                        .font(.system(size: 16))
                }
                Text("Version")
                    .foregroundStyle(.primary)
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }
            .fontDesign(.serif)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("App version")
            .accessibilityValue("1.0.0")
            // Terms of use link
            HStack{
                ReusableLinkView(iconName: "info.circle", linkText: "Terms of Use", destinationURL: URL(string: "https://movesynchub.com/terms")!, accessibilityIdentifier: "termsLink", accessibilityLabel: "Terms of Use", accessibilityHint: "Open the apps terms of use.")
            }
        } header: {
            Text("About")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(themeColor)
                .dynamicTypeSize(.medium)
                .accessibilityAddTraits(.isHeader)
        } .fontDesign(.serif)
}
    // MARK:  Rate the app section with a button to request an App Store review.
    private var rateAppSection: some View {
        Section {
            Button(action: requestAppReview) {
                HStack {
                    ZStack{
                        Rectangle()
                            .fill(.blue)
                            .frame(width: 35, height: 35)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Image(systemName: "star.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.white)
                            .font(.system(size: 16))
                    }
                    Text("Rate FitSync")
                    .fontDesign(.serif)
                    .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
            }
            .accessibilityIdentifier("rateAppButton")
            .accessibilityLabel("Rate MoveSync1.0 in the App Store")
            .accessibilityHint("Double-tap to request rating the app in the App Store")
            .accessibilityAddTraits(.isButton)
          
        } header: {
            Text("Rate FitSync")
                .font(.title3)
                .fontWeight(.medium)
                .fontDesign(.serif)
                .foregroundStyle(themeColor)
                .dynamicTypeSize(.medium)
                .accessibilityAddTraits(.isHeader)
        }
    }
    
    /// Requests an App Store review prompt using StoreKit.
    private func requestAppReview() {
        requestReview()
    }
}

