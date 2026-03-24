import Foundation
import CoreGraphics

struct TrackSegment: Identifiable {
    let id: UUID
    var name: String // "Canton A1"
    var length: CGFloat // Length in meters
    var speedLimit: CGFloat // Max speed in m/s
    var startPosition: CGFloat // Global distance from the start of the line where this segment begins
    var isOccupied: Bool = false
    var nextSegmentId: UUID?
    var previousSegmentId: UUID?
    
    // Geometry for 3D rendering (simplified)
    var startPoint: CGPoint
    var endPoint: CGPoint
}
