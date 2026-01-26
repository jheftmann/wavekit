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
        // Fetch wave, rating, wind, and tide data in parallel
        let days = authManager.isLoggedIn ? 16 : 1
        async let waveTask = fetchWave(spotId: spot.id, days: days)
        async let ratingTask = fetchRating(spotId: spot.id, days: days)
        async let windTask = fetchWind(spotId: spot.id)
        async let tideTask = fetchTide(spotId: spot.id)

        let (wave, rating, wind, tide) = await (waveTask, ratingTask, windTask, tideTask)

        let spotName = wave?.associated?.location?.name ?? spot.name

        // Update spot name if we got a better one from API
        if spotName != spot.name {
            FavoritesStore.shared.updateSpotName(spotId: spot.id, name: spotName)
        }

        // Update spot coordinates if available
        if let lat = wave?.associated?.location?.lat,
           let lon = wave?.associated?.location?.lon,
           (spot.latitude == nil || spot.longitude == nil) {
            FavoritesStore.shared.updateSpotCoordinates(spotId: spot.id, latitude: lat, longitude: lon)
        }

        // Get spot's timezone offset (default to local if not available)
        let utcOffset = wave?.associated?.utcOffset ?? (TimeZone.current.secondsFromGMT() / 3600)

        // Build period forecasts for AM (6am), Noon (12pm), PM (6pm)
        let periods = buildPeriodForecasts(wave: wave, rating: rating, wind: wind)

        // Build extended forecast (daily)
        let extendedForecast = buildExtendedForecast(wave: wave, rating: rating, utcOffset: utcOffset)

        // Build tide events (high/low only)
        let tideEvents = buildTideEvents(tide: tide)

        guard !periods.isEmpty else { return nil }

        return SpotForecast(
            id: spot.id,
            spotName: spotName,
            periods: periods,
            extendedForecast: extendedForecast,
            tideEvents: tideEvents,
            timestamp: Date()
        )
    }

    private func buildPeriodForecasts(wave: WaveForecastResponse?, rating: RatingForecastResponse?, wind: WindForecastResponse?) -> [PeriodForecast] {
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

            // Find closest wind entry
            let windEntry = wind?.data?.wind?.min(by: { entry1, entry2 in
                abs(entry1.timestamp - targetTimestamp) < abs(entry2.timestamp - targetTimestamp)
            })

            // Get primary swell (largest height, excluding zero values)
            let primarySwell = waveEntry?.swells?
                .filter { ($0.height ?? 0) > 0 }
                .max(by: { ($0.height ?? 0) < ($1.height ?? 0) })

            let period = PeriodForecast(
                label: label,
                waveMin: waveEntry?.surf?.min,
                waveMax: waveEntry?.surf?.max,
                rating: SurfRating(from: ratingEntry?.rating?.key),
                swellHeight: primarySwell?.height,
                swellPeriod: primarySwell?.period,
                swellDirection: primarySwell?.direction,
                windSpeed: windEntry?.speed,
                windGust: windEntry?.gust,
                windDirection: windEntry?.direction,
                windDirectionType: windEntry?.directionType
            )

            periods.append(period)
        }

        return periods
    }

    private func buildTideEvents(tide: TideForecastResponse?) -> [TideEvent] {
        guard let tides = tide?.data?.tides else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        return tides
            .filter { $0.type == "HIGH" || $0.type == "LOW" }
            .filter { entry in
                let date = Date(timeIntervalSince1970: TimeInterval(entry.timestamp))
                return date >= today && date < tomorrow
            }
            .map { entry in
                TideEvent(
                    id: entry.timestamp,
                    time: Date(timeIntervalSince1970: TimeInterval(entry.timestamp)),
                    type: entry.type,
                    height: entry.height
                )
            }
            .sorted { $0.time < $1.time }
    }

    private func buildExtendedForecast(wave: WaveForecastResponse?, rating: RatingForecastResponse?, utcOffset: Int) -> [DayForecast] {
        // Use spot's timezone for grouping data by day
        let spotTimeZone = TimeZone(secondsFromGMT: utcOffset * 3600) ?? .current
        var calendar = Calendar.current
        calendar.timeZone = spotTimeZone

        // Group wave data by day (in spot's timezone)
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

            // Use noon values for wave height (matches Surfline display)
            let waveMin = closestWave?.surf?.min
            let waveMax = closestWave?.surf?.max
            let wavePlus = closestWave?.surf?.plus ?? false

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
                waveMin: waveMin,
                waveMax: waveMax,
                wavePlus: wavePlus,
                ratingAM: ratingAt(hour: 6),
                ratingNoon: ratingAt(hour: 12),
                ratingPM: ratingAt(hour: 18),
                swellDirection: closestWave?.swells?
                    .filter { ($0.height ?? 0) > 0 }
                    .max(by: { ($0.height ?? 0) < ($1.height ?? 0) })?
                    .direction,
                utcOffset: utcOffset
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

    private func fetchWind(spotId: String) async -> WindForecastResponse? {
        await fetch(
            endpoint: "wind",
            spotId: spotId,
            days: 1,
            responseType: WindForecastResponse.self
        )
    }

    private func fetchTide(spotId: String) async -> TideForecastResponse? {
        await fetch(
            endpoint: "tides",
            spotId: spotId,
            days: 1,
            responseType: TideForecastResponse.self
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
