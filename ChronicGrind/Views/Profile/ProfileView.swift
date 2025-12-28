//
//  ProfileView.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/27/25.
//

import SwiftUI
import SwiftData
import PhotosUI
internal import HealthKit

/// A view for displaying and editing the user's profile information, including personal details, health metrics, and profile picture.
///
/// This view integrates with HealthKit to fetch and display health data, and allows users to update their profile.
/// It supports accessibility features for VoiceOver and other assistive technologies.
struct ProfileView: View {
    // MARK: - PROPERTIES
    
    /// The model context for SwiftData operations.
    @Environment(\.modelContext) private var modelContext
    
    /// Environment value to dismiss the view.
    @Environment(\.dismiss) private var dismiss
    
    /// Authentication manager to access the current user.
    @Environment(AuthenticationManager.self) private var authManager
    
    /// HealthKit manager for fetching health data.
    @Environment(HealthKitManager.self) private var healthKitManager
    
    // Local states for editing user data (stored in metric units)
    /// User's weight in kilograms (internal storage).
    @State private var weightKg: Double?
    
    /// User's height in meters (internal storage).
    @State private var heightM: Double?
    
    /// User's age in years.
    @State private var age: Int?
    
    /// Authorization prompt visibility for HealthKit.
    @State private var showAuthorizationPrompt: Bool = false
    
    /// User's resting heart rate in beats per minute.
    @State private var restingHeartRate: Double?
    
    /// User's maximum heart rate in beats per minute.
    @State private var maxHeartRate: Double?
    
    /// String representation of the user's biological sex.
    @State private var biologicalSexString: String?
    
    /// User's selected fitness goal.
    @State private var fitnessGoal: String?
    
    /// Data for the user's profile image.
    @State private var profileImageData: Data?
    
    // UI states
    /// Flag indicating if changes have been made to the profile.
    @State private var hasChanges: Bool = false
    
    /// Flag to show the success alert after saving.
    @State private var showAlert: Bool = false
    
    /// Selected item from the photos picker.
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    /// Flag indicating if data is being loaded from HealthKit.
    @State private var isLoading: Bool = false
    
    /// Error message to display if an error occurs.
    @State private var errorMessage: String?
    
    /// Persisted hex string for the user’s selected theme color.
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    
    /// Persisted unit system (metric or imperial) for measurements.
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .metric
    
    /// Persisted appearance setting (system, light, or dark) for the app’s color scheme.
    @AppStorage("appearanceSetting") private var appearanceSetting: AppearanceSetting = .system
    
    /// The computed theme color, derived from the stored hex string or defaulting to blue.
    private var themeColor: Color {
        Color(hex: selectedThemeColorData) ?? .blue
    }
    
    /// The current authenticated user.
    private var user: User? {
        authManager.currentUser
    }
    
    /// The user's health metrics from the model.
    private var healthMetrics: HealthMetrics? {
        user?.healthMetrics
    }
    
    // Computed bindings for weight (converts based on unit system)
    private var weightBinding: Binding<Double?> {
        Binding<Double?>(
            get: {
                guard let w = weightKg else { return nil }
                let value = unitSystem == .metric ? w : UnitConverter.convertWeightToImperial(w)
                return value.rounded()
            },
            set: { newValue in
                hasChanges = true
                guard let nv = newValue else {
                    weightKg = nil
                    return
                }
                weightKg = unitSystem == .metric ? nv : UnitConverter.convertWeightToMetric(nv)
            }
        )
    }
    
    // Computed bindings for height in imperial (feet and inches)
    private var feetBinding: Binding<Int?> {
        Binding<Int?>(
            get: { heightM.map { UnitConverter.convertHeightToImperial($0).feet } },
            set: { newValue in
                hasChanges = true
                guard let nv = newValue else {
                    heightM = nil
                    return
                }
                let currentInches = heightM.map { UnitConverter.convertHeightToImperial($0).inches } ?? 0
                heightM = UnitConverter.convertHeightToMetric(Double(nv), Double(currentInches))
            }
        )
    }
    
    private var inchesBinding: Binding<Int?> {
        Binding<Int?>(
            get: { heightM.map { UnitConverter.convertHeightToImperial($0).inches } },
            set: { newValue in
                hasChanges = true
                guard let nv = newValue else {
                    heightM = nil
                    return
                }
                let currentFeet = heightM.map { UnitConverter.convertHeightToImperial($0).feet } ?? 0
                heightM = UnitConverter.convertHeightToMetric(Double(currentFeet), Double(nv))
            }
        )
    }
    
