import Foundation
import Network
import Combine


class ServerNetworkService: ObservableObject {
    static let shared = ServerNetworkService()
    
    @Published var isEnabled: Bool = true {
        didSet {
            if isEnabled {
                startServer()
            } else {
                stopServer()
            }
        }
    }
    @Published var port: UInt16 = 9090
    @Published var connectedClientCount: Int = 0
    
    let commandPublisher = PassthroughSubject<AppCommand, Never>()
    
    private var listener: NWListener?
    private var connectedClients: [NWConnection] = []
    private let queue = DispatchQueue(label: "com.telemetry.service")
    
    private init() {
        startServer()
    }
    
    func startServer() {
        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            
            listener?.stateUpdateHandler = { state in
                print("ServerNetworkService State: \(state)")
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            
            listener?.start(queue: queue)
            print("ServerNetworkService started on port \(port)")
        } catch {
            print("Failed to start server: \(error)")
        }
    }
    
    func stopServer() {
        listener?.cancel()
        listener = nil
        for client in connectedClients {
            client.cancel()
        }
        connectedClients.removeAll()
        updateClientCount()
        print("ServerNetworkService stopped")
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Client connected: \(connection.endpoint)")
                self?.queue.async {
                    self?.connectedClients.append(connection)
                    self?.updateClientCount()
                    self?.receiveData(on: connection)
                }
            case .failed(let error):
                print("Client connection failed: \(error)")
                self?.removeClient(connection)
            case .cancelled:
                print("Client disconnected: \(connection.endpoint)")
                self?.removeClient(connection)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }
    
    private func receiveData(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
            if let data = data, !data.isEmpty {
                // Assuming newline-delimited JSON commands
                if let str = String(data: data, encoding: .utf8) {
                    let commands = str.split(separator: "\n")
                    for cmdStr in commands {
                        if let cmdData = cmdStr.data(using: .utf8) {
                            do {
                                let decoder = JSONDecoder()
                                let command = try decoder.decode(AppCommand.self, from: cmdData)
                                DispatchQueue.main.async {
                                    self?.commandPublisher.send(command)
                                }
                            } catch {
                                print("Failed to decode command: \(error) - Data: \(cmdStr)")
                            }
                        }
                    }
                }
            }
            
            if isComplete {
                self?.removeClient(connection)
            } else if error == nil {
                // Continue receiving
                self?.receiveData(on: connection)
            } else {
                self?.removeClient(connection)
            }
        }
    }
    
    private func removeClient(_ connection: NWConnection) {
        queue.async { [weak self] in
            if let index = self?.connectedClients.firstIndex(where: { $0 === connection }) {
                self?.connectedClients.remove(at: index)
                self?.updateClientCount()
            }
        }
    }
    
    private func updateClientCount() {
        let count = connectedClients.count
        DispatchQueue.main.async {
            self.connectedClientCount = count
        }
    }
    
    func broadcast(telemetry: SystemTelemetry) {
        guard isEnabled else { return }
        
        queue.async { [weak self] in
            guard let self = self, !self.connectedClients.isEmpty else { return }
            
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                var data = try encoder.encode(telemetry)
                data.append(contentsOf: "\n".data(using: .utf8)!)
                
                for client in self.connectedClients {
                    client.send(content: data, completion: .contentProcessed({ [weak self] error in
                        if let error = error {
                            print("Failed to send data to client: \(error)")
                            self?.removeClient(client)
                        }
                    }))
                }
            } catch {
                print("Failed to encode telemetry data: \(error)")
            }
        }
    }
}
