import SwiftUI

struct SpotRowView: View {
    let spot: Spot
    let forecast: SpotForecast?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Spot name
            Text(forecast?.spotName ?? spot.name)
                .font(.system(.body, weight: .medium))
                .lineLimit(1)

            if let forecast = forecast {
                // Period grid: AM | Noon | PM
                HStack(spacing: 0) {
                    ForEach(forecast.periods, id: \.label) { period in
                        PeriodColumnView(period: period)
                        if period.label != "PM" {
                            Divider()
                                .frame(height: 32)
                                .padding(.horizontal, 4)
                        }
                    }
                }
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }
}

struct PeriodColumnView: View {
    let period: PeriodForecast

    var body: some View {
        VStack(spacing: 2) {
            // Time label
            Text(period.label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)

            // Rating bar
            RatingBarView(rating: period.rating)

            // Wave height
            Text(period.waveDisplay)
                .font(.system(size: 13, weight: .semibold, design: .rounded))

            // Swell info (compact)
            if let height = period.swellHeight, let periodSec = period.swellPeriod {
                HStack(spacing: 2) {
                    Text(String(format: "%.1f", height))
                        .font(.system(size: 9))
                    Text("\(periodSec)s")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(period.directionArrow)
                        .font(.system(size: 10))
                }
                .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct RatingBarView: View {
    let rating: SurfRating

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(rating.color)
            .frame(width: 33, height: 4)
    }
}

#Preview {
    VStack(spacing: 0) {
        SpotRowView(
            spot: Spot(id: "1", name: "Venice Breakwater", slug: "venice-breakwater"),
            forecast: SpotForecast(
                id: "1",
                spotName: "Venice Breakwater",
                periods: [
                    PeriodForecast(label: "AM", waveMin: 2, waveMax: 3, rating: .good,
                                   swellHeight: 1.7, swellPeriod: 10, swellDirection: 190),
                    PeriodForecast(label: "Noon", waveMin: 2, waveMax: 3, rating: .fair,
                                   swellHeight: 1.7, swellPeriod: 9, swellDirection: 190),
                    PeriodForecast(label: "PM", waveMin: 2, waveMax: 3, rating: .fairToGood,
                                   swellHeight: 1.7, swellPeriod: 9, swellDirection: 190)
                ],
                timestamp: Date()
            )
        )

        Divider()

        SpotRowView(
            spot: Spot(id: "2", name: "El Porto", slug: "el-porto"),
            forecast: SpotForecast(
                id: "2",
                spotName: "El Porto",
                periods: [
                    PeriodForecast(label: "AM", waveMin: 3, waveMax: 5, rating: .epic,
                                   swellHeight: 2.1, swellPeriod: 14, swellDirection: 270),
                    PeriodForecast(label: "Noon", waveMin: 3, waveMax: 4, rating: .good,
                                   swellHeight: 2.0, swellPeriod: 13, swellDirection: 270),
                    PeriodForecast(label: "PM", waveMin: 2, waveMax: 3, rating: .fair,
                                   swellHeight: 1.8, swellPeriod: 12, swellDirection: 265)
                ],
                timestamp: Date()
            )
        )

        Divider()

        SpotRowView(
            spot: Spot(id: "3", name: "Malibu", slug: "malibu"),
            forecast: nil
        )
    }
    .frame(width: 320)
}
