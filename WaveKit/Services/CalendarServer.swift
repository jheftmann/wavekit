import Foundation
import Network

final class CalendarServer {
    static let shared = CalendarServer()

    let port: UInt16 = 8765

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "wavekit.calendarserver", qos: .background)
    private let lock = NSLock()
    private var _forecasts: [String: SpotForecast] = [:]

    private init() {}

    func start() {
        guard listener == nil else { return }

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        guard let nwPort = NWEndpoint.Port(rawValue: port),
              let listener = try? NWListener(using: params, on: nwPort) else {
            print("CalendarServer: failed to create listener on port \(port)")
            return
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: queue)
        self.listener = listener
        print("CalendarServer: listening on port \(port)")
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    func updateForecasts(_ forecasts: [String: SpotForecast]) {
        lock.lock()
        _forecasts = forecasts
        lock.unlock()
    }

    // MARK: - Connection Handling

    private func handle(_ connection: NWConnection) {
        NSLog("CalendarServer: new connection from \(connection.endpoint)")
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            if let error { NSLog("CalendarServer: receive error: \(error)") }
            guard let self, let data, !data.isEmpty else {
                NSLog("CalendarServer: empty/nil data, isComplete=\(isComplete), cancelling")
                connection.cancel()
                return
            }

            let rawHead = data.prefix(200)
            NSLog("CalendarServer: received \(data.count) bytes, head: \(String(bytes: rawHead, encoding: .utf8) ?? rawHead.map { String(format: "%02x", $0) }.joined())")

            let request = String(data: data, encoding: .utf8) ?? ""
            let path = self.parsePath(from: request)
            NSLog("CalendarServer: path=\(path)")
            let responseData = self.responseData(for: path)

            connection.send(content: responseData, completion: .contentProcessed { err in
                if let err { NSLog("CalendarServer: send error: \(err)") }
                connection.cancel()
            })
        }
    }

    private func parsePath(from request: String) -> String {
        let firstLine = request.components(separatedBy: "\r\n").first
            ?? request.components(separatedBy: "\n").first
            ?? ""
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return "/" }
        return parts[1]
    }

    private func responseData(for path: String) -> Data {
        let (status, contentType, body) = buildResponse(for: path)
        let statusText = status == 200 ? "OK" : "Not Found"
        let bodyBytes = body.utf8.count
        let header = "HTTP/1.1 \(status) \(statusText)\r\n" +
                     "Content-Type: \(contentType)\r\n" +
                     "Content-Length: \(bodyBytes)\r\n" +
                     "Connection: close\r\n\r\n"
        return (header + body).data(using: .utf8) ?? Data()
    }

    private func buildResponse(for path: String) -> (Int, String, String) {
        guard path.hasPrefix("/spot/"), path.hasSuffix(".ics") else {
            return (404, "text/plain", "Not Found")
        }

        let spotId = String(path.dropFirst("/spot/".count).dropLast(".ics".count))
        guard !spotId.isEmpty else {
            return (404, "text/plain", "Not Found")
        }

        lock.lock()
        let forecasts = _forecasts
        lock.unlock()

        let ics = ICSGenerator.generate(for: spotId, using: forecasts)
        return (200, "text/calendar; charset=utf-8", ics)
    }
}
