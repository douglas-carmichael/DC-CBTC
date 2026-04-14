import Foundation
import CoreGraphics

struct Train: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String // "Rame 101"
    var length: CGFloat = 52.0 // Length in meters
    var position: CGFloat // Distance along the track in meters
    var speed: CGFloat // Current speed in m/s
    var acceleration: CGFloat // Current acceleration in m/s²
    var targetSpeed: CGFloat // Speed limit or target speed from PCC
    var movementAuthority: CGFloat // Limit of Movement Authority (LMA) in meters
    var currentSegmentId: UUID? // The ID of the track segment the train is currently on
    var status: TrainStatus
    
    enum TravelDirection: CGFloat, Codable {
        case forward = 1.0
        case reverse = -1.0
    }
    var travelDirection: TravelDirection = .forward
    
    // Fault Injection Flags
    var isDoorFault: Bool = false
    var isEngineFault: Bool = false
    var isBrakeFault: Bool = false
    var isSignalFault: Bool = false
    
    // Adhesion / Traction Faults
    var isPatinage: Bool = false // Wheel Slip (Acceleration)
    var isEnrayage: Bool = false // Wheel Slide (Braking)
    
    enum TrainStatus: String, CaseIterable, Codable {
        case stopped = "Arrêt"
        case moving = "En mouvement"
        case emergency = "Urgence"
        case docked = "À quai"
    }

    // Manual Control
    enum TrainMode: String, CaseIterable, Codable {
        case auto = "Automatique"
        case manual = "Manuel"
    }
    
    var mode: TrainMode = .auto
    var manualSpeedRequest: CGFloat = 0.0 // Requested speed in m/s (0-20)
    var areDoorsOpen: Bool = false
    var isEmergencyBrakeApplied: Bool = false
    
    // Startup Sequence
    enum StartupState: Int, CaseIterable, Equatable, Codable {
        case booting
        case memoryCheck     // Checking RAM
        case systemsCheck    // Checking Pneumatics, Electrics
        case radioConnect    // Connecting to PCC
        case ready           // Fully operational
    }
    
    var startupState: StartupState = .ready
    var startupTime: TimeInterval = 0.0 // Time spent in current startup state

    // Passenger & Station Logic
    var passengerCount: Int = 0
    var isDwelling: Bool = false
    var isDepartureHold: Bool = false // Held for interval pacing
    var dwellTimeRemaining: TimeInterval = 0.0
    var lastServicedStationId: UUID? = nil
    var lastPaxChange: Int = 0 // +boarding / -alighting at current stop
    var paxRemaining: Int = 0 // pax still to board (+) or alight (-)
    var paxExchangeInterval: TimeInterval = 0.0 // time between each pax change
    var paxExchangeTimer: TimeInterval = 0.0 // accumulator
    var nextStationName: String = "..."
    
    // Tire Status (VAL)
    struct Tire: Identifiable, Equatable, Codable {
        let id: Int
        var pressure: Double // Bars
        var status: TireStatus
        
        enum TireStatus: String, CaseIterable, Codable {
            case ok = "OK"
            case lowPressure = "PRESSION BASSE"
            case puncture = "CREVAISON"
            case burst = "ECLATEMENT"
        }
    }
    
    var tires: [Tire] = (1...8).map { Tire(id: $0, pressure: 9.0, status: .ok) }
    
    mutating func cycleTireStatus(at index: Int) {
        guard tires.indices.contains(index) else { return }
        switch tires[index].status {
        case .ok:
            tires[index].status = .lowPressure
            tires[index].pressure = 6.5
        case .lowPressure:
            tires[index].status = .puncture
            tires[index].pressure = 4.0
        case .puncture:
            tires[index].status = .burst
            tires[index].pressure = 0.0
        case .burst:
            tires[index].status = .ok
            tires[index].pressure = 9.0
        }
    }
    
    // Alarm Log
    struct Alarm: Identifiable, Equatable, Codable {
        let id: UUID
        let label: String        // e.g. "DEFAUT PORTES"
        let timestamp: Date      // When alarm was triggered
        var isActive: Bool       // Currently active or resolved
    }
    
    var alarms: [Alarm] = []
    
    // Auxiliary Systems (Synoptic Data)
    var mainVoltage: Double = 750.0 // V DC
    var batteryVoltage: Double = 76.5 // V DC (Charging)
    var cvsOutputVoltage: Double = 112.0 // V DC
    var compressorPressure: Double = 8.5 // bar
    var isCompressorRunning: Bool = false
    var areLightsOn: Bool = true
    var areVentilated: Bool = true
    
    // Real-Time Simulation Data
    var tractionCurrent: Double = 0.0 // Amperes (0-1500)
    var tractionTorque: Double = 0.0 // Percentage (-100 to 100)
    var lightingCurrent: Double = 15.0 // Amperes (base)
    var interiorTemperature: Double = 24.0 // Celsius
    var targetTemperature: Double = 22.0 // Celsius
    
    // Asservissement Telemetry
    var consigneVitesse: CGFloat = 0.0
    var speedError: CGFloat = 0.0
    var desiredAcceleration: CGFloat = 0.0
    var distanceToMA: CGFloat = 0.0
    
    // Command States
    var isLoadSheddingActive: Bool = false // DELESTAGE BT
    var isMultimediaResetting: Bool = false // RAZ MULTIMEDIA
    var emergencyBrakeCounter: Int = 0 // COMPTEUR FU
    var isVideoSystemInitialized: Bool = true // INIT. SYSTEME VIDEO
    var isSoundSystemActive: Bool = true // TEST SONORISATION
    
    // Archiving
    var isArchiving: Bool = false // ENR. ARCHIVAGE DAM
}
