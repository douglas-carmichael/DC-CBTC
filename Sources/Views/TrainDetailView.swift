import SwiftUI

struct TrainDetailViewWrapper: View {
    let trainID: UUID
    @EnvironmentObject var simulationController: SimulationController
    
    var body: some View {
        if let train = simulationController.trains.first(where: { $0.id == trainID }) {
            TrainDetailView(train: train, onClose: {
                // In a separate window, close might mean closing the window, 
                // but standard macOS windows have a close button.
                // We can leave this empty or use proper window closing env if needed.
            })
        } else {
            Text("Signal Lost: Train \(trainID.uuidString)")
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
    }
}

struct TrainDetailView: View {
    let train: Train
    let onClose: () -> Void
    var isDemoMode: Bool = false // Add optional parameter
    @EnvironmentObject var simulationController: SimulationController // Injected
    
    // Retro font simulation
    private let fontName = "VT323-Regular" // Or another monospaced font
    private var baseFontSize: CGFloat {
        return isDemoMode ? 18 : 12 // Scale up for demo mode
    }
    
    enum DrillDownView: String, CaseIterable {
        case none
        case traction       // Traction / Braking / Tires
        case signaling      // Alarms / Position / SEC
        case dca            // DCA / PA
        case operations     // Exploitation / Doors / Prep
        case auxiliary      // Auxiliaries
        case alarms         // Dedicated Alarms Page
        case pneumatics     // Dedicated Pneumatics Page
        case security       // Dedicated Security Page
        case telecommands   // Dedicated Telecommands Page
        case history        // Dedicated History Page
        case asservissement // Asservissement Telemetry Page
    }
    
    @State private var currentView: DrillDownView = .none
    @State private var selectedAuxiliary: String? // Search/Drill-down state
    
    // Type alias for status items to ensure consistency
    typealias StatusItem = (label: String, color: Color, active: Bool, value: String?, faultKey: WritableKeyPath<Train, Bool>?)
    
