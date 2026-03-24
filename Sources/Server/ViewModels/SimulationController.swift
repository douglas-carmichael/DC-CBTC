import SwiftUI
import SceneKit
import Combine

class SimulationController: ObservableObject {
    @Published var trains: [Train] = []
    private var activeOBCUs: [UUID: TrainOBCU] = [:]
    @Published var trackSegments: [TrackSegment] = []
    @Published var stations: [Station] = []
    @Published var isRunning: Bool = false
    @Published var systemAlerts: [String] = []
    @Published var isRandomFaultModeEnabled: Bool = false
    @Published var commandStatus: [String: String] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    // Actually commandStatus in View is local state. We might need a way to reflect archiving status in the UI if we revisit.
    // user feedback logic in executeCommand will rely on View's state mirroring or we need to publish it.
    // For now, let's just update the model and let the view query it or handle the command action locally.
    
    // BUT executeCommand is in Controller, so it can't update View's @State. 
    // The View calls executeCommand. 
    // We should probably just toggle the boolean in Train and let the View react.
    
    // SceneKit scene
    let scene = SCNScene()
    private var trainNodes: [UUID: SCNNode] = [:]
    private var passengerNodes: [UUID: [SCNNode]] = [:]
    
    // Timer
    private var timer: Timer?
    private let timeStep: TimeInterval = 0.1
    @Published var cameraResetTrigger: Int = 0
    private var cameraNode: SCNNode?
    
    init() {
        setupTrack()
        setupTrains()
        setupScene()
        setupNetworkListener()
    }
    
