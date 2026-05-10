import Foundation
import Network

class TerminalNetworkService {
    static let shared = TerminalNetworkService()
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.cbtc.terminalNetwork")
    
    var onTelemetryReceived: ((SystemTelemetry) -> Void)?
    var onConnectionStateChanged: ((Bool) -> Void)?
    
    var isConnected: Bool = false {
        didSet { onConnectionStateChanged?(isConnected) }
    }
    
    private init() {}
    
    func connect(host: String = "localhost", port: UInt16 = 9090) {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
        connection = NWConnection(to: endpoint, using: .tcp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isConnected = true
                self?.receiveData()
            case .failed(_):
                self?.isConnected = false
            case .cancelled:
                self?.isConnected = false
            default: break
            }
        }
        
        connection?.start(queue: queue)
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
    }
    
    private func receiveData() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
            if let data = data, !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                let packets = str.split(separator: "\n")
                for packetStr in packets {
                    if let packetData = packetStr.data(using: .utf8) {
                        do {
                            let decoder = JSONDecoder()
                            decoder.dateDecodingStrategy = .iso8601
                            let telemetry = try decoder.decode(SystemTelemetry.self, from: packetData)
                            self?.onTelemetryReceived?(telemetry)
                        } catch {
                            // Silently ignore decode errors in TUI to avoid layout corruption
                        }
                    }
                }
            }
            if isComplete || error != nil {
                self?.disconnect()
            } else {
                self?.receiveData()
            }
        }
    }
    
    func send(command: AppCommand) {
        guard isConnected, let connection = connection else { return }
        do {
            let encoder = JSONEncoder()
            var data = try encoder.encode(command)
            data.append(contentsOf: "\n".data(using: .utf8)!)
            connection.send(content: data, completion: .contentProcessed({ _ in }))
        } catch {}
    }
}
