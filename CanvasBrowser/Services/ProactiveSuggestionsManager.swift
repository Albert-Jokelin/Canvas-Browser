import Foundation
import EventKit
import CoreLocation
import Combine
import os.log

/// Manages intelligent tab suggestions based on context: calendar, location, time of day
@MainActor
class ProactiveSuggestionsManager: NSObject, ObservableObject {
    static let shared = ProactiveSuggestionsManager()

    // MARK: - Published Properties

    @Published var suggestions: [ProactiveSuggestion] = []
    @Published var isEnabled = true
    @Published var hasCalendarAccess = false
    @Published var hasLocationAccess = false

    // MARK: - Dependencies

    private let eventStore = EKEventStore()
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?

    private let logger = Logger(subsystem: "com.canvas.browser", category: "ProactiveSuggestions")
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    // MARK: - Suggestion Categories

    enum SuggestionCategory: String, CaseIterable {
        case morningRoutine = "morning_routine"
        case calendar = "calendar"
        case travel = "travel"
        case location = "location"
        case timeOfDay = "time_of_day"
        case weekday = "weekday"

        var icon: String {
            switch self {
            case .morningRoutine: return "sunrise.fill"
            case .calendar: return "calendar"
            case .travel: return "airplane"
            case .location: return "location.fill"
            case .timeOfDay: return "clock.fill"
            case .weekday: return "calendar.badge.clock"
            }
        }
    }

    // MARK: - Initialization

    override private init() {
        super.init()
        locationManager.delegate = self
        startUpdateTimer()
        requestPermissions()
    }

    // MARK: - Permissions

    func requestPermissions() {
        requestCalendarAccess()
        requestLocationAccess()
    }

