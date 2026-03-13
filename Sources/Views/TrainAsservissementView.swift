import SwiftUI

struct TrainAsservissementView: View {
    @Environment(\.dynamicScale) var dynamicScale

    let train: Train
    let onBack: () -> Void
    @EnvironmentObject var simulationController: SimulationController
    
    // Retro font simulation
    private let fontName = "VT323-Regular"
    
    enum AsservissementNode: String {
        case consigne = "CONSIGNE"
        case regulateur = "REGULATEUR"
        case dynamique = "DYNAMIQUE"
        case effort = "EFFORT"
        case limite = "CIBLE MA"
    }
    
    @State private var selectedNode: AsservissementNode? = nil
    
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
                Text("ASSERVISSEMENT")
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
            
            // Content
            ZStack {
                Color.black
                
                // Connection Lines
                Path { path in
                    // Start from CIBLE MA (Top Left) and CONSIGNE (Top Center)
                    path.move(to: CGPoint(x: 200, y: 80))
                    path.addLine(to: CGPoint(x: 200, y: 140))
                    path.addLine(to: CGPoint(x: 400, y: 140))
                    
                    path.move(to: CGPoint(x: 400, y: 80))
                    path.addLine(to: CGPoint(x: 400, y: 160))
                    
                    // REGULATEUR (Center)
                    path.move(to: CGPoint(x: 400, y: 220))
                    path.addLine(to: CGPoint(x: 400, y: 260))
                    
                    // EFFORT to DYNAMIQUE
                    path.move(to: CGPoint(x: 400, y: 320))
                    path.addLine(to: CGPoint(x: 400, y: 360))
                    
                    // Feedback loop: DYNAMIQUE -> REGULATEUR
                    path.move(to: CGPoint(x: 400, y: 420))
                    path.addLine(to: CGPoint(x: 400, y: 450))
                    path.addLine(to: CGPoint(x: 600, y: 450))
                    path.addLine(to: CGPoint(x: 600, y: 190))
                    path.addLine(to: CGPoint(x: 460, y: 190))
                }
                .stroke(Color.green, lineWidth: 2)
                
                // Nodes
                AsservissementNodeView(
                    title: "CIBLE MA",
                    value: String(format: "%.1f m", train.distanceToMA),
                    valueColor: train.distanceToMA < 20 ? .red : .cyan,
                    isSelected: selectedNode == .limite,
                    action: { selectedNode = .limite }
                )
                .position(x: 200, y: 50)
                
                AsservissementNodeView(
                    title: "CONSIGNE",
                    value: String(format: "%.1f m/s", train.consigneVitesse),
                    valueColor: .cyan,
                    isSelected: selectedNode == .consigne,
                    action: { selectedNode = .consigne }
                )
                .position(x: 400, y: 50)
                
                AsservissementNodeView(
                    title: "REGULATEUR",
                    value: "PI",
                    valueColor: .blue,
                    isSelected: selectedNode == .regulateur,
                    action: { selectedNode = .regulateur }
                )
                .position(x: 400, y: 190)
                
                AsservissementNodeView(
                    title: "EFFORT",
                    value: String(format: "%+.2f m/s²", train.desiredAcceleration),
                    valueColor: train.desiredAcceleration < 0 ? .red : .blue,
                    isSelected: selectedNode == .effort,
                    action: { selectedNode = .effort }
                )
                .position(x: 400, y: 290)
                
                AsservissementNodeView(
                    title: "DYNAMIQUE",
                    value: String(format: "%.1f m/s", train.speed),
                    valueColor: .green,
                    isSelected: selectedNode == .dynamique,
                    action: { selectedNode = .dynamique }
                )
                .position(x: 400, y: 390)
                
                // Detail Panel
                if let node = selectedNode {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            AsservissementDetailPanel(node: node, train: train, onClose: {
                                selectedNode = nil
                            })
                            .padding()
                        }
                    }
                }
            }
        }
        .background(Color.black)
        .overlay(Rectangle().stroke(Color.green, lineWidth: 2))
    }
    
    private func parseTrainID(_ name: String) -> String {
        return name.components(separatedBy: " ").last ?? "000"
    }
}

// Subcomponents

struct AsservissementNodeView: View {
    @Environment(\.dynamicScale) var dynamicScale

    let title: String
    let value: String
    let valueColor: Color
    let isSelected: Bool
    let action: () -> Void
    
    private let fontName = "VT323-Regular"
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.custom(fontName, size: 16 * dynamicScale))
                    .foregroundColor(isSelected ? .white : .green)
                Text(value)
                    .font(.custom(fontName, size: 14 * dynamicScale))
                    .foregroundColor(valueColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? Color.white : Color.green, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AsservissementDetailPanel: View {
    @Environment(\.dynamicScale) var dynamicScale

    let node: TrainAsservissementView.AsservissementNode
    let train: Train
    let onClose: () -> Void
    
    private let fontName = "VT323-Regular"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("DETAIL: \(node.rawValue)")
                    .font(.custom(fontName, size: 18 * dynamicScale))
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 20 * dynamicScale))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 5)
            .overlay(Rectangle().frame(height: 2).foregroundColor(.black), alignment: .bottom)
            
            // Content
            VStack(spacing: 8) {
                switch node {
                case .consigne:
                    detailRow(label: "VITESSE CIBLE", value: String(format: "%.1f m/s", train.consigneVitesse))
                    detailRow(label: "LIMITE VITESSE", value: String(format: "%.1f m/s", train.distanceToMA < 50 ? 5.0 : 20.0))
                    detailRow(label: "MODE", value: train.mode == .manual ? "MANUEL" : "AUTOMATIQUE")
                case .regulateur:
                    detailRow(label: "ERREUR VIT", value: String(format: "%+.2f m/s", train.speedError))
                    detailRow(label: "GAIN P (Kp)", value: "0.8")
                    detailRow(label: "GAIN I (Ki)", value: "0.1")
                case .dynamique:
                    detailRow(label: "VITESSE RE...", value: String(format: "%.1f m/s", train.speed))
                    detailRow(label: "ACCEL ACT.", value: String(format: "%+.2f m/s²", train.acceleration))
                    detailRow(label: "PATINAGE", value: train.isPatinage ? "OUI" : "NON")
                    detailRow(label: "ENRAYAGE", value: train.isEnrayage ? "OUI" : "NON")
                case .effort:
                    detailRow(label: "ACC RETENUE", value: String(format: "%+.2f m/s²", train.desiredAcceleration))
                    detailRow(label: "TRACT/FREIN", value: train.desiredAcceleration > 0 ? "TRACTION" : "FREINAGE")
                    detailRow(label: "LIM. ADHER", value: "1.2 m/s²")
                case .limite:
                    detailRow(label: "DIST MA", value: String(format: "%.1f m", train.distanceToMA))
                    if let uuid = train.currentSegmentId?.uuidString {
                        detailRow(label: "CANTON", value: "C-\(uuid.prefix(4))")
                    } else {
                        detailRow(label: "CANTON", value: "---")
                    }
                }
            }
        }
        .padding()
        .frame(width: 250)
        .background(Color.green)
        .overlay(Rectangle().stroke(Color.white, lineWidth: 2))
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom(fontName, size: 14 * dynamicScale))
                .foregroundColor(.black)
            Spacer()
            Text(value)
                .font(.custom(fontName, size: 14 * dynamicScale))
                .fontWeight(.bold)
                .foregroundColor(.black)
        }
    }
}
