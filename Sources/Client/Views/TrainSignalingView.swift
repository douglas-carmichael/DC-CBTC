import SwiftUI

struct TrainSignalingView: View {
    @Environment(\.dynamicScale) var dynamicScale

    let train: Train
    @Binding var selectedSystem: String?
    let onBack: () -> Void
    
    // Retro font simulation
    private let fontName = "VT323-Regular"
    
    // Detailed descriptions map
    private let descriptions: [String: String] = [
        "CANTON": "Identifiant du canton occupé par la rame.\nPermet la localisation précise sur la ligne.",
        "PA": "Niveau de Pilotage Automatique.\n4 = Automatisation intégrale (GoA4).",
        "TMD": "Transmission Machine-Describe.\nLien de communication bidirectionnel.",
        "PROCHAIN ARRET": "Prochaine station desservie.",
        "DISTANCE ARRET": "Distance estimée jusqu'au point d'arrêt en station.",
        "VITESSE": "Vitesse instantanée de la rame en km/h.",
        "MODE": "Mode de conduite actif (Automatique / Manuel)."
    ]
    
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
                Text(.init(String.loc("section.position_localisation")))
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
            
            .overlay(Rectangle().frame(height: 1).foregroundColor(.white), alignment: .bottom)
            
            ZStack(alignment: .bottom) {
                GeometryReader { geometry in
                    ZStack {
                        // Grid Layout
                        VStack(spacing: 20) {
                            // Row 1
                            HStack(spacing: 20) {
                                ParameterBox(label: "CANTON", value: String((train.currentSegmentId?.uuidString ?? "????").prefix(4)), status: .ok, selected: selectedSystem == "CANTON")
                                    .onTapGesture { selectedSystem = "CANTON" }
                                ParameterBox(label: "PA", value: "4", status: .ok, selected: selectedSystem == "PA")
                                    .onTapGesture { selectedSystem = "PA" }
                            }
                            
                            // Row 2
                            HStack(spacing: 20) {
                                ParameterBox(label: "TMD", value: "OK", status: .ok, selected: selectedSystem == "TMD")
                                    .onTapGesture { selectedSystem = "TMD" }
                                ParameterBox(label: "PROCHAIN ARRET", value: train.nextStationName, status: .neutral, selected: selectedSystem == "PROCHAIN ARRET")
                                    .onTapGesture { selectedSystem = "PROCHAIN ARRET" }
                            }
                            
                            // Row 3
                            HStack(spacing: 20) {
                                ParameterBox(label: "DISTANCE ARRET", value: train.isDwelling ? "A QUAI" : "EN COURS", status: .neutral, selected: selectedSystem == "DISTANCE ARRET")
                                    .onTapGesture { selectedSystem = "DISTANCE ARRET" }
                                ParameterBox(label: "VITESSE", value: String(format: "%.0f KM/H", train.speed * 3.6), status: .neutral, selected: selectedSystem == "VITESSE")
                                    .onTapGesture { selectedSystem = "VITESSE" }
                            }
                            
                            // Row 4
                            HStack(spacing: 20) {
                                ParameterBox(label: "MODE", value: train.mode == .manual ? "MANUEL" : "AUTO", status: train.mode == .manual ? .neutral : .ok, selected: selectedSystem == "MODE")
                                    .onTapGesture { selectedSystem = "MODE" }
                                Spacer()
                            }
                        }
                        .padding(40)
                    }
                }
                .background(Color.black)
                
                // Detail Panel Overlay
                if let system = selectedSystem {
                    detailPanel(for: system)
                        .transition(.move(edge: .bottom))
                        .zIndex(1)
                }
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
            
            ScrollView {
                Text(descriptions[system] ?? "Pas de description disponible.")
                    .font(.custom(fontName, size: 18 * dynamicScale))
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
        }
        .padding()
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .background(Color.green.opacity(0.95))
        .overlay(Rectangle().stroke(Color.white, lineWidth: 2).padding(1))
    }
    
    enum StatusType {
        case ok
        case neutral
        case alarm
        
        var color: Color {
            switch self {
            case .ok: return .blue
            case .neutral: return .white
            case .alarm: return .red
            }
        }
    }
    
    struct ParameterBox: View {
    @Environment(\.dynamicScale) var dynamicScale

        let label: String
        let value: String
        let status: StatusType
        let selected: Bool
        
        var body: some View {
            HStack {
                Text(label)
                    .font(.custom("VT323-Regular", size: 20 * dynamicScale))
                    .foregroundColor(.green)
                Spacer()
                Text(value)
                    .font(.custom("VT323-Regular", size: 20 * dynamicScale))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(status.color)
                    .cornerRadius(4)
            }
            .padding()
            .frame(height: 60)
            .background(Color.black)
            .contentShape(Rectangle()) // Ensure entire box is tappable
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Color.white : Color.green, lineWidth: selected ? 3 : 1)
            )
        }
    }
}