    // MARK: - BODY
    
    var body: some View {
        ZStack {
            Color.proBackground.ignoresSafeArea()
            NavigationStack {
                Form {
                    // MARK: - PROFILE PICTURE
                    Section(header: Text("Profile Picture")
                        .foregroundStyle(themeColor)
                        .fontDesign(.serif)
                        .accessibilityLabel("Profile Picture section header")) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                                if let imageData = profileImageData, let uiImage = UIImage(data: imageData) {
                                    ZStack {
                                        Circle()
                                            .fill(themeColor)
                                            .frame(width: 105, height: 105)
                                            .accessibilityHidden(true) // Background circle is decorative
                                        
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                            .accessibilityLabel("User's profile picture")
                                            .accessibilityHint("Double-tap to change profile picture")
                                    }
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .frame(width: 100, height: 100)
                                        .foregroundStyle(themeColor)
                                        .accessibilityLabel("Default profile picture")
                                        .accessibilityHint("Double-tap to add a profile picture")
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 10)
                            .accessibilityElement(children: .combine) // Combine for better VoiceOver navigation
                            .accessibilityLabel("Profile picture picker")
                            .accessibilityHint("Double-tap to select a new profile picture from your photo library")
                    }
                    
                    // MARK: - PERSONAL INFORMATION
                    Section(header: Text("Personal Information")
                        .foregroundStyle(themeColor)
                        .fontDesign(.serif)
                        .accessibilityLabel("Personal Information section header")) {
                            Picker("Biological Sex", selection: $biologicalSexString) {
                                Text("Not Set").tag(String?.none)
                                Text("Male").tag(String?.some("Male"))
                                Text("Female").tag(String?.some("Female"))
                            }
                            .onChange(of: biologicalSexString) { hasChanges = true }
                            .accessibilityLabel("Biological Sex picker")
                            .accessibilityHint("Select your biological sex")
                            
                            HStack {
                                Text("Age")
                                    .padding(.horizontal, 7)
                                Spacer()
                                TextField("Age", value: $age, format: .number)
                                    .keyboardType(.numberPad)
                                    .onChange(of: age) { hasChanges = true }
                                    .padding(.horizontal, 7)
                                    .accessibilityLabel("Age text field")
                                    .accessibilityHint("Enter your age in years")
                            }
                            
                            Picker("Fitness Goal", selection: $fitnessGoal) {
                                Text("General Fitness").tag(String?.some("General Fitness"))
                                Text("Weight Loss").tag(String?.some("Weight Loss"))
                                Text("Muscle Gain").tag(String?.some("Muscle Gain"))
                                Text("Endurance").tag(String?.some("Endurance"))
                                Text("Other").tag(String?.some("Other"))
                            }
                            .onChange(of: fitnessGoal) { hasChanges = true }
                            .accessibilityLabel("Fitness Goal picker")
                            .accessibilityHint("Select your fitness goal")
                    }
                    .fontDesign(.serif)
                    
                    // MARK: - HEALTH METRICS
                    Section(header: Text("Health Metrics")
                        .foregroundStyle(themeColor)
                        .fontDesign(.serif)
                        .accessibilityLabel("Health Metrics section header")) {
                            HStack {
                                Text("Weight:")
                                    .padding(.horizontal, 7)
                                Spacer()
                                TextField(unitSystem == .metric ? "Weight (kg)" : "Weight (lbs)", value: weightBinding, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .padding(.horizontal, 7)
                                    .accessibilityLabel("Weight text field")
                                    .accessibilityHint("Enter your weight in \(unitSystem == .metric ? "kilograms" : "pounds")")
                            }
                            if unitSystem == .metric {
                                HStack {
                                    Text("Height:")
                                        .padding(.horizontal, 7)
                                    Spacer()
                                    TextField("Height (m)", value: $heightM, format: .number)
                                        .keyboardType(.decimalPad)
                                        .onChange(of: heightM) { hasChanges = true }
                                        .multilineTextAlignment(.trailing)
                                        .padding(.horizontal, 7)
                                        .accessibilityLabel("Height text field")
                                        .accessibilityHint("Enter your height in meters")
                                }
                            } else {
                                HStack {
                                    Text("Height")
                                        .padding(.horizontal, 7)
                                    Spacer()
                                    TextField("", value: feetBinding, format: .number)
                                        .keyboardType(.numberPad)
                                        .frame(maxWidth: 60)
                                        .multilineTextAlignment(.trailing)
                                        .accessibilityLabel("Feet text field")
                                        .accessibilityHint("Enter your height in feet")
                                    Text("ft")
                                        .foregroundStyle(.secondary)
                                    TextField("", value: inchesBinding, format: .number)
                                        .keyboardType(.numberPad)
                                        .frame(maxWidth: 60)
                                        .multilineTextAlignment(.trailing)
                                        .accessibilityLabel("Inches text field")
                                        .accessibilityHint("Enter your height in inches (0-11)")
                                    Text("in")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            HStack {
                                Text("Resting Heart Rate")
                                    .padding(.horizontal, 7)
                                Spacer()
                                TextField("(bpm)", value: $restingHeartRate, format: .number)
                                    .keyboardType(.decimalPad)
                                    .onChange(of: restingHeartRate) { hasChanges = true }
                                    .multilineTextAlignment(.trailing)
                                    .padding(.horizontal, 7)
                                    .accessibilityLabel("Resting Heart Rate text field")
                                    .accessibilityHint("Enter your resting heart rate in beats per minute")
                            }
                            HStack {
                                Text("Max Heart Rate")
                                    .padding(.horizontal, 7)
                                Spacer()
                                TextField("(bpm)", value: $maxHeartRate, format: .number)
                                    .keyboardType(.decimalPad)
                                    .onChange(of: maxHeartRate) { hasChanges = true }
                                    .multilineTextAlignment(.trailing)
                                    .padding(.horizontal, 7)
                                    .accessibilityLabel("Max Heart Rate text field")
                                    .accessibilityHint("Enter your maximum heart rate in beats per minute")
                            }
                    }
                    .fontDesign(.serif)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .accessibilityLabel("Error message: \(errorMessage)")
                    }
                }
                .scrollContentBackground(.hidden)
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.proBackground, for: .navigationBar)
                .tint(themeColor)
            }
        }
        .preferredColorScheme(appearanceSetting.colorScheme)
        .toolbar {
            if hasChanges {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .fontDesign(.serif)
                    .foregroundStyle(themeColor)
                    .accessibilityLabel("Save button")
                    .accessibilityHint("Tap to save changes to your profile")
                }
            }
        }
        .alert("Profile Updated", isPresented: $showAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your profile has been successfully updated.")
                .accessibilityLabel("Profile updated alert message")
        }
        .overlay {
            if isLoading {
                ProgressView("Fetching Health Data...")
                    .accessibilityLabel("Fetching health data progress indicator")
            }
        }
        .sheet(isPresented: $showAuthorizationPrompt) {
            HealthKitPromptView(
                onAuthorize: {
                    Task {
                        do {
                            try await healthKitManager.requestAuthorization()
                            // Retry fetching data after successful authorization
                            await fetchFromHealthKit()
                        } catch {
                            errorMessage = "Authorization failed: \(error.localizedDescription)"
                        }
                        showAuthorizationPrompt = false
                    }
                },
                onDismiss: {
                    showAuthorizationPrompt = false
                    // Optionally set an error message if dismissed without authorizing
                    errorMessage = "HealthKit access is required to fetch health data. You can authorize later in Settings."
                }
            )
            .presentationDetents([.medium])
            .accessibilityLabel("HealthKit authorization prompt")
        }
        .onAppear {
            loadInitialData()
            Task {
                await fetchFromHealthKit()
            }
        }
        .onChange(of: selectedPhotoItem) { oldItem, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    if let optimizedData = ImageOptimizer.optimize(imageData: data) {
                        profileImageData = optimizedData
                        hasChanges = true
                    }
                }
            }
        }
    }
    
    // MARK: - PRIVATE FUNCTIONS
    
    /// Loads initial data from the user's health metrics or creates new metrics if none exist.
    private func loadInitialData() {
        guard let healthMetrics = healthMetrics else {
            // Create new HealthMetrics if none exists
            let newMetrics = HealthMetrics()
            user?.healthMetrics = newMetrics
            modelContext.insert(newMetrics)
            try? modelContext.save()
            return
        }
        
        weightKg = healthMetrics.weight
        heightM = healthMetrics.height
        age = healthMetrics.age
        restingHeartRate = healthMetrics.restingHeartRate
        maxHeartRate = healthMetrics.maxHeartRate
        biologicalSexString = healthMetrics.biologicalSexString
        fitnessGoal = healthMetrics.fitnessGoal ?? "General Fitness"
        profileImageData = healthMetrics.profileImageData
    }
    
    /// Fetches health data from HealthKit and updates local states.
    ///
    /// This function runs asynchronously and handles errors by setting an error message or showing the authorization prompt.
    /// It differentiates between authorization-related errors and other issues to provide a user-friendly experience.
    private func fetchFromHealthKit() async {
        isLoading = true
        do {
            // Fetch weight, height, maxHR (which includes age calculation)
            let (fetchedWeight, fetchedHeight, fetchedMaxHR) = try await healthKitManager.fetchHealthMetrics()
            
            // Fetch biological sex
            let biologicalSex = try healthKitManager.healthStore.biologicalSex().biologicalSex
            let fetchedSexString: String? = {
                switch biologicalSex {
                case .male: return "Male"
                case .female: return "Female"
                case .other: return "Other"
                default: return "Not Set"
                }
            }()
            
            // Fetch age separately if needed (from dateOfBirth)
            let dobComponents = try healthKitManager.healthStore.dateOfBirthComponents()
            let dobDate = dobComponents.date
            let fetchedAge = (dobDate != nil) ? Calendar.current.dateComponents([.year], from: dobDate!, to: Date()).year : nil
            
            // Fetch resting heart rate
            let restingHR: Double? = await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
                healthKitManager.fetchLatestRestingHeartRate { value, error in
                    if let error = error {
                        print("Error fetching resting HR: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(returning: value)
                    }
                }
            }
            
            await MainActor.run {
                // Update local states if not already set or to refresh
                if weightKg == nil { weightKg = fetchedWeight }
                if heightM == nil { heightM = fetchedHeight }
                if age == nil { age = fetchedAge }
                if restingHeartRate == nil { restingHeartRate = restingHR }
                if maxHeartRate == nil { maxHeartRate = fetchedMaxHR }
                if biologicalSexString == nil { biologicalSexString = fetchedSexString }
                
                hasChanges = true // Since we fetched new data, enable save
            }
        } catch let error as HKError {
            await MainActor.run {
                if error.code == .errorAuthorizationDenied || error.code == .errorAuthorizationNotDetermined {
                    showAuthorizationPrompt = true
                } else {
                    errorMessage = "An error occurred: \(error.localizedDescription)"
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            }
        }
        await MainActor.run {
            isLoading = false
        }
    }
    
    /// Saves the updated profile data to the model context.
    ///
    /// Displays an error message if saving fails.
    private func saveProfile() {
        guard let healthMetrics = healthMetrics else { return }
        
        healthMetrics.weight = weightKg
        healthMetrics.height = heightM
        healthMetrics.age = age
        healthMetrics.restingHeartRate = restingHeartRate
        healthMetrics.maxHeartRate = maxHeartRate
        healthMetrics.biologicalSexString = biologicalSexString
        healthMetrics.fitnessGoal = fitnessGoal
        healthMetrics.profileImageData = profileImageData
        
        do {
            try modelContext.save()
            hasChanges = false
            showAlert = true
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
        }
    }
}
// Fallback appearance enum if not provided elsewhere in the project
// This ensures ProfileView compiles even if AppAppearanceSetting is missing.
//MARK: APPEARANCE SETTING
/// An enumeration of appearance settings for the app’s color scheme, used in the settings picker.
/// Conforms to `CaseIterable` and `Identifiable` for SwiftUI picker compatibility.
enum AppearanceSetting: String, CaseIterable, Identifiable {
    /// Follows the system’s light or dark mode.
    case system = "System Default"
    /// Forces light mode.
    case light = "Light Mode"
    /// Forces dark mode.
    case dark = "Dark Mode"
    
    /// A unique identifier for the appearance setting.
    var id: String { self.rawValue }
    
    /// The display name for the picker UI.
    var displayAppearance: String {
        return self.rawValue
    }
    /// The corresponding SwiftUI color scheme, or nil for system default.
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

