import Foundation
import Combine

enum APIError: LocalizedError {
    case networkError(Error)
    case decodingError(Error)
    case unauthorized
    case spotNotFound
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError:
            return "Failed to parse response"
        case .unauthorized:
            return "Please log in for full forecast data"
        case .spotNotFound:
            return "Spot not found"
        case .rateLimited:
            return "Too many requests. Please wait."
        }
    }
}

@MainActor
final class SurflineAPI: ObservableObject {
    static let shared = SurflineAPI()

    @Published private(set) var forecasts: [String: SpotForecast] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: Error?
    @Published private(set) var lastUpdated: Date?

    private let authManager = AuthManager.shared
    private let baseURL = "https://services.surfline.com/kbyg/spots/forecasts"

    private var refreshTask: Task<Void, Never>?

    private init() {}

    func fetchForecasts(for spots: [Spot]) async {
        guard !spots.isEmpty else {
            forecasts = [:]
            return
        }

        isLoading = true
        lastError = nil

        // Fetch all spots concurrently
        await withTaskGroup(of: (String, SpotForecast?).self) { group in
            for spot in spots {
                group.addTask {
                    let forecast = await self.fetchForecast(for: spot)
                    return (spot.id, forecast)
                }
            }

            var results: [String: SpotForecast] = [:]
            for await (spotId, forecast) in group {
                if let forecast = forecast {
                    results[spotId] = forecast
                }
            }

            forecasts = results
        }

        isLoading = false
        lastUpdated = Date()
    }

    private func fetchForecast(for spot: Spot) async -> SpotForecast? {
        // Fetch wave and rating data in parallel (extended days if logged in)
        let days = authManager.isLoggedIn ? 16 : 1
        async let waveTask = fetchWave(spotId: spot.id, days: days)
        async let ratingTask = fetchRating(spotId: spot.id, days: days)

        let (wave, rating) = await (waveTask, ratingTask)

        let spotName = wave?.associated?.location?.name ?? spot.name

        // Update spot name if we got a better one from API
        if spotName != spot.name {
            FavoritesStore.shared.updateSpotName(spotId: spot.id, name: spotName)
        }

        // Build period forecasts for AM (6am), Noon (12pm), PM (6pm)
        let periods = buildPeriodForecasts(wave: wave, rating: rating)

        // Build extended forecast (daily)
        let extendedForecast = buildExtendedForecast(wave: wave, rating: rating)

        guard !periods.isEmpty else { return nil }

        return SpotForecast(
            id: spot.id,
            spotName: spotName,
            periods: periods,
            extendedForecast: extendedForecast,
            timestamp: Date()
        )
    }

    private func buildPeriodForecasts(wave: WaveForecastResponse?, rating: RatingForecastResponse?) -> [PeriodForecast] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Target hours: 6 (AM), 12 (Noon), 18 (PM)
        let targetHours = [(6, "AM"), (12, "Noon"), (18, "PM")]

        var periods: [PeriodForecast] = []

        for (hour, label) in targetHours {
            guard let targetDate = calendar.date(byAdding: .hour, value: hour, to: today) else { continue }
            let targetTimestamp = Int(targetDate.timeIntervalSince1970)

            // Find closest wave entry
            let waveEntry = wave?.data?.wave?.min(by: { entry1, entry2 in
                abs(entry1.timestamp - targetTimestamp) < abs(entry2.timestamp - targetTimestamp)
            })

            // Find closest rating entry
            let ratingEntry = rating?.data?.rating?.min(by: { entry1, entry2 in
                abs(entry1.timestamp - targetTimestamp) < abs(entry2.timestamp - targetTimestamp)
            })

            // Get primary swell (first in array)
            let primarySwell = waveEntry?.swells?.first

            let period = PeriodForecast(
                label: label,
                waveMin: waveEntry?.surf?.min,
                waveMax: waveEntry?.surf?.max,
                rating: SurfRating(from: ratingEntry?.rating?.key),
                swellHeight: primarySwell?.height,
                swellPeriod: primarySwell?.period,
                swellDirection: primarySwell?.direction
            )

            periods.append(period)
        }

