import Foundation
import Combine

@MainActor
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    @Published private(set) var spots: [Spot] = []

    private let userDefaultsKey = "surfline_favorite_spots"

    private init() {
        loadSpots()
    }

    private func loadSpots() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([Spot].self, from: data) else {
            spots = []
            return
        }
        spots = decoded
    }

    private func saveSpots() {
        guard let data = try? JSONEncoder().encode(spots) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    func addSpot(_ spot: Spot) {
        guard !spots.contains(where: { $0.id == spot.id }) else { return }
        spots.append(spot)
        saveSpots()
    }

    func removeSpot(_ spot: Spot) {
        spots.removeAll { $0.id == spot.id }
        saveSpots()
    }

    func removeSpot(at indexSet: IndexSet) {
        spots.remove(atOffsets: indexSet)
        saveSpots()
    }

    func moveSpot(from source: IndexSet, to destination: Int) {
        spots.move(fromOffsets: source, toOffset: destination)
        saveSpots()
    }

    func addSpotFromURL(_ urlString: String) -> Result<Spot, AddSpotError> {
        guard let parsed = Spot.fromURL(urlString) else {
            return .failure(.invalidURL)
        }

        if spots.contains(where: { $0.id == parsed.spotId }) {
            return .failure(.alreadyExists)
        }

        // Create spot with slug as temporary name (will be updated when forecast loads)
        let name = parsed.slug?.replacingOccurrences(of: "-", with: " ").capitalized ?? "Unknown Spot"

        let spot = Spot(
            id: parsed.spotId,
            name: name,
            slug: parsed.slug
        )

        addSpot(spot)
        return .success(spot)
    }

    func updateSpotName(spotId: String, name: String) {
        guard let index = spots.firstIndex(where: { $0.id == spotId }) else { return }
        let oldSpot = spots[index]
        var newSpot = Spot(id: oldSpot.id, name: name, slug: oldSpot.slug)
        newSpot.latitude = oldSpot.latitude
        newSpot.longitude = oldSpot.longitude
        spots[index] = newSpot
        saveSpots()
    }

    func updateSpotCoordinates(spotId: String, latitude: Double, longitude: Double) {
        guard let index = spots.firstIndex(where: { $0.id == spotId }) else { return }
        let oldSpot = spots[index]
        var newSpot = Spot(id: oldSpot.id, name: oldSpot.name, slug: oldSpot.slug)
        newSpot.latitude = latitude
        newSpot.longitude = longitude
        spots[index] = newSpot
        saveSpots()
    }

    func sortByDistance(from locationManager: LocationManager) {
        spots.sort { spot1, spot2 in
            let distance1 = locationManager.distance(to: spot1) ?? .greatestFiniteMagnitude
            let distance2 = locationManager.distance(to: spot2) ?? .greatestFiniteMagnitude
            return distance1 < distance2
        }
        saveSpots()
    }

    enum AddSpotError: LocalizedError {
        case invalidURL
        case alreadyExists

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid Surfline URL. Please paste a surf report URL."
            case .alreadyExists:
                return "This spot is already in your favorites."
            }
        }
    }
}
