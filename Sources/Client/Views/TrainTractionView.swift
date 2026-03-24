import SwiftUI

struct TrainTractionView: View {
    @Environment(\.dynamicScale) var dynamicScale

    let train: Train
    @Binding var selectedSystem: String?
    let onBack: () -> Void
    
    // Retro font simulation
    private let fontName = "VT323-Regular"
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("RETOUR")
                    }
                    .font(.custom(fontName, size: 18 * dynamicScale))
                    .foregroundColor(.black)
                    .padding(4)
                    .background(Color.green)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                Text("TRACTION / FREINAGE")
                    .font(.custom(fontName, size: 32 * dynamicScale))
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Spacer()
                Text(parseTrainID(train.name))
                    .font(.custom(fontName, size: 32 * dynamicScale))
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            .padding(8)
            .background(Color.black)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.white), alignment: .bottom)
            
            GeometryReader { geometry in
                ZStack {
                    // Draw Bogies and Axles
                    Path { path in
                        let w = geometry.size.width
                        let h = geometry.size.height
                        
                        // Main Chassis Line
                        path.move(to: CGPoint(x: w * 0.1, y: h * 0.5))
                        path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.5))
                        
                        // Bogie 1 (Front)
                        path.move(to: CGPoint(x: w * 0.25, y: h * 0.3))
                        path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.7))
                        path.addRect(CGRect(x: w * 0.2, y: h * 0.4, width: w * 0.1, height: h * 0.2))
                        
                        // Bogie 2 (Rear)
                        path.move(to: CGPoint(x: w * 0.75, y: h * 0.3))
                        path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.7))
                        path.addRect(CGRect(x: w * 0.7, y: h * 0.4, width: w * 0.1, height: h * 0.2))
                    }
                    .stroke(Color.green, lineWidth: 2)
                    
                    // Components
                    
                    // Motor 1 (Front)
                    SynopticBox(label: "MOTEUR 1", status: train.acceleration > 0 ? "TRACTION" : (train.speed > 0 ? "ROUE LIBRE" : "ARRET"), color: train.isEngineFault ? .red : .blue, x: 0.25, y: 0.5, width: 100, height: 60, geometry: geometry, isSelected: selectedSystem == "MOTEUR 1")
                        .onTapGesture { withAnimation { selectedSystem = "MOTEUR 1" } }
                    
                    // Motor 2 (Rear)
                    SynopticBox(label: "MOTEUR 2", status: train.acceleration > 0 ? "TRACTION" : (train.speed > 0 ? "ROUE LIBRE" : "ARRET"), color: train.isEngineFault ? .red : .blue, x: 0.75, y: 0.5, width: 100, height: 60, geometry: geometry, isSelected: selectedSystem == "MOTEUR 2")
                        .onTapGesture { withAnimation { selectedSystem = "MOTEUR 2" } }
                    
                    // Brakes (Front Bogie)
                    SynopticLoad(label: "FREIN 1", active: train.isBrakeFault || train.isEmergencyBrakeApplied || train.speed == 0, x: 0.25, y: 0.3, geometry: geometry)
                         .onTapGesture { withAnimation { selectedSystem = "FREINAGE" } }
                    SynopticLoad(label: "FREIN 2", active: train.isBrakeFault || train.isEmergencyBrakeApplied || train.speed == 0, x: 0.25, y: 0.7, geometry: geometry)
                         .onTapGesture { withAnimation { selectedSystem = "FREINAGE" } }
                    
                    // Brakes (Rear Bogie)
                    SynopticLoad(label: "FREIN 3", active: train.isBrakeFault || train.isEmergencyBrakeApplied || train.speed == 0, x: 0.75, y: 0.3, geometry: geometry)
                         .onTapGesture { withAnimation { selectedSystem = "FREINAGE" } }
                    SynopticLoad(label: "FREIN 4", active: train.isBrakeFault || train.isEmergencyBrakeApplied || train.speed == 0, x: 0.75, y: 0.7, geometry: geometry)
                         .onTapGesture { withAnimation { selectedSystem = "FREINAGE" } }
                    
                    // Tires (Represented as small rectangles near wheels)
                    ForEach(train.tires) { tire in
                        // Calculate position based on ID (1-8)
                        // 1-4 Front, 5-8 Rear
                        // 1,2 Left Front; 3,4 Right Front
                        // 5,6 Left Rear; 7,8 Right Rear
                        let isFront = tire.id <= 4
                        let isLeft = (tire.id % 4 == 1) || (tire.id % 4 == 2)
                        
                        let baseX = isFront ? 0.2 : 0.7
                        let baseY = isLeft ? 0.2 : 0.8
                        
                        // Offset slightly for pairs
                        let offsetX = ((tire.id - 1) % 2) == 0 ? -0.05 : 0.05
                         
                        SynopticTank(label: "PNEU \(tire.id)", value: "\(Int(tire.pressure))b", x: baseX + offsetX, y: baseY, geometry: geometry)
                            .onTapGesture { withAnimation { selectedSystem = "PNEU \(tire.id)" } }
                    }
                    
                    // Status Text
                    VStack {
                        Text("VITESSE: \(String(format: "%.1f", train.speed * 3.6)) km/h")
                        Text("ACCEL: \(String(format: "%.2f", train.acceleration)) m/s²")
                    }
                    .font(.custom(fontName, size: 24 * dynamicScale))
                    .foregroundColor(.green)
                    .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.2)
                    
                }
            }
            .background(Color.black)
            
            // Detail Panel Overlay
            if let system = selectedSystem {
                detailPanel(for: system)
                    .transition(.move(edge: .trailing))
            }
        }
        .background(Color.black)
        .overlay(Rectangle().stroke(Color.green, lineWidth: 2))
    }
    
    private func parseTrainID(_ name: String) -> String {
        return name.components(separatedBy: " ").last ?? "000"
    }
    
    // Detailed drill-down view
    private func detailPanel(for system: String) -> some View {
        GeometryReader { geometry in
            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("DETAIL: \(system)")
                            .font(.custom(fontName, size: 24 * dynamicScale))
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        Spacer()
                        Button(action: { withAnimation { selectedSystem = nil } }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.bottom, 8)
                    .overlay(Rectangle().frame(height: 2).foregroundColor(.black), alignment: .bottom)
                    
                    // Data
                    Group {
                        if system.contains("MOTEUR") {
                            detailRow(label: "COUPLE", value: String(format: "%.0f %%", train.tractionTorque))
                            detailRow(label: "COURANT", value: String(format: "%.0f A", train.tractionCurrent))
                            detailRow(label: "TEMP", value: "65°C")
                            detailRow(label: "VITESSE ROT.", value: "\(Int(train.speed * 60)) RPM")
                        } else if system == "FREINAGE" {
                            detailRow(label: "PRESSION CYL.", value: train.isEmergencyBrakeApplied ? "8.0 bar" : (train.speed == 0 ? "3.0 bar" : (train.acceleration < 0 ? "4.5 bar" : "0.0 bar")))
                             detailRow(label: "ETAT GARNITURE", value: "OK")
                             detailRow(label: "TEMP DISQUE", value: train.acceleration < 0 ? "150°C" : "120°C")
                        } else if system.contains("PNEU") {
                             // Find tire
                             if let idStr = system.components(separatedBy: " ").last, let id = Int(idStr), let tire = train.tires.first(where: { $0.id == id }) {
                                 detailRow(label: "PRESSION", value: "\(tire.pressure) bar")
                                 detailRow(label: "ETAT", value: tire.status.rawValue)
                                 detailRow(label: "TEMP", value: "45°C")
                             }
                        } else {
                             Text("Pas de donnees.")
                                .font(.custom(fontName, size: 14 * dynamicScale))
                                .foregroundColor(.black)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .frame(width: 300)
                .background(Color.green.opacity(0.95))
                .overlay(Rectangle().stroke(Color.white, lineWidth: 2))
            }
        }
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.custom(fontName, size: 16 * dynamicScale)).foregroundColor(.black)
            Spacer()
            Text(value).font(.custom(fontName, size: 16 * dynamicScale)).fontWeight(.bold).foregroundColor(.black)
        }
    }
    
    // MARK: - Reused Sub-components (Ideally these should be shared)
    struct SynopticBox: View {
    @Environment(\.dynamicScale) var dynamicScale

        let label: String
        let status: String
        let color: Color
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let geometry: GeometryProxy
        var isSelected: Bool = false
        
        var body: some View {
            ZStack {
                Rectangle()
                    .stroke(isSelected ? Color.white : Color.green, lineWidth: isSelected ? 3 : 1)
                    .background(Color.black)
                    .frame(width: width, height: height)
                
                VStack(spacing: 2) {
                    Text(label).font(.custom("VT323-Regular", size: 14 * dynamicScale)).foregroundColor(.green)
                    Text(status).font(.custom("VT323-Regular", size: 14 * dynamicScale)).foregroundColor(color)
                }
            }
            .position(x: geometry.size.width * x, y: geometry.size.height * y)
        }
    }
    
    struct SynopticLoad: View {
    @Environment(\.dynamicScale) var dynamicScale

        let label: String
        let active: Bool
        let x: CGFloat
        let y: CGFloat
        let geometry: GeometryProxy
        
        var body: some View {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(active ? Color.red.opacity(0.7) : Color.black)
                    Circle()
                        .stroke(Color.green, lineWidth: 1)
                }
                .frame(width: 20, height: 20)
                Text(label)
                    .font(.custom("VT323-Regular", size: 10 * dynamicScale))
                    .foregroundColor(.green)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
            }
            .position(x: geometry.size.width * x, y: geometry.size.height * y)
        }
    }
    
    struct SynopticTank: View {
    @Environment(\.dynamicScale) var dynamicScale

        let label: String
        let value: String
        let x: CGFloat
        let y: CGFloat
        let geometry: GeometryProxy
        
        var body: some View {
            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.green, lineWidth: 1)
                    .frame(width: 40, height: 20)
                    .overlay(Text(value).font(.custom("VT323-Regular", size: 12 * dynamicScale)).foregroundColor(.blue))
                Text(label).font(.custom("VT323-Regular", size: 10 * dynamicScale)).foregroundColor(.green)
            }
            .position(x: geometry.size.width * x, y: geometry.size.height * y)
        }
    }
}
