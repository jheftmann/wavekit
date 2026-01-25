import SwiftUI

struct SpotRowView: View {
    let spot: Spot
    let forecast: SpotForecast?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Spot name + tide
            HStack {
                Text(forecast?.spotName ?? spot.name)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)
                Spacer()
                if let forecast = forecast, !forecast.tideEvents.isEmpty {
                    TideCompactView(events: forecast.tideEvents)
                }
            }
            .frame(height: 18)

            if let forecast = forecast {
                HStack(spacing: 8) {
                    ForEach(forecast.periods, id: \.label) { period in
                        VStack(alignment: .leading, spacing: 2) {
                            // Header: label + rating
                            HStack(spacing: 4) {
                                Text(period.label)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 32, alignment: .leading)
                                RatingBarView(rating: period.rating)
                            }

                            // Wave + Swell inline
                            HStack(spacing: 4) {
                                Text(period.waveDisplay)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                if let h = period.swellHeight, let p = period.swellPeriod {
                                    Text(String(format: "%.1f/%ds", h, p))
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                            }

                            // Wind
                            if let w = period.windDisplay {
                                HStack(spacing: 2) {
                                    Text(w)
                                        .font(.system(size: 10))
                                    Text("kts")
                                        .font(.system(size: 8))
                                    Text(period.windArrow)
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(height: 85, alignment: .top)
        .contentShape(Rectangle())
    }
}

struct TideCompactView: View {
    let events: [TideEvent]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(events) { event in
                HStack(spacing: 1) {
                    Text(event.type == "HIGH" ? "▲" : "▼")
                        .font(.system(size: 6))
                        .foregroundColor(event.type == "HIGH" ? .blue : .secondary)
                    Text(event.timeDisplay)
                        .font(.system(size: 8))
                }
                .foregroundColor(.secondary)
            }
        }
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
                                   swellHeight: 1.7, swellPeriod: 10, swellDirection: 190,
                                   windSpeed: 5, windGust: 8, windDirection: 45, windDirectionType: "Offshore"),
                    PeriodForecast(label: "Noon", waveMin: 2, waveMax: 3, rating: .fair,
                                   swellHeight: 1.7, swellPeriod: 9, swellDirection: 190,
                                   windSpeed: 8, windGust: 12, windDirection: 270, windDirectionType: "Onshore"),
                    PeriodForecast(label: "PM", waveMin: 2, waveMax: 3, rating: .fairToGood,
                                   swellHeight: 1.7, swellPeriod: 9, swellDirection: 190,
                                   windSpeed: 3, windGust: 5, windDirection: 180, windDirectionType: "Cross-shore")
                ],
                tideEvents: [
                    TideEvent(id: 1, time: Date(), type: "HIGH", height: 4.5),
                    TideEvent(id: 2, time: Date().addingTimeInterval(6*3600), type: "LOW", height: 1.2)
                ],
                timestamp: Date()
            )
        )

        Divider()

        SpotRowView(
            spot: Spot(id: "2", name: "Malibu", slug: "malibu"),
            forecast: nil
        )
    }
    .frame(width: 320)
}
