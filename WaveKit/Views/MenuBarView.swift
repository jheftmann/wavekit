import SwiftUI

enum ViewMode: String, CaseIterable {
    case forecast = "Forecast"
    case today = "Today"
}

struct MenuBarView: View {
    @ObservedObject var api: SurflineAPI
    @ObservedObject var favoritesStore: FavoritesStore
    @ObservedObject var authManager: AuthManager

    @Environment(\.openWindow) private var openWindow
    @State private var viewMode: ViewMode = .forecast

    var body: some View {
        VStack(spacing: 0) {
            // Header with toggle
            VStack(spacing: 8) {
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
                    .help("Settings")
                }

                // View mode toggle (only show if logged in and has spots)
                if authManager.isLoggedIn && !favoritesStore.spots.isEmpty {
                    Picker("View", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
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
        .frame(width: 320)
        .task {
            // Initial fetch
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

    private var spotListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(favoritesStore.spots) { spot in
                    Button {
                        openSpotInBrowser(spot)
                    } label: {
                        if viewMode == .forecast {
                            ForecastRowView(
                                spot: spot,
                                forecast: api.forecasts[spot.id]
                            )
                        } else {
                            SpotRowView(
                                spot: spot,
                                forecast: api.forecasts[spot.id]
                            )
                        }
                    }
                    .buttonStyle(.plain)

                    if spot.id != favoritesStore.spots.last?.id {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
        }
        .frame(maxHeight: 400)
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
        authManager: AuthManager.shared
    )
}
