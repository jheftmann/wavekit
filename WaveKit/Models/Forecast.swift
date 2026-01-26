import Foundation
import SwiftUI

// MARK: - Wave Forecast

struct WaveForecastResponse: Codable {
    let associated: WaveAssociated?
    let data: WaveData?
}

struct WaveAssociated: Codable {
    let units: WaveUnits?
    let location: LocationInfo?
}

struct WaveUnits: Codable {
    let waveHeight: String?
}

struct LocationInfo: Codable {
    let name: String?
    let lat: Double?
    let lon: Double?
}

struct WaveData: Codable {
    let wave: [WaveEntry]?
}

struct WaveEntry: Codable {
    let timestamp: Int
    let surf: SurfInfo?
    let swells: [SwellInfo]?
}

struct SurfInfo: Codable {
    let min: Double
    let max: Double
    let plus: Bool?
    let humanRelation: String?
}

struct SwellInfo: Codable {
    let height: Double?
    let period: Int?
    let direction: Double?  // degrees
    let directionMin: Double?
}

// MARK: - Tide Forecast

struct TideForecastResponse: Codable {
    let associated: TideAssociated?
    let data: TideData?
}

struct TideAssociated: Codable {
    let tideLocation: TideLocation?
}

struct TideLocation: Codable {
    let name: String?
}

struct TideData: Codable {
    let tides: [TideEntry]?
}

struct TideEntry: Codable {
    let timestamp: Int
    let type: String  // "NORMAL", "HIGH", "LOW"
    let height: Double
}

// MARK: - Wind Forecast

struct WindForecastResponse: Codable {
    let data: WindData?
}

struct WindData: Codable {
    let wind: [WindEntry]?
}

struct WindEntry: Codable {
    let timestamp: Int
    let speed: Double
    let direction: Double
    let directionType: String?  // "Offshore", "Onshore", "Cross-shore"
    let gust: Double?
}

// MARK: - Rating Forecast

struct RatingForecastResponse: Codable {
    let data: RatingData?
}

struct RatingData: Codable {
    let rating: [RatingEntry]?
}

struct RatingEntry: Codable {
    let timestamp: Int
    let rating: RatingInfo?
}

struct RatingInfo: Codable {
    let key: String?  // "POOR", "POOR_TO_FAIR", "FAIR", "FAIR_TO_GOOD", "GOOD", "EPIC"
    let value: Double?  // 0-6 scale
}

// MARK: - Conditions Forecast

struct ConditionsForecastResponse: Codable {
    let data: ConditionsData?
}

struct ConditionsData: Codable {
    let conditions: [ConditionsEntry]?
}

struct ConditionsEntry: Codable {
    let timestamp: Int
    let am: ConditionPeriod?
    let pm: ConditionPeriod?
}

struct ConditionPeriod: Codable {
    let rating: String?  // "POOR", "FAIR", "GOOD"
    let human: String?   // Human-readable description
}

// MARK: - Rating Enum

enum SurfRating: Int, Comparable {
    case veryPoor = 0
    case poor = 1
    case poorToFair = 2
    case fair = 3
    case fairToGood = 4
    case good = 5
    case epic = 6
    case unknown = -1

    static func < (lhs: SurfRating, rhs: SurfRating) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    init(from key: String?) {
        switch key?.uppercased() {
        case "VERY_POOR": self = .veryPoor
        case "POOR": self = .poor
        case "POOR_TO_FAIR": self = .poorToFair
        case "FAIR": self = .fair
        case "FAIR_TO_GOOD": self = .fairToGood
        case "GOOD": self = .good
        case "EPIC": self = .epic
        default: self = .unknown
        }
    }

    // Colors matching Surfline's rating guide
    var color: Color {
        switch self {
        case .veryPoor: return Color(red: 0.95, green: 0.3, blue: 0.5)   // Pink/Red
        case .poor: return Color(red: 1.0, green: 0.6, blue: 0.0)        // Orange
        case .poorToFair: return Color(red: 0.95, green: 0.8, blue: 0.0) // Yellow
        case .fair: return Color(red: 0.2, green: 0.85, blue: 0.25)       // Green
        case .fairToGood: return Color(red: 0.25, green: 0.57, blue: 0.45) // #409173
        case .good: return Color(red: 0.0, green: 0.7, blue: 0.7)        // Cyan/Teal
        case .epic: return Color(red: 0.0, green: 0.6, blue: 0.8)        // Blue/Cyan
        case .unknown: return .secondary
        }
    }

    var dotCount: Int {
        switch self {
        case .veryPoor: return 1
        case .poor: return 2
        case .poorToFair: return 3
        case .fair: return 4
        case .fairToGood: return 5
        case .good: return 6
        case .epic: return 6
        case .unknown: return 0
        }
    }
}

