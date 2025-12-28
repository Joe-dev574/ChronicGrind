//
//  ProgressBoardView.swift
//  ChronicGrind
//
//  Created by Joseph DeWeese on 12/27/25.
//

import SwiftUI
import SwiftData
internal import HealthKit
import OSLog
import Combine

/// Represents a single day in the workout heatmap grid.
/// This struct encapsulates the data for each cell in the heatmap, including the date, workout status, and visual indicators.
struct DayGridItem: Identifiable, Sendable {
    /// A unique identifier for the grid item.
    let id = UUID()
    
    /// The date associated with the grid item.
    let date: Date
    
    /// Indicates whether a workout was completed on this day.
    var didWorkout: Bool
    
    /// Indicates whether this day is today.
    let isToday: Bool
    
    /// Indicates whether the workout was a test workout.
    var isTestWorkout: Bool
}

/// A view representing a single day cell in the workout heatmap.
/// This view renders a circular cell with gradients and shadows based on workout status, ensuring high contrast against the background.
struct DayCellView: View {
    /// Indicates whether a workout was completed on this day.
    let didWorkout: Bool
    
    /// Indicates whether this day is today.
    let isToday: Bool
    
    /// The theme color for styling the cell.
    var themeColor: Color
    
    /// Indicates whether the workout was a test workout.
    var isTestWorkout: Bool
    
    /// Tracks whether the cell is currently pressed for animation.
    @State private var isPressed: Bool = false
    
    /// The radial gradient used to fill the cell based on workout status.
    /// Enhanced with higher opacity for better contrast against light/dark backgrounds.
    private var cellGradient: RadialGradient {
        if isTestWorkout {
            return RadialGradient(gradient: Gradient(colors: [.white.opacity(0.5), .indigo, .indigo]), center: .init(x: 0.3, y: 0.3), startRadius: 0, endRadius: 10)
        } else if didWorkout {
            return RadialGradient(gradient: Gradient(colors: [.white.opacity(0.5), .green, .green]), center: .init(x: 0.3, y: 0.3), startRadius: 0, endRadius: 10)
        } else {
            return RadialGradient(gradient: Gradient(colors: [.white.opacity(0.2), .gray.opacity(0.2)]), center: .init(x: 0.3, y: 0.3), startRadius: 0, endRadius: 10)
        }
    }
    
    var body: some View {
        Circle()
            .fill(cellGradient)
            .frame(width: 20, height: 20)
            .overlay(
                isToday ? Circle().stroke(themeColor.opacity(0.9), lineWidth: 3) : nil
            )
            .shadow(color: .black.opacity(didWorkout ? 0.5 : 0.2), radius: 3, x: 2, y: 2) // Increased shadow opacity for better depth and contrast.
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .onTapGesture {
                withAnimation {
                    isPressed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isPressed = false
                    }
                }
            }
            .accessibilityLabel(isToday ? "Today, \(didWorkout ? "Workout completed" : "No workout")" : didWorkout ? "Workout completed" : "No workout")
            .accessibilityHint(didWorkout ? "Tap to highlight workout day" : "Tap to highlight non-workout day")
    }
}

/// A view displaying a line graph of workout metrics over time.
/// This view plots data points with a filled area and line, using theme colors with adjusted opacities for improved visibility and contrast.
struct WorkoutGraph: View {
    /// The values to plot in the graph.
    let values: [Double]
    
    /// The theme color for styling the graph.
    let themeColor: Color
    
    /// The title displayed above the graph.
    let title: String
    
    /// An optional fixed maximum value for the y-axis.
    var fixedMaxValue: Double? = nil
    
    /// The effective maximum value for the y-axis, ensuring a minimum of 1.0.
    private var effectiveMaxValue: Double {
        let dataMax = values.isEmpty ? 1.0 : (values.max() ?? 1.0)
        let yAxisMax = fixedMaxValue ?? dataMax
        return max(yAxisMax, 1.0)
    }
    
    /// Padding for the leading labels.
    private let leadingPaddingForLabels: CGFloat = 10
    
    /// Padding for the trailing edge of the graph.
    private let trailingPadding: CGFloat = 10
    
