import Foundation

enum AppCommand: Codable {
    case startSimulation
    case stopSimulation
    case emergencyStop
    case toggleEmergencyStop
    case resetSimulation
    case addTrain
    case removeTrain(id: UUID)
    case executeTrainCommand(trainId: UUID, command: String)
    case setRandomFaultMode(isEnabled: Bool)
    case resetCamera
    case toggleTrainPhysics(trainId: UUID, patinage: Bool, enrayage: Bool)
    case cycleTireStatus(trainId: UUID, tireIndex: Int)
    case toggleFault(trainId: UUID, faultType: FaultType)
    case setServiceProvisoire(sp: ServiceProvisoire?)
    case setTrainMode(trainId: UUID, mode: Train.TrainMode)
    case setManualSpeed(trainId: UUID, speed: Double)
}

enum FaultType: String, Codable {
    case door
    case engine
    case brake
    case signal
}
