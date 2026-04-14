import Foundation
import CoreGraphics

actor TrainOBCU {
    private var train: Train
    
    private var isPhysicsRunning: Bool = false
    private let timeStep: TimeInterval = 0.1
    private var physicsTask: Task<Void, Never>?
    
    private let trackSegments: [TrackSegment]
    private let stations: [Station]
    
    init(train: Train, trackSegments: [TrackSegment], stations: [Station]) {
        self.train = train
        self.trackSegments = trackSegments
        self.stations = stations
    }
    
    func start() {
        guard physicsTask == nil else { return }
        isPhysicsRunning = true
        physicsTask = Task {
            while !Task.isCancelled {
                if isPhysicsRunning {
                    updateLogic()
                }
                try? await Task.sleep(nanoseconds: UInt64(timeStep * 1_000_000_000))
            }
        }
    }
    
    func stop() {
        isPhysicsRunning = false
        physicsTask?.cancel()
        physicsTask = nil
    }
    
    func getTelemetry() -> Train {
        return train
    }
    
    func modifyTrain(_ mutation: (inout Train) -> Void) {
        mutation(&train)
    }
    
    func receiveMovementAuthority(targetSpeed: CGFloat, lma: CGFloat) {
        train.targetSpeed = targetSpeed
        train.movementAuthority = lma
    }
    
    func reverseDirection() {
        train.travelDirection = (train.travelDirection == .forward) ? .reverse : .forward
        train.speed = 0.0 // Ensure safety when reversing
        train.movementAuthority = train.position
    }
    
    func setEmergencyBrake(_ applied: Bool) {
        train.isEmergencyBrakeApplied = applied
        if applied {
            train.status = .emergency
        }
    }
    
    func toggleFault(type: FaultType, enabled: Bool) {
        switch type {
        case .door: train.isDoorFault = enabled
        case .engine: train.isEngineFault = enabled
        case .brake: train.isBrakeFault = enabled
        case .signal: train.isSignalFault = enabled
        }
    }
    
    func updatePhysicsToggles(patinage: Bool, enrayage: Bool) {
        train.isPatinage = patinage
        train.isEnrayage = enrayage
    }
    
    func setLoadShedding(_ active: Bool) { train.isLoadSheddingActive = active }
    func cycleTireStatus(at index: Int) { train.cycleTireStatus(at: index) }
    func addAlarm(_ alarm: Train.Alarm) { train.alarms.append(alarm) }
    func resolveAlarm(at index: Int) { train.alarms[index].isActive = false }
    
    // Auxiliary System Modifiers
    func updateMainVoltage(_ volts: Double) { train.mainVoltage = volts }
    func updateTraction(current: Double, torque: Double) { 
        train.tractionCurrent = current
        train.tractionTorque = torque
    }
    func updateCompressor(pressure: Double, running: Bool) {
        train.compressorPressure = pressure
        train.isCompressorRunning = running
    }
    func updateLighting(current: Double) { train.lightingCurrent = current }
    func updateTemperature(_ temp: Double) { train.interiorTemperature = temp }
    func updateStationName(_ name: String) { train.nextStationName = name }
    
    func updateStartup(state: Train.StartupState, time: TimeInterval) {
        train.startupState = state
        train.startupTime = time
    }
    
    // Core Actor Loop Thread
    private func updateLogic() {
        guard train.startupState == .ready else { return }
        
        let maxAcceleration: CGFloat = 1.0 // m/s²
        let maxBraking: CGFloat = 1.2    // m/s²
        let trackLength = trackSegments.reduce(0.0) { $0 + $1.length }
        
        // distToMA should use the unified distanceTo method because MA is an absolute point on the loop.
        // Wait, if MA is absolute point, LMA distance:
        var effectiveDistToMA = distanceTo(target: train.movementAuthority, from: train.position, trackLength: trackLength)
        if effectiveDistToMA < 0 { effectiveDistToMA += trackLength }
        
        // Critical Overrides
        if train.isDoorFault || train.isBrakeFault || train.isEmergencyBrakeApplied {
             train.status = .emergency
             applyPhysics(acceleration: -maxBraking, trackLength: trackLength)
             return
        }
        
        // Manual Mode Overrides
        if train.mode == .manual {
            if train.areDoorsOpen {
                train.status = (train.speed > 0) ? .moving : .docked
                applyPhysics(acceleration: (train.speed > 0) ? -maxBraking : 0.0, trackLength: trackLength)
            } else {
                let target = train.manualSpeedRequest
                var desiredAcc: CGFloat = 0.0
                if train.speed < target { desiredAcc = maxAcceleration }
                else if train.speed > target { desiredAcc = -maxBraking }
                else { desiredAcc = 0.0 }
                if train.isEngineFault {
                    desiredAcc = (train.speed > 0) ? -0.1 : 0.0
                }
                train.status = (train.speed > 0) ? .moving : .stopped
                applyPhysics(acceleration: desiredAcc, trackLength: trackLength)
            }
            return
        }
        
        // Automatic Mode Logic
        if train.isDwelling {
            train.dwellTimeRemaining -= timeStep
            if train.dwellTimeRemaining <= 0 {
                train.passengerCount += train.paxRemaining
                if train.passengerCount < 0 { train.passengerCount = 0 }
                train.paxRemaining = 0
                train.dwellTimeRemaining = 0 // Cap at zero
                
                // Only depart if not held by PCC interval logic
                if !train.isDepartureHold {
                    train.isDwelling = false
                    train.areDoorsOpen = false
                    train.status = .moving
                    train.lastPaxChange = 0
                }
            } else {
                if train.paxRemaining != 0 {
                    train.paxExchangeTimer -= timeStep
                    if train.paxExchangeTimer <= 0 {
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
                return
            }
        }
        
        // Target Station Resolution
        var distToStationStop: CGFloat? = nil
        var targetStationId: UUID? = nil
        
        for station in stations {
            if train.lastServicedStationId != station.id {
                let d = distanceTo(target: station.position, from: train.position, trackLength: trackLength)
                if d >= -5.0 && d < 150.0 {
                    if distToStationStop == nil || d < distToStationStop! {
                        distToStationStop = d
                        targetStationId = station.id
                    }
                }
            }
        }
        
        if let dist = distToStationStop, let stationId = targetStationId {
            if dist < effectiveDistToMA {
                effectiveDistToMA = dist
            }
            if dist <= 1.5 && abs(train.speed) < 0.1 {
                train.isDwelling = true
                let dwellTime = Double.random(in: 5.0...10.0)
                train.dwellTimeRemaining = dwellTime
                train.areDoorsOpen = true
                train.status = .docked
                train.speed = 0
                train.lastServicedStationId = stationId
                let change = Int.random(in: -10...20)
                train.lastPaxChange = change
                train.paxRemaining = change
                train.paxExchangeInterval = abs(change) > 0 ? (dwellTime * 0.6) / Double(abs(change)) : 1.0
                train.paxExchangeTimer = 0.0
                return
            }
        } else {
            if let lastId = train.lastServicedStationId, let lastStation = stations.first(where: { $0.id == lastId }) {
                let dist = distanceTo(target: lastStation.position, from: train.position, trackLength: trackLength)
                if dist > 200 { train.lastServicedStationId = nil }
            }
        }
        
        if train.isSignalFault {
            effectiveDistToMA = 0
        }
        
        let asservissement = AsservissementModule()
        let finalAcceleration = asservissement.process(
            train: &train,
            effectiveDistToMA: effectiveDistToMA,
            maxAcceleration: maxAcceleration
        )
        
        applyPhysics(acceleration: finalAcceleration, trackLength: trackLength)
        
        if let newSegment = trackSegments.first(where: { train.position >= $0.startPosition && train.position < $0.startPosition + $0.length }) {
             train.currentSegmentId = newSegment.id
        }
    }
    
    private func applyPhysics(acceleration: CGFloat, trackLength: CGFloat) {
        train.acceleration = acceleration
        train.speed += acceleration * CGFloat(timeStep)
        if train.speed < 0 { train.speed = 0 }
        
        train.position += train.speed * train.travelDirection.rawValue * CGFloat(timeStep)
        train.position = train.position.truncatingRemainder(dividingBy: trackLength)
        if train.position < 0 { train.position += trackLength }
    }
    
    private func distanceTo(target: CGFloat, from position: CGFloat, trackLength: CGFloat) -> CGFloat {
        var d = target - position
        if train.travelDirection == .reverse {
            d = position - target
        }
        if d < -trackLength / 2 { d += trackLength }
        else if d > trackLength / 2 { d -= trackLength }
        return d
    }
}