    private func requestCalendarAccess() {
        Task {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    hasCalendarAccess = granted
                    if granted {
                        logger.info("Calendar access granted")
                        Task { await self.updateSuggestions() }
                    }
                }
            } catch {
                logger.error("Failed to request calendar access: \(error.localizedDescription)")
            }
        }
    }

    private func requestLocationAccess() {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            hasLocationAccess = true
            locationManager.startUpdatingLocation()
        default:
            hasLocationAccess = false
        }
    }

    // MARK: - Update Timer

    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateSuggestions()
            }
        }
        // Initial update
        Task { await updateSuggestions() }
    }

    // MARK: - Suggestion Generation

    func updateSuggestions() async {
        guard isEnabled else {
            suggestions = []
            return
        }

        var newSuggestions: [ProactiveSuggestion] = []

        // Time-based suggestions
        newSuggestions.append(contentsOf: generateTimeBasedSuggestions())

        // Calendar-based suggestions
        if hasCalendarAccess {
            newSuggestions.append(contentsOf: await generateCalendarSuggestions())
        }

        // Location-based suggestions
        if hasLocationAccess, let location = currentLocation {
            newSuggestions.append(contentsOf: generateLocationSuggestions(location))
        }

        // Day of week suggestions
        newSuggestions.append(contentsOf: generateWeekdaySuggestions())

        // Sort by relevance and limit
        suggestions = Array(newSuggestions.sorted { $0.relevanceScore > $1.relevanceScore }.prefix(5))

        logger.info("Generated \(self.suggestions.count) proactive suggestions")
    }

    // MARK: - Time-Based Suggestions

    private func generateTimeBasedSuggestions() -> [ProactiveSuggestion] {
        var suggestions: [ProactiveSuggestion] = []
        let hour = Calendar.current.component(.hour, from: Date())

        // Morning (6 AM - 10 AM)
        if hour >= 6 && hour < 10 {
            suggestions.append(ProactiveSuggestion(
                title: "Morning News",
                subtitle: "Catch up on today's headlines",
                icon: "newspaper.fill",
                category: .morningRoutine,
                url: URL(string: "https://news.google.com"),
                relevanceScore: 0.8
            ))

            suggestions.append(ProactiveSuggestion(
                title: "Weather",
                subtitle: "Check today's forecast",
                icon: "cloud.sun.fill",
                category: .morningRoutine,
                url: URL(string: "https://weather.com"),
                relevanceScore: 0.9
            ))
        }

        // Lunch time (11 AM - 1 PM)
        if hour >= 11 && hour < 13 {
            suggestions.append(ProactiveSuggestion(
                title: "Lunch Spots",
                subtitle: "Find nearby restaurants",
                icon: "fork.knife",
                category: .timeOfDay,
                url: URL(string: "https://www.google.com/maps/search/restaurants"),
                relevanceScore: 0.7
            ))
        }

        // Evening (6 PM - 10 PM)
        if hour >= 18 && hour < 22 {
            suggestions.append(ProactiveSuggestion(
                title: "Evening Entertainment",
                subtitle: "Movies, shows, and more",
                icon: "tv.fill",
                category: .timeOfDay,
                url: nil, // GenTab suggestion
                genTabTopic: "What to watch tonight",
                relevanceScore: 0.6
            ))
        }

        return suggestions
    }

    // MARK: - Calendar-Based Suggestions

    private func generateCalendarSuggestions() async -> [ProactiveSuggestion] {
        var suggestions: [ProactiveSuggestion] = []

        let calendar = Calendar.current
        let now = Date()
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now

        let predicate = eventStore.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)

        for event in events.prefix(3) {
            // Skip all-day events
            guard !event.isAllDay else { continue }

            // Check if event is within next 2 hours
            guard let startDate = event.startDate,
                  startDate.timeIntervalSinceNow < 7200 else { continue }

            let timeUntil = startDate.timeIntervalSinceNow
            let minutesUntil = Int(timeUntil / 60)

            // Create suggestion based on event
            if let url = event.url {
                suggestions.append(ProactiveSuggestion(
                    title: event.title ?? "Upcoming Event",
                    subtitle: "In \(minutesUntil) minutes",
                    icon: "calendar",
                    category: .calendar,
                    url: url,
                    relevanceScore: min(1.0, 1.0 - (timeUntil / 7200))
                ))
            } else if let location = event.location, !location.isEmpty {
                // Suggest maps for events with locations
                let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location
                suggestions.append(ProactiveSuggestion(
                    title: "Navigate to \(event.title ?? "Event")",
                    subtitle: location,
                    icon: "map.fill",
                    category: .calendar,
                    url: URL(string: "https://www.google.com/maps/search/?api=1&query=\(encodedLocation)"),
                    relevanceScore: min(1.0, 1.0 - (timeUntil / 7200))
                ))
            } else if let notes = event.notes, notes.contains("http") {
                // Extract URLs from notes
                if let range = notes.range(of: "https?://[^\\s]+", options: .regularExpression),
                   let url = URL(string: String(notes[range])) {
                    suggestions.append(ProactiveSuggestion(
                        title: event.title ?? "Event Link",
                        subtitle: "Related to upcoming meeting",
                        icon: "link",
                        category: .calendar,
                        url: url,
                        relevanceScore: min(1.0, 1.0 - (timeUntil / 7200))
                    ))
                }
            }
        }

        return suggestions
    }

    // MARK: - Location-Based Suggestions

    private func generateLocationSuggestions(_ location: CLLocation) -> [ProactiveSuggestion] {
        var suggestions: [ProactiveSuggestion] = []

        // These would ideally be more sophisticated with reverse geocoding
        // For now, provide generic location-aware suggestions

        suggestions.append(ProactiveSuggestion(
            title: "Nearby Places",
            subtitle: "Explore what's around you",
            icon: "mappin.and.ellipse",
            category: .location,
            url: URL(string: "https://www.google.com/maps/search/nearby/@\(location.coordinate.latitude),\(location.coordinate.longitude),15z"),
            relevanceScore: 0.5
        ))

        return suggestions
    }

    // MARK: - Weekday Suggestions

    private func generateWeekdaySuggestions() -> [ProactiveSuggestion] {
        var suggestions: [ProactiveSuggestion] = []
        let weekday = Calendar.current.component(.weekday, from: Date())

        // Weekend (Saturday = 7, Sunday = 1)
        if weekday == 1 || weekday == 7 {
            suggestions.append(ProactiveSuggestion(
                title: "Weekend Activities",
                subtitle: "Things to do this weekend",
                icon: "sparkles",
                category: .weekday,
                url: nil,
                genTabTopic: "Fun weekend activities nearby",
                relevanceScore: 0.6
            ))
        }

        // Monday
        if weekday == 2 {
            suggestions.append(ProactiveSuggestion(
                title: "Week Ahead",
                subtitle: "Plan your week",
                icon: "list.bullet.clipboard",
                category: .weekday,
                url: nil,
                genTabTopic: "Productivity tips for the week",
                relevanceScore: 0.5
            ))
        }

        // Friday
        if weekday == 6 {
            suggestions.append(ProactiveSuggestion(
                title: "Weekend Plans",
                subtitle: "Events and activities",
                icon: "party.popper.fill",
                category: .weekday,
                url: nil,
                genTabTopic: "Weekend events and activities",
                relevanceScore: 0.6
            ))
        }

        return suggestions
    }

    // MARK: - Manual Triggers

    func refreshSuggestions() {
        Task {
            await updateSuggestions()
        }
    }

    func dismissSuggestion(_ suggestion: ProactiveSuggestion) {
        suggestions.removeAll { $0.id == suggestion.id }

        // Track dismissed suggestions to avoid showing again soon
        var dismissed = UserDefaults.standard.array(forKey: "dismissedSuggestionTitles") as? [String] ?? []
        dismissed.append(suggestion.title)
        // Keep only last 20
        if dismissed.count > 20 {
            dismissed.removeFirst(dismissed.count - 20)
        }
        UserDefaults.standard.set(dismissed, forKey: "dismissedSuggestionTitles")
    }

    // MARK: - Cleanup

    func stopUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
        locationManager.stopUpdatingLocation()
    }

    deinit {
        updateTimer?.invalidate()
    }
}

// MARK: - CLLocationManagerDelegate

extension ProactiveSuggestionsManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.hasLocationAccess = true
                self.locationManager.startUpdatingLocation()
            default:
                self.hasLocationAccess = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.logger.error("Location error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Proactive Suggestion

struct ProactiveSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let category: ProactiveSuggestionsManager.SuggestionCategory
    let url: URL?
    var genTabTopic: String?
    let relevanceScore: Double
    let timestamp = Date()

    var isGenTabSuggestion: Bool {
        genTabTopic != nil
    }
}