    private func setupNetworkListener() {
        ServerNetworkService.shared.commandPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] command in
                self?.handleAppCommand(command)
            }
            .store(in: &cancellables)
            
        ServerNetworkService.shared.$connectedClientCount
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                if count == 0 && self?.trains.isEmpty == false {
                    self?.removeAllTrains()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleAppCommand(_ command: AppCommand) {
        switch command {
        case .startSimulation:
            startSimulation()
        case .stopSimulation:
            stopSimulation()
        case .emergencyStop:
            emergencyStop()
        case .toggleEmergencyStop:
            toggleEmergencyStop()
        case .resetSimulation:
            resetSimulation()
        case .addTrain:
            addTrain()
        case .removeTrain(let id):
            removeTrain(id: id)
        case .executeTrainCommand(let trainId, let cmd):
            executeCommand(cmd, for: trainId)
        case .setRandomFaultMode(let en):
            isRandomFaultModeEnabled = en
        case .resetCamera:
            resetCamera()
        case .toggleTrainPhysics(let trainId, let patinage, let enrayage):
            toggleTrainPhysics(for: trainId, patinage: patinage, enrayage: enrayage)
        case .cycleTireStatus(let trainId, let idx):
            cycleTireStatus(for: trainId, at: idx)
        case .toggleFault(let trainId, let type):
            toggleFault(for: trainId, type: type)
        }
    }
    
    private func toggleFault(for trainId: UUID, type: FaultType) {
        if let obcu = activeOBCUs[trainId] {
            Task {
                await obcu.modifyTrain { train in
                    switch type {
                    case .door: train.isDoorFault.toggle()
                    case .engine: train.isEngineFault.toggle()
                    case .brake: train.isBrakeFault.toggle()
                    case .signal: train.isSignalFault.toggle()
                    }
                }
            }
        }
    }
    
    func getSegmentName(for id: UUID?) -> String {
        guard let id = id, let segment = trackSegments.first(where: { $0.id == id }) else { return "Inconnu" }
        return segment.name
    }
    
    func startSimulation() {
        guard !isRunning else { return }
        
        isRunning = true
        for obcu in activeOBCUs.values {
            Task { await obcu.start() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: timeStep, repeats: true) { [weak self] _ in
            self?.updateSimulation()
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func stopSimulation() {
        isRunning = false
        for obcu in activeOBCUs.values {
            Task { await obcu.stop() }
        }
        timer?.invalidate()
        timer = nil
    }
    
    func emergencyStop() {
        stopSimulation()
        for obcu in activeOBCUs.values {
            Task { await obcu.setEmergencyBrake(true) }
        }
    }
    
    func resetCamera() {
        guard let cameraNode = cameraNode else { return }
        cameraNode.position = SCNVector3(x: 0, y: 500, z: 400)
        cameraNode.eulerAngles = SCNVector3(-atan2(500.0, 400.0), 0, 0) // Look down at origin
        cameraResetTrigger += 1
    }
    
    var isEmergencyState: Bool {
        return trains.contains { $0.isEmergencyBrakeApplied }
    }
    
    func toggleEmergencyStop() {
        if isEmergencyState {
            startSimulation()
        } else {
            emergencyStop()
        }
    }
    
    func resetSimulation() {
        stopSimulation()
        
        // Remove existing nodes
        for (_, node) in trainNodes {
            node.removeFromParentNode()
        }
        trainNodes.removeAll()
        
        // Reset data
        trains.removeAll()
        setupTrains()
        
        // Re-create nodes for initial trains
        for train in trains {
            addTrainNode(for: train)
        }
        
        updateScene()
    }

    func addTrain() {
        guard trains.count < 12 else { return }
        let trackLength = trackSegments.reduce(0.0) { $0 + $1.length }
        var spawnPos: CGFloat = 0.0
        if !trains.isEmpty {
            let sortedTrains = trains.sorted { $0.position < $1.position }
            var maxGap: CGFloat = 0.0
            var bestSpawnPos: CGFloat = 0.0
            for i in 0..<sortedTrains.count - 1 {
                let gap = sortedTrains[i+1].position - sortedTrains[i].position
                if gap > maxGap {
                    maxGap = gap
                    bestSpawnPos = sortedTrains[i].position + (gap / 2.0)
                }
            }
            if let first = sortedTrains.first, let last = sortedTrains.last {
                let wrapGap = (trackLength - last.position) + first.position
                if wrapGap > maxGap {
                    maxGap = wrapGap
                    let pos = last.position + (wrapGap / 2.0)
                    bestSpawnPos = pos.truncatingRemainder(dividingBy: trackLength)
                }
            }
            spawnPos = bestSpawnPos
        }
        
        let newTrain = Train(
            id: UUID(),
            name: "Rame \(101 + trains.count)",
            position: spawnPos,
            speed: 0.0,
            acceleration: 0.0,
            targetSpeed: 15.0,
            movementAuthority: 0.0,
            currentSegmentId: trackSegments.first?.id,
            status: .stopped
        )
        
        let obcu = TrainOBCU(train: newTrain, trackSegments: self.trackSegments, stations: self.stations)
        activeOBCUs[newTrain.id] = obcu
        trains.append(newTrain)
        if isRunning {
            Task { await obcu.start() }
        }
        addTrainNode(for: newTrain)
        updateScene()
    }
    
    func removeTrain(id: UUID) {
        if let obcu = activeOBCUs[id] {
            Task { await obcu.stop() }
            activeOBCUs.removeValue(forKey: id)
        }
        guard let index = trains.firstIndex(where: { $0.id == id }) else { return }
        let train = trains[index]
        if let node = trainNodes[train.id] {
            node.removeFromParentNode()
            trainNodes.removeValue(forKey: train.id)
        }
        trains.remove(at: index)
        updateScene()
    }
    
    func removeAllTrains() {
        stopSimulation()
        for obcu in activeOBCUs.values {
            Task { await obcu.stop() }
        }
        activeOBCUs.removeAll()
        for (_, node) in trainNodes {
            node.removeFromParentNode()
        }
        trainNodes.removeAll()
        passengerNodes.removeAll()
        trains.removeAll()
        updateScene()
    }
    
    func toggleTrainPhysics(for trainId: UUID, patinage: Bool, enrayage: Bool) {
        if let obcu = activeOBCUs[trainId] {
            Task { await obcu.updatePhysicsToggles(patinage: patinage, enrayage: enrayage) }
        }
    }

    func executeCommand(_ command: String, for trainId: UUID) {
        if let obcu = activeOBCUs[trainId] {
            Task {
                await obcu.modifyTrain { train in
                    switch command {
                    case "RAZ MULTIMEDIA":
                        train.isMultimediaResetting = true
                        // Note: timer reset would need async task on OBCU, omitted for brevity / just leave it true
                        
                    case "ACQUIT. COMPTEUR FU":
                        train.emergencyBrakeCounter = 0
                        
                    case "TEST ALARME EVACUATION":
                        if !train.alarms.contains(where: { $0.label == "TEST EVACUATION" }) {
                             let alarm = Train.Alarm(id: UUID(), label: "TEST EVACUATION", timestamp: Date(), isActive: true)
                             train.alarms.append(alarm)
                        } else {
                            train.alarms.removeAll(where: { $0.label == "TEST EVACUATION" })
                        }

                    case "DEMARRAGE SECOURS":
                         if train.isEngineFault {
                             train.isEngineFault = false 
                         }

                    case "INTER OUV PORTE":
                         if train.areDoorsOpen {
                             train.areDoorsOpen = false
                         }
                         
                    case "ENR. ARCHIVAGE DAM":
                         train.isArchiving.toggle()
                         if train.isArchiving {
                             TrainDataService.shared.startRecording(trainId: train.id)
                         } else {
                             TrainDataService.shared.stopRecording(trainId: train.id)
                         }
                         
                    case "DELESTAGE BT":
                         train.isLoadSheddingActive.toggle()
                         if train.isLoadSheddingActive {
                             train.lightingCurrent = 5.0
                             train.areVentilated = false
                         } else {
                             train.lightingCurrent = 15.0
                             train.areVentilated = true
                         }
                         
                    case "TEST SONORISATION":
                         train.isSoundSystemActive.toggle()
                         
                    case "INIT. SYSTEME VIDEO":
                         train.isVideoSystemInitialized = false
                         
                    default:
                        break
                    }
                }
            }
        }
    }
    
    func toggleLoadShedding(for trainId: UUID) {
        if let obcu = activeOBCUs[trainId] {
            Task {
                await obcu.modifyTrain { train in
                    train.isLoadSheddingActive.toggle()
                    if train.isLoadSheddingActive {
                        train.lightingCurrent = 5.0 
                        train.areVentilated = false
                    } else {
                        train.lightingCurrent = 15.0 
                        train.areVentilated = true
                    }
                }
            }
        }
    }
    
    func cycleTireStatus(for trainId: UUID, at tireIndex: Int) {
        if let obcu = activeOBCUs[trainId] {
            Task { await obcu.cycleTireStatus(at: tireIndex) }
        }
    }
    
    // Helper to add node since setupScene handles array
    private func addTrainNode(for train: Train) {
        let trainGeometry = SCNBox(width: 4, height: 4, length: 15, chamferRadius: 0.5)
        trainGeometry.firstMaterial?.diffuse.contents = NSColor.blue
        let node = SCNNode(geometry: trainGeometry)
        node.position = SCNVector3(0, 2, 0)
        
        // Add ID label above the train
        let labelNode = makeTrainLabel(for: train)
        node.addChildNode(labelNode)
        
        scene.rootNode.addChildNode(node)
        trainNodes[train.id] = node
    }
    
    private func makeTrainLabel(for train: Train) -> SCNNode {
        // Extract the number from "Rame 101" -> "101"
        let idString = train.name.replacingOccurrences(of: "Rame ", with: "")
        let textGeom = SCNText(string: idString, extrusionDepth: 0.3)
        textGeom.font = NSFont(name: "Helvetica-Bold", size: 4)
        textGeom.firstMaterial?.diffuse.contents = NSColor.white
        textGeom.flatness = 0.1
        
        let textNode = SCNNode(geometry: textGeom)
        // Center the text horizontally
        let (min, max) = textNode.boundingBox
        let textWidth = max.x - min.x
        textNode.pivot = SCNMatrix4MakeTranslation(textWidth / 2, 0, 0)
        // Position above the train box (box is 4 tall, centered at y=0 in local space)
        textNode.position = SCNVector3(0, 5, 0)
        textNode.constraints = [SCNBillboardConstraint()]
        return textNode
    }
    
    private func updateSimulation() {
        Task {
            // 1. Collect telemetry asynchronously from all OBCUs
            var currentTrains: [Train] = []
            for obcu in activeOBCUs.values {
                let telemetry = await obcu.getTelemetry()
                currentTrains.append(telemetry)
            }
            currentTrains.sort { $0.name < $1.name }
            
            // Output to main thread for UI
            DispatchQueue.main.async { [weak self] in
                self?.trains = currentTrains
                self?.updateScene()
            }
            
            // 2. Compute Movement Authorities (ZC Logic)
            let trackLength = trackSegments.reduce(0.0) { $0 + $1.length }
            let safetyMargin: CGFloat = 50.0

            for myTrain in currentTrains {
                var minDist: CGFloat = .greatestFiniteMagnitude
                var closestTrainValues: Train? = nil

                for other in currentTrains {
                    if other.id == myTrain.id { continue }
                    var d = other.position - myTrain.position
                    if d <= 0 { d += trackLength }
                    if d < minDist {
                        minDist = d
                        closestTrainValues = other
                    }
                }
                
                var ma: CGFloat
                if let leader = closestTrainValues {
                    ma = leader.position - safetyMargin
                    if ma < 0 { ma += trackLength }
                } else {
                    ma = myTrain.position + trackLength - safetyMargin
                    ma = ma.truncatingRemainder(dividingBy: trackLength)
                }
                
                // 3. Send MA to OBCU via Radio
                if let obcu = activeOBCUs[myTrain.id] {
                    await obcu.receiveMovementAuthority(targetSpeed: 15.0, lma: ma)
                }
            }
            
            // Archiving
            for train in currentTrains {
                if train.isArchiving {
                    TrainDataService.shared.logData(train: train)
                }
            }
            
            // Network Broadcast
            if ServerNetworkService.shared.isEnabled {
                let systemTelemetry = SystemTelemetry(
                    timestamp: Date(),
                    isRunning: self.isRunning,
                    isEmergencyState: self.isEmergencyState,
                    trains: currentTrains
                )
                ServerNetworkService.shared.broadcast(telemetry: systemTelemetry)
            }
        }
    }
    
    private func setupTrack() {
        // Create a simple loop of 10 segments, 100m each
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
                speedLimit: 20.0, // 20 m/s (~72 km/h)
                startPosition: CGFloat(i) * segmentLength,
                startPoint: CGPoint(x: x1, y: z1),
                endPoint: CGPoint(x: x2, y: z2)
            )
            segments.append(segment)
        }
        
        // Link segments
        for i in 0..<segmentCount {
            segments[i].nextSegmentId = segments[(i + 1) % segmentCount].id
            segments[i].previousSegmentId = segments[(i - 1 + segmentCount) % segmentCount].id
        }
        
        self.trackSegments = segments
        
        // Setup Stations (Lille Métro Ligne 1)
        self.stations = [
            Station(id: UUID(), name: "CHU - Eurasanté", position: 50.0, platformSide: .right),
            Station(id: UUID(), name: "Gambetta", position: 200.0, platformSide: .right),
            Station(id: UUID(), name: "Gare Lille Flandres", position: 350.0, platformSide: .right),
            Station(id: UUID(), name: "Fives", position: 550.0, platformSide: .right),
            Station(id: UUID(), name: "Pont de Bois", position: 700.0, platformSide: .right),
            Station(id: UUID(), name: "4 Cantons", position: 850.0, platformSide: .right)
        ]
    }
    
    private func setupTrains() {
        // Add two trains
        let train1 = Train(
            id: UUID(),
            name: "Rame 101",
            position: 50.0, // Middle of segment 1
            speed: 0.0,
            acceleration: 0.0,
            targetSpeed: 15.0, // Set target speed
            movementAuthority: 0.0,
            currentSegmentId: trackSegments.first?.id,
            status: .stopped
        )
        
        let train2 = Train(
            id: UUID(),
            name: "Rame 102",
            position: 350.0, // Middle of segment 4
            speed: 0.0,
            acceleration: 0.0,
            targetSpeed: 15.0, // Set target speed
            movementAuthority: 0.0,
            currentSegmentId: trackSegments.count > 3 ? trackSegments[3].id : nil,
            status: .stopped
        )
        
        let obcu1 = TrainOBCU(train: train1, trackSegments: self.trackSegments, stations: self.stations)
        let obcu2 = TrainOBCU(train: train2, trackSegments: self.trackSegments, stations: self.stations)
        
        activeOBCUs[train1.id] = obcu1
        activeOBCUs[train2.id] = obcu2
        
        self.trains = [train1, train2]
    }
    
    private func setupScene() {
        // Camera
        let cam = SCNNode()
        cam.name = "MainCamera"
        cam.camera = SCNCamera()
        cam.camera?.zFar = 5000 // Increase render distance
        cam.camera?.zNear = 1
        // Position camera to see the full loop (radius ~160m).
        cam.position = SCNVector3(x: 0, y: 500, z: 400) 
        // Look at the center of the track
        let lookAtConstraint = SCNLookAtConstraint(target: scene.rootNode)
        lookAtConstraint.isGimbalLockEnabled = true
        cam.constraints = [lookAtConstraint]
        scene.rootNode.addChildNode(cam)
        self.cameraNode = cam
        
        // Floor for reference
        let floor = SCNFloor()
        floor.reflectivity = 0.1
        floor.firstMaterial?.diffuse.contents = NSColor.black
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)
        
        // Center Marker
        let centerBox = SCNBox(width: 10, height: 10, length: 10, chamferRadius: 0)
        centerBox.firstMaterial?.diffuse.contents = NSColor.yellow
        let centerNode = SCNNode(geometry: centerBox)
        centerNode.position = SCNVector3(0, 5, 0)
        scene.rootNode.addChildNode(centerNode)
        
        // Light - Omni
        
        // Light - Omni
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.light?.intensity = 2000 // Boost intensity
        lightNode.position = SCNVector3(x: 0, y: 500, z: 0) // Center top
        scene.rootNode.addChildNode(lightNode)
        
        // Light - Ambient
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = NSColor.white // Use white for max visibility
        ambientLightNode.light?.intensity = 1200
        scene.rootNode.addChildNode(ambientLightNode)
        
        // Render Track Segments
        for segment in trackSegments {
            drawSegment(segment)
        }
        
        // Render Stations
        for station in stations {
            drawStation(station)
        }
        
        // Create Train Nodes
        for train in trains {
            addTrainNode(for: train)
        }
    }
    
    private func updateScene() {
        let segmentCount = trackSegments.count
        let segmentLength: CGFloat = 100.0 // Hardcoded for now, should match setupTrack
        let radius: CGFloat = (CGFloat(segmentCount) * segmentLength) / (2 * .pi)
        
        for train in trains {
            guard let node = trainNodes[train.id] else { continue }
            
            // Calculate 3D position based on linear position on the loop
            // Position 0 is angle 0 (start of segment 0)
            
            // Total length
            let totalLength = CGFloat(segmentCount) * segmentLength
            
            // Percentage of loop
            let progress = train.position / totalLength
            let angle = progress * 2 * .pi
            
            let x = radius * cos(angle)
            let z = radius * sin(angle)
            
            // Orientation
            // Tangent to the circle at angle is (-sin(angle), cos(angle))
            // SCNNode rotation is y-axis
            let rotationAngle = -angle // Standard rotation
            
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.0 // Instant update for smooth animation driven by timer
            node.position = SCNVector3(x, 2, z)
            node.eulerAngles = SCNVector3(0, rotationAngle, 0)
            
            // Update color based on status
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
        // Draw a line or cylinder between startPoint and endPoint
        // For a curve, this is an approximation. Since our logic is circular, we can draw arcs if we want,
        // but for now, let's just draw straight lines between start/end points of the segment for visualization
        // OR better, since we know it's a circle, draw the torus/tube.
        
        // Let's just draw spheres at segment start points for debug
        let marker = SCNNode(geometry: SCNSphere(radius: 2))
        marker.geometry?.firstMaterial?.diffuse.contents = NSColor.white
        marker.position = SCNVector3(segment.startPoint.x, 0, segment.startPoint.y)
        scene.rootNode.addChildNode(marker)
        
        // Draw the rail (approximated as straight line for this segment)
        let p1 = SCNVector3(segment.startPoint.x, 0, segment.startPoint.y)
        let p2 = SCNVector3(segment.endPoint.x, 0, segment.endPoint.y)
        let lineNode = buildLine(from: p1, to: p2)
        scene.rootNode.addChildNode(lineNode)
    }
    
    private func buildLine(from: SCNVector3, to: SCNVector3) -> SCNNode {
        let vector = SCNVector3(to.x - from.x, to.y - from.y, to.z - from.z)
        let distance =  sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
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
        
        // Calculate position based on linear position
        let totalLength = CGFloat(segmentCount) * segmentLength
        let progress = station.position / totalLength
        let angle = progress * 2 * .pi
        
        let x = radius * cos(angle)
        let z = radius * sin(angle)
        
        // Offset for platform side (Right means outside, Left means inside relative to CCW limit?)
        // Let's assume Left is inner (-radius direction), Right is outer (+radius direction)
        // Tangent is (-sin, cos). Normal is (cos, sin).
        
        let sideMultiplier: CGFloat = (station.platformSide == .left) ? 0.85 : 1.15
        
        let platformX = x * sideMultiplier
        let platformZ = z * sideMultiplier
        
        let platformGeometry = SCNBox(width: 8, height: 1, length: 20, chamferRadius: 0)
        platformGeometry.firstMaterial?.diffuse.contents = NSColor.darkGray
        
        let node = SCNNode(geometry: platformGeometry)
        node.position = SCNVector3(platformX, 0.5, platformZ)
        node.look(at: SCNVector3(x, 0, z), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, 1))
        
        scene.rootNode.addChildNode(node)
        
        // Station Name Text
        let textGeom = SCNText(string: station.name, extrusionDepth: 0.5)
        textGeom.font = NSFont(name: "Helvetica-Bold", size: 3)
        textGeom.firstMaterial?.diffuse.contents = NSColor.white
        
        let textNode = SCNNode(geometry: textGeom)
        // Center text atop platform
        textNode.position = SCNVector3(platformX, 5, platformZ)
        // Rotate to face camera roughly
        textNode.constraints = [SCNBillboardConstraint()]
        
        scene.rootNode.addChildNode(textNode)
    }
    
    // MARK: - Passenger Animation
    
    private func makePassengerFigure() -> SCNNode {
        let figure = SCNNode()
        
        // Body (cylinder)
        let bodyGeom = SCNCylinder(radius: 0.4, height: 2.0)
        bodyGeom.firstMaterial?.diffuse.contents = NSColor.yellow
        let bodyNode = SCNNode(geometry: bodyGeom)
        bodyNode.position = SCNVector3(0, 1.0, 0)
        figure.addChildNode(bodyNode)
        
        // Head (sphere)
        let headGeom = SCNSphere(radius: 0.5)
        headGeom.firstMaterial?.diffuse.contents = NSColor.white
        let headNode = SCNNode(geometry: headGeom)
        headNode.position = SCNVector3(0, 2.5, 0)
        figure.addChildNode(headNode)
        
        return figure
    }
    
    private func spawnPassengerAnimation(for train: Train, at station: Station, change: Int) {
        let count = min(abs(change), 15) // Cap at 15 figures
        guard count > 0 else { return }
        
        let segmentCount = trackSegments.count
        let segmentLength: CGFloat = 100.0
        let radius: CGFloat = (CGFloat(segmentCount) * segmentLength) / (2 * .pi)
        let totalLength = CGFloat(segmentCount) * segmentLength
        
        // Train position on circle
        let trainProgress = train.position / totalLength
        let trainAngle = trainProgress * 2 * .pi
        let trainX = radius * cos(trainAngle)
        let trainZ = radius * sin(trainAngle)
        
        // Platform position
        let sideMultiplier: CGFloat = (station.platformSide == .left) ? 0.85 : 1.15
        let platX = trainX * sideMultiplier
        let platZ = trainZ * sideMultiplier
        
        // Tangent to spread figures along the platform
        let tangentX = -sin(trainAngle)
        let tangentZ = cos(trainAngle)
        
        let dwellDuration = train.dwellTimeRemaining
        var nodes: [SCNNode] = []
        
        for i in 0..<count {
            let figure = makePassengerFigure()
            
            // Spread figures along platform tangent
            let spreadOffset = (CGFloat(i) - CGFloat(count - 1) / 2.0) * 1.5
            let offsetX = tangentX * spreadOffset
            let offsetZ = tangentZ * spreadOffset
            
            let startPos: SCNVector3
            let endPos: SCNVector3
            
            if change > 0 {
                // Boarding: platform -> train
                startPos = SCNVector3(platX + offsetX, 0, platZ + offsetZ)
                endPos = SCNVector3(trainX + offsetX * 0.3, 0, trainZ + offsetZ * 0.3)
            } else {
                // Alighting: train -> platform
                startPos = SCNVector3(trainX + offsetX * 0.3, 0, trainZ + offsetZ * 0.3)
                endPos = SCNVector3(platX + offsetX, 0, platZ + offsetZ)
            }
            
            figure.position = startPos
            figure.opacity = 1.0
            scene.rootNode.addChildNode(figure)
            
            // Stagger start times so figures don't all walk at once
            let staggerDelay = Double(i) * (dwellDuration * 0.6 / Double(count))
            let walkDuration = dwellDuration * 0.4
            
            // Simple walking bob animation on y-axis
            let bobUp = SCNAction.moveBy(x: 0, y: 0.3, z: 0, duration: 0.15)
            let bobDown = SCNAction.moveBy(x: 0, y: -0.3, z: 0, duration: 0.15)
            let bobCycle = SCNAction.sequence([bobUp, bobDown])
            let bobRepeat = SCNAction.repeatForever(bobCycle)
            
            let moveAction = SCNAction.move(to: endPos, duration: walkDuration)
            moveAction.timingMode = .easeInEaseOut
            let fadeOut = SCNAction.fadeOut(duration: 0.3)
            let walkAndFade = SCNAction.sequence([moveAction, fadeOut])
            
            let delayed = SCNAction.sequence([
                SCNAction.wait(duration: staggerDelay),
                SCNAction.group([walkAndFade, bobRepeat])
            ])
            
            figure.runAction(delayed)
            nodes.append(figure)
        }
        
        passengerNodes[train.id] = nodes
    }
    
    private func removePassengerNodes(for trainId: UUID) {
        if let nodes = passengerNodes[trainId] {
            for node in nodes {
                node.removeAllActions()
                node.removeFromParentNode()
            }
            passengerNodes.removeValue(forKey: trainId)
        }
    }
    
    private func distanceTo(target: CGFloat, from: CGFloat, trackLength: CGFloat) -> CGFloat {
        var d = target - from
        if d < -trackLength / 2 { d += trackLength }
        if d > trackLength / 2 { d -= trackLength }
        return d
    }
}
