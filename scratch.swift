import Foundation

enum AppCommand: Codable {
    case startSimulation
    case stopSimulation
    case addTrain
    case removeTrain(id: UUID)
}

let encoder = JSONEncoder()
let data1 = try! encoder.encode(AppCommand.startSimulation)
print("Encoded startSimulation:", String(data: data1, encoding: .utf8)!)

do {
    let _ = try JSONDecoder().decode(AppCommand.self, from: data1)
    print("Decoded startSimulation successfully")
} catch {
    print("Decode startSimulation error:", error)
}
