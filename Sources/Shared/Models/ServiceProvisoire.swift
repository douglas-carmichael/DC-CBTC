import Foundation

struct ServiceProvisoire: Codable, Equatable {
    var startStationId: UUID
    var endStationId: UUID
    var intervalle: TimeInterval = 60.0 // Headway in seconds
}
