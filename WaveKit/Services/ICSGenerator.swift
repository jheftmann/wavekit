import Foundation

struct ICSGenerator {

    static func calendarURL(for spotId: String) -> String {
        "webcal://localhost:8765/spot/\(spotId).ics"
    }

    static func generate(for spotId: String, using forecasts: [String: SpotForecast]) -> String {
        guard let forecast = forecasts[spotId] else {
            return emptyCalendar()
        }
        return generateCalendar(from: forecast)
    }

    private static func generateCalendar(from forecast: SpotForecast) -> String {
        var lines: [String] = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//WaveKit//Surf Forecast//EN",
            "X-WR-CALNAME:\(forecast.spotName)",
            "X-WR-CALDESC:Surf forecast for \(forecast.spotName)",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "REFRESH-INTERVAL;VALUE=DURATION:PT30M",
            "X-PUBLISHED-TTL:PT30M"
        ]

        for day in forecast.extendedForecast {
            let segments: [(label: String, rating: SurfRating, startHour: Int, endHour: Int)] = [
                ("AM",   day.ratingAM,   6, 12),
                ("Noon", day.ratingNoon, 12, 17),
                ("PM",   day.ratingPM,   17, 21)
            ]

            for seg in segments {
                let startStr = floatingTime(dayStart: day.date, hour: seg.startHour, utcOffset: day.utcOffset)
                let endStr   = floatingTime(dayStart: day.date, hour: seg.endHour,   utcOffset: day.utcOffset)
                let title    = "\(day.waveDisplay) · \(seg.rating.displayName)"
                let uid      = "\(forecast.id)-\(dayStamp(day.date))-\(seg.label)@wavekit"
                let desc     = description(for: seg.label, day: day, forecast: forecast)

                lines += [
                    "BEGIN:VEVENT",
                    "UID:\(uid)",
                    "DTSTART:\(startStr)",
                    "DTEND:\(endStr)",
                    "SUMMARY:\(title)"
                ]
                if !desc.isEmpty {
                    lines.append("DESCRIPTION:\(desc)")
                }
                lines.append("END:VEVENT")
            }
        }

        lines.append("END:VCALENDAR")
        return lines.joined(separator: "\r\n")
    }

    // Floating local time (no timezone suffix) — shows the spot's local hour in any calendar
    private static func floatingTime(dayStart: Date, hour: Int, utcOffset: Int) -> String {
        let date = dayStart.addingTimeInterval(TimeInterval(hour * 3600))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        formatter.timeZone = TimeZone(secondsFromGMT: utcOffset * 3600) ?? .current
        return formatter.string(from: date)
    }

    private static func dayStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private static func description(for label: String, day: DayForecast, forecast: SpotForecast) -> String {
        var parts: [String] = []

        // Enrich today's events with full period detail (swell + wind)
        let calendar = Calendar.current
        if calendar.isDateInToday(day.date),
           let period = forecast.periods.first(where: { $0.label == label }) {
            if let swell = period.swellDisplay {
                parts.append("Swell: \(swell)")
            }
            if let wind = period.windDisplay {
                let type = period.windDirectionType.map { " \($0)" } ?? ""
                parts.append("Wind: \(wind)kts \(period.windArrow)\(type)")
            }
        }

        if let dir = day.swellDirection {
            parts.append("Swell direction: \(day.directionArrows) \(Int(dir))°")
        }

        // Escape special ICS chars
        return parts.joined(separator: "\\n")
            .replacingOccurrences(of: ",", with: "\\,")
    }

    private static func emptyCalendar() -> String {
        [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//WaveKit//Surf Forecast//EN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "END:VCALENDAR"
        ].joined(separator: "\r\n")
    }
}
