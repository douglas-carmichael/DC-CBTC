import SwiftUI

struct TrainOperationsView: View {
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
                Text("EXPLOITATION / PORTES")
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
                    // Draw Car Outline (Top Down)
                    Path { path in
                        let w = geometry.size.width
                        let h = geometry.size.height
                        
                        // Outline
                        let carRect = CGRect(x: w * 0.1, y: h * 0.3, width: w * 0.8, height: h * 0.4)
                        path.addRect(carRect)
                        
                        // Internal Dividers
                        path.move(to: CGPoint(x: w * 0.3, y: h * 0.3))
                        path.addLine(to: CGPoint(x: w * 0.3, y: h * 0.7))
                        
                        path.move(to: CGPoint(x: w * 0.5, y: h * 0.3))
                        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.7))
                        
                        path.move(to: CGPoint(x: w * 0.7, y: h * 0.3))
                        path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.7))
                    }
                    .stroke(Color.green, lineWidth: 2)
                    
                    // Components
                    
                    // Doors (Left Side - Top in diagram)
                    Group {
                        DoorView(label: "P1", isOpen: train.areDoorsOpen, isFault: train.isDoorFault, x: 0.2, y: 0.3, geometry: geometry, isSelected: selectedSystem == "PORTE 1")
                            .onTapGesture { withAnimation { selectedSystem = "PORTE 1" } }
                        DoorView(label: "P3", isOpen: train.areDoorsOpen, isFault: train.isDoorFault, x: 0.4, y: 0.3, geometry: geometry, isSelected: selectedSystem == "PORTE 3")
                            .onTapGesture { withAnimation { selectedSystem = "PORTE 3" } }
                        DoorView(label: "P5", isOpen: train.areDoorsOpen, isFault: train.isDoorFault, x: 0.6, y: 0.3, geometry: geometry, isSelected: selectedSystem == "PORTE 5")
                            .onTapGesture { withAnimation { selectedSystem = "PORTE 5" } }
                        DoorView(label: "P7", isOpen: train.areDoorsOpen, isFault: train.isDoorFault, x: 0.8, y: 0.3, geometry: geometry, isSelected: selectedSystem == "PORTE 7")
                            .onTapGesture { withAnimation { selectedSystem = "PORTE 7" } }
                    }
                    
                    // Doors (Right Side - Bottom in diagram)
                    Group {
                         DoorView(label: "P2", isOpen: train.areDoorsOpen, isFault: train.isDoorFault, x: 0.2, y: 0.7, geometry: geometry, isSelected: selectedSystem == "PORTE 2")
                            .onTapGesture { withAnimation { selectedSystem = "PORTE 2" } }
                         DoorView(label: "P4", isOpen: train.areDoorsOpen, isFault: train.isDoorFault, x: 0.4, y: 0.7, geometry: geometry, isSelected: selectedSystem == "PORTE 4")
                            .onTapGesture { withAnimation { selectedSystem = "PORTE 4" } }
                         DoorView(label: "P6", isOpen: train.areDoorsOpen, isFault: train.isDoorFault, x: 0.6, y: 0.7, geometry: geometry, isSelected: selectedSystem == "PORTE 6")
                            .onTapGesture { withAnimation { selectedSystem = "PORTE 6" } }
                         DoorView(label: "P8", isOpen: train.areDoorsOpen, isFault: train.isDoorFault, x: 0.8, y: 0.7, geometry: geometry, isSelected: selectedSystem == "PORTE 8")
                            .onTapGesture { withAnimation { selectedSystem = "PORTE 8" } }
                    }
                    
                    // Passengers
                    VStack {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 40 * dynamicScale))
                            .foregroundColor(.white)
                        Text("\(train.passengerCount)")
                            .font(.custom(fontName, size: 24 * dynamicScale))
                            .foregroundColor(.white)
                    }
                    .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.5)
                    .onTapGesture { withAnimation { selectedSystem = "PASSAGERS" } }
                    
                    // Exploitation Status
                    SynopticBox(label: "MODE EXP", status: "NOMINAL", color: .blue, x: 0.5, y: 0.85, width: 120, height: 40, geometry: geometry, isSelected: selectedSystem == "MODE EXP")
                        .onTapGesture { withAnimation { selectedSystem = "MODE EXP" } }

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
                         if system.contains("PORTE") {
                             detailRow(label: "ETAT", value: train.areDoorsOpen ? "OUVERTE" : "FERMEE")
                             detailRow(label: "VERROUILLAGE", value: train.areDoorsOpen ? "NON" : "OUI")
                             detailRow(label: "ISOLEMENT", value: "NON")
                             detailRow(label: "OBSTACLE", value: "NON")
                         } else if system == "PASSAGERS" {
                             detailRow(label: "CHARGE", value: "\(train.passengerCount)")
                             detailRow(label: "POIDS EST.", value: "\(train.passengerCount * 75) kg")
                             detailRow(label: "CONFORT", value: "NORMAL")
                         } else if system == "MODE EXP" {
                             detailRow(label: "SERVICE", value: "COMMERCIAL")
                             detailRow(label: "MISSION", value: "1234")
                             detailRow(label: "PROCHAIN ARRET", value: train.nextStationName)
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
    
    struct DoorView: View {
    @Environment(\.dynamicScale) var dynamicScale

        let label: String
        let isOpen: Bool
        let isFault: Bool
        let x: CGFloat
        let y: CGFloat
        let geometry: GeometryProxy
        var isSelected: Bool = false
        
        var body: some View {
            ZStack {
                // Door rect
                Rectangle()
                    .fill(isOpen ? Color.clear : (isFault ? Color.red.opacity(0.5) : Color.green.opacity(0.2)))
                    .border(isSelected ? Color.white : (isFault ? Color.red : Color.green), width: isSelected ? 3 : 1)
                    .frame(width: 40, height: 10)
                
                if isOpen {
                    // Draw "Open" brackets
                    Text("[    ]")
                        .font(.custom("VT323-Regular", size: 12 * dynamicScale))
                        .foregroundColor(.green)
                }
                
                Text(label)
                    .font(.custom("VT323-Regular", size: 10 * dynamicScale))
                    .foregroundColor(.green)
                    .offset(y: -15)
            }
            .position(x: geometry.size.width * x, y: geometry.size.height * y)
        }
    }
}
