import Foundation
import EventKit
import Contacts
import MapKit
import SwiftUI

// MARK: - Calendar Integration

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    @Published var events: [EKEvent] = []
    @Published var calendars: [EKCalendar] = []
    @Published var hasAccess = false

    private let eventStore = EKEventStore()

    private init() {}

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                self.hasAccess = granted
                if granted {
                    loadCalendars()
                }
            }
            return granted
        } catch {
            print("Calendar access error: \(error)")
            return false
        }
    }

    private func loadCalendars() {
        calendars = eventStore.calendars(for: .event)
    }

    func fetchEvents(from startDate: Date, to endDate: Date) {
        guard hasAccess else { return }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    func fetchTodaysEvents() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        fetchEvents(from: startOfDay, to: endOfDay)
    }

    func fetchUpcomingEvents(days: Int = 7) {
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate)!
        fetchEvents(from: startDate, to: endDate)
    }

    func createEvent(title: String, startDate: Date, endDate: Date, notes: String? = nil, url: URL? = nil) -> Bool {
        guard hasAccess else { return false }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        if let url = url {
            event.url = url
        }
        event.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(event, span: .thisEvent)
            fetchTodaysEvents()
            return true
        } catch {
            print("Failed to create event: \(error)")
            return false
        }
    }
}

// MARK: - Reminders Integration

class RemindersManager: ObservableObject {
    static let shared = RemindersManager()

    @Published var reminders: [EKReminder] = []
    @Published var lists: [EKCalendar] = []
    @Published var hasAccess = false

    private let eventStore = EKEventStore()

    private init() {}

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            await MainActor.run {
                self.hasAccess = granted
                if granted {
                    loadLists()
                }
            }
            return granted
        } catch {
            print("Reminders access error: \(error)")
            return false
        }
    }

    private func loadLists() {
        lists = eventStore.calendars(for: .reminder)
    }

    func fetchReminders(completed: Bool? = nil) {
        guard hasAccess else { return }

        let predicate = eventStore.predicateForReminders(in: nil)

        eventStore.fetchReminders(matching: predicate) { [weak self] fetchedReminders in
            DispatchQueue.main.async {
                guard let reminders = fetchedReminders else { return }
                if let completed = completed {
                    self?.reminders = reminders.filter { $0.isCompleted == completed }
                } else {
                    self?.reminders = reminders
                }
            }
        }
    }

    func createReminder(title: String, dueDate: Date? = nil, notes: String? = nil, url: URL? = nil) -> Bool {
        guard hasAccess else { return false }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        if let dueDate = dueDate {
            let calendar = Calendar.current
            reminder.dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        }

        do {
            try eventStore.save(reminder, commit: true)
            fetchReminders(completed: false)
            return true
        } catch {
            print("Failed to create reminder: \(error)")
            return false
        }
    }

    func completeReminder(_ reminder: EKReminder) -> Bool {
        reminder.isCompleted = true

        do {
            try eventStore.save(reminder, commit: true)
            fetchReminders(completed: false)
            return true
        } catch {
            print("Failed to complete reminder: \(error)")
            return false
        }
    }
}

// MARK: - Contacts Integration

class ContactsManager: ObservableObject {
    static let shared = ContactsManager()

    @Published var contacts: [CNContact] = []
    @Published var hasAccess = false

    private let store = CNContactStore()

    private init() {}

    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestAccess(for: .contacts)
            await MainActor.run {
                self.hasAccess = granted
            }
            return granted
        } catch {
            print("Contacts access error: \(error)")
            return false
        }
    }

    func fetchContacts() {
        guard hasAccess else { return }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactUrlAddressesKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .userDefault

        var fetchedContacts: [CNContact] = []

        do {
            try store.enumerateContacts(with: request) { contact, _ in
                fetchedContacts.append(contact)
            }
            contacts = fetchedContacts
        } catch {
            print("Failed to fetch contacts: \(error)")
        }
    }

    func search(query: String) -> [CNContact] {
        guard hasAccess, !query.isEmpty else { return contacts }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]

        let predicate = CNContact.predicateForContacts(matchingName: query)

        do {
            return try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
        } catch {
            print("Failed to search contacts: \(error)")
            return []
        }
    }
}

