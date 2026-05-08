import SwiftUI

enum ViewMode: String, CaseIterable {
    case forecast = "Forecast"
    case today = "Today"
}

struct MenuBarView: View {
    @ObservedObject var api: SurflineAPI
    @ObservedObject var favoritesStore: FavoritesStore
    @ObservedObject var authManager: AuthManager
    @ObservedObject var locationManager: LocationManager

    @Environment(\.openWindow) private var openWindow
    @State private var viewMode: ViewMode = .forecast

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 0)
                .onAppear { NSApp.keyWindow?.makeFirstResponder(nil) }
            // Header with toggle
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("WaveKit")
                        .font(.headline)
                    Spacer()
                    Button {
                        openWindow(id: "settings")
                    } label: {
                        Label("Settings", systemImage: "gear")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .focusEffectDisabled()
                    .help("Settings")
                }

                // View mode + sort toggles (only show if logged in and has spots)
                if authManager.isLoggedIn && !favoritesStore.spots.isEmpty {
                    HStack(spacing: 8) {
                        viewModeToggle
                        sortToggle
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Spot List
            if favoritesStore.spots.isEmpty {
                emptyStateView
            } else {
                spotListView
            }

            Divider()

            // Footer
            footerView
        }
        .frame(width: 360)
        .task {
            // Request location and fetch forecasts
            locationManager.requestLocation()
            await api.fetchForecasts(for: favoritesStore.spots)
        }
        .onChange(of: favoritesStore.spots) { _, newSpots in
            Task {
                await api.fetchForecasts(for: newSpots)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "water.waves")
                .font(.system(size: 36))
                .foregroundColor(.accentColor)

            VStack(spacing: 6) {
                Text("Welcome to WaveKit")
                    .font(.headline)

                Text("Your surf forecast at a glance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Go to any spot on Surfline.com", systemImage: "1.circle.fill")
                Label("Copy the URL from your browser", systemImage: "2.circle.fill")
                Label("Click + below to add it here", systemImage: "3.circle.fill")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Button("Add Your First Spot") {
                openWindow(id: "addspot")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
    }

    private var displayedSpots: [Spot] {
        if favoritesStore.sortMode == .distance {
            return favoritesStore.spotsSortedByDistance(using: locationManager)
        }
        return favoritesStore.spots
    }

    private var viewModeToggle: some View {
        Picker("View", selection: $viewMode) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var sortToggle: some View {
        Picker("Sort", selection: Binding(
            get: { favoritesStore.sortMode },
            set: { favoritesStore.setSortMode($0) }
        )) {
            Image(systemName: "location.fill").tag(SortMode.distance)
            Image(systemName: "list.bullet").tag(SortMode.manual)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 56)
    }

    private let rowHeight: CGFloat = 85
    private let maxVisibleRows: Int = 5

    private var spotListView: some View {
        let spotCount = displayedSpots.count
        let visibleRows = min(spotCount, maxVisibleRows)
        let listHeight = CGFloat(visibleRows) * rowHeight

        return Group {
            if viewMode == .forecast {
                forecastListView
            } else {
                todayListView
            }
        }
        .frame(height: listHeight)
    }

    private var forecastListView: some View {
        let spots = displayedSpots
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(spots) { spot in
                    Button {
                        openSpotInBrowser(spot)
                    } label: {
                        ForecastRowView(
                            spot: spot,
                            forecast: api.forecasts[spot.id]
                        )
                    }
                    .buttonStyle(.plain)

                    if spot.id != spots.last?.id {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
        }
    }

    private var todayListView: some View {
        let spots = displayedSpots
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(spots) { spot in
                    Button {
                        openSpotInBrowser(spot)
                    } label: {
                        SpotRowView(
                            spot: spot,
                            forecast: api.forecasts[spot.id]
                        )
                    }
                    .buttonStyle(.plain)

                    if spot.id != spots.last?.id {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
        }
    }

    private var footerView: some View {
        HStack {
            // Add spot button
            Button {
                openWindow(id: "addspot")
            } label: {
                Label("Add Spot", systemImage: "plus")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .focusEffectDisabled()
            .help("Add Spot")

            Spacer()

            // Last updated + Refresh button
            Button {
                Task {
                    await api.fetchForecasts(for: favoritesStore.spots)
                }
            } label: {
                HStack(spacing: 4) {
                    if let lastUpdated = api.lastUpdated {
                        Text(shortTimeAgo(lastUpdated))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if api.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .buttonStyle(.borderless)
            .focusEffectDisabled()
            .disabled(api.isLoading)
            .help("Refresh forecasts")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func openSpotInBrowser(_ spot: Spot) {
        NSWorkspace.shared.open(spot.surflineURL)
    }

    private func shortTimeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 {
            return "now"
        } else if seconds < 3600 {
            return "\(seconds / 60)m"
        } else if seconds < 86400 {
            return "\(seconds / 3600)h"
        } else {
            return "\(seconds / 86400)d"
        }
    }
}

#Preview {
    MenuBarView(
        api: SurflineAPI.shared,
        favoritesStore: FavoritesStore.shared,
        authManager: AuthManager.shared,
        locationManager: LocationManager.shared
    )
}