// MARK: - Tide Event (High/Low)

struct TideEvent: Identifiable {
    let id: Int  // timestamp
    let time: Date
    let type: String  // "HIGH" or "LOW"
    let height: Double

    var timeDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter.string(from: time).lowercased()
    }

    var heightDisplay: String {
        String(format: "%.1fft", height)
    }

    var shortDisplay: String {
        let prefix = type == "HIGH" ? "H" : "L"
        return "\(prefix) \(timeDisplay)"
    }
}

// MARK: - Period Forecast (AM/Noon/PM)

struct PeriodForecast {
    let label: String  // "AM", "Noon", "PM"
    let waveMin: Double?
    let waveMax: Double?
    let rating: SurfRating
    let swellHeight: Double?
    let swellPeriod: Int?
    let swellDirection: Double?  // degrees
    let windSpeed: Double?
    let windGust: Double?
    let windDirection: Double?
    let windDirectionType: String?  // "Offshore", "Onshore", etc.

    var waveDisplay: String {
        guard let min = waveMin, let max = waveMax else { return "—" }
        if min == max || max - min < 0.5 {
            return "\(Int(round(min)))ft"
        }
        return "\(Int(round(min)))-\(Int(round(max)))ft"
    }

    var swellDisplay: String? {
        guard let height = swellHeight, let period = swellPeriod else { return nil }
        return String(format: "%.1fft %ds", height, period)
    }

    var windDisplay: String? {
        guard let speed = windSpeed else { return nil }
        let speedInt = Int(round(speed))
        if let gust = windGust, abs(gust - speed) >= 1 {
            return "\(speedInt)-\(Int(round(gust)))"
        }
        return "\(speedInt)"
    }

    var windArrow: String {
        guard let dir = windDirection else { return "" }
        // Wind direction is where wind comes FROM, arrow shows direction it blows
        let arrows = ["↓", "↙", "←", "↖", "↑", "↗", "→", "↘"]
        let index = Int(round(dir / 45.0)) % 8
        return arrows[index]
    }

    var directionArrow: String {
        guard let dir = swellDirection else { return "" }
        // Convert degrees to arrow (direction swell is traveling toward)
        let arrows = ["↓", "↙", "←", "↖", "↑", "↗", "→", "↘"]
        let index = (Int(round(dir / 45.0)) - 1 + 8) % 8
        return arrows[index]
    }
}

// MARK: - Day Forecast (for extended forecast view)

struct DayForecast: Identifiable {
    let id: Date
    let date: Date
    let waveMin: Double?
    let waveMax: Double?
    let wavePlus: Bool
    let ratingAM: SurfRating
    let ratingNoon: SurfRating
    let ratingPM: SurfRating
    let swellDirection: Double?

    var dateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE M/d"
            return formatter.string(from: date)
        }
    }

    var waveDisplay: String {
        guard let min = waveMin, let max = waveMax else { return "—" }
        let plus = wavePlus ? "+" : ""
        if min == max || max - min < 0.5 {
            return "\(Int(round(min)))ft\(plus)"
        }
        return "\(Int(round(min)))-\(Int(round(max)))ft\(plus)"
    }

    var directionArrows: String {
        guard let dir = swellDirection else { return "" }
        let arrows = ["↓", "↙", "←", "↖", "↑", "↗", "→", "↘"]
        let index = (Int(round(dir / 45.0)) - 1 + 8) % 8
        return arrows[index]
    }

    var bestRating: SurfRating {
        [ratingAM, ratingNoon, ratingPM].max() ?? .unknown
    }

    var isGoodDay: Bool {
        bestRating >= .good
    }
}

// MARK: - Combined Spot Forecast

struct SpotForecast: Identifiable {
    let id: String  // spotId
    let spotName: String
    let periods: [PeriodForecast]  // AM, Noon, PM for today
    let extendedForecast: [DayForecast]  // Multi-day forecast
    let tideEvents: [TideEvent]  // High/low tides for today
    let timestamp: Date

    init(id: String, spotName: String, periods: [PeriodForecast], extendedForecast: [DayForecast] = [], tideEvents: [TideEvent] = [], timestamp: Date) {
        self.id = id
        self.spotName = spotName
        self.periods = periods
        self.extendedForecast = extendedForecast
        self.tideEvents = tideEvents
        self.timestamp = timestamp
    }

    // Convenience for best rating of the day
    var bestRating: SurfRating {
        periods.map(\.rating).max() ?? .unknown
    }

    // Current period based on time of day
    var currentPeriod: PeriodForecast? {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 11 {
            return periods.first { $0.label == "AM" }
        } else if hour < 17 {
            return periods.first { $0.label == "Noon" }
        } else {
            return periods.first { $0.label == "PM" }
        }
    }
}
