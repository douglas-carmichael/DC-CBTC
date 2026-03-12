import SwiftUI
import AppKit

struct ManualControlView: View {
    let trainID: UUID
    @EnvironmentObject var simulationController: SimulationController
    @State private var localSpeedRequest: Float = 0.0
    
    // Binding for manual control
    private func binding(for train: Train) -> Binding<Train> {
        guard let index = simulationController.trains.firstIndex(where: { $0.id == train.id }) else {
            fatalError("Train not found")
        }
        return $simulationController.trains[index]
    }
    
    var body: some View {
        Group {
            if let index = simulationController.trains.firstIndex(where: { $0.id == trainID }) {
                // Get the train directly from array
                let train = simulationController.trains[index]
                let trainBinding = $simulationController.trains[index]
                
                VStack(spacing: 20) {
                    Text(train.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Mode Switch
                    Picker("Mode", selection: trainBinding.mode) {
                        ForEach(Train.TrainMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    .onChange(of: trainBinding.mode.wrappedValue) { oldValue, newMode in
                        // Reset manual requests when switching
                        if newMode == .manual {
                            localSpeedRequest = Float(train.targetSpeed)
                            // Use main thread or just update binding directly
                            DispatchQueue.main.async {
                                simulationController.trains[index].manualSpeedRequest = CGFloat(localSpeedRequest)
                            }
                        }
                    }
                    
                    Divider()
                    
                    if train.mode == .manual {
                        VStack(spacing: 15) {
                            Text("Commandes Manuelles")
                                .font(.headline)
                            
                            // Speed Control
                            VStack(alignment: .leading) {
                                Text("Vitesse Cible: \(Int(localSpeedRequest)) m/s")
                                Slider(value: Binding(
                                    get: { localSpeedRequest },
                                    set: { val in
                                        localSpeedRequest = val
                                        simulationController.trains[index].manualSpeedRequest = CGFloat(val)
                                    }
                                ), in: 0...25, step: 1) {
                                    Text("Vitesse")
                                }
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            
                            // Doors
                            Toggle(isOn: trainBinding.areDoorsOpen) {
                                Label("Portes", systemImage: train.areDoorsOpen ? "door.left.hand.open" : "door.left.hand.closed")
                                    .foregroundColor(train.areDoorsOpen ? .red : .primary)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            
                            // Emergency Brake
                            Toggle(isOn: trainBinding.isEmergencyBrakeApplied) {
                                Label("Frein d'Urgence", systemImage: "exclamationmark.octagon.fill")
                                    .foregroundColor(.red)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .red))
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        .padding()
                        .transition(.opacity)
                    } else {
                        VStack {
                            Spacer()
                            Text("Mode Automatique Actif")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Le train est contrôlé par le système CBTC.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    Divider()
                    
                    // Live Status
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Vitesse Actuelle: \(String(format: "%.1f", train.speed)) m/s")
                            Text("Statut : \(train.status.rawValue)")
                        }
                        Spacer()
                        if train.mode == .manual {
                            Text("MANUEL")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(4)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        } else {
                            Text("AUTO")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(4)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    .padding()
                }
                .padding()
                .frame(width: 350, height: 500)
                .onAppear {
                    // Sync local state to model
                    if let t = simulationController.trains.first(where: { $0.id == trainID }) {
                         localSpeedRequest = Float(t.manualSpeedRequest)
                    }
                }
            } else {
                Text("Train introuvable")
                    .foregroundColor(.secondary)
                    .frame(width: 300, height: 200)
            }
        }
    }
}
