import SwiftUI

struct ClockView: View {
    @State private var currentDate = Date()
    let fontName: String
    let size: CGFloat
    let color: Color
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
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
        Text(Self.formatter.string(from: currentDate))
            .font(.custom(fontName, size: size))
            .foregroundColor(color)
            .onReceive(timer) { input in
                currentDate = input
            }
            .onAppear {
                currentDate = Date()
            }
    }
}
