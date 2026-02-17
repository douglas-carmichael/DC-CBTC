import SwiftUI
import SceneKit
import Combine

class SimulationController: ObservableObject {
    // published state for UI
    @Published var trains: [Train] = []
    @Published var trackSegments: [TrackSegment] = []
    @Published var stations: [Station] = []
    @Published var isRunning: Bool = false
    @Published var systemAlerts: [String] = []
    @Published var isRandomFaultModeEnabled: Bool = false
    @Published var commandStatus: [String: String] = [:] // Global command status? Or per train?
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
    }
    
    func getSegmentName(for id: UUID?) -> String {
        guard let id = id, let segment = trackSegments.first(where: { $0.id == id }) else { return "Inconnu" }
        return segment.name
    }
    
    func startSimulation() {
        guard !isRunning else { return }
        
        // Reset speeds if coming from emergency stop or initial state
        for i in 0..<trains.count {
            if trains[i].targetSpeed == 0 {
                trains[i].targetSpeed = 15.0
            }
            if trains[i].status == .emergency {
                trains[i].status = .stopped
                trains[i].isEmergencyBrakeApplied = false
            }
        }
        
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: timeStep, repeats: true) { [weak self] _ in
            self?.updateSimulation()
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func stopSimulation() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func emergencyStop() {
        stopSimulation()
        for i in 0..<trains.count {
            trains[i].speed = 0
            trains[i].targetSpeed = 0
            trains[i].status = .emergency
            trains[i].isEmergencyBrakeApplied = true
        }
        updateScene()
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
        // Limit number of trains to prevent gridlock (Loop capacity ~10-12)
        guard trains.count < 12 else { return }
        // Calculate track length
        let trackLength = trackSegments.reduce(0.0) { $0 + $1.length }
        
        // Default spawn position if no trains exist
        var spawnPos: CGFloat = 0.0
        
        if !trains.isEmpty {
            // Sort trains by position to find gaps
            let sortedTrains = trains.sorted { $0.position < $1.position }
            
            var maxGap: CGFloat = 0.0
            var bestSpawnPos: CGFloat = 0.0
            
            // Check gaps between adjacent trains
            for i in 0..<sortedTrains.count - 1 {
                let gap = sortedTrains[i+1].position - sortedTrains[i].position
                if gap > maxGap {
                    maxGap = gap
                    bestSpawnPos = sortedTrains[i].position + (gap / 2.0)
                }
            }
            
            // Check wrap-around gap (between last and first train)
            if let first = sortedTrains.first, let last = sortedTrains.last {
                let wrapGap = (trackLength - last.position) + first.position
                if wrapGap > maxGap {
                    maxGap = wrapGap
                    // Position is last position + half gap, wrapped around track length
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
            targetSpeed: 15.0, // Default to 15 m/s so it moves when started
            movementAuthority: 0.0,
            currentSegmentId: trackSegments.first?.id, // Will be updated by updateSimulation next cycle
            status: .stopped,
            isDoorFault: false,
            isEngineFault: false,
            isBrakeFault: false,
            isSignalFault: false,
            isPatinage: false,
            isEnrayage: false,
            mode: .auto,
            manualSpeedRequest: 0.0,
            areDoorsOpen: false,
            isEmergencyBrakeApplied: false,
            startupState: .booting,
            startupTime: 0.0
        )
        
        trains.append(newTrain)
        
        // Update segment immediately for correctness before next physics update
        if let segment = trackSegments.first(where: { newTrain.position >= $0.startPosition && newTrain.position < $0.startPosition + $0.length }) {
             var updatedTrain = newTrain
             updatedTrain.currentSegmentId = segment.id
             // Update the train in the array
             if let idx = trains.firstIndex(where: { $0.id == updatedTrain.id }) {
                 trains[idx] = updatedTrain
             }
        }
        
        // thorough scene update to add node
        addTrainNode(for: newTrain)
        updateScene()
    }
    
    func removeTrain(id: UUID) {
        guard let index = trains.firstIndex(where: { $0.id == id }) else { return }
        let train = trains[index]
        
        // Remove node
        if let node = trainNodes[train.id] {
            node.removeFromParentNode()
            trainNodes.removeValue(forKey: train.id)
        }
        
        trains.remove(at: index)
        updateScene()
    }
    
    func toggleTrainPhysics(for trainId: UUID, patinage: Bool, enrayage: Bool) {
        if let index = trains.firstIndex(where: { $0.id == trainId }) {
            trains[index].isPatinage = patinage
            trains[index].isEnrayage = enrayage
        }
    }

    func executeCommand(_ command: String, for trainId: UUID) {
        guard let index = trains.firstIndex(where: { $0.id == trainId }) else { return }
        
        switch command {
        case "RAZ MULTIMEDIA":
            // Simulate reset
            trains[index].isMultimediaResetting = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let i = self.trains.firstIndex(where: { $0.id == trainId }) {
                    self.trains[i].isMultimediaResetting = false
                }
            }
            
        case "ACQUIT. COMPTEUR FU":
            trains[index].emergencyBrakeCounter = 0
            
        case "TEST ALARME EVACUATION":
            // Toggle an alarm state for testing
            // checking if alarm already exists
            if !trains[index].alarms.contains(where: { $0.label == "TEST EVACUATION" }) {
                 let alarm = Train.Alarm(id: UUID(), label: "TEST EVACUATION", timestamp: Date(), isActive: true)
                 trains[index].alarms.append(alarm)
            } else {
                trains[index].alarms.removeAll(where: { $0.label == "TEST EVACUATION" })
            }

        case "DEMARRAGE SECOURS":
            // Attempt to clear checking engine fault temporarily or allow move
            // For now, let's just log it or maybe clear a fault if it exists
             if trains[index].isEngineFault {
                 trains[index].isEngineFault = false // Try to reset fault
             }

        case "INTER OUV PORTE":
             // Toggle door interlock? Assume it forces doors closed if open?
             if trains[index].areDoorsOpen {
                 trains[index].areDoorsOpen = false
             }
             
        case "ENR. ARCHIVAGE DAM":
             // Toggle archiving
             if let index = trains.firstIndex(where: { $0.id == trainId }) {
                 trains[index].isArchiving.toggle()
                 if trains[index].isArchiving {
                     TrainDataService.shared.startRecording(trainId: trainId)
                 } else {
                     TrainDataService.shared.stopRecording(trainId: trainId)
                 }
                 // Visual feedback?
                 commandStatus["ENR. ARCHIVAGE DAM"] = trains[index].isArchiving ? "EN COURS..." : "STOP"
                 DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                     self.commandStatus["ENR. ARCHIVAGE DAM"] = self.trains[index].isArchiving ? "ACTIF" : nil
                 }
             }
             
        case "DELESTAGE BT":
             // Toggle Load Shedding
             toggleLoadShedding(for: trainId)
             
        case "RAZ APPAREIL DE VOIE", "RAZ MOTEUR AIGUILLE":
             // Specific to track, but simulated on train scope for now?
             break
             
        case "TEST SONORISATION":
             trains[index].isSoundSystemActive.toggle()
             
        case "INIT. SYSTEME VIDEO":
             trains[index].isVideoSystemInitialized = false
             DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                 if let i = self.trains.firstIndex(where: { $0.id == trainId }) {
                     self.trains[i].isVideoSystemInitialized = true
                 }
             }
             
        default:
            break
        }
    }
    
    func toggleLoadShedding(for trainId: UUID) {
        if let index = trains.firstIndex(where: { $0.id == trainId }) {
            trains[index].isLoadSheddingActive.toggle()
            
            // Effect on power consumption
            if trains[index].isLoadSheddingActive {
                trains[index].lightingCurrent = 5.0 // Reduced
                trains[index].areVentilated = false
            } else {
                trains[index].lightingCurrent = 15.0 // Normal
                trains[index].areVentilated = true
            }
        }
    }
    
    func cycleTireStatus(for trainId: UUID, at tireIndex: Int) {
        guard let index = trains.firstIndex(where: { $0.id == trainId }) else { return }
        trains[index].cycleTireStatus(at: tireIndex)
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
        // Core physics and CBTC logic loop
        for i in 0..<trains.count {
            if trains[i].startupState == .ready {
                updateTrainPhysics(at: i)
                updateMovementAuthority(at: i)
            }
        }
        
        // Update startup sequences
        updateStartupSequence()

        if isRandomFaultModeEnabled {
            updateRandomFaults()
        }
        
        updateAlarms()
        updateRealTimeData()
        
        // Update Archiving
        for train in trains {
            if train.isArchiving {
                TrainDataService.shared.logData(train: train)
            }
        }
        
        // Ensure scene updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            self?.updateScene()
        }
    }
    
    private func updateRealTimeData() {
        for i in 0..<trains.count {
            var train = trains[i]
            
            // 1. Auxiliary Voltage Fluctuation (720V - 780V)
            // Add random noise
            let voltageNoise = Double.random(in: -2.0...2.0)
            // Base voltage depends on load?
            var baseVoltage = 750.0
            if train.acceleration > 0 { baseVoltage -= 15.0 } // Voltage drop under load
            if train.acceleration < 0 { baseVoltage += 20.0 } // Regen
            
            train.mainVoltage = baseVoltage + voltageNoise
            
            // 2. Traction Current & Torque
            if train.acceleration > 0 {
                // Accelerating
                // Current proportional to acceleration (F=ma)
                let targetCurrent = 800.0 * (Double(train.acceleration) / 1.0) // Max 1.0 m/s2
                train.tractionCurrent = moveTowards(current: train.tractionCurrent, target: targetCurrent, step: 50.0)
                
                let targetTorque = 100.0 * (Double(train.acceleration) / 1.0)
                train.tractionTorque = moveTowards(current: train.tractionTorque, target: targetTorque, step: 5.0)
                
            } else if train.acceleration < 0 {
                // Braking (Regen)
                let targetCurrent = -400.0 * (abs(Double(train.acceleration)) / 1.2)
                train.tractionCurrent = moveTowards(current: train.tractionCurrent, target: targetCurrent, step: 50.0)
                
                let targetTorque = -100.0 * (abs(Double(train.acceleration)) / 1.2)
                train.tractionTorque = moveTowards(current: train.tractionTorque, target: targetTorque, step: 5.0)
                
            } else {
                // Coasting / Stopped
                let baseLoad = train.areLightsOn ? 20.0 : 5.0
                train.tractionCurrent = moveTowards(current: train.tractionCurrent, target: baseLoad, step: 10.0)
                train.tractionTorque = moveTowards(current: train.tractionTorque, target: 0.0, step: 5.0)
            }
            
            // 3. Compressor Logic
            if train.compressorPressure < 7.5 {
                 train.isCompressorRunning = true
            } else if train.compressorPressure > 9.0 {
                 train.isCompressorRunning = false
            }
            
            if train.isCompressorRunning {
                train.compressorPressure += 0.05 * timeStep // Rise
            } else {
                train.compressorPressure -= 0.005 * timeStep // Small leak/usage
            }
            
            // 4. Lighting Current
            if train.areLightsOn {
                let lightNoise = Double.random(in: -0.2...0.2)
                train.lightingCurrent = 15.0 + lightNoise
            } else {
                train.lightingCurrent = 0.0
            }
            
            // 5. Temperature Control
            // Move towards target if ventilated
            if train.areVentilated {
                let diff = train.targetTemperature - train.interiorTemperature
                // Very slow adjustment
                train.interiorTemperature += diff * 0.05 * timeStep
            }
            // Add some "Body heat" if passengers > 0?
            train.interiorTemperature += Double(train.passengerCount) * 0.0001 * timeStep
            
            // 6. Next Station Calculation
            let trackLength = trackSegments.reduce(0.0) { $0 + $1.length }
            var bestDist: CGFloat = .greatestFiniteMagnitude
            var bestStation: String = "..."
            
            for station in stations {
                // Find distance to station AHEAD
                var d = station.position - train.position
                if d < 0 { d += trackLength }
                
                if d < bestDist {
                    bestDist = d
                    bestStation = station.name
                }
            }
            train.nextStationName = bestStation.uppercased()
            
            trains[i] = train
        }
    }
    
    private func moveTowards(current: Double, target: Double, step: Double) -> Double {
        if current < target {
            return min(current + step, target)
        } else {
            return max(current - step, target)
        }
    }
    
    private func updateStartupSequence() {
        for i in 0..<trains.count {
            if trains[i].startupState != .ready {
                trains[i].startupTime += timeStep
                
                // State Machine Transition
                switch trains[i].startupState {
                case .booting:
                    if trains[i].startupTime > 3.0 { // 3s boot
                        trains[i].startupState = .memoryCheck
                        trains[i].startupTime = 0
                    }
                case .memoryCheck:
                    if trains[i].startupTime > 2.0 { // 2s RAM check
                        trains[i].startupState = .systemsCheck
                        trains[i].startupTime = 0
                    }
                case .systemsCheck:
                    if trains[i].startupTime > 4.0 { // 4s Systems check
                        trains[i].startupState = .radioConnect
                        trains[i].startupTime = 0
                    }
                case .radioConnect:
                    if trains[i].startupTime > 3.0 { // 3s Connection
                        trains[i].startupState = .ready
                        trains[i].startupTime = 0
                        // ready to go
                    }
                case .ready: break
                }
            }
        }
    }
    
    private func updateRandomFaults() {
        for i in 0..<trains.count {
            // Low probability check (e.g. 0.05% per tick = ~1 fault every 2000 ticks = ~3 mins per train)
            if Double.random(in: 0...100) < 0.05 {
                let train = trains[i]
                var faultType = Int.random(in: 0...3) 
                
                // Contextual faults
                if train.speed > 0 {
                    // Moving: Engine, Brake, Signal
                    if faultType == 0 { // Door fault unlikely while moving unless it forces stop
                         faultType = 1 
                    }
                } else {
                    // Stopped: Door, Engine, Signal
                    if faultType == 2 { // Brake fault less noticeable if stopped
                        faultType = 0
                    }
                }
                
                switch faultType {
                case 0: 
                    if !train.isDoorFault {
                        trains[i].isDoorFault = true
                        print("Random Fault: Door Fault on \(train.name)")
                    }
                case 1: 
                     if !train.isEngineFault {
                        trains[i].isEngineFault = true
                        print("Random Fault: Engine Fault on \(train.name)")
                     }
                case 2:
                     if !train.isBrakeFault {
                        trains[i].isBrakeFault = true
                        print("Random Fault: Brake Fault on \(train.name)")
                     }
                case 3:
                     if !train.isSignalFault {
                        trains[i].isSignalFault = true
                        print("Random Fault: Signal Fault on \(train.name)")
                     }
                default: break
                }
            }
        }
    }
    
    private func updateAlarms() {
        // Define all boolean fault conditions to monitor
        let booleanFaults: [(keyPath: KeyPath<Train, Bool>, label: String)] = [
            (\.isDoorFault,              "DEFAUT PORTES"),
            (\.isEngineFault,            "DEFAUT TRACTION"),
            (\.isBrakeFault,             "DEFAUT FREINAGE"),
            (\.isSignalFault,            "PERTE SIGNAL"),
            (\.isPatinage,               "PATINAGE"),
            (\.isEnrayage,               "ENRAYAGE"),
            (\.isEmergencyBrakeApplied,  "ARRET D'URGENCE"),
        ]
        
        for i in 0..<trains.count {
            var train = trains[i]
            
            // --- Boolean faults ---
            for fault in booleanFaults {
                let isActive = train[keyPath: fault.keyPath]
                let existingActiveIndex = train.alarms.lastIndex(where: { $0.label == fault.label && $0.isActive })
                
                if isActive && existingActiveIndex == nil {
                    // Fault just became active — create new alarm
                    train.alarms.append(Train.Alarm(
                        id: UUID(),
                        label: fault.label,
                        timestamp: Date(),
                        isActive: true
                    ))
                } else if !isActive, let idx = existingActiveIndex {
                    // Fault cleared — mark resolved
                    train.alarms[idx].isActive = false
                }
            }
            
            // --- Tire faults ---
            for tire in train.tires {
                let tireLabels: [(Train.Tire.TireStatus, String)] = [
                    (.lowPressure, "PNEU \(tire.id) PRESSION BASSE"),
                    (.puncture,    "PNEU \(tire.id) CREVAISON"),
                    (.burst,       "PNEU \(tire.id) ECLATEMENT"),
                ]
                
                for (status, label) in tireLabels {
                    let isFault = (tire.status == status)
                    let existingActiveIndex = train.alarms.lastIndex(where: { $0.label == label && $0.isActive })
                    
                    if isFault && existingActiveIndex == nil {
                        train.alarms.append(Train.Alarm(
                            id: UUID(),
                            label: label,
                            timestamp: Date(),
                            isActive: true
                        ))
                    } else if !isFault, let idx = existingActiveIndex {
                        train.alarms[idx].isActive = false
                    }
                }
            }
            
            trains[i] = train
        }
    }
    
    private func updateTrainPhysics(at index: Int) {
        var train = trains[index]
        
        // Simple Physics
        let maxAcceleration: CGFloat = 1.0 // m/s²
        let maxBraking: CGFloat = 1.2 // m/s²
        
        let trackLength = trackSegments.reduce(0.0) { $0 + $1.length }
        
        // Determine distance to MA (Limit of Movement Authority)
        let distToMA = train.movementAuthority - train.position
        var effectiveDistToMA = distToMA
        if effectiveDistToMA < 0 { effectiveDistToMA += trackLength }
        
        // Fault / Mode Handling
        
        // 1. Critical Safety Faults (Override EVERYTHING)
        // Door Fault, Brake Fault, or Emergency Brake Applied manually
        if train.isDoorFault || train.isBrakeFault || train.isEmergencyBrakeApplied {
             train.status = .emergency
             // Apply brakes
             let desiredAcc = -maxBraking
             applyPhysics(train: &train, acceleration: desiredAcc, trackLength: trackLength)
             trains[index] = train
             return
        }
        
        // 2. Determine Operation Mode
        if train.mode == .manual {
            // MANUAL MODE
            // Ignore Signal Fault (Driver runs on sight)
            // Ignore MA (Driver responsibility, unless we want strict ATP intervention, but "Manual" implies override)
            
            if train.areDoorsOpen {
                // Cannot move with doors open
                let desiredAcc = (train.speed > 0) ? -maxBraking : 0.0
                train.status = (train.speed > 0) ? .moving : .docked
                applyPhysics(train: &train, acceleration: desiredAcc, trackLength: trackLength)
            } else {
                // Manual Throttle / Speed Hold
                let target = train.manualSpeedRequest
                var desiredAcc: CGFloat = 0.0
                
                if train.speed < target { desiredAcc = maxAcceleration }
                else if train.speed > target { desiredAcc = -maxBraking }
                else { desiredAcc = 0.0 }
                
                // Engine Fault still applies? Probably implies loss of power.
                if train.isEngineFault {
                    desiredAcc = (train.speed > 0) ? -0.1 : 0.0
                }
                
                train.status = (train.speed > 0) ? .moving : .stopped
                applyPhysics(train: &train, acceleration: desiredAcc, trackLength: trackLength)
            }
            
        } else {
            // AUTO MODE
            
            // DWELL Logic
            if train.isDwelling {
                train.dwellTimeRemaining -= timeStep
                if train.dwellTimeRemaining <= 0 {
                    // Depart — apply any remaining pax at once
                    train.passengerCount += train.paxRemaining
                    if train.passengerCount < 0 { train.passengerCount = 0 }
                    train.paxRemaining = 0
                    train.isDwelling = false
                    train.areDoorsOpen = false
                    train.status = .moving // Ready to move
                    train.lastPaxChange = 0
                    removePassengerNodes(for: train.id)
                    // lastServicedStationId is already set when dwell started
                } else {
                    // Continue Dwell — gradual pax exchange
                    if train.paxRemaining != 0 {
                        train.paxExchangeTimer -= timeStep
                        if train.paxExchangeTimer <= 0 {
                            // Move one passenger
                            if train.paxRemaining > 0 {
                                train.passengerCount += 1
                                train.paxRemaining -= 1
                            } else {
                                train.passengerCount -= 1
                                if train.passengerCount < 0 { train.passengerCount = 0 }
                                train.paxRemaining += 1
                            }
                            train.paxExchangeTimer = train.paxExchangeInterval
                        }
                    }
                    train.status = .docked
                    train.speed = 0
                    train.acceleration = 0
                    // No physics update needed, stay put
                    trains[index] = train
                    return
                }
            }
            
            // Station Approach / Stop Logic
            var distToStationStop: CGFloat? = nil
            var targetStationId: UUID? = nil
            
            for station in stations {
                // If we haven't just serviced this station
                if train.lastServicedStationId != station.id {
                    let d = distanceTo(target: station.position, from: train.position, trackLength: trackLength)
                    
                    // If we are close (e.g. < 150m) and approaching
                    if d >= -5.0 && d < 150.0 {
                        // Check if this station is closer than any other we found
                        if distToStationStop == nil || d < distToStationStop! {
                            distToStationStop = d
                            targetStationId = station.id
                        }
                    }
                }
            }
            
            // If we need to stop at a station, limit MA-like behavior
            if let dist = distToStationStop, let stationId = targetStationId {
                // Treat station as a red signal at dist 0
                if dist < effectiveDistToMA {
                    effectiveDistToMA = dist
                }
                
                // Trigger Dwell if stopped at station
                if dist < 0.5 && abs(train.speed) < 0.1 {
                    // ARRIVED
                    train.isDwelling = true
                    let dwellTime = Double.random(in: 5.0...10.0)
                    train.dwellTimeRemaining = dwellTime
                    train.areDoorsOpen = true
                    train.status = .docked
                    train.speed = 0
                    train.lastServicedStationId = stationId
                    
                    // Passenger Exchange — set up gradual change
                    let change = Int.random(in: -10...20)
                    train.lastPaxChange = change
                    train.paxRemaining = change
                    // Spread pax changes across ~60% of dwell time (matching animation stagger)
                    let exchangeWindow = dwellTime * 0.6
                    train.paxExchangeInterval = abs(change) > 0 ? exchangeWindow / Double(abs(change)) : 1.0
                    train.paxExchangeTimer = 0.0 // First pax exchanges immediately on next tick
                    
                    // Spawn walking passenger animation
                    if let station = stations.first(where: { $0.id == stationId }) {
                        spawnPassengerAnimation(for: train, at: station, change: change)
                    }
                    
                    trains[index] = train
                    return
                }
            } else {
                // If we are far from the last serviced station, reset it so we can stop there again next lap
                // Simple logic: if closest station is > 200m away, reset lastServiced? 
                // Better: if distance to lastServiced is large.
                if let lastId = train.lastServicedStationId, let lastStation = stations.first(where: { $0.id == lastId }) {
                    let dist = distanceTo(target: lastStation.position, from: train.position, trackLength: trackLength)
                    if dist > 200 { // We have left the station area
                        train.lastServicedStationId = nil
                    }
                }
            }
            
            // Signal Fault stops train in Auto
            if train.isSignalFault {
                effectiveDistToMA = 0
            }
            
            let safeBrakingDistance = (train.speed * train.speed) / (2 * maxBraking)
            var desiredAcc: CGFloat = 0.0
            
            if effectiveDistToMA < safeBrakingDistance + 0.5 { // +0.5m buffer
                // Safety Braking for MA or Station
                desiredAcc = -maxBraking
                if train.speed == 0 && effectiveDistToMA < 1.0 {
                     train.status = .stopped
                } else {
                    train.status = .moving
                }
            } else if train.isEngineFault {
                // Engine failure
                desiredAcc = (train.speed > 0) ? -0.1 : 0.0
                train.status = .moving
            } else if train.speed < train.targetSpeed {
                desiredAcc = maxAcceleration
                train.status = .moving
            } else if train.speed > train.targetSpeed {
                desiredAcc = -maxBraking
                train.status = .moving
            } else {
                desiredAcc = 0
                if train.speed == 0 { train.status = .stopped }
            }
            
            
            
            // Apply Adhesion Loss Logic
            var finalAcceleration = desiredAcc
            
            // Calculate Aggregate Tire Physics
            var totalAdhesionFactor: CGFloat = 0.0
            var totalDragDeceleration: CGFloat = 0.0
            
            for tire in train.tires {
                switch tire.status {
                case .ok:
                    totalAdhesionFactor += 1.0
                    totalDragDeceleration += 0.0
                case .lowPressure:
                    totalAdhesionFactor += 0.9
                    totalDragDeceleration += 0.05 // increased rolling resistance
                case .puncture:
                    totalAdhesionFactor += 0.5
                    totalDragDeceleration += 0.2 // significant drag
                case .burst:
                    totalAdhesionFactor += 0.1
                    totalDragDeceleration += 0.5 // massive drag / grinding
                }
            }
            
            // Average Adhesion (0.0 - 1.0)
            let avgAdhesion = totalAdhesionFactor / CGFloat(train.tires.count)
            
            // Apply traction limits
            if finalAcceleration > 0 {
                // Acceleration is limited by adhesion
                finalAcceleration *= avgAdhesion
            } else if finalAcceleration < 0 {
                // Braking is also limited by adhesion (ABS limit)
                finalAcceleration *= avgAdhesion
            }
            
            // Apply Glissement/Enrayage Global Faults if active (multiplicative)
            if train.isPatinage && finalAcceleration > 0 {
                 finalAcceleration *= 0.2
            }
            if train.isEnrayage && finalAcceleration < 0 {
                finalAcceleration *= 0.3
            }
            
            // Apply Tire Drag (always decelerates)
            // Only apply drag if moving
            if train.speed > 0 {
                finalAcceleration -= totalDragDeceleration
            } else if train.speed == 0 && finalAcceleration < totalDragDeceleration {
                // If stopped and trying to accelerate less than drag, we stay stopped
                // But if acceleration > drag, we move.
                if finalAcceleration < totalDragDeceleration {
                     finalAcceleration = 0
                } else {
                     finalAcceleration -= totalDragDeceleration
                }
            }
            
            applyPhysics(train: &train, acceleration: finalAcceleration, trackLength: trackLength)
        }

        // Update segment
        if let newSegment = trackSegments.first(where: { train.position >= $0.startPosition && train.position < $0.startPosition + $0.length }) {
             train.currentSegmentId = newSegment.id
        }
        
        trains[index] = train
    }
    
    private func applyPhysics(train: inout Train, acceleration: CGFloat, trackLength: CGFloat) {
        train.acceleration = acceleration
        train.speed += acceleration * CGFloat(timeStep)
        if train.speed < 0 { train.speed = 0 }
        
        train.position += train.speed * CGFloat(timeStep)
        train.position = train.position.truncatingRemainder(dividingBy: trackLength)
    }
    
    private func updateMovementAuthority(at index: Int) {
        // CBTC Logic using closest train ahead
        let trackLength = trackSegments.reduce(0.0) { $0 + $1.length }
        let myTrain = trains[index]
        
        // Find closest train ahead
        var minDist: CGFloat = .greatestFiniteMagnitude
        var closestTrainValues: Train? = nil

        for other in trains {
            if other.id == myTrain.id { continue }
            
            var d = other.position - myTrain.position
            if d <= 0 { d += trackLength }
            
            if d < minDist {
                minDist = d
                closestTrainValues = other
            }
        }
        
        let safetyMargin: CGFloat = 50.0 // meters
        
        if let leader = closestTrainValues {
            var ma = leader.position - safetyMargin
            if ma < 0 { ma += trackLength }
            trains[index].movementAuthority = ma
        } else {
             // No leader (single train), full loop allowed minus margin for safety
             var ma = myTrain.position + trackLength - safetyMargin
             ma = ma.truncatingRemainder(dividingBy: trackLength)
             trains[index].movementAuthority = ma
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
            
            let id = UUID()
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
            currentSegmentId: trackSegments[0].id,
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
            currentSegmentId: trackSegments[3].id,
            status: .stopped
        )
        
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
