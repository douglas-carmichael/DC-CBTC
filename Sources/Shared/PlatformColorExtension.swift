import SwiftUI

extension Color {
    #if os(macOS)
    static let platformControlBackground = Color(NSColor.controlBackgroundColor)
    static let platformWindowBackground = Color(NSColor.windowBackgroundColor)
    #else
    static let platformControlBackground = Color(UIColor.darkGray)
    static let platformWindowBackground = Color(UIColor.black)
    #endif
}
