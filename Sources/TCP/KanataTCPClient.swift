import Foundation
import Network

// MARK: - Event parsing

enum KanataEvent: Equatable {
    case layerChange(String)
    case other

    static func parse(from string: String) throws -> KanataEvent {
        guard let data = string.data(using: .utf8) else {
            throw KanataParseError.invalidData
        }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let obj else { throw KanataParseError.invalidJSON }

        if let lc = obj["LayerChange"] as? [String: Any],
           let name = lc["new"] as? String {
            return .layerChange(name)
        }
        return .other
    }

    static func parseBuffer(_ buffer: String) -> [KanataEvent] {
        buffer.split(separator: "\n").compactMap { line in
            try? parse(from: String(line))
        }
    }
}

enum KanataParseError: Error {
    case invalidData
    case invalidJSON
}

// MARK: - TCP Client

protocol KanataTCPClientDelegate: AnyObject {
    func didReceiveEvent(_ event: KanataEvent)
    func didConnect()
    func didDisconnect()
}

final class KanataTCPClient {
    private let host: String
    private let port: UInt16
    private let reconnectInterval: TimeInterval
    private var connection: NWConnection?
    private var buffer = ""
    weak var delegate: KanataTCPClientDelegate?
    private var reconnectTimer: Timer?
    private let queue = DispatchQueue(label: "kanata-tcp")

    init(host: String, port: Int, reconnectInterval: TimeInterval) {
        self.host = host
        self.port = UInt16(port)
        self.reconnectInterval = reconnectInterval
    }

    func start() {
        connect()
    }

    func stop() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        connection?.cancel()
        connection = nil
    }

    private func connect() {
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!
        let conn = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        self.connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                Log.info("Connected to kanata TCP at \(self.host):\(self.port)")
                DispatchQueue.main.async { self.delegate?.didConnect() }
                self.receive(on: conn)
            case .failed(let error):
                Log.error("TCP connection failed: \(error)")
                DispatchQueue.main.async {
                    self.delegate?.didDisconnect()
                    self.scheduleReconnect()
                }
            case .cancelled:
                break
            default:
                break
            }
        }

        conn.start(queue: queue)
    }

    private func receive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, let str = String(data: data, encoding: .utf8) {
                self.buffer += str
                while let newlineIndex = self.buffer.firstIndex(of: "\n") {
                    let line = String(self.buffer[self.buffer.startIndex..<newlineIndex])
                    self.buffer = String(self.buffer[self.buffer.index(after: newlineIndex)...])
                    if let event = try? KanataEvent.parse(from: line) {
                        DispatchQueue.main.async { self.delegate?.didReceiveEvent(event) }
                    }
                }
            }
            if isComplete || error != nil {
                Log.info("TCP connection closed")
                DispatchQueue.main.async {
                    self.delegate?.didDisconnect()
                    self.scheduleReconnect()
                }
                return
            }
            self.receive(on: conn)
        }
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectInterval, repeats: false) { [weak self] _ in
            guard let self else { return }
            Log.info("Reconnecting to kanata TCP...")
            self.connect()
        }
    }
}