// MARK: - Maps Integration

class MapsManager {
    static let shared = MapsManager()

    private init() {}

    func openInMaps(address: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let placemark = placemarks?.first,
               let location = placemark.location {
                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
                mapItem.name = address
                mapItem.openInMaps()
            }
        }
    }

    func openInMaps(coordinate: CLLocationCoordinate2D, name: String? = nil) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps()
    }

    func openDirections(to destination: CLLocationCoordinate2D, destinationName: String? = nil) {
        let destinationPlacemark = MKPlacemark(coordinate: destination)
        let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
        destinationMapItem.name = destinationName

        MKMapItem.openMaps(
            with: [MKMapItem.forCurrentLocation(), destinationMapItem],
            launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault]
        )
    }

    func searchNearby(query: String, region: MKCoordinateRegion) async -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region

        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            return response.mapItems
        } catch {
            print("Maps search error: \(error)")
            return []
        }
    }
}

// MARK: - Notes Integration

class NotesManager {
    static let shared = NotesManager()

    private init() {}

    func createNote(title: String, body: String) {
        // Open Notes app with a new note
        // Using AppleScript via NSAppleScript
        let script = """
        tell application "Notes"
            activate
            tell account "iCloud"
                make new note with properties {name:"\(escapeForAppleScript(title))", body:"\(escapeForAppleScript(body))"}
            end tell
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
            }
        }
    }

    func openNotes() {
        NSWorkspace.shared.launchApplication("Notes")
    }

    private func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

// MARK: - Photos Integration

class PhotosManager {
    static let shared = PhotosManager()

    private init() {}

    func saveImage(_ image: NSImage, completion: @escaping (Bool) -> Void) {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            completion(false)
            return
        }

        // Save to Pictures folder
        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        let filename = "Canvas_\(Date().timeIntervalSince1970).png"
        let fileURL = picturesURL.appendingPathComponent(filename)

        do {
            try pngData.write(to: fileURL)
            completion(true)
        } catch {
            print("Failed to save image: \(error)")
            completion(false)
        }
    }

    func openPhotos() {
        NSWorkspace.shared.launchApplication("Photos")
    }
}

// MARK: - Unified Integration Manager

class AppleIntegrationManager: ObservableObject {
    static let shared = AppleIntegrationManager()

    let calendar = CalendarManager.shared
    let reminders = RemindersManager.shared
    let contacts = ContactsManager.shared
    let maps = MapsManager.shared
    let notes = NotesManager.shared
    let photos = PhotosManager.shared

    @Published var isCalendarAuthorized = false
    @Published var isRemindersAuthorized = false
    @Published var isContactsAuthorized = false

    private init() {}

    func requestAllPermissions() async {
        async let calendarAccess = calendar.requestAccess()
        async let remindersAccess = reminders.requestAccess()
        async let contactsAccess = contacts.requestAccess()

        let results = await (calendarAccess, remindersAccess, contactsAccess)

        await MainActor.run {
            isCalendarAuthorized = results.0
            isRemindersAuthorized = results.1
            isContactsAuthorized = results.2
        }
    }

    // MARK: - Quick Actions from Web Content

    func createEventFromWebPage(title: String, url: URL, suggestedDate: Date? = nil) {
        let startDate = suggestedDate ?? Date().addingTimeInterval(3600) // Default to 1 hour from now
        let endDate = startDate.addingTimeInterval(3600) // 1 hour duration

        _ = calendar.createEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            notes: "From web page",
            url: url
        )
    }

    func createReminderFromWebPage(title: String, url: URL) {
        _ = reminders.createReminder(
            title: title,
            dueDate: Date().addingTimeInterval(86400), // Tomorrow
            notes: "From: \(url.absoluteString)",
            url: url
        )
    }

    func saveToNotes(title: String, content: String, url: URL) {
        let noteContent = "\(content)\n\nSource: \(url.absoluteString)"
        notes.createNote(title: title, body: noteContent)
    }

    func openAddressInMaps(_ address: String) {
        maps.openInMaps(address: address)
    }
}
