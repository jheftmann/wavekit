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
    let humanRelation: String?
}

struct SwellInfo: Codable {
    let height: Double?
    let period: Int?
    let direction: Double?  // degrees
    let directionMin: Double?
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
    case poor = 1
    case poorToFair = 2
    case fair = 3
    case fairToGood = 4
    case good = 5
    case epic = 6
    case unknown = 0

    static func < (lhs: SurfRating, rhs: SurfRating) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    init(from key: String?) {
        switch key?.uppercased() {
        case "POOR": self = .poor
        case "POOR_TO_FAIR": self = .poorToFair
        case "FAIR": self = .fair
        case "FAIR_TO_GOOD": self = .fairToGood
        case "GOOD": self = .good
        case "EPIC": self = .epic
        default: self = .unknown
        }
    }

    var color: Color {
        switch self {
        case .poor: return .gray
        case .poorToFair: return Color(red: 0.6, green: 0.6, blue: 0.4)
        case .fair: return .yellow
        case .fairToGood: return Color(red: 0.6, green: 0.8, blue: 0.2)
        case .good: return .green
        case .epic: return Color(red: 0.0, green: 0.8, blue: 0.4)
        case .unknown: return .secondary
        }
    }

    var dotCount: Int {
        switch self {
        case .poor: return 1
        case .poorToFair: return 2
        case .fair: return 3
        case .fairToGood: return 4
        case .good: return 5
        case .epic: return 6
        case .unknown: return 0
        }
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

    var waveDisplay: String {
        guard let min = waveMin, let max = waveMax else { return "—" }
        if min == max || max - min < 0.5 {
            return "\(Int(round(min)))"
        }
        return "\(Int(round(min)))-\(Int(round(max)))"
    }

    var swellDisplay: String? {
        guard let height = swellHeight, let period = swellPeriod else { return nil }
        return String(format: "%.1fft %ds", height, period)
    }

    var directionArrow: String {
        guard let dir = swellDirection else { return "" }
        // Convert degrees to arrow (direction swell is coming FROM)
        let arrows = ["↓", "↙", "←", "↖", "↑", "↗", "→", "↘"]
        let index = Int(round(dir / 45.0)) % 8
        return arrows[index]
    }
}

// MARK: - Combined Spot Forecast

struct SpotForecast: Identifiable {
    let id: String  // spotId
    let spotName: String
    let periods: [PeriodForecast]  // AM, Noon, PM
    let timestamp: Date

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
