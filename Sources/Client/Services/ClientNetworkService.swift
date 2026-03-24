import Foundation
import Network
import Combine
import SceneKit

class ClientNetworkService: ObservableObject {
    static let shared = ClientNetworkService()
    
    @Published var trains: [Train] = []
    @Published var isRunning: Bool = false
    @Published var isEmergencyState: Bool = false
    @Published var isConnected: Bool = false
    @Published var lastUpdate: Date?
    
    // We can hold static/local track and stations here for View rendering, 
    // since we removed ClientNetworkService from the client.
    @Published var trackSegments: [TrackSegment] = []
    @Published var stations: [Station] = []
    @Published var isRandomFaultModeEnabled: Bool = false
    
    // UI State for 3D View
    @Published var cameraResetTrigger: Int = 0
    let scene = SCNScene()
    private var cameraNode: SCNNode?
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.cbtc.clientNetwork")
    
    private init() {
        initializeScene()
    }
    
    func connect(host: String = "localhost", port: UInt16 = 9090) {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
        connection = NWConnection(to: endpoint, using: .tcp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    print("Connected to server")
                    self?.receiveData()
                case .failed(let error):
                    self?.isConnected = false
                    print("Connection failed: \(error)")
                    // Optional: Try reconnect
                case .cancelled:
                    self?.isConnected = false
                    print("Connection cancelled")
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
                                    self?.updateScene()
                                }
                            } catch {
                                print("Decode error: \(error)")
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
            
            connection.send(content: data, completion: .contentProcessed({ error in
                if let error = error {
                    print("Send error: \(error)")
                }
            }))
            
            // Optimistic local state update for some commands
            DispatchQueue.main.async {
                switch command {
                case .setRandomFaultMode(let en):
                    self.isRandomFaultModeEnabled = en
                default: break
                }
            }
            
        } catch {
            print("Command encode error: \(error)")
        }
    }
    
    func getSegmentName(for id: UUID?) -> String {
        guard let id = id, let segment = trackSegments.first(where: { $0.id == id }) else { return "Inconnu" }
        return segment.name
    }

    // MARK: - Compatibility Wrappers
    func startSimulation() { send(command: .startSimulation) }
    func stopSimulation() { send(command: .stopSimulation) }
    func emergencyStop() { send(command: .emergencyStop) }
    func toggleEmergencyStop() { send(command: .toggleEmergencyStop) }
    func resetSimulation() { send(command: .resetSimulation) }
    func addTrain() { send(command: .addTrain) }
    func removeTrain(id: UUID) { send(command: .removeTrain(id: id)) }
    func executeCommand(_ command: String, for trainId: UUID) { send(command: .executeTrainCommand(trainId: trainId, command: command)) }
    func resetCamera() { 
        guard let cameraNode = cameraNode else { return }
        cameraNode.position = SCNVector3(x: 0, y: 500, z: 400)
        cameraNode.eulerAngles = SCNVector3(-atan2(500.0, 400.0), 0, 0) // Look down at origin
        cameraResetTrigger += 1
        send(command: .resetCamera) 
    }
    func toggleTrainPhysics(for trainId: UUID, patinage: Bool, enrayage: Bool) { send(command: .toggleTrainPhysics(trainId: trainId, patinage: patinage, enrayage: enrayage)) }
    func cycleTireStatus(for trainId: UUID, at tireIndex: Int) { send(command: .cycleTireStatus(trainId: trainId, tireIndex: tireIndex)) }
    func toggleFault(for trainId: UUID, faultType: FaultType) { send(command: .toggleFault(trainId: trainId, faultType: faultType)) }

    private var trainNodes: [UUID: SCNNode] = [:]

    func initializeScene() {
        setupTrack()
        setupScene()
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
            Station(id: UUID(), name: "CHU - Eurasanté", position: 50.0, platformSide: .right),
            Station(id: UUID(), name: "Gambetta", position: 200.0, platformSide: .right),
            Station(id: UUID(), name: "Gare Lille Flandres", position: 350.0, platformSide: .right),
            Station(id: UUID(), name: "Fives", position: 550.0, platformSide: .right),
            Station(id: UUID(), name: "Pont de Bois", position: 700.0, platformSide: .right),
            Station(id: UUID(), name: "4 Cantons", position: 850.0, platformSide: .right)
        ]
    }
    
    private func setupScene() {
        // Camera
        let cam = SCNNode()
        cam.name = "MainCamera"
        cam.camera = SCNCamera()
        cam.camera?.zFar = 5000 // Increase render distance
        cam.camera?.zNear = 1
        cam.position = SCNVector3(x: 0, y: 500, z: 400) 
        
        // Look at the center of the track
        let lookAtConstraint = SCNLookAtConstraint(target: scene.rootNode)
        lookAtConstraint.isGimbalLockEnabled = true
        cam.constraints = [lookAtConstraint]
        scene.rootNode.addChildNode(cam)
        self.cameraNode = cam
        
        let floor = SCNFloor()
        floor.reflectivity = 0.1
        floor.firstMaterial?.diffuse.contents = NSColor.black
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)
        
        let centerBox = SCNBox(width: 10, height: 10, length: 10, chamferRadius: 0)
        centerBox.firstMaterial?.diffuse.contents = NSColor.yellow
        let centerNode = SCNNode(geometry: centerBox)
        centerNode.position = SCNVector3(0, 5, 0)
        scene.rootNode.addChildNode(centerNode)
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.light?.intensity = 2000
        lightNode.position = SCNVector3(x: 0, y: 500, z: 0)
        scene.rootNode.addChildNode(lightNode)
        
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = NSColor.white
        ambientLightNode.light?.intensity = 1200
        scene.rootNode.addChildNode(ambientLightNode)
        
        for segment in trackSegments { drawSegment(segment) }
        for station in stations { drawStation(station) }
    }
    
    private func updateScene() {
        let segmentCount = trackSegments.count
        guard segmentCount > 0 else { return }
        
        // Ensure all trains have nodes, and remove dead ones
        let currentTrainIds = Set(trains.map { $0.id })
        for (id, node) in trainNodes {
            if !currentTrainIds.contains(id) {
                node.removeFromParentNode()
                trainNodes.removeValue(forKey: id)
            }
        }
        for train in trains {
            if trainNodes[train.id] == nil {
                addTrainNode(for: train)
            }
        }
        
        let segmentLength: CGFloat = 100.0
        let radius: CGFloat = (CGFloat(segmentCount) * segmentLength) / (2 * .pi)
        
        for train in trains {
            guard let node = trainNodes[train.id] else { continue }
            
            let totalLength = CGFloat(segmentCount) * segmentLength
            let progress = train.position / totalLength
            let angle = progress * 2 * .pi
            
            let x = radius * cos(angle)
            let z = radius * sin(angle)
            let rotationAngle = -angle
            
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.1 // Match telemetry interval
            node.position = SCNVector3(x, 2, z)
            node.eulerAngles = SCNVector3(0, rotationAngle, 0)
            
            if train.isLoadSheddingActive {
                node.geometry?.firstMaterial?.diffuse.contents = NSColor.orange
            } else if train.status == .stopped {
                node.geometry?.firstMaterial?.diffuse.contents = NSColor.red
            } else if train.status == .moving {
                node.geometry?.firstMaterial?.diffuse.contents = NSColor.green
            }
            SCNTransaction.commit()
        }
    }
    
    private func drawSegment(_ segment: TrackSegment) {
        let marker = SCNNode(geometry: SCNSphere(radius: 2))
        marker.geometry?.firstMaterial?.diffuse.contents = NSColor.white
        marker.position = SCNVector3(segment.startPoint.x, 0, segment.startPoint.y)
        scene.rootNode.addChildNode(marker)
        
        let p1 = SCNVector3(segment.startPoint.x, 0, segment.startPoint.y)
        let p2 = SCNVector3(segment.endPoint.x, 0, segment.endPoint.y)
        scene.rootNode.addChildNode(buildLine(from: p1, to: p2))
    }
    
    private func buildLine(from: SCNVector3, to: SCNVector3) -> SCNNode {
        let vector = SCNVector3(to.x - from.x, to.y - from.y, to.z - from.z)
        let distance = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        let mid = SCNVector3(x:(from.x + to.x) / 2, y:(from.y + to.y) / 2, z:(from.z + to.z) / 2)
        
        let lineGeometry = SCNCylinder(radius: 0.5, height: CGFloat(distance))
        lineGeometry.firstMaterial?.diffuse.contents = NSColor.gray
        
        let lineNode = SCNNode(geometry: lineGeometry)
        lineNode.position = mid
        lineNode.look(at: to, up: scene.rootNode.worldUp, localFront: lineNode.worldUp)
        return lineNode
    }
    
    private func drawStation(_ station: Station) {
        let segmentCount = trackSegments.count
        let segmentLength: CGFloat = 100.0
        let radius: CGFloat = (CGFloat(segmentCount) * segmentLength) / (2 * .pi)
        
        let totalLength = CGFloat(segmentCount) * segmentLength
        let progress = station.position / totalLength
        let angle = progress * 2 * .pi
        
        let x = radius * cos(angle)
        let z = radius * sin(angle)
        
        let sideMultiplier: CGFloat = (station.platformSide == .left) ? 0.85 : 1.15
        let platformX = x * sideMultiplier
        let platformZ = z * sideMultiplier
        
        let platformGeometry = SCNBox(width: 8, height: 1, length: 20, chamferRadius: 0)
        platformGeometry.firstMaterial?.diffuse.contents = NSColor.darkGray
        
        let node = SCNNode(geometry: platformGeometry)
        node.position = SCNVector3(platformX, 0.5, platformZ)
        node.look(at: SCNVector3(x, 0, z), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, 1))
        
        scene.rootNode.addChildNode(node)
        
        let textGeom = SCNText(string: station.name, extrusionDepth: 0.5)
        textGeom.font = NSFont(name: "Helvetica-Bold", size: 3)
        textGeom.firstMaterial?.diffuse.contents = NSColor.white
        
        let textNode = SCNNode(geometry: textGeom)
        textNode.position = SCNVector3(platformX, 5, platformZ)
        textNode.constraints = [SCNBillboardConstraint()]
        scene.rootNode.addChildNode(textNode)
    }
    
    private func addTrainNode(for train: Train) {
        let trainGeometry = SCNBox(width: 4, height: 4, length: 15, chamferRadius: 0.5)
        trainGeometry.firstMaterial?.diffuse.contents = NSColor.blue
        let node = SCNNode(geometry: trainGeometry)
        node.position = SCNVector3(0, 2, 0)
        
        node.addChildNode(makeTrainLabel(for: train))
        scene.rootNode.addChildNode(node)
        trainNodes[train.id] = node
    }
    
    private func makeTrainLabel(for train: Train) -> SCNNode {
        let idString = train.name.replacingOccurrences(of: "Rame ", with: "")
        let textGeom = SCNText(string: idString, extrusionDepth: 0.3)
        textGeom.font = NSFont(name: "Helvetica-Bold", size: 4)
        textGeom.firstMaterial?.diffuse.contents = NSColor.white
        textGeom.flatness = 0.1
        
        let textNode = SCNNode(geometry: textGeom)
        let (min, max) = textNode.boundingBox
        let textWidth = max.x - min.x
        textNode.pivot = SCNMatrix4MakeTranslation(textWidth / 2, 0, 0)
        textNode.position = SCNVector3(0, 5, 0)
        textNode.constraints = [SCNBillboardConstraint()]
        return textNode
    }
}
