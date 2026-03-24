import SwiftUI

struct SynopticView: View {
    @EnvironmentObject var simulationController: ClientNetworkService
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text("TCO - TABLEAU DE CONTROLE OPTIQUE")
                    .font(.custom("VT323-Regular", size: 24))
                    .foregroundColor(.green)
                Spacer()
                ClockView(fontName: "VT323-Regular", size: 18, color: .green)
                    .padding(.trailing)
            }
            .padding()
            .background(Color.black)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.green), alignment: .bottom)
            
            // Canvas
            GeometryReader { geometry in
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    // Main Drawing Canvas
                    Canvas { context, size in
                        // Calculate Bounding Box of the Track
                        let segments = simulationController.trackSegments
                        guard !segments.isEmpty else { return }
                        
                        var minX: CGFloat = .greatestFiniteMagnitude
                        var maxX: CGFloat = -.greatestFiniteMagnitude
                        var minY: CGFloat = .greatestFiniteMagnitude
                        var maxY: CGFloat = -.greatestFiniteMagnitude
                        
                        for segment in segments {
                            minX = min(minX, segment.startPoint.x, segment.endPoint.x)
                            maxX = max(maxX, segment.startPoint.x, segment.endPoint.x)
                            minY = min(minY, segment.startPoint.y, segment.endPoint.y)
                            maxY = max(maxY, segment.startPoint.y, segment.endPoint.y)
                        }
                        
                        let trackWidth = maxX - minX
                        let trackHeight = maxY - minY
                        
                        // Add padding
                        let padding: CGFloat = 50.0
                        let totalWidth = trackWidth + (padding * 2)
                        let totalHeight = trackHeight + (padding * 2)
                        
                        // Calculate Scale to Fit
                        let scaleX = size.width / totalWidth
                        let scaleY = size.height / totalHeight
                        let scale = min(scaleX, scaleY)
                        
                        // Center the content
                        let drawingWidth = trackWidth * scale
                        let drawingHeight = trackHeight * scale
                        
                        let xOffset = (size.width - drawingWidth) / 2 - (minX * scale)
                        let yOffset = (size.height - drawingHeight) / 2 - (minY * scale)
                        
                        context.translateBy(x: xOffset, y: yOffset)
                        context.scaleBy(x: scale, y: scale)
                        
                        // 1. Draw Track Segments
                        for segment in segments {
                            let path = Path { p in
                                p.move(to: segment.startPoint)
                                p.addLine(to: segment.endPoint)
                            }
                            
                            // Determine color based on occupancy
                            var strokeColor = Color.gray
                            if segment.isOccupied {
                                strokeColor = .red
                            } else {
                                strokeColor = .white.opacity(0.3)
                            }
                            
                            context.stroke(path, with: .color(strokeColor), lineWidth: 4)
                        }
                        
                        // 2. Draw Stations
                        for station in simulationController.stations {
                            // Find segment station is on to get position
                            if let point = getPointOnTrack(at: station.position, segments: simulationController.trackSegments) {
                                let rect = CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20)
                                context.fill(Path(rect), with: .color(.blue.opacity(0.5)))
                                context.stroke(Path(rect), with: .color(.blue), lineWidth: 1)
                                
                                // Label - Draw in screen space to avoid scaling text too small/large? 
                                // Actually, canvas text drawing is affected by transform.
                                // Let's simplify and draw text with inverted scale or just standard size?
                                // If we scale everything, text scales too.
                                // Better: Draw text at transformed position.
                                
                                let text = Text(station.name)
                                    .font(.custom("VT323-Regular", size: 16)) // Fixed font size
                                    .foregroundColor(.white)
                                
                                // We offset y by -20 / scale to maintain constant visual distance?
                                // Or simpler: Just draw.
                                context.draw(text, at: CGPoint(x: point.x, y: point.y - 20))
                            }
                        }
                        
                        // 3. Draw Trains
                        for train in simulationController.trains {
                            if let transform = getTransformOnTrack(at: train.position, segments: simulationController.trackSegments) {
                                // Create a local context for the train to apply rotation without affecting others
                                var trainContext = context
                                trainContext.translateBy(x: transform.position.x, y: transform.position.y)
                                trainContext.rotate(by: transform.rotation)
                                
                                // Train dimensions in track space
                                // Width = length of train, Height = visual width (e.g. 10 units/meters?)
                                let trainHeight: CGFloat = 8.0 
                                let trainRect = CGRect(x: -train.length / 2, y: -trainHeight / 2, width: train.length, height: trainHeight)
                                
                                var trainColor: Color = .green
                                switch train.status {
                                case .stopped: trainColor = .orange
                                case .emergency: trainColor = .red
                                case .docked: trainColor = .blue
                                default: trainColor = .green
                                }
                                
                                trainContext.fill(Path(roundedRect: trainRect, cornerRadius: 2), with: .color(trainColor))
                                
                                // Direction Indicator (Arrow at front)
                                let arrowPath = Path { p in
                                    p.move(to: CGPoint(x: train.length / 2 - 2, y: -trainHeight / 2))
                                    p.addLine(to: CGPoint(x: train.length / 2 + 2, y: 0))
                                    p.addLine(to: CGPoint(x: train.length / 2 - 2, y: trainHeight / 2))
                                }
                                trainContext.fill(arrowPath, with: .color(.white))
                                
                                // ID Label - Draw non-rotated? 
                                // If we want it readable, maybe better to draw it in main context using position?
                                // But then it might overlap complex track. 
                                // Let's draw it above the train in the rotated context for now, or just standard.
                                // Actually, let's draw it in the main context to keep it horizontal.
                                let idText = Text(train.name.replacingOccurrences(of: "Rame ", with: ""))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                
                                // Draw text at position (unrotated)
                                context.draw(idText, at: CGPoint(x: transform.position.x, y: transform.position.y - 10))
                            }
                        }
                        
                    }
                }
            }
        }
    }
    
    // Helper to map linear position to 2D Point
    func getPointOnTrack(at position: CGFloat, segments: [TrackSegment]) -> CGPoint? {
        let trackLength = segments.reduce(0.0) { $0 + $1.length }
        let normalizedPos = position.truncatingRemainder(dividingBy: trackLength)
        
        for segment in segments {
            if normalizedPos >= segment.startPosition && normalizedPos <= (segment.startPosition + segment.length) {
                // Found it
                let localDist = normalizedPos - segment.startPosition
                let progress = localDist / segment.length
                
                let dx = segment.endPoint.x - segment.startPoint.x
                let dy = segment.endPoint.y - segment.startPoint.y
                
                return CGPoint(
                    x: segment.startPoint.x + dx * progress,
                    y: segment.startPoint.y + dy * progress
                )
            }
        }
        
        if let first = segments.first, normalizedPos < 1.0 {
             return first.startPoint
        }
        
        return nil
    }
    
    // Helper to map linear position to 2D Point and Rotation
    func getTransformOnTrack(at position: CGFloat, segments: [TrackSegment]) -> (position: CGPoint, rotation: Angle)? {
        let trackLength = segments.reduce(0.0) { $0 + $1.length }
        let normalizedPos = position.truncatingRemainder(dividingBy: trackLength)
        
        for segment in segments {
            if normalizedPos >= segment.startPosition && normalizedPos <= (segment.startPosition + segment.length) {
                // Found it
                let localDist = normalizedPos - segment.startPosition
                let progress = localDist / segment.length
                
                let dx = segment.endPoint.x - segment.startPoint.x
                let dy = segment.endPoint.y - segment.startPoint.y
                
                let x = segment.startPoint.x + dx * progress
                let y = segment.startPoint.y + dy * progress
                
                let angle = atan2(dy, dx)
                
                return (CGPoint(x: x, y: y), Angle(radians: Double(angle)))
            }
        }
        
        if let first = segments.first {
             let dx = first.endPoint.x - first.startPoint.x
             let dy = first.endPoint.y - first.startPoint.y
             let angle = atan2(dy, dx)
             return (first.startPoint, Angle(radians: Double(angle)))
        }
        
        return nil
    }
}
