import SwiftUI

struct TrainSecurityView: View {
    @Environment(\.dynamicScale) var dynamicScale

    let train: Train
    let onBack: () -> Void
    
    // Retro font simulation
    private let fontName = "VT323-Regular"
    
    @State private var selectedSystem: String?
    
    // Detailed descriptions map
    private let descriptions: [String: String] = [
        "F.S VALIDEE": "Faisceau de Sécurité.\nConfirme l'intégrité de la voie et l'absence d'obstacles majeurs.",
        "RX FREQUENCE P.P": "Réception Porte-Pilote.\nSignal de communication continu entre le sol et le train (Tapis).",
        "RX MODE N. OU P.": "Mode Normal ou Parking.\nN = Exploitation normale.\nP = Garage/Maintenance.",
        "RX MODE ACCOSTAGE": "Mode d'approche en station.\n0 = En ligne\n1 = Approche lointaine\n2 = Approche finale (précision).",
        "RX SENS": "Sens de circulation.\n1 = Nominal (Impair)\n2 = Inverse (Pair).",
        "COMMANDE FU": "Commande de Freinage d'Urgence.\nActive si le PA ou le sol détecte une anomalie critique.",
        "VEHIC. A L'ARRET": "Détection Zéro Vitesse.\nIndique que le train est totalement immobile (v < 3 cm/s).",
        "COMPTEUR FU": "Compteur de Freinages d'Urgence.\nNombre de déclenchements depuis le dernier reset.",
        "DISC. COMMANDE FU": "Discordance Boucle FU.\nIndique une incohérence entre la commande et l'état réel du frein."
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
                Text(.init(String.loc("section.etat_securite")))
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
            ZStack(alignment: .bottom) {
                // Main Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Grid of Security Statuses
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            SecurityItem(label: "F.S VALIDEE", status: "OK", isActive: true, selected: selectedSystem == "F.S VALIDEE")
                                .onTapGesture { selectedSystem = "F.S VALIDEE" }
                            SecurityItem(label: "RX FREQUENCE P.P", status: "RECU", isActive: true, selected: selectedSystem == "RX FREQUENCE P.P")
                                .onTapGesture { selectedSystem = "RX FREQUENCE P.P" }
                            SecurityItem(label: "RX MODE N. OU P.", status: "N", isActive: true, isValue: true, selected: selectedSystem == "RX MODE N. OU P.")
                                .onTapGesture { selectedSystem = "RX MODE N. OU P." }
                            SecurityItem(label: "RX MODE ACCOSTAGE", status: "2", isActive: true, isValue: true, selected: selectedSystem == "RX MODE ACCOSTAGE")
                                .onTapGesture { selectedSystem = "RX MODE ACCOSTAGE" }
                            SecurityItem(label: "RX SENS", status: "2", isActive: true, isValue: true, selected: selectedSystem == "RX SENS")
                                .onTapGesture { selectedSystem = "RX SENS" }
                            SecurityItem(label: "COMMANDE FU", status: train.isEmergencyBrakeApplied ? "ACTIVE" : "INACTIVE", isActive: train.isEmergencyBrakeApplied, isAlert: true, selected: selectedSystem == "COMMANDE FU")
                                .onTapGesture { selectedSystem = "COMMANDE FU" }
                            SecurityItem(label: "VEHIC. A L'ARRET", status: train.speed == 0 ? "OUI" : "NON", isActive: train.speed == 0, selected: selectedSystem == "VEHIC. A L'ARRET")
                                .onTapGesture { selectedSystem = "VEHIC. A L'ARRET" }
                            SecurityItem(label: "COMPTEUR FU", status: "0", isActive: true, isValue: true, selected: selectedSystem == "COMPTEUR FU")
                                .onTapGesture { selectedSystem = "COMPTEUR FU" }
                            SecurityItem(label: "DISC. COMMANDE FU", status: "NON", isActive: false, selected: selectedSystem == "DISC. COMMANDE FU")
                                .onTapGesture { selectedSystem = "DISC. COMMANDE FU" }
                        }
                        .padding()
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
    
    struct SecurityItem: View {
    @Environment(\.dynamicScale) var dynamicScale

        let label: String
        let status: String
        let isActive: Bool
        var isValue: Bool = false
        var isAlert: Bool = false
        var selected: Bool = false
        
        private let fontName = "VT323-Regular"
        
        var body: some View {
            HStack {
                Text(label)
                    .font(.custom(fontName, size: 20 * dynamicScale))
                    .foregroundColor(.green)
                Spacer()
                Text(status)
                    .font(.custom(fontName, size: 20 * dynamicScale))
                    .fontWeight(.bold)
                    .foregroundColor(color)
                    .padding(4)
                    .border(color, width: 1)
            }
            .padding()
            .background(Color.black)
            .contentShape(Rectangle()) // Essential for tap gesture
            .overlay(
                Rectangle()
                    .stroke(selected ? Color.white : Color.green.opacity(0.5), lineWidth: selected ? 3 : 1)
            )
        }
        
        var color: Color {
            if isAlert && isActive { return .red }
            if isValue { return .white }
            return isActive ? .blue : .gray
        }
    }
}