    /// Padding for the top of the graph.
    private let topPadding: CGFloat = 5
    
    /// Padding for the bottom of the graph.
    private let bottomPadding: CGFloat = 5
    
    /// Width of the y-axis labels.
    private let labelWidth: CGFloat = 30
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(themeColor.opacity(0.9)) // Slightly reduced opacity for text to blend better while maintaining contrast.
                .padding(.leading, leadingPaddingForLabels)
            
            GeometryReader { geometry in
                let availableWidth = geometry.size.width - leadingPaddingForLabels - trailingPadding
                let availableHeight = geometry.size.height - topPadding - bottomPadding
                let drawableHeight = max(0, availableHeight)
                let drawableWidth = max(0, availableWidth)
                let dataPointSpacing = (values.count > 1) ? (drawableWidth / CGFloat(values.count - 1)) : 0
                
                ZStack(alignment: .leading) {
                    ForEach(0...3, id: \.self) { i in
                        let yPos = topPadding + (drawableHeight * CGFloat(i) / 3.0)
                        let lineValue = effectiveMaxValue * (1.0 - CGFloat(i) / 3.0)
                        
                        Path { path in
                            path.move(to: CGPoint(x: leadingPaddingForLabels, y: yPos))
                            path.addLine(to: CGPoint(x: geometry.size.width - trailingPadding, y: yPos))
                        }
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1) // Increased grid line opacity for better visibility.
                        
                        if drawableHeight > 10 {
                            Text(String(format: "%.0f", lineValue))
                                .font(.caption2)
                                .foregroundStyle(.secondary) // Adjusted for contrast.
                                .frame(width: labelWidth, alignment: .trailing)
                                .position(x: leadingPaddingForLabels / 2, y: yPos)
                        }
                    }
                    
                    Group {
                        Path { path in
                            path.move(to: CGPoint(x: leadingPaddingForLabels, y: topPadding + drawableHeight))
                            
                            for (index, value) in values.enumerated() {
                                let x = leadingPaddingForLabels + (values.count > 1 ? CGFloat(index) * dataPointSpacing : drawableWidth / 2)
                                let normalizedValue = max(0, min(CGFloat(value) / CGFloat(effectiveMaxValue), 1.0))
                                let yValue = topPadding + drawableHeight * (1.0 - normalizedValue)
                                
                                if index == 0 && values.count > 1 {
                                    path.addLine(to: CGPoint(x: x, y: topPadding + drawableHeight))
                                }
                                path.addLine(to: CGPoint(x: x, y: yValue))
                            }
                            
                            if !values.isEmpty {
                                let lastX = leadingPaddingForLabels + (values.count > 1 ? CGFloat(values.count - 1) * dataPointSpacing : drawableWidth / 2)
                                path.addLine(to: CGPoint(x: lastX, y: topPadding + drawableHeight))
                            }
                            path.closeSubpath()
                        }
                        .fill(LinearGradient(gradient: Gradient(colors: [themeColor.opacity(0.6), themeColor.opacity(0.1)]), startPoint: .top, endPoint: .bottom)) // Increased fill opacity for better contrast.
                        
                        Path { path in
                            guard !values.isEmpty else { return }
                            
                            for (index, value) in values.enumerated() {
                                let x = leadingPaddingForLabels + (values.count > 1 ? CGFloat(index) * dataPointSpacing : drawableWidth / 2)
                                let normalizedValue = max(0, min(CGFloat(value) / CGFloat(effectiveMaxValue), 1.0))
                                let yValue = topPadding + drawableHeight * (1.0 - normalizedValue)
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: yValue))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: yValue))
                                }
                            }
                        }
                        .stroke(themeColor, lineWidth: 2) // Increased line opacity.
                        .shadow(color: themeColor.opacity(0.3), radius: 4, y: 2) // Enhanced shadow for depth.
                        
                        ForEach(values.indices, id: \.self) { index in
                            let x = leadingPaddingForLabels + (values.count > 1 ? CGFloat(index) * dataPointSpacing : drawableWidth / 2)
                            let normalizedValue = max(0, min(CGFloat(values[index]) / CGFloat(effectiveMaxValue), 1.0))
                            let yValue = topPadding + drawableHeight * (1.0 - normalizedValue)
                            Circle()
                                .fill(themeColor.opacity(0.9))
                                .frame(width: 6, height: 6)
                                .position(x: x, y: yValue)
                                .shadow(color: .black.opacity(0.3), radius: 2) // Increased shadow for points.
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Enumerations

/// Enumerates the types of statistics displayed in the progress board.
/// Each case represents a key metric with associated display and description properties.
enum InfoStatItem: String, Identifiable {
    /// Total number of workouts in the last 90 days.
    case totalWorkouts
    /// Total workout duration in the last 90 days.
    case totalTime
    /// Average workouts per week in the last 90 days.
    case avgWorkoutsPerWeek
    /// Number of unique active days in the last 90 days.
    case activeDays
    
    /// A unique identifier for the stat item.
    var id: String { self.rawValue }
    
    /// A descriptive text explaining the stat for display in a popover.
    var descriptionText: String {
        switch self {
        case .totalWorkouts:
            return "The total number of workouts completed in the last 90 days."
        case .totalTime:
            return "The total duration of all workouts completed in the last 90 days."
        case .avgWorkoutsPerWeek:
            return "The average number of workouts completed per week over the last 90 days."
        case .activeDays:
            return "The number of unique days you completed at least one workout in the last 90 days."
        }
    }
    
    /// The display title for the stat, used in the UI.
    var displayTitle: String {
        switch self {
        case .totalWorkouts: return "  Total Workouts   "
        case .totalTime: return " Total Time "
        case .avgWorkoutsPerWeek: return "Avg Workouts/Wk"
        case .activeDays: return "Active Days"
        }
    }
}

/// A comprehensive progress board view summarizing workout activity over the last 90 days.
/// This view includes a heatmap, statistical summaries, line graphs, and advanced HealthKit metrics (if authorized).
/// It integrates with SwiftData for data persistence and HealthKit for enhanced analytics, providing a responsive and accessible UI.
///
/// - Note: Requires HealthKit authorization to display advanced metrics and a valid SwiftData configuration.
/// - SeeAlso: `DayCellView`, `WorkoutGraph`, `HealthKitManager`
struct ProgressBoardView: View {
    // MARK: - Environment Properties
    
    /// The SwiftData model context for fetching workout history.
    @Environment(\.modelContext) private var modelContext
    
    /// The HealthKit manager for fetching advanced metrics.
    @Environment(HealthKitManager.self) private var healthKitManager
    
    /// The error manager for presenting user-facing alerts.
    @Environment(ErrorManager.self) private var errorManager
    
    /// The presentation mode to handle view dismissal.
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - Stored Properties
    
    /// The selected theme color, stored in app storage.
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF"
    
    // MARK: - Computed Properties
    
    /// The theme color derived from the stored hex value.
    private var themeColor: Color { Color(hex: selectedThemeColorData) ?? .blue }
    
    // MARK: - State Properties
    
    /// Dates of workouts for the heatmap (currently unused but retained for potential future use).
    @State private var workoutDates: Set<DateComponents> = []
    
    /// The list of days to display in the heatmap.
    @State private var daysToDisplay: [DayGridItem] = []
    
    /// Weekly workout durations for the graph (in minutes).
    @State private var weeklyDurations: [Double] = []
    
    /// Weekly workout counts for the graph.
    @State private var weeklyWorkoutCounts: [Int] = []
    
    /// Weekly progress pulse scores for the graph.
    @State private var weeklyProgressPulseScores: [Double] = []
    
    /// Total workouts in the last 90 days.
    @State private var totalWorkoutsLast90Days: Int = 0
    
    /// Formatted total duration in the last 90 days.
    @State private var totalDurationLast90DaysFormatted: String = "0 min"
    
    /// Average workouts per week in the last 90 days.
    @State private var avgWorkoutsPerWeekLast90Days: Double = 0.0
    
    /// Distinct active days in the last 90 days.
    @State private var distinctActiveDaysLast90Days: Int = 0
    
    /// Latest metrics per category.
    @State private var latestCategoryMetrics: [String: WorkoutMetrics] = [:]
    
    /// Indicates whether data is loading.
    @State private var isLoading: Bool = true
    
    /// State to control the metrics info popover.
    @State private var showMetricsInfoPopover: Bool = false
    
    // MARK: - Private Properties
    
    /// Shared instance of the purchase manager.
    private let purchaseManager = PurchaseManager.shared
    
    /// Logger for debugging and monitoring view operations.
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Unknown", category: "ProgressBoardView")
    
    /// Calendar instance for date calculations.
    private let calendar = Calendar.current
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            if isLoading {
                ProgressView("Loading Progress Board...")
                    .progressViewStyle(.circular)
            } else {
                ZStack{
                    Color.proBackground.ignoresSafeArea(edges: .all)
                    ScrollView {
                        VStack(alignment: .center, spacing: 20) {
                            // Main Title
                            Text("Progress Board")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(themeColor)
                            
                            // Heatmap Section
                            Text("Workout Heatmap - Last 90 Days")
                                .font(.headline)
                                .foregroundStyle(themeColor)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(20), spacing: 4), count: 7), spacing: 0) {
                                ForEach(daysToDisplay) { day in
                                    DayCellView(didWorkout: day.didWorkout, isToday: day.isToday, themeColor: themeColor, isTestWorkout: day.isTestWorkout)
                                }
                            }
                            .padding(8)
                            
                            // Legend for Heatmap
                            HStack(spacing: 20) {
                                HStack {
                                    Circle().fill(RadialGradient(gradient: Gradient(colors: [.white.opacity(0.7), .green.opacity(0.9), .green]), center: .init(x: 0.3, y: 0.3), startRadius: 0, endRadius: 10)).frame(width: 20, height: 20)
                                    Text("Workout Day")
                                }
                                HStack {
                                    Circle().fill(RadialGradient(gradient: Gradient(colors: [.white.opacity(0.7), .indigo.opacity(0.9), .indigo]), center: .init(x: 0.3, y: 0.3), startRadius: 0, endRadius: 10)).frame(width: 20, height: 20)
                                    Text("Test Workout")
                                }
                                HStack {
                                    Circle().fill(RadialGradient(gradient: Gradient(colors: [.white.opacity(0.3), .gray.opacity(0.5)]), center: .init(x: 0.3, y: 0.3), startRadius: 0, endRadius: 10)).frame(width: 20, height: 20)
                                    Text("No Workout")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary.opacity(0.8)) // Adjusted for better contrast.
                            
                            // Stats Section
                            Text("90-Day Statistics")
                                .font(.headline)
                                .foregroundStyle(themeColor)
                            
                            Grid(alignment: .leading) {
                                GridRow {
                                    infoStatView(for: .totalWorkouts, value: "\(totalWorkoutsLast90Days)")
                                    infoStatView(for: .totalTime, value: totalDurationLast90DaysFormatted)
                                }
                                GridRow {
                                    infoStatView(for: .avgWorkoutsPerWeek, value: String(format: "%.1f", avgWorkoutsPerWeekLast90Days))
                                    infoStatView(for: .activeDays, value: "\(distinctActiveDaysLast90Days)")
                                }
                            }
                            .padding()
                            
                            // Graphs Section
                            WorkoutGraph(values: weeklyDurations, themeColor: themeColor, title: "Weekly Workout Duration (minutes)")
                                .frame(height: 150)
                            
                            WorkoutGraph(values: weeklyWorkoutCounts.map { Double($0) }, themeColor: themeColor, title: "Weekly Workout Count")
                                .frame(height: 150)
                            
                            if purchaseManager.isSubscribed {
                                WorkoutGraph(values: weeklyProgressPulseScores, themeColor: themeColor, title: "Weekly Average Progress Pulse Score")
                                    .frame(height: 150)
                            }
                            
                            // Category Metrics Section
                            if healthKitManager.isReadAuthorized && !latestCategoryMetrics.isEmpty {
                                Text("Latest Metrics per Category")
                                    .font(.headline)
                                    .foregroundStyle(themeColor)
                                
                                ForEach(fetchCategories().sorted(by: { $0.categoryName < $1.categoryName }), id: \.self) { category in
                                    if let metrics = latestCategoryMetrics[category.categoryName] {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(category.categoryName)
                                                .font(.subheadline.bold())
                                            
                                            if let intensity = metrics.intensityScore {
                                                Text("Intensity Score: \(String(format: "%.0f", intensity))%")
                                            }
                                            
                                            if purchaseManager.isSubscribed, let pulse = metrics.progressPulseScore {
                                                Text("Progress Pulse: \(String(format: "%.0f", pulse))")
                                            }
                                            
                                            if let zone = metrics.dominantZone {
                                                Text("Dominant Zone: \(zone) (\(zoneDescription(zone)))")
                                            }
                                        }
                                        .padding(.bottom, 10)
                                    }
                                }
                            }
                            
                            // Premium Banner
                            if !purchaseManager.isSubscribed {
                                premiumBanner
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await refreshBoard()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(themeColor.opacity(0.9)) // Theme color with high opacity for contrast.
                                .font(.title2)
                        }
                        .accessibilityLabel("Dismiss Progress Board")
                        .accessibilityHint("Closes the progress board view")
                    }
                }
            }
        }
        .onAppear {
            Task {
                await initializeBoard()
            }
        }
        .alert("Subscription", isPresented: Binding<Bool>(get: { purchaseManager.message != nil }, set: { if !$0 { purchaseManager.message = nil } }), actions: {}, message: {
            Text(purchaseManager.message ?? "")
        })
    }
    
    // MARK: - Private Views
    
    /// A view for displaying a single info stat with popover for description.
    /// - Parameters:
    ///   - stat: The statistic item to display.
    ///   - value: The value of the statistic.
    /// - Returns: A view with the stat title, value, and popover for details.
    private func infoStatView(for stat: InfoStatItem, value: String) -> some View {
        InfoStatTile(stat: stat, value: value, themeColor: themeColor)
    }

    /// A small subview that owns its presentation state for the info popover.
    private struct InfoStatTile: View {
        let stat: InfoStatItem
        let value: String
        let themeColor: Color
        @State private var showPopover: Bool = false
        
        var body: some View {
            VStack(alignment: .leading) {
                Text(stat.displayTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.8))
                Text(value)
                    .font(.headline)
                    .foregroundStyle(themeColor.opacity(0.9))
            }
            .padding()
            .background(Color.gray.opacity(0.15)) // Slightly darker background for contrast.
            .cornerRadius(8)
            .onTapGesture {
                showPopover = true
            }
            .popover(isPresented: $showPopover) {
                Text(stat.descriptionText)
                    .padding()
                    .presentationCompactAdaptation(.popover)
            }
        }
    }
    
    /// The premium banner for unsubscribed users.
    /// This banner encourages subscription with a professional layout and theme-colored elements.
    private var premiumBanner: some View {
        VStack(spacing: 12) {
            Text("Unlock Advanced Metrics with Premium")
                .font(.title3.bold())
                .foregroundStyle(themeColor.opacity(0.9))
                .multilineTextAlignment(.center)
            
            Text("Subscribe to access Progress Pulse Scores, detailed insights, and more to optimize your fitness journey.")
                .font(.subheadline)
                .foregroundStyle(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button("Learn More") {
                    showMetricsInfoPopover = true
                }
                .buttonStyle(.bordered)
                .tint(themeColor.opacity(0.9))
                
                if purchaseManager.isPurchasing {
                    ProgressView()
                } else {
                    Button("Subscribe Now") {
                        Task {
                            await purchaseManager.purchase()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeColor.opacity(0.9))
                }
            }
        }
        .padding(20)
        .background(Color.proBackground)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.4), radius: 6) // Enhanced shadow for depth.
        .padding(.horizontal)
        .popover(isPresented: $showMetricsInfoPopover) {
            AdvancedMetricsExplanationView()
                .presentationDetents([.medium])
        }
    }
    
    // MARK: - Private Methods
    
    /// Initializes the progress board by fetching history data and metrics.
    /// This method is called on appearance to load initial data.
    private func initializeBoard() async {
        logger.debug("[ProgressBoardView] [initializeBoard] Called. HealthKit Authorized: \(self.healthKitManager.isReadAuthorized)")
        Task {
            await fetchJournalHistoryDataAsync()
            if healthKitManager.isReadAuthorized{
                logger.debug("[ProgressBoardView] [initializeBoard] HealthKit is authorized, calling fetchLatestMetrics().")
                await fetchLatestMetrics()
            } else {
                await MainActor.run {
                    self.latestCategoryMetrics = [:]
                    logger.debug("[ProgressBoardView] [initializeBoard] HealthKit NOT authorized, clearing latestCategoryMetrics.")
                    if self.isLoading { self.isLoading = false }
                }
            }
        }
    }
    
    /// Refreshes the progress board by fetching updated history data and metrics.
    /// This method is triggered by the refreshable modifier.
    private func refreshBoard() async {
        logger.debug("[ProgressBoardView] [refreshBoard] Called. HealthKit Authorized: \(self.healthKitManager.isReadAuthorized)")
        await fetchJournalHistoryDataAsync()
        if healthKitManager.isReadAuthorized {
            logger.debug("[ProgressBoardView] [refreshBoard] HealthKit is authorized, calling fetchLatestMetrics().")
            await fetchLatestMetrics()
        } else {
            await MainActor.run {
                self.latestCategoryMetrics = [:]
                logger.debug("[ProgressBoardView] [refreshBoard] HealthKit NOT authorized, clearing latestCategoryMetrics.")
            }
        }
    }
    
    /// Fetches workout history data asynchronously and updates the view’s state.
    /// This method queries SwiftData for history entries, calculates metrics, and updates state properties on the main actor.
    private func fetchJournalHistoryDataAsync() async {
        await MainActor.run { self.isLoading = true }
        logger.debug("[ProgressBoardView] [fetchHistoryDataAsync] Starting fetch. isLoading set to true.")
        
        let now = Date()
        let endOfTodayForPredicate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        
        let startOfToday = calendar.startOfDay(for: now)
        guard let historyFetchStartDate = calendar.date(byAdding: .day, value: -89, to: startOfToday) else {
            logger.error("[ProgressBoardView] [fetchHistoryDataAsync] Failed to calculate history fetch start date.")
            await MainActor.run {
                errorManager.present(title: "Error", message: "Failed to calculate date range for history.")
                self.isLoading = false
            }
            return
        }
        
        logger.debug("[ProgressBoardView] [fetchHistoryDataAsync] Fetching history from: \(historyFetchStartDate.formatted(date: .long, time: .standard)) up to (but not including): \(endOfTodayForPredicate.formatted(date: .long, time: .standard)) for graphs and heatmap.")
        
        let predicate = #Predicate<History> { history in
            history.date >= historyFetchStartDate && history.date < endOfTodayForPredicate
        }
        
        var descriptor = FetchDescriptor<History>(predicate: predicate, sortBy: [SortDescriptor(\History.date)])
        descriptor.relationshipKeyPathsForPrefetching = [\History.workout]
        
        do {
            let history = try modelContext.fetch(descriptor)
            logger.log("[ProgressBoardView] [fetchHistoryDataAsync] Fetched \(history.count) history records with predicate for the last 90 days.")
            
            var calculatedDaysToDisplay: [DayGridItem] = []
            guard let heatmapStartDate = calendar.date(byAdding: .day, value: -89, to: startOfToday) else {
                logger.error("[ProgressBoardView] [fetchHistoryDataAsync] Failed to calculate heatmapStartDate for display loop.")
                await MainActor.run {
                    errorManager.present(title: "Error", message: "Date calculation error.")
                    self.isLoading = false
                }
                return
            }
            
            var currentDateIterator = heatmapStartDate
            for i in 0..<90 {
                let displayDate = calendar.startOfDay(for: currentDateIterator)
                let isCurrentItemToday = calendar.isDate(displayDate, inSameDayAs: startOfToday)
                
                let didWorkoutOnThisDay = history.contains(where: { calendar.isDate($0.date, inSameDayAs: displayDate) })
                let isTestWorkoutOnThisDay = history.first(where: { calendar.isDate($0.date, inSameDayAs: displayDate) })?.workout?.title.lowercased().contains("test") ?? false
                
                calculatedDaysToDisplay.append(DayGridItem(
                    date: displayDate,
                    didWorkout: didWorkoutOnThisDay,
                    isToday: isCurrentItemToday,
                    isTestWorkout: isTestWorkoutOnThisDay
                ))
                if i < 89 {
                    currentDateIterator = calendar.date(byAdding: .day, value: 1, to: currentDateIterator)!
                }
            }
            logger.debug("[ProgressBoardView] [fetchHistoryDataAsync] Calculated \(calculatedDaysToDisplay.count) days for heatmap display. First: \(calculatedDaysToDisplay.first?.date.description ?? "N/A"), Last: \(calculatedDaysToDisplay.last?.date.description ?? "N/A")")
            
            let calculatedTotalWorkouts90Days = history.count
            let totalDurationMinutes90Days = history.reduce(0.0) { $0 + $1.lastSessionDuration }
            
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute]
            formatter.unitsStyle = .abbreviated
            let calculatedTotalDurationFormatted = formatter.string(from: TimeInterval(totalDurationMinutes90Days * 60)) ?? "\(Int(totalDurationMinutes90Days)) min"
            
            let numberOfWeeksIn90Days = 90.0 / 7.0
            let calculatedAvgWorkoutsPerWeek = Double(calculatedTotalWorkouts90Days) / numberOfWeeksIn90Days
            
            var distinctDays = Set<DateComponents>()
            for historyItem in history {
                distinctDays.insert(calendar.dateComponents([.year, .month, .day], from: historyItem.date))
            }
            let calculatedDistinctActiveDays = distinctDays.count
            
            let calculatedWeeklyDurations: [Double] = (0..<12).map { weekIndex -> Double in
                let endOfWeekDay = calendar.date(byAdding: .day, value: -(weekIndex * 7), to: startOfToday)!
                let startOfWeekDay = calendar.date(byAdding: .day, value: -6, to: endOfWeekDay)!
                return history.filter { history in
                    let historyDay = calendar.startOfDay(for: history.date)
                    return historyDay >= startOfWeekDay && historyDay <= endOfWeekDay
                }.reduce(0.0) { $0 + $1.lastSessionDuration }
            }.reversed()
            
            let calculatedWeeklyWorkoutCounts: [Int] = (0..<12).map { weekIndex in
                let endOfWeekDay = calendar.date(byAdding: .day, value: -(weekIndex * 7), to: startOfToday)!
                let startOfWeekDay = calendar.date(byAdding: .day, value: -6, to: endOfWeekDay)!
                return history.filter { history in
                    let historyDate = calendar.startOfDay(for: history.date)
                    return historyDate >= startOfWeekDay && historyDate <= endOfWeekDay
                }.count
            }.reversed()
            
            let calculatedWeeklyProgressPulseScores: [Double] = (0..<12).map { weekIndex -> Double in
                let endOfWeekDay = calendar.date(byAdding: .day, value: -(weekIndex * 7), to: startOfToday)!
                let startOfWeekDay = calendar.date(byAdding: .day, value: -6, to: endOfWeekDay)!
                let scoresInWeek = history.filter { history in
                    let historyDay = calendar.startOfDay(for: history.date)
                    return historyDay >= startOfWeekDay && historyDay <= endOfWeekDay && history.progressPulseScore != nil
                }.compactMap { $0.progressPulseScore }
                return scoresInWeek.isEmpty ? 0.0 : scoresInWeek.reduce(0.0, +) / Double(scoresInWeek.count)
            }.reversed()
            
            await MainActor.run {
                self.daysToDisplay = calculatedDaysToDisplay
                self.weeklyDurations = calculatedWeeklyDurations
                self.weeklyWorkoutCounts = calculatedWeeklyWorkoutCounts
                self.weeklyProgressPulseScores = calculatedWeeklyProgressPulseScores
                
                self.totalWorkoutsLast90Days = calculatedTotalWorkouts90Days
                self.totalDurationLast90DaysFormatted = calculatedTotalDurationFormatted
                self.avgWorkoutsPerWeekLast90Days = calculatedAvgWorkoutsPerWeek
                self.distinctActiveDaysLast90Days = calculatedDistinctActiveDays
                
                self.isLoading = false
                logger.log("[ProgressBoardView] [fetchHistoryDataAsync] History data processed. Weekly Pulse Scores: \(calculatedWeeklyProgressPulseScores), Total 90-day Workouts: \(calculatedTotalWorkouts90Days)")
            }
        } catch {
            logger.error("[ProgressBoardView] [fetchHistoryDataAsync] Failed to fetch history: \(error.localizedDescription)")
            await MainActor.run {
                errorManager.present(title: "Error", message: "Failed to load activity data: \(error.localizedDescription)")
                self.isLoading = false
            }
        }
    }
    
    /// Fetches the latest workout metrics per category from SwiftData.
    /// This method groups history entries by category and extracts the most recent metrics for each.
    private func fetchLatestMetrics() async {
        logger.debug("[ProgressBoardView] [fetchLatestMetrics] Fetching latest metrics per category.")
        
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -89, to: today) else {
            logger.error("[ProgressBoardView] [fetchLatestMetrics] Failed to calculate start date.")
            return
        }
        
        let predicate = #Predicate<History> { history in
            history.date >= startDate && history.date <= today &&
            (history.intensityScore != nil || history.progressPulseScore != nil || history.dominantZone != nil)
        }
        
        var descriptor = FetchDescriptor<History>(predicate: predicate, sortBy: [SortDescriptor(\History.date, order: .reverse)])
        descriptor.relationshipKeyPathsForPrefetching = [\History.workout?.category]
        
        do {
            let historiesWithMetrics = try modelContext.fetch(descriptor)
            logger.debug("[ProgressBoardView] [fetchLatestMetrics] Fetched \(historiesWithMetrics.count) histories potentially containing metrics for predicate.")
            
            let latestHistoryPerCategory = Dictionary(grouping: historiesWithMetrics, by: { $0.workout?.category?.categoryName ?? "Uncategorized" })
                .compactMapValues { $0.first }
            
            var newMetrics: [String: WorkoutMetrics] = [:]
            for (categoryName, latestHistory) in latestHistoryPerCategory {
                logger.trace("[ProgressBoardView] [fetchLatestMetrics] Latest metrics for category '\(categoryName)' from history date: \(latestHistory.date), Intensity: \(latestHistory.intensityScore ?? -1), Pulse: \(latestHistory.progressPulseScore ?? -1), Zone: \(latestHistory.dominantZone ?? -1)")
                newMetrics[categoryName] = WorkoutMetrics(
                    intensityScore: latestHistory.intensityScore,
                    progressPulseScore: latestHistory.progressPulseScore,
                    dominantZone: latestHistory.dominantZone
                )
            }
            
            await MainActor.run {
                self.latestCategoryMetrics = newMetrics
                logger.debug("[ProgressBoardView] [fetchLatestMetrics] Latest metrics updated. Count: \(newMetrics.count). Keys: \(newMetrics.keys.joined(separator: ", "))")
            }
        } catch {
            logger.error("[ProgressBoardView] [fetchLatestMetrics] Failed to fetch histories for metrics: \(error.localizedDescription)")
        }
    }
    
    /// Fetches all workout categories from SwiftData.
    /// - Returns: An array of `Category` objects sorted by name.
    private func fetchCategories() -> [Category] {
        let descriptor = FetchDescriptor<Category>()
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch categories: \(error)")
            return []
        }
    }
    
    /// Returns a description for a heart rate zone.
    /// - Parameter zone: The heart rate zone number (1–5).
    /// - Returns: A string describing the zone intensity.
    private func zoneDescription(_ zone: Int) -> String {
        switch zone {
        case 1: return "Very Light"
        case 2: return "Light"
        case 3: return "Moderate"
        case 4: return "Hard"
        case 5: return "Maximum"
        default: return "Unknown"
        }
    }
    
}

// MARK: - Supporting Structures

/// Represents workout metrics for a category.
/// This struct holds optional values for intensity, progress pulse, and dominant heart rate zone.
struct WorkoutMetrics {
    let intensityScore: Double?
    let progressPulseScore: Double?
    let dominantZone: Int?
}

