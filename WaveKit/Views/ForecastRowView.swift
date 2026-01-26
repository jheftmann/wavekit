import SwiftUI

struct ForecastRowView: View {
    let spot: Spot
    let forecast: SpotForecast?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Spot name
            HStack {
                Text(forecast?.spotName ?? spot.name)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)
                Spacer()
            }
            .frame(height: 18)

            // Day columns with horizontal scroll
            if let forecast = forecast, !forecast.extendedForecast.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(forecast.extendedForecast) { day in
                            DayColumnView(day: day)
                                .frame(width: 52, alignment: .leading)
                        }
                    }
                }
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Loading forecast...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(height: 85, alignment: .top)
        .contentShape(Rectangle())
    }
}

struct DayColumnView: View {
    let day: DayForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Date label with star for good days
            HStack(spacing: 2) {
                if day.isGoodDay {
                    Image(systemName: "star.fill")
                        .font(.system(size: 7))
                        .foregroundColor(.yellow)
                }
                Text(day.dateLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            // Rating bar (3 segments: AM, Noon, PM)
            HStack(spacing: 1) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(day.ratingAM.color)
                    .frame(width: 11, height: 4)
                RoundedRectangle(cornerRadius: 1)
                    .fill(day.ratingNoon.color)
                    .frame(width: 11, height: 4)
                RoundedRectangle(cornerRadius: 1)
                    .fill(day.ratingPM.color)
                    .frame(width: 11, height: 4)
            }

            // Wave height
            Text(day.waveDisplay)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .frame(height: 48, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: 0) {
        ForecastRowView(
            spot: Spot(id: "1", name: "Venice Breakwater", slug: "venice-breakwater"),
            forecast: SpotForecast(
                id: "1",
                spotName: "Venice Breakwater",
                periods: [],
                extendedForecast: [
                    DayForecast(id: Date(), date: Date(), waveMin: 2, waveMax: 3, wavePlus: false, ratingAM: .fair, ratingNoon: .fair, ratingPM: .poorToFair, swellDirection: 190, utcOffset: -8),
                    DayForecast(id: Date().addingTimeInterval(86400), date: Date().addingTimeInterval(86400), waveMin: 2, waveMax: 3, wavePlus: false, ratingAM: .fair, ratingNoon: .fairToGood, ratingPM: .fair, swellDirection: 190, utcOffset: -8),
                    DayForecast(id: Date().addingTimeInterval(86400*2), date: Date().addingTimeInterval(86400*2), waveMin: 3, waveMax: 4, wavePlus: false, ratingAM: .good, ratingNoon: .good, ratingPM: .fairToGood, swellDirection: 200, utcOffset: -8),
                    DayForecast(id: Date().addingTimeInterval(86400*3), date: Date().addingTimeInterval(86400*3), waveMin: 3, waveMax: 5, wavePlus: true, ratingAM: .good, ratingNoon: .epic, ratingPM: .good, swellDirection: 210, utcOffset: -8),
                    DayForecast(id: Date().addingTimeInterval(86400*4), date: Date().addingTimeInterval(86400*4), waveMin: 2, waveMax: 4, wavePlus: false, ratingAM: .fairToGood, ratingNoon: .good, ratingPM: .fair, swellDirection: 195, utcOffset: -8),
                    DayForecast(id: Date().addingTimeInterval(86400*5), date: Date().addingTimeInterval(86400*5), waveMin: 2, waveMax: 3, wavePlus: false, ratingAM: .fair, ratingNoon: .fair, ratingPM: .poorToFair, swellDirection: 180, utcOffset: -8),
                ],
                timestamp: Date()
            )
        )
    }
    .frame(width: 320)
}
