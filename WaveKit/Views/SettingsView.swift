import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var authManager: AuthManager
    @ObservedObject var favoritesStore: FavoritesStore
    @State private var calEnabledIds: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            // Account Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Account")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if authManager.isLoggedIn {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("Signed In")
                                .font(.body)
                            if let username = authManager.username {
                                Text(username)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button("Sign Out") {
                            authManager.logout()
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .foregroundColor(.secondary)
                        Text("Not signed in")
                        Spacer()
                        Button("Sign In") {
                            openWindow(id: "login")
                        }
                    }
                }
            }
            .padding()

            Divider()

            // Spots Section
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
                    .buttonStyle(.borderless)
                }

                if favoritesStore.spots.isEmpty {
                    Text("No spots added yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    List {
                        ForEach(favoritesStore.spots) { spot in
                            HStack(spacing: 8) {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                                Text(spot.name)
                                Spacer()
                                Button {
                                    if calEnabledIds.contains(spot.id) {
                                        CalendarManager.shared.disableSpot(spot.id)
                                        calEnabledIds.remove(spot.id)
                                    } else {
                                        calEnabledIds.insert(spot.id)
                                        Task {
                                            await CalendarManager.shared.enableSpot(
                                                spot.id,
                                                name: spot.name,
                                                forecasts: SurflineAPI.shared.forecasts
                                            )
                                        }
                                    }
                                } label: {
                                    Image(systemName: calEnabledIds.contains(spot.id) ? "calendar.badge.checkmark" : "calendar.badge.plus")
                                        .foregroundColor(calEnabledIds.contains(spot.id) ? .blue : .secondary)
                                }
                                .buttonStyle(.borderless)
                                Button {
                                    favoritesStore.removeSpot(spot)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .onMove { from, to in
                            favoritesStore.moveSpot(from: from, to: to)
                        }
                    }
                    .frame(height: min(CGFloat(favoritesStore.spots.count) * 32 + 20, 200))
                }
            }
            .padding()

            Spacer()

            // Footer
            Divider()
            HStack {
                Text("WaveKit v1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Quit App") {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundColor(.red)
            }
            .padding()
        }
        .frame(width: 350, height: 450)
        .onAppear {
            calEnabledIds = CalendarManager.shared.enabledSpotIds
        }
    }
}

#Preview {
    SettingsView(
        authManager: AuthManager.shared,
        favoritesStore: FavoritesStore.shared
    )
}
