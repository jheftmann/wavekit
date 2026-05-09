import SwiftUI
import UniformTypeIdentifiers

enum ViewMode: String, CaseIterable {
    case forecast = "Forecast"
    case today = "Today"
}

/// NSSegmentedControl wrapper that honours an explicit pixel width via setWidth(_:forSegment:).
/// SwiftUI's Picker(.segmented) ignores proposed widths — this bypasses that limitation.
private struct ViewModeSegmentedControl: NSViewRepresentable {
    @Binding var selection: ViewMode
    let width: CGFloat

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl()
        control.segmentCount = ViewMode.allCases.count
        for (i, mode) in ViewMode.allCases.enumerated() {
            control.setLabel(mode.rawValue, forSegment: i)
        }
        control.trackingMode = .selectOne
        control.target = context.coordinator
        control.action = #selector(Coordinator.changed(_:))
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        let segW = width / CGFloat(ViewMode.allCases.count)
        for i in 0..<ViewMode.allCases.count {
            control.setWidth(segW, forSegment: i)
        }
        control.selectedSegment = ViewMode.allCases.firstIndex(of: selection) ?? 0
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject {
        var parent: ViewModeSegmentedControl
        init(_ p: ViewModeSegmentedControl) { parent = p }
        @objc func changed(_ sender: NSSegmentedControl) {
            parent.selection = ViewMode.allCases[sender.selectedSegment]
        }
    }
}

struct MenuBarView: View {
    @ObservedObject var api: SurflineAPI
    @ObservedObject var favoritesStore: FavoritesStore
    @ObservedObject var authManager: AuthManager
    @ObservedObject var locationManager: LocationManager
    @ObservedObject private var calendarManager = CalendarManager.shared

    @Environment(\.openWindow) private var openWindow
    @State private var viewMode: ViewMode = .forecast
    @State private var showingSettings = false
    @State private var draggingSpotId: String?

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 0)
                .onAppear { NSApp.keyWindow?.makeFirstResponder(nil) }

            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(showingSettings ? "Settings" : "WaveKit")
                        .font(.headline)
                    Spacer()
                    Button {
                        showingSettings.toggle()
                    } label: {
                        Label(showingSettings ? "Close" : "Settings",
                              systemImage: showingSettings ? "xmark" : "gear")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .focusEffectDisabled()
                    .help(showingSettings ? "Close Settings" : "Settings")
                }

                if !showingSettings && authManager.isLoggedIn && !favoritesStore.spots.isEmpty {
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

            if showingSettings {
                settingsContentView
            } else {
                if favoritesStore.spots.isEmpty {
                    emptyStateView
                } else {
                    spotListView
                }
                Divider()
                footerView
            }
        }
        .frame(width: 360)
        .task {
            locationManager.requestLocation()
            await api.fetchForecasts(for: favoritesStore.spots)
        }
        .onChange(of: favoritesStore.spots) { _, newSpots in
            Task {
                await api.fetchForecasts(for: newSpots)
            }
        }
    }

    // MARK: - Settings

    private var settingsContentView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    // Account
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Connect your Surfline account to get extended forecasts")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if authManager.isLoggedIn {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Signed in to Surfline")
                                    if let username = authManager.username {
                                        Text(username)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Button("Sign Out") { authManager.logout() }
                            }
                        } else {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.questionmark")
                                    .foregroundColor(.secondary)
                                Text("Not signed in")
                                Spacer()
                                Button("Sign In") { openWindow(id: "login") }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()

                    Divider()

                    // Favorite Spots
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Favorite Spots")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button {
                                openWindow(id: "addspot")
                            } label: {
                                Image(systemName: "plus")
                            }
                        }

                        if favoritesStore.spots.isEmpty {
                            Text("No spots added yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(favoritesStore.spots) { spot in
                                    HStack(spacing: 8) {
                                        Image(systemName: "line.3.horizontal")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 12))
                                        Text(spot.name)
                                        Spacer()
                                        settingsCalendarButton(for: spot)
                                        settingsTrashButton(for: spot)
                                    }
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                                    .opacity(draggingSpotId == spot.id ? 0.4 : 1)
                                    .onDrag {
                                        draggingSpotId = spot.id
                                        return NSItemProvider(object: spot.id as NSString)
                                    }
                                    .onDrop(of: [UTType.text], delegate: SpotDropDelegate(
                                        targetSpot: spot,
                                        store: favoritesStore,
                                        draggingSpotId: $draggingSpotId
                                    ))

                                    if spot.id != favoritesStore.spots.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }

            Divider()

            // Settings footer
            HStack {
                Text("WaveKit v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Quit App") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: CGFloat(maxVisibleRows) * rowHeight + 160) // cap so ScrollView kicks in
    }

    @ViewBuilder
    private func settingsCalendarButton(for spot: Spot) -> some View {
        let isEnabled = calendarManager.enabledSpotIds.contains(spot.id)
        Button {
            if isEnabled {
                calendarManager.disableSpot(spot.id)
            } else {
                Task {
                    await calendarManager.enableSpot(
                        spot.id,
                        name: spot.name,
                        forecasts: SurflineAPI.shared.forecasts
                    )
                }
            }
        } label: {
            Image(systemName: isEnabled ? "calendar.badge.checkmark" : "calendar.badge.plus")
                .foregroundColor(isEnabled ? .accentColor : .secondary)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func settingsTrashButton(for spot: Spot) -> some View {
        Button {
            favoritesStore.removeSpot(spot)
        } label: {
            Image(systemName: "trash")
                .foregroundColor(.red)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
    }

    // MARK: - Main view

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

    // 360 window − 24 h-padding − 8 gap − 56 sort toggle = 272
    private let viewModeToggleWidth: CGFloat = 272

    private var viewModeToggle: some View {
        ViewModeSegmentedControl(selection: $viewMode, width: viewModeToggleWidth)
            .frame(width: viewModeToggleWidth, height: 24)
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
