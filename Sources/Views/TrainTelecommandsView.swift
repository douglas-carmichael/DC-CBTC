import SwiftUI

struct TrainTelecommandsView: View {
    let train: Train
    let onBack: () -> Void
    
    // Retro font simulation
    private let fontName = "VT323-Regular"
    
    @State private var commandStatus: [String: String] = [:] // Command -> Status (e.g., "EN COURS", "OK")
    
    let commands = [
        "RAZ MULTIMEDIA",
        "ACQUIT. COMPTEUR FU",
        "TEST ALARME EVACUATION",
        "DEMARRAGE SECOURS",
        "INTER OUV PORTE",
        "ENR. ARCHIVAGE DAM",
        "RAZ APPAREIL DE VOIE",
        "RAZ MOTEUR AIGUILLE",
        "TEST SONORISATION",
        "INIT. SYSTEME VIDEO",
        "DELESTAGE BT"
    ]
    
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
                Text("TELECOMMANDES")
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
            
            // Command Grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    ForEach(commands, id: \.self) { command in
                        CommandButton(
                            label: command,
                            status: commandStatus[command],
                            action: { executeCommand(command) }
                        )
                    }
                }
                .padding()
            }
        }
        .background(Color.black)
        .overlay(Rectangle().stroke(Color.green, lineWidth: 2))
    }
    
    @EnvironmentObject var simulationController: SimulationController
    
    private func executeCommand(_ command: String) {
        // Send command to controller
        simulationController.executeCommand(command, for: train.id)
        
        // Visual Feedback
        commandStatus[command] = "EN COURS..."
        
        // Delay to simulate processing (visual only, logic is instant or async in controller)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            commandStatus[command] = "OK"
            
            // Clear status after another delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                commandStatus[command] = nil
            }
        }
    }
    
    private func parseTrainID(_ name: String) -> String {
        return name.components(separatedBy: " ").last ?? "000"
    }
    
    struct CommandButton: View {
        let label: String
        let status: String?
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack {
                    Text(label)
                        .font(.custom("VT323-Regular", size: 18))
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                    
                    if let status = status {
                        Text(status)
                            .font(.custom("VT323-Regular", size: 14))
                            .foregroundColor(status == "OK" ? .blue : .yellow)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(status == "EN COURS..." ? Color.yellow : (status == "OK" ? Color.blue : Color.green), lineWidth: 2)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}
