import Foundation

struct Spot: Identifiable, Codable, Equatable {
    let id: String  // spotId from Surfline
    let name: String
    let slug: String?  // URL-friendly name like "venice-breakwater"

    var surflineURL: URL {
        if let slug = slug {
            return URL(string: "https://www.surfline.com/surf-report/\(slug)/\(id)")!
        }
        return URL(string: "https://www.surfline.com/surf-report/spot/\(id)")!
    }

    static func fromURL(_ urlString: String) -> (spotId: String, slug: String?)? {
        // Parse URLs like:
        // https://www.surfline.com/surf-report/venice-breakwater/590927576a2e4300134fbed8
        // https://www.surfline.com/surf-report/el-porto/5842041f4e65fad6a7708816

        guard let url = URL(string: urlString),
              url.host?.contains("surfline.com") == true else {
            return nil
        }

        let components = url.pathComponents

        // Find "surf-report" in path and extract following components
        if let reportIndex = components.firstIndex(of: "surf-report"),
           components.count > reportIndex + 2 {
            let slug = components[reportIndex + 1]
            let spotId = components[reportIndex + 2]

            // Validate spotId looks like a MongoDB ObjectId (24 hex chars)
            if spotId.count == 24, spotId.allSatisfy({ $0.isHexDigit }) {
                return (spotId, slug)
            }
        }

        return nil
    }
}
