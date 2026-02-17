import Foundation
import CoreGraphics

struct Station: Identifiable {
    let id: UUID
    var name: String
    var position: CGFloat // Global distance along the track
    var platformSide: PlatformSide
    
    enum PlatformSide {
        case left
        case right
        case center
    }
}