    var body: some View {
        Group {
            switch currentView {
            case .traction:
                TrainTractionView(train: train, selectedSystem: $selectedAuxiliary, onBack: { currentView = .none })
            case .signaling:
                TrainSignalingView(train: train, selectedSystem: $selectedAuxiliary, onBack: { currentView = .none })
            case .dca:
                TrainDCAView(train: train, selectedSystem: $selectedAuxiliary, onBack: { currentView = .none })
            case .operations:
                TrainOperationsView(train: train, selectedSystem: $selectedAuxiliary, onBack: { currentView = .none })
            case .auxiliary:
                TrainAuxiliaryView(train: train, selectedSystem: $selectedAuxiliary, onBack: { 
                    currentView = .none
                    selectedAuxiliary = nil
                    selectedAuxiliary = nil
                })
            case .alarms:
                TrainAlarmsView(train: train, onBack: { currentView = .none })
            case .pneumatics:
                TrainPneumaticsView(train: train, onBack: { currentView = .none })
            case .security:
                TrainSecurityView(train: train, onBack: { currentView = .none })
            case .telecommands:
                TrainTelecommandsView(train: train, onBack: { currentView = .none })
            case .history:
                TrainHistoryView(train: train, onClose: { currentView = .none })
            case .asservissement:
                TrainAsservissementView(train: train, onBack: { currentView = .none })
            case .none:
                VStack(spacing: 0) {
            // Header
            HStack {
                ClockView(fontName: fontName, size: baseFontSize * 1.5, color: .white)
                Spacer()
                Text("VEHICULE")
                    .font(.custom(fontName, size: baseFontSize * 2.6)) // 32 -> ~32 or 46
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Spacer()
                Text(parseTrainID(train.name)) // e.g., "101"
                    .font(.custom(fontName, size: baseFontSize * 2.6)) // 32 -> ~32 or 46
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Spacer()
                Text("SYNTH_VEH")
                    .font(.custom(fontName, size: baseFontSize * 1.5))
                    .padding(4)
                    .background(Color.red)
                    .foregroundColor(.black)
                
                // Window mode doesn't need explicit close button in UI, use window controls
            }
            .padding(8)
            .background(Color.black)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.white), alignment: .bottom)
            
            if train.startupState != .ready {
                bootScreen
            } else {
                // Main Grid
                HStack(spacing: 0) {
                    // Column 1
                    VStack(spacing: 0) {
                        detailSection(title: "ALARMES", items: [
                            ("TMS", .blue, train.isSignalFault, nil, \.isSignalFault), // Signal Fault
                            ("EVACUATION", .red, train.status == .emergency, nil, nil),
                            ("ALARME TECH", .red, false, nil, nil),
                            ("DEFAUT TECH", .red, train.isEngineFault, nil, \.isEngineFault), // Engine Fault
                            ("PARITE TMD", .blue, false, nil, nil)
                        ], targetView: .alarms)
                        Divider().background(Color.green)
                        detailSection(title: "POSITION", items: [
                            ("CANTON", .white, true, "Canton \((train.currentSegmentId?.uuidString ?? "????").prefix(4))", nil),
                            ("PA", .white, true, "4", nil),
                            ("TMD", .green, true, "OK", nil)
                        ], targetView: .signaling)
                        Divider().background(Color.green)
                        detailSection(title: "EXPLOITATION", items: [
                            ("RAME FORME 52M", .blue, true, nil, nil),
                            ("VIT.MOD. PAR STAT", .blue, false, nil, nil),
                            ("COND MANUELLE-AUTO", .white, true, train.mode == .manual ? "M" : "A", nil),
                            ("DEFAUT PREPA", .red, train.isDoorFault, "NON", \.isDoorFault), // Door Fault
                            ("ACCOSTAGE AUTO.", .blue, true, nil, nil),
                            ("SURCHARGE", .blue, false, nil, nil),
                            ("CHARGE PAX", .white, true, "\(train.passengerCount)", nil)
                        ], targetView: .operations)
                    }
                    .frame(maxWidth: .infinity)
                    Divider().background(Color.green)
                    // Column 2
                    VStack(spacing: 0) {
                        detailSection(title: "PREPARATION MAT", items: [
                            ("AUTOMATE PREP.", .blue, true, nil, nil),
                            ("COND MANUELLE-AUTO", .white, true, train.mode == .manual ? "M" : "A", nil),
                            ("ABSENCE HT", .blue, false, nil, nil)
                        ], targetView: .operations)
                        Divider().background(Color.green)
                        Divider().background(Color.green)
                        VStack(alignment: .leading, spacing: 4) {
                             // Custom Header with Button
                             HStack {
                                 Text("AUXILIAIRES")
                                     .font(.custom(fontName, size: baseFontSize * 1.5))
                                     .fontWeight(.bold)
                                     .foregroundColor(.green)
                                 Spacer()
                                 Spacer()
                                 Button(action: { currentView = .auxiliary }) {
                                     Image(systemName: "chevron.right.circle.fill")
                                         .foregroundColor(.green)
                                         .font(.system(size: baseFontSize + 2))
                                 }
                                 .buttonStyle(PlainButtonStyle())
                             }
                             .padding(.bottom, 4)
                             .overlay(Rectangle().frame(height: 1).foregroundColor(.green), alignment: .bottom)
                             
                             // Items
                             auxRow(label: "CHAUFFAGE", active: true)
                             auxRow(label: "BATTERIES", active: true)
                             auxRow(label: "CONVERTISSEUR", active: true)
                             auxRow(label: "DELESTAGE BT", active: train.isLoadSheddingActive, onToggle: {
                                 simulationController.executeCommand("DELESTAGE BT", for: train.id)
                             })
                             auxRow(label: "ECLAIRAGE", active: true)
                             auxRow(label: "SUSPENSION", active: true)
                             auxRow(label: "COMPRESSEUR", active: true)
                             auxRow(label: "TEMP COFFRE-FREIN", active: false)
                             auxRow(label: "VENTILATION", active: true)

                             Spacer()
                        }
                        .padding(4)
                        .frame(maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    Divider().background(Color.green)
                    
                    // Column 3
                    VStack(spacing: 0) {
                        detailSection(title: "TRACTION", items: [
                            ("SENS TRACTION", .white, true, train.speed > 0 ? "AV" : "--", nil),
                            ("2 OND EN SERVICE", .blue, true, nil, nil),
                            ("ORDRE TRACTION", .blue, train.acceleration > 0, nil, nil),
                            ("AVARIE ONDULEUR", .red, false, nil, nil),
                            ("DEFAUT TRACTION", .red, false, nil, nil),
                            ("PATIN.-ENRAYAGE", .red, train.isPatinage || train.isEnrayage, train.isPatinage ? "PAT" : (train.isEnrayage ? "ENR" : nil), nil)
                        ], targetView: .traction)
                        Divider().background(Color.green)
                        detailSection(title: "FREINAGE", items: [
                            ("ORDRE FU", .blue, train.isEmergencyBrakeApplied, nil, nil),
                            ("FU PASSAGERS", .blue, false, nil, nil),
                            ("FU OBSTACLES", .blue, false, nil, nil),
                            ("FU RUPT. ATTEL.", .blue, false, nil, nil),
                            ("DEFAUT FU", .red, train.isBrakeFault, nil, \.isBrakeFault),
                            ("DEFAUT FN", .red, false, nil, nil),
                            ("FREIN PERMANENT", .blue, train.speed == 0, nil, nil),
                            ("AUTOTEST FREIN", .blue, false, nil, nil)
                        ], targetView: .traction)
                    }
                    .frame(maxWidth: .infinity)
                    Divider().background(Color.green)
                    
                    // Column 4
                    VStack(spacing: 0) {
                        detailSection(title: "ETAT/ALARME DCA", items: [
                            ("DCA EN SERVICE", .white, true, "2", nil),
                            ("CDE.OUV.PORTES", .blue, train.areDoorsOpen, nil, nil),
                            ("DEF.TRX.VEH.STA", .blue, false, nil, nil),
                            ("OUV. PORTES LIGNE", .blue, false, nil, nil),
                            ("DEF. 2 ONDULEURS", .blue, false, nil, nil),
                            ("DEF. SEQ. DEMARRAGE", .blue, false, nil, nil),
                            ("VITESSE =", .white, true, String(format: "%.1f", train.speed), nil),
                            ("VIT.LIM.PAR AVAR.", .blue, false, nil, nil),
                            ("VO AUTO-CONTROLE", .blue, true, nil, nil)
                        ], targetView: .dca)
                        Divider().background(Color.green)
                        detailSection(title: "ETAT/ALARME SEC", items: [
                            ("F.S VALIDEE", .blue, true, nil, nil),
                            ("RX FREQUENCE P.P", .blue, true, nil, nil),
                            ("RX MODE N. OU P.", .white, true, "N", nil),
                            ("RX MODE ACCOSTAGE", .white, true, "2", nil),
                            ("RX SENS", .white, true, "2", nil),
                            ("COMMANDE FU", .blue, false, nil, nil),
                            ("VEHIC.A L'ARRET", .blue, train.speed == 0, nil, nil),
                            ("COMPTEUR FU", .white, true, "0", nil),
                            ("DISC. COMMANDE FU", .blue, false, nil, nil)
                        ], targetView: .security)
                    }
                    .frame(maxWidth: .infinity)
                    Divider().background(Color.green)
                    
                    // Column 5 (Pneumatiques & Asservissement)
                    VStack(spacing: 0) {
                        detailSection(title: "PNEUMATIQUES", items: tireStatusItems(), targetView: .pneumatics)
                        Divider().background(Color.green)
                        detailSection(title: "ASSERVISSEMENT", items: [
                            ("CONSIGNE VIT.", .white, true, String(format: "%.1f m/s", train.consigneVitesse), nil),
                            ("ERREUR VIT.", .white, true, String(format: "%.2f", train.speedError), nil),
                            ("ACCEL. DEMANDEE", .white, true, String(format: "%.2f m/s²", train.desiredAcceleration), nil),
                            ("DIST. CIBLE MA", .white, true, String(format: "%.1f m", train.distanceToMA), nil)
                        ], targetView: .asservissement)
                    }
                    .frame(maxWidth: .infinity)
                }
                .background(Color.black)
                
                // Footer
                HStack {
                    Text("DIAGNOSTIC TRACTION: \(tractionDiagnostic)")
                    Spacer()
                    
                    Button(action: { currentView = .telecommands }) {
                        Text("TELECOMMANDES")
                            .font(.custom(fontName, size: baseFontSize + 2))
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .foregroundColor(.black)
                            .cornerRadius(2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Button(action: { currentView = .history }) {
                        Text("HISTORIQUE")
                            .font(.custom(fontName, size: baseFontSize + 2))
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    Text("DIAGNOSTIC AUTOMATISMES: \(automatismesDiagnostic)")
                }
                .font(.custom(fontName, size: baseFontSize + 2))
                .foregroundColor(.green)
                .padding(8)
                .background(Color.black)
                .overlay(Rectangle().frame(height: 1).foregroundColor(.green), alignment: .top)
            } // Close else
        } // Close VStack
        .background(Color.black)
        .overlay(Rectangle().stroke(Color.green, lineWidth: 2))
            } // Close switch
        } // Close Group
    } // Close body
    
    private func parseTrainID(_ name: String) -> String {
        // "Rame 101" -> "101"
        return name.components(separatedBy: " ").last ?? "000"
    }
    
    // Helper to generate a section
    private func tireStatusItems() -> [StatusItem] {
        train.tires.map { tire in
            (label: "PNEU \(tire.id)", 
             color: tire.status == .ok ? .blue : (tire.status == .burst ? .purple : .red), 
             active: true, 
             value: "\(String(format: "%.1f", tire.pressure))b \(tire.status == .ok ? "OK" : (tire.status == .lowPressure ? "PB" : (tire.status == .puncture ? "CREV" : "ECLAT")))", 
             faultKey: nil)
        }
    }

    private func auxRow(label: String, active: Bool, onToggle: (() -> Void)? = nil) -> some View {
        Button(action: {
            selectedAuxiliary = label
            currentView = .auxiliary
        }) {
            HStack {
                Text(label)
                    .font(.custom(fontName, size: baseFontSize + 2)) // 14 -> 14 or 20
                    .foregroundColor(.green)
                Spacer()
                
                if let onToggle = onToggle {
                    Button(action: onToggle) {
                        Rectangle()
                            .fill(active ? Color.blue : Color.clear)
                            .border(Color.blue, width: 1)
                            .frame(width: 8, height: 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Rectangle()
                        .fill(active ? Color.blue : Color.clear)
                        .border(Color.blue, width: 1)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func detailSection(title: String, items: [StatusItem], targetView: DrillDownView = .none) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { 
                if targetView != .none { 
                    currentView = targetView 
                } 
            }) {
                HStack {
                    Text(title)
                        .font(.custom(fontName, size: baseFontSize * 1.5))
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    if targetView != .none {
                         Spacer()
                         Image(systemName: "chevron.right.circle.fill")
                             .foregroundColor(.green)
                             .font(.system(size: baseFontSize + 2))
                    } else {
                        Spacer()
                    }
                }
                .padding(.bottom, 4)
                .overlay(Rectangle().frame(height: 1).foregroundColor(.green), alignment: .bottom)
            }
            .buttonStyle(PlainButtonStyle())
            
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                HStack {
                    if let keyPath = item.faultKey {
                        // Interactive button for fault
                        Button(action: {
                            toggleFault(keyPath)
                        }) {
                            HStack {
                                Text(item.label)
                                    .font(.custom(fontName, size: baseFontSize + 2))
                                    .fontWeight(.bold) // Bold if interactive
                                    .foregroundColor(item.active ? .red : .green) // Red if fault active
                                
                                Image(systemName: item.active ? "exclamationmark.triangle.fill" : "checkmark.circle")
                                    .font(.system(size: baseFontSize))
                                    .foregroundColor(item.active ? .red : .gray)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        // Static text
                        Text(item.label)
                            .font(.custom(fontName, size: baseFontSize + 2))
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    if let value = item.value {
                        Text(value)
                            .font(.custom(fontName, size: baseFontSize + 2))
                            .foregroundColor(item.color)
                            .padding(.horizontal, 4)
                            .background(item.active ? Color.clear : Color.clear)
                    } else {
                        // Square indicator
                        Rectangle()
                            .fill(item.active ? item.color : Color.clear)
                            .border(item.color, width: 1)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            Spacer()
        }
        .padding(4)
        .frame(maxHeight: .infinity)
    }
    
    private func toggleFault(_ keyPath: WritableKeyPath<Train, Bool>) {
        if let index = simulationController.trains.firstIndex(where: { $0.id == train.id }) {
            simulationController.trains[index][keyPath: keyPath].toggle()
        }
    }
    
    // Dynamic Diagnostics
    private var tractionDiagnostic: String {
        if train.isEngineFault { return "DEFAUT CHAINE TRACTION / DISJONCTEUR OUVERT" }
        if train.isBrakeFault { return "DEFAUT FREINAGE / ISOLATION PNEU." }
        if train.isEmergencyBrakeApplied { return "FREINAGE D'URGENCE ACTIVE" }
        return "RAS"
    }

    private var automatismesDiagnostic: String {
        if train.mode == .manual { return "EN CONDUITE MANUELLE" }
        if train.isSignalFault { return "PERTE SIGNAL / CODE VITESSE INVALID" }
        if train.isDoorFault { return "DEFAUT PORTES / BOUCLE DE SECURITE OUVERTE" }
        if train.status == .emergency { return "ARRET D'URGENCE CMD PCC" }
        return "FONCTIONNEMENT NOMINAL / CHAINE FS ETABLIE"
    }
    
    @ViewBuilder
    var bootScreen: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("ALSTOM - SYSTEME DE CONTROLE TRAIN - V3.42")
                .font(.custom(fontName, size: baseFontSize * 1.5))
                .foregroundColor(.green)
                .padding(.bottom, 20)
            
            Group {
                Text("BIOS CHECK... OK")
                if train.startupState.rawValue >= Train.StartupState.memoryCheck.rawValue {
                   Text("VERIFICATION MEMOIRE... 64MB OK")
                }
                if train.startupState.rawValue >= Train.StartupState.systemsCheck.rawValue {
                   Text("INITIALISATION PNEUMATIQUE... OK")
                   Text("INITIALISATION ELECTRIQUE... OK")
                }
                if train.startupState.rawValue >= Train.StartupState.radioConnect.rawValue {
                   Text("RECHERCHE RESEAU PCC...")
                   Text("CONNEXION ETABLIE.")
                }
            }
            .font(.custom(fontName, size: baseFontSize + 2))
            .foregroundColor(.green)
            
            Spacer()
            
            HStack {
                Text("SEQUENCE DE DEMARRAGE EN COURS...")
                Spacer()
                if train.startupState == .radioConnect {
                     ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .green))
                        .scaleEffect(0.5)
                }
            }
            .font(.custom(fontName, size: baseFontSize + 2))
            .foregroundColor(.green)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .padding()
    }
}

// Append Asservissement View inline to avoid modifying .pbxproj manually
struct TrainAsservissementView: View {
    let train: Train
    let onBack: () -> Void
    @EnvironmentObject var simulationController: SimulationController
    
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
                Text("ASSERVISSEMENT")
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
            
            // Content
            VStack(spacing: 20) {
                Text("BOUCLE DE CONTROLE DE VITESSE")
                    .font(.custom(fontName, size: 24))
                    .foregroundColor(.green)
                    .padding(.top, 20)
                
                // Speed parameters
                HStack(spacing: 40) {
                    TelemetryBox(title: "VITESSE ACTUELLE", value: String(format: "%.1f", train.speed), unit: "m/s", color: .green)
                    TelemetryBox(title: "CONSIGNE VITESSE", value: String(format: "%.1f", train.consigneVitesse), unit: "m/s", color: .cyan)
                    TelemetryBox(title: "ERREUR VITESSE", value: String(format: "%+.2f", train.speedError), unit: "m/s", color: abs(train.speedError) > 0.5 ? .orange : .green)
                }
                
                // Physical parameters
                HStack(spacing: 40) {
                    TelemetryBox(title: "ACCEL. DEMANDEE", value: String(format: "%+.2f", train.desiredAcceleration), unit: "m/s²", color: train.desiredAcceleration < 0 ? .red : .blue)
                    TelemetryBox(title: "ACCEL. REELLE", value: String(format: "%+.2f", train.acceleration), unit: "m/s²", color: .green)
                    TelemetryBox(title: "DIST. CIBLE MA", value: String(format: "%.1f", train.distanceToMA), unit: "m", color: train.distanceToMA < 20 ? .red : .yellow)
                }
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            
        }
        .background(Color.black)
        .overlay(Rectangle().stroke(Color.green, lineWidth: 2))
    }
    
    private func parseTrainID(_ name: String) -> String {
        return name.components(separatedBy: " ").last ?? "000"
    }
    
    struct TelemetryBox: View {
        let title: String
        let value: String
        let unit: String
        let color: Color
        private let fontName = "VT323-Regular"
        
        var body: some View {
            VStack(spacing: 5) {
                Text(title)
                    .font(.custom(fontName, size: 18))
                    .foregroundColor(color)
                
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value)
                        .font(.custom(fontName, size: 48))
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    Text(unit)
                        .font(.custom(fontName, size: 18))
                        .foregroundColor(color)
                }
            }
            .padding()
            .frame(width: 200)
            .background(Color.black)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.5), lineWidth: 2))
        }
    }
}
