import Foundation

struct SystemTelemetry: Codable {
    let timestamp: Date
    let isRunning: Bool
    let isEmergencyState: Bool
    let trains: [Train]
}
