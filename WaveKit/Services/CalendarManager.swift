import EventKit
import Foundation

@MainActor
final class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    private let store = EKEventStore()
    @Published private(set) var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published private(set) var enabledSpotIds: Set<String>

    private func calIdKey(_ spotId: String) -> String { "wavekit_cal_id_\(spotId)" }
    private func eventIdsKey(_ spotId: String) -> String { "wavekit_event_ids_\(spotId)" }
    private let enabledSpotsKey = "wavekit_calendar_enabled_spots"

    private init() {
        enabledSpotIds = Set(UserDefaults.standard.stringArray(forKey: "wavekit_calendar_enabled_spots") ?? [])
    }

    var isAuthorized: Bool {
        authStatus == .fullAccess || authStatus == .writeOnly
    }

    // MARK: - Permission

    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            authStatus = EKEventStore.authorizationStatus(for: .event)
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Enable / Disable

    func enableSpot(_ spotId: String, name: String, forecasts: [String: SpotForecast]) async {
        guard await requestAccess() else { return }
        enabledSpotIds.insert(spotId)
        UserDefaults.standard.set(Array(enabledSpotIds), forKey: enabledSpotsKey)
        if let forecast = forecasts[spotId] {
            syncSpot(spotId, forecast: forecast)
        }
    }

    func disableSpot(_ spotId: String) {
        removeSpotCalendar(spotId)
        enabledSpotIds.remove(spotId)
        UserDefaults.standard.set(Array(enabledSpotIds), forKey: enabledSpotsKey)
    }

    // MARK: - Sync

    func syncAll(forecasts: [String: SpotForecast]) {
        guard isAuthorized, !enabledSpotIds.isEmpty else { return }
        for spotId in enabledSpotIds {
            if let forecast = forecasts[spotId] {
                syncSpot(spotId, forecast: forecast)
            }
        }
    }

    private func syncSpot(_ spotId: String, forecast: SpotForecast) {
        let utcOffset = forecast.extendedForecast.first?.utcOffset ?? 0
        let spotTZ = TimeZone(secondsFromGMT: utcOffset * 3600) ?? .current

        guard let calendarId = getOrCreateCalendar(for: spotId, name: "🌊 \(forecast.spotName)"),
              let calendar = store.calendar(withIdentifier: calendarId) else { return }

        // Remove old events
        for id in storedEventIds(for: spotId) {
            if let event = store.event(withIdentifier: id) {
                try? store.remove(event, span: .thisEvent, commit: false)
            }
        }

        // Create new events for each day × period
        var newIds: [String] = []
        let segments: [(String, Int, Int)] = [("AM", 6, 12), ("Noon", 12, 17), ("PM", 17, 21)]

        for day in forecast.extendedForecast {
            for (label, startHour, endHour) in segments {
                let rating: SurfRating
                switch label {
                case "AM":   rating = day.ratingAM
                case "Noon": rating = day.ratingNoon
                default:     rating = day.ratingPM
                }

                let event = EKEvent(eventStore: store)
                event.calendar = calendar
                event.title = "\(day.waveDisplay) · \(rating.displayName)"
                event.startDate = day.date.addingTimeInterval(TimeInterval(startHour * 3600))
                event.endDate   = day.date.addingTimeInterval(TimeInterval(endHour * 3600))
                event.timeZone  = spotTZ

                var notes: [String] = []
                if let period = forecast.periods.first(where: { $0.label == label }) {
                    if let swell = period.swellDisplay { notes.append("Swell: \(swell)") }
                    if let wind = period.windDisplay {
                        let dirType = period.windDirectionType.map { " \($0)" } ?? ""
                        notes.append("Wind: \(wind)kts \(period.windArrow)\(dirType)")
                    }
                }
                if let dir = day.swellDirection {
                    notes.append("Swell direction: \(day.directionArrows) \(Int(dir))°")
                }
                if !notes.isEmpty { event.notes = notes.joined(separator: "\n") }

                try? store.save(event, span: .thisEvent, commit: false)
                if let id = event.eventIdentifier { newIds.append(id) }
            }
        }

        try? store.commit()
        storeEventIds(newIds, for: spotId)
    }

    private func removeSpotCalendar(_ spotId: String) {
        for id in storedEventIds(for: spotId) {
            if let event = store.event(withIdentifier: id) {
                try? store.remove(event, span: .thisEvent, commit: false)
            }
        }
        try? store.commit()
        UserDefaults.standard.removeObject(forKey: eventIdsKey(spotId))

        if let calId = UserDefaults.standard.string(forKey: calIdKey(spotId)),
           let calendar = store.calendar(withIdentifier: calId) {
            try? store.removeCalendar(calendar, commit: true)
        }
        UserDefaults.standard.removeObject(forKey: calIdKey(spotId))
    }

    private func getOrCreateCalendar(for spotId: String, name: String) -> String? {
        // Return existing if still valid, updating title if needed
        if let existing = UserDefaults.standard.string(forKey: calIdKey(spotId)),
           let cal = store.calendar(withIdentifier: existing) {
            if cal.title != name {
                cal.title = name
                try? store.saveCalendar(cal, commit: true)
            }
            return existing
        }

        let cal = EKCalendar(for: .event, eventStore: store)
        cal.title = name

        // Prefer iCloud so the calendar syncs across devices; fall back to local
        let source = store.sources.first { $0.sourceType == .calDAV && $0.title.contains("iCloud") }
            ?? store.defaultCalendarForNewEvents?.source
            ?? store.sources.first { $0.sourceType == .local }

        guard let source else { return nil }
        cal.source = source

        do {
            try store.saveCalendar(cal, commit: true)
        } catch {
            return nil
        }

        UserDefaults.standard.set(cal.calendarIdentifier, forKey: calIdKey(spotId))
        return cal.calendarIdentifier
    }

    private func storedEventIds(for spotId: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: eventIdsKey(spotId)) ?? []
    }

    private func storeEventIds(_ ids: [String], for spotId: String) {
        UserDefaults.standard.set(ids, forKey: eventIdsKey(spotId))
    }
}
