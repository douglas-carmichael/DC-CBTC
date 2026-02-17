import SwiftUI

struct TrainDCAView: View {
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
                    .font(.custom(fontName, size: 18))
                    .foregroundColor(.black)
                    .padding(4)
                    .background(Color.green)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                Text("ETAT DCA / AUTOMATISMES")
                    .font(.custom(fontName, size: 32))
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Spacer()
                Text(parseTrainID(train.name))
                    .font(.custom(fontName, size: 32))
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            .padding(8)
            .background(Color.black)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.white), alignment: .bottom)
            
            GeometryReader { geometry in
                ZStack {
                    // Draw Automation Logic Flow
                    Path { path in
                        let w = geometry.size.width
                        let h = geometry.size.height
                        
                        // Vertical Flow line
                        path.move(to: CGPoint(x: w * 0.5, y: h * 0.15))
                        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.85))
                        
                        // Connectors to boxes
                        path.move(to: CGPoint(x: w * 0.5, y: h * 0.3))
                        path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.3)) // To Traction Cmd
                        
                        path.move(to: CGPoint(x: w * 0.5, y: h * 0.7))
                        path.addLine(to: CGPoint(x: w * 0.3, y: h * 0.7)) // To Door Cmd
                    }
                    .stroke(Color.green, lineWidth: 2)
                    
                    // Components
                    
                    // Master Scheduler / Program
                    SynopticBox(label: "LOGIQUE PA", status: train.mode == .auto ? "ACTIF" : "OFF", color: .blue, x: 0.5, y: 0.15, width: 140, height: 60, geometry: geometry, isSelected: selectedSystem == "LOGIQUE PA")
                        .onTapGesture { withAnimation { selectedSystem = "LOGIQUE PA" } }
                    
                    // Traction Command Interface
                    SynopticBox(label: "CDE TRACTION", status: train.acceleration > 0 ? "ACCEL" : "NEUTRE", color: .blue, x: 0.8, y: 0.3, width: 120, height: 60, geometry: geometry, isSelected: selectedSystem == "CDE TRACTION")
                        .onTapGesture { withAnimation { selectedSystem = "CDE TRACTION" } }
                    
                    // Station Module
                    SynopticBox(label: "MODULE STATION", status: train.speed == 0 ? "A QUAI" : "EN LIGNE", color: .white, x: 0.5, y: 0.5, width: 140, height: 60, geometry: geometry, isSelected: selectedSystem == "MODULE STATION")
                        .onTapGesture { withAnimation { selectedSystem = "MODULE STATION" } }

                    // Door Command Interface
                    SynopticBox(label: "CDE PORTES", status: train.areDoorsOpen ? "OUVERTURE" : "VERROU", color: train.areDoorsOpen ? .green : .white, x: 0.2, y: 0.7, width: 120, height: 60, geometry: geometry, isSelected: selectedSystem == "CDE PORTES")
                        .onTapGesture { withAnimation { selectedSystem = "CDE PORTES" } }
                    
                    // Safety / Emergency
                    SynopticBox(label: "BOUCLE SECURITE", status: "FERMEE", color: .green, x: 0.5, y: 0.85, width: 140, height: 40, geometry: geometry, isSelected: selectedSystem == "BOUCLE SEC")
                         .onTapGesture { withAnimation { selectedSystem = "BOUCLE SEC" } }
                    
                    
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
                            .font(.custom(fontName, size: 24))
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
                        if system == "LOGIQUE PA" {
                             detailRow(label: "PROGRAMME", value: "NORMAL")
                             detailRow(label: "SEQUENCE", value: train.speed > 0 ? "MARCHE" : "STATION")
                             detailRow(label: "REGULATION", value: "0 sec")
                        } else if system == "CDE TRACTION" {
                             detailRow(label: "ORDRE", value: train.acceleration > 0 ? "+0.8 m/s2" : "0.0")
                             detailRow(label: "DERIVEE", value: "OK")
                             detailRow(label: "LIMITATION", value: "NON")
                        } else if system == "MODULE STATION" {
                             detailRow(label: "DETECTION", value: train.speed == 0 ? "OUI" : "NON")
                             detailRow(label: "ALIGNEMENT", value: train.speed == 0 ? "OK" : "--")
                             detailRow(label: "TEMPS STATION", value: "20 sec")
                        } else if system == "CDE PORTES" {
                             detailRow(label: "AUTORISATION", value: train.speed == 0 ? "OUI" : "NON")
                             detailRow(label: "CDE OUVERTURE", value: train.areDoorsOpen ? "1" : "0")
                             detailRow(label: "CDE FERMETURE", value: train.areDoorsOpen ? "0" : "1")
                        } else if system == "BOUCLE SEC" {
                             detailRow(label: "ETAT GLOBAL", value: "OK")
                             detailRow(label: "URGENCE PCC", value: "NON")
                             detailRow(label: "VACMA", value: "INACTIF")
                        } else {
                             Text("Pas de donnees.")
                                .font(.custom(fontName, size: 14))
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
            Text(label).font(.custom(fontName, size: 16)).foregroundColor(.black)
            Spacer()
            Text(value).font(.custom(fontName, size: 16)).fontWeight(.bold).foregroundColor(.black)
        }
    }
    
    struct SynopticBox: View {
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
                    Text(label).font(.custom("VT323-Regular", size: 14)).foregroundColor(.green)
                    Text(status).font(.custom("VT323-Regular", size: 14)).foregroundColor(color)
                }
            }
            .position(x: geometry.size.width * x, y: geometry.size.height * y)
        }
    }
}
