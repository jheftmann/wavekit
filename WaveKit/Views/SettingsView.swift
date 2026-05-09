import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var authManager: AuthManager
    @ObservedObject var favoritesStore: FavoritesStore
    @ObservedObject private var calendarManager = CalendarManager.shared
    @State private var draggingSpotId: String?

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
                    VStack(spacing: 0) {
                        ForEach(favoritesStore.spots) { spot in
                            HStack(spacing: 8) {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                                Text(spot.name)
                                Spacer()
                                calendarButton(for: spot)
                                trashButton(for: spot)
                            }
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onDrag {
                                draggingSpotId = spot.id
                                return NSItemProvider(object: spot.id as NSString)
                            }
                            .onDrop(of: [UTType.utf8PlainText], delegate: SpotDropDelegate(
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
            .padding()

            Spacer()

            // Footer
            Divider()
            HStack {
                Text("WaveKit v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
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
    }

    @ViewBuilder
    private func calendarButton(for spot: Spot) -> some View {
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
    private func trashButton(for spot: Spot) -> some View {
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
}

struct SpotDropDelegate: DropDelegate {
    let targetSpot: Spot
    let store: FavoritesStore
    @Binding var draggingSpotId: String?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let draggingId = draggingSpotId,
              draggingId != targetSpot.id,
              let from = store.spots.firstIndex(where: { $0.id == draggingId }),
              let to = store.spots.firstIndex(where: { $0.id == targetSpot.id })
        else { return }

        store.moveSpot(from: IndexSet(integer: from), to: to > from ? to + 1 : to)
    }

    func validateDrop(info: DropInfo) -> Bool { true }

    func performDrop(info: DropInfo) -> Bool {
        draggingSpotId = nil
        return true
    }
}

#Preview {
    SettingsView(
        authManager: AuthManager.shared,
        favoritesStore: FavoritesStore.shared
    )
}
