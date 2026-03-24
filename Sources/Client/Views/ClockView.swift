import SwiftUI

struct ClockView: View {
    let fontName: String
    let size: CGFloat
    let color: Color
    
    // Static formatter for performance and consistency
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    init(fontName: String = "VT323-Regular", size: CGFloat = 18, color: Color = .green) {
        self.fontName = fontName
        self.size = size
        self.color = color
    }
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            Text(Self.formatter.string(from: context.date))
                .font(.custom(fontName, size: size))
                .foregroundColor(color)
        }
    }
}
