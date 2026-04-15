import SwiftUI

struct TrainAuxiliaryView: View {
    @Environment(\.dynamicScale) var dynamicScale

    let train: Train
    @Binding var selectedSystem: String?
    let onBack: () -> Void
    @EnvironmentObject var simulationController: ClientNetworkService
    
    // Retro font simulation
    
    // Retro font simulation
    private let fontName = "VT323-Regular"
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text(.init(String.loc("btn.retour")))
                    }
                    .font(.custom(fontName, size: 18 * dynamicScale))
                    .foregroundColor(.black)
                    .padding(4)
                    .background(Color.green)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                Text(.init(String.loc("tab.auxiliaires")))
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
            
            // Synoptic Diagram
            GeometryReader { geometry in
                ZStack {
                    // Background Lines (Wiring) - Updated for Third Rail (Side/Bottom)
                    Path { path in
                        let w = geometry.size.width
                        let h = geometry.size.height
                        
                        // Third Rail Inputs (Sides)
                        path.move(to: CGPoint(x: 0, y: h * 0.8)) // Left Shoe
                        path.addLine(to: CGPoint(x: w * 0.1, y: h * 0.8))
                        path.addLine(to: CGPoint(x: w * 0.1, y: h * 0.2)) // Up to bus
                        
                        path.move(to: CGPoint(x: w, y: h * 0.8)) // Right Shoe
                        path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.8))
                        path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.2)) // Up to bus
                        
                        // Main 750V Bus Line (Top)
                        path.move(to: CGPoint(x: w * 0.1, y: h * 0.2))
                        path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.2))
                        
                        // Drop to CVS
                        path.move(to: CGPoint(x: w * 0.3, y: h * 0.2))
                        path.addLine(to: CGPoint(x: w * 0.3, y: h * 0.375)) // To Center of CVS
                        
                        // Drop to Compressor
                        path.move(to: CGPoint(x: w * 0.7, y: h * 0.2))
                        path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.375)) // To Center of Compressor
                        
                        // CVS Output (112V)
                        path.move(to: CGPoint(x: w * 0.3, y: h * 0.375)) // From Center of CVS
                        path.addLine(to: CGPoint(x: w * 0.3, y: h * 0.6))
                        
                        // Battery Connection
                        path.move(to: CGPoint(x: w * 0.3, y: h * 0.6))
                        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.6)) // To Battery
                         path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.6)) // To Low Voltage Bus
                         
                        // Low Voltage Bus
                        path.move(to: CGPoint(x: w * 0.15, y: h * 0.6))
                        path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.8))
                        
                        // Load Shedding Contact (Simulation)
                        // If load shedding, show open circuit?
                        
                        // Loads from Low Voltage
                        path.move(to: CGPoint(x: w * 0.15, y: h * 0.8))
                        path.addLine(to: CGPoint(x: w * 0.1, y: h * 0.8)) // Horizontal
                        path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.8)) // Horizontal
                        
                        // Drops to Eclairage / Ventilation
                        path.move(to: CGPoint(x: w * 0.1, y: h * 0.8))
                        path.addLine(to: CGPoint(x: w * 0.1, y: h * 0.85)) // To Light
                        
                        path.move(to: CGPoint(x: w * 0.2, y: h * 0.8))
                        path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.85)) // To Vent
                        
                    }
                    .stroke(Color.green, lineWidth: 2)
                    
                    // Components
                    
                    // Third Rail Shoes
                    SynopticComponent(label: "FROTTEUR G", value: String(format: "%.0fV", train.mainVoltage), color: .red, x: 0.05, y: 0.8, geometry: geometry)
                        .onTapGesture { withAnimation { selectedSystem = "CAPTAGE 750V" } }
                    SynopticComponent(label: "FROTTEUR D", value: String(format: "%.0fV", train.mainVoltage), color: .red, x: 0.95, y: 0.8, geometry: geometry)
                        .onTapGesture { withAnimation { selectedSystem = "CAPTAGE 750V" } }

                    
                    // CVS
                    SynopticBox(label: "CVS", status: "ACTIF", color: .blue, x: 0.3, y: 0.375, width: 80, height: 50, geometry: geometry, isSelected: selectedSystem == "CVS")
                        .onTapGesture { withAnimation { selectedSystem = "CVS" } }
                    
                    // Compressor
                    SynopticBox(label: "GROUPE MA", status: train.isCompressorRunning ? "ON" : "OFF", color: train.isCompressorRunning ? .green : .gray, x: 0.7, y: 0.375, width: 90, height: 50, geometry: geometry, isSelected: selectedSystem == "COMPRESSEUR")
                        .onTapGesture { withAnimation { selectedSystem = "COMPRESSEUR" } }
                    
                    // Battery
                     SynopticBox(label: "BATTERIE", status: String(format: "%.1fV", train.batteryVoltage), color: .blue, x: 0.5, y: 0.6, width: 80, height: 50, geometry: geometry, isSelected: selectedSystem == "BATTERIE")
                        .onTapGesture { withAnimation { selectedSystem = "BATTERIE" } }

                    // Load Shedding
                    SynopticBox(label: "DELESTAGE BT", status: train.isLoadSheddingActive ? "ACTIF" : "INACTIF", color: train.isLoadSheddingActive ? .red : .gray, x: 0.15, y: 0.7, width: 80, height: 40, geometry: geometry, isSelected: selectedSystem == "DELESTAGE BT")
                        .onTapGesture { withAnimation { selectedSystem = "DELESTAGE BT" } }
                    
                    // Lights
                    SynopticLoad(label: "ECLAIRAGE", active: train.areLightsOn, x: 0.1, y: 0.85, geometry: geometry)
                        .onTapGesture { withAnimation { selectedSystem = "ECLAIRAGE" } }
                    
                    // Ventilation
                    SynopticLoad(label: "VENTILATION", active: train.areVentilated, x: 0.2, y: 0.85, geometry: geometry)
                        .onTapGesture { withAnimation { selectedSystem = "VENTILATION" } }
                    
                    // Pressure Tank
                    SynopticTank(label: "RESERVOIR PRINCIPAL", value: String(format: "%.1f bar", train.compressorPressure), x: 0.7, y: 0.6, geometry: geometry)
                         .onTapGesture { withAnimation { selectedSystem = "GROUPE MA" } }
                    
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
                    
                    // Mock Detail Data based on system
                    Group {
                        if system == "CAPTAGE 750V" {
                            detailRow(label: "TENSION LIGNE", value: "\(Int(train.mainVoltage)) V")
                            detailRow(label: "INTENSITE", value: "120 A")
                            detailRow(label: "FROTTEUR G", value: "ACTIF")
                            detailRow(label: "FROTTEUR D", value: "ACTIF")
                        } else if system == "CVS" {
                            detailRow(label: "ENTREE", value: "\(Int(train.mainVoltage)) V")
                            detailRow(label: "SORTIE", value: "\(Int(train.cvsOutputVoltage)) V")
                            detailRow(label: "TEMPERATURE", value: "45°C")
                            detailRow(label: "CHARGE", value: "65%")
                        } else if system == "COMPRESSEUR" {
                            detailRow(label: "ETAT", value: train.isCompressorRunning ? "MARCHE" : "ARRET")
                            detailRow(label: "PRESSION", value: String(format: "%.1f bar", train.compressorPressure))
                            detailRow(label: "HUILE", value: "OK")
                            detailRow(label: "VIBRATION", value: "NORMAL")
                        } else if system == "BATTERIE" {
                            detailRow(label: "TENSION", value: "\(train.batteryVoltage) V")
                            detailRow(label: "COURANT", value: "+12 A")
                            detailRow(label: "CHARGE", value: "92%")
                            detailRow(label: "TEMP", value: "22°C")
                        } else if system == "ECLAIRAGE" {
                             detailRow(label: "TENSION", value: String(format: "%.0fV DC", train.cvsOutputVoltage)) // Use CVS output
                             detailRow(label: "INTENSITE", value: String(format: "%.1f A", train.lightingCurrent))
                             detailRow(label: "CIRCUIT A", value: "OK")
                             detailRow(label: "CIRCUIT B", value: "OK")
                        } else if system == "VENTILATION" {
                             detailRow(label: "MODE", value: "CLIMATISATION")
                             detailRow(label: "CONSIGNE", value: String(format: "%.0f°C", train.targetTemperature))
                             detailRow(label: "TEMP INT.", value: String(format: "%.1f°C", train.interiorTemperature))
                             detailRow(label: "TEMP INT.", value: String(format: "%.1f°C", train.interiorTemperature))
                             detailRow(label: "VENTILATEURS", value: "MARCHE")
                        } else if system == "GROUPE MA" {
                             detailRow(label: "ETAT", value: train.isCompressorRunning ? "MARCHE" : "ARRET")
                             detailRow(label: "PRESSION CP", value: String(format: "%.1f bar", train.compressorPressure))
                             detailRow(label: "TENSION", value: String(format: "%.0fV", train.mainVoltage))
                             detailRow(label: "COURANT", value: train.isCompressorRunning ? "15 A" : "0 A")
                        } else if system == "DELESTAGE BT" {
                             detailRow(label: "ETAT", value: train.isLoadSheddingActive ? "ACTIF" : "INACTIF")
                             detailRow(label: "ECLAIRAGE", value: train.isLoadSheddingActive ? "REDUIT" : "NORMAL")
                             detailRow(label: "VENTILATION", value: train.isLoadSheddingActive ? "ARRET" : "MARCHE")
                             
                             // Interactive Toggle
                             Button(action: {
                                simulationController.executeCommand("DELESTAGE BT", for: train.id)
                             }) {
                                 Text(train.isLoadSheddingActive ? "DESACTIVER" : "ACTIVER")
                                     .font(.custom(fontName, size: 14 * dynamicScale))
                                     .foregroundColor(train.isLoadSheddingActive ? .red : .green)
                                     .padding(4)
                                     .overlay(RoundedRectangle(cornerRadius: 4).stroke(train.isLoadSheddingActive ? Color.red : Color.green))
                             }
                             .buttonStyle(PlainButtonStyle())
                        } else {
                             Text(.init(String.loc("label.no_data")))
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

    
    private func parseTrainID(_ name: String) -> String {
        return name.components(separatedBy: " ").last ?? "000"
    }
    
    // Sub-components for the diagram
    struct SynopticComponent: View {
    @Environment(\.dynamicScale) var dynamicScale

        let label: String
        let value: String
        let color: Color
        let x: CGFloat
        let y: CGFloat
        let geometry: GeometryProxy
        
        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.custom("VT323-Regular", size: 12 * dynamicScale)).foregroundColor(.green)
                Text(value).font(.custom("VT323-Regular", size: 14 * dynamicScale)).fontWeight(.bold).foregroundColor(color)
            }
            .position(x: geometry.size.width * x, y: geometry.size.height * y - 30)
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
    
    struct SynopticLoad: View {
    @Environment(\.dynamicScale) var dynamicScale

        let label: String
        let active: Bool
        let x: CGFloat
        let y: CGFloat
        let geometry: GeometryProxy
        
        var body: some View {
            VStack(spacing: 2) {
                Circle()
                    .stroke(Color.green, lineWidth: 1)
                    .background(active ? Color.green.opacity(0.3) : Color.black)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text(.init(String.loc("btn.close_x")))
                            .font(.system(size: 12 * dynamicScale, weight: .bold))
                            .foregroundColor(active ? .green : .gray)
                    )
                Text(label).font(.custom("VT323-Regular", size: 10 * dynamicScale)).foregroundColor(.green)
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
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.green, lineWidth: 1)
                    .frame(width: 60, height: 30)
                    .overlay(Text(value).font(.custom("VT323-Regular", size: 14 * dynamicScale)).foregroundColor(.blue))
                Text(label).font(.custom("VT323-Regular", size: 10 * dynamicScale)).foregroundColor(.green)
            }
            .position(x: geometry.size.width * x, y: geometry.size.height * y)
        }
    }
}