        return periods
    }

    private func buildExtendedForecast(wave: WaveForecastResponse?, rating: RatingForecastResponse?) -> [DayForecast] {
        let calendar = Calendar.current

        // Group wave data by day
        var dayData: [Date: (waves: [WaveEntry], ratings: [RatingEntry])] = [:]

        // Process wave entries
        if let waveEntries = wave?.data?.wave {
            for entry in waveEntries {
                let date = Date(timeIntervalSince1970: TimeInterval(entry.timestamp))
                let dayStart = calendar.startOfDay(for: date)
                if dayData[dayStart] == nil {
                    dayData[dayStart] = (waves: [], ratings: [])
                }
                dayData[dayStart]?.waves.append(entry)
            }
        }

        // Process rating entries
        if let ratingEntries = rating?.data?.rating {
            for entry in ratingEntries {
                let date = Date(timeIntervalSince1970: TimeInterval(entry.timestamp))
                let dayStart = calendar.startOfDay(for: date)
                if dayData[dayStart] == nil {
                    dayData[dayStart] = (waves: [], ratings: [])
                }
                dayData[dayStart]?.ratings.append(entry)
            }
        }

        // Build daily forecasts
        var forecasts: [DayForecast] = []
        for (dayStart, data) in dayData.sorted(by: { $0.key < $1.key }) {
            // Get noon entry for representative values (or average)
            let noonTime = calendar.date(byAdding: .hour, value: 12, to: dayStart)!
            let noonTimestamp = Int(noonTime.timeIntervalSince1970)

            let closestWave = data.waves.min(by: {
                abs($0.timestamp - noonTimestamp) < abs($1.timestamp - noonTimestamp)
            })

            // Get min/max for the day
            let dayWaveMin = data.waves.compactMap { $0.surf?.min }.min()
            let dayWaveMax = data.waves.compactMap { $0.surf?.max }.max()

            // Get ratings for AM (6am), Noon (12pm), PM (6pm)
            func ratingAt(hour: Int) -> SurfRating {
                guard let targetTime = calendar.date(byAdding: .hour, value: hour, to: dayStart) else {
                    return .unknown
                }
                let targetTimestamp = Int(targetTime.timeIntervalSince1970)
                let closest = data.ratings.min(by: {
                    abs($0.timestamp - targetTimestamp) < abs($1.timestamp - targetTimestamp)
                })
                return SurfRating(from: closest?.rating?.key)
            }

            let forecast = DayForecast(
                id: dayStart,
                date: dayStart,
                waveMin: dayWaveMin,
                waveMax: dayWaveMax,
                ratingAM: ratingAt(hour: 6),
                ratingNoon: ratingAt(hour: 12),
                ratingPM: ratingAt(hour: 18),
                swellDirection: closestWave?.swells?.first?.direction
            )

            forecasts.append(forecast)
        }

        return forecasts
    }

    private func fetchWave(spotId: String, days: Int = 1) async -> WaveForecastResponse? {
        await fetch(
            endpoint: "wave",
            spotId: spotId,
            days: days,
            responseType: WaveForecastResponse.self
        )
    }

    private func fetchRating(spotId: String, days: Int = 1) async -> RatingForecastResponse? {
        await fetch(
            endpoint: "rating",
            spotId: spotId,
            days: days,
            responseType: RatingForecastResponse.self
        )
    }

    private func fetch<T: Decodable>(
        endpoint: String,
        spotId: String,
        days: Int = 1,
        responseType: T.Type
    ) async -> T? {
        let url = URL(string: "\(baseURL)/\(endpoint)?spotId=\(spotId)&days=\(days)")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Try to add auth token if available
        if let token = try? await authManager.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return nil
            }

            if httpResponse.statusCode == 401 {
                lastError = APIError.unauthorized
                return nil
            }

            if httpResponse.statusCode == 429 {
                lastError = APIError.rateLimited
                return nil
            }

            guard httpResponse.statusCode == 200 else {
                return nil
            }

            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("API Error for \(endpoint): \(error)")
            return nil
        }
    }

    // Auto-refresh setup
    func startAutoRefresh(interval: TimeInterval = 1800) { // 30 minutes
        stopAutoRefresh()

        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if !Task.isCancelled {
                    await fetchForecasts(for: FavoritesStore.shared.spots)
                }
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}
