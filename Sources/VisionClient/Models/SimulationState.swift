import Foundation
import Network
import Combine
import SwiftUI

class SimulationState: ObservableObject {
    @Published var trains: [Train] = []
    @Published var isRunning: Bool = false
    @Published var isEmergencyState: Bool = false
    @Published var isConnected: Bool = false
    @Published var lastUpdate: Date?
    @Published var activeServiceProvisoire: ServiceProvisoire? = nil
    
    @Published var trackSegments: [TrackSegment] = []
    @Published var stations: [Station] = []
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.cbtc.visionNetwork")
    
    init() {
        setupTrack()
        connect()
    }
    
    private func setupTrack() {
        var segments: [TrackSegment] = []
        let segmentCount = 10
        let segmentLength: CGFloat = 100.0
        let radius: CGFloat = (CGFloat(segmentCount) * segmentLength) / (2 * .pi)
        
        for i in 0..<segmentCount {
            let angleStart = (CGFloat(i) / CGFloat(segmentCount)) * 2 * .pi
            let angleEnd = (CGFloat(i + 1) / CGFloat(segmentCount)) * 2 * .pi
            
            let x1 = radius * cos(angleStart)
            let z1 = radius * sin(angleStart)
            let x2 = radius * cos(angleEnd)
            let z2 = radius * sin(angleEnd)
            
            let idStr = String(format: "00000000-0000-0000-0000-%012X", i + 1)
            let id = UUID(uuidString: idStr)!
            let segment = TrackSegment(
                id: id,
                name: "Canton \(i + 1)",
                length: segmentLength,
                speedLimit: 20.0,
                startPosition: CGFloat(i) * segmentLength,
                startPoint: CGPoint(x: x1, y: z1),
                endPoint: CGPoint(x: x2, y: z2)
            )
            segments.append(segment)
        }
        
        for i in 0..<segmentCount {
            segments[i].nextSegmentId = segments[(i + 1) % segmentCount].id
            segments[i].previousSegmentId = segments[(i - 1 + segmentCount) % segmentCount].id
        }
        self.trackSegments = segments
        
        self.stations = [
            Station(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!, name: "CHU - Eurasanté", position: 50.0, platformSide: .right),
            Station(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!, name: "Gambetta", position: 200.0, platformSide: .right),
            Station(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!, name: "Gare Lille Flandres", position: 350.0, platformSide: .right),
            Station(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A4")!, name: "Fives", position: 550.0, platformSide: .right),
            Station(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A5")!, name: "Pont de Bois", position: 700.0, platformSide: .right),
            Station(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A6")!, name: "4 Cantons", position: 850.0, platformSide: .right)
        ]
    }
    
    func connect(host: String = "127.0.0.1", port: UInt16 = 9090) {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
        connection = NWConnection(to: endpoint, using: .tcp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.receiveData()
                case .failed(let error):
                    print("Connection failed: \(error)")
                    self?.isConnected = false
                case .cancelled:
                    print("Connection cancelled")
                    self?.isConnected = false
                default:
                    break
                }
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
            if let data = data, !data.isEmpty {
                if let str = String(data: data, encoding: .utf8) {
                    let packets = str.split(separator: "\n")
                    for packetStr in packets {
                        if let packetData = packetStr.data(using: .utf8) {
                            do {
                                let decoder = JSONDecoder()
                                decoder.dateDecodingStrategy = .iso8601
                                let telemetry = try decoder.decode(SystemTelemetry.self, from: packetData)
                                DispatchQueue.main.async {
                                    self?.trains = telemetry.trains
                                    self?.isRunning = telemetry.isRunning
                                    self?.isEmergencyState = telemetry.isEmergencyState
                                    self?.lastUpdate = telemetry.timestamp
                                }
                            } catch {
                            }
                        }
                    }
                }
            }
            
            if isComplete {
                self?.disconnect()
            } else if error == nil {
                self?.receiveData()
            } else {
                self?.disconnect()
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
    
    // MARK: - AppCommand Wrappers
    func startSimulation() { send(command: .startSimulation) }
    func stopSimulation() { send(command: .stopSimulation) }
    func emergencyStop() { send(command: .emergencyStop) }
    func resetSimulation() { send(command: .resetSimulation) }
    func addTrain() { send(command: .addTrain) }
    func removeTrain(id: UUID) { send(command: .removeTrain(id: id)) }
    func setTrainMode(id: UUID, mode: Train.TrainMode) { send(command: .setTrainMode(trainId: id, mode: mode)) }
    func setManualSpeed(id: UUID, speed: Double) { send(command: .setManualSpeed(trainId: id, speed: speed)) }
    func executeTrainCommand(id: UUID, command: String) { send(command: .executeTrainCommand(trainId: id, command: command)) }
}
