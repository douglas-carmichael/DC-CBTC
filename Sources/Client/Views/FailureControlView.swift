import SwiftUI

struct FailureControlView: View {
    @EnvironmentObject var simulationController: ClientNetworkService
    @State private var selectedTrainIndex: Int = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text(.init(String.loc("section.injecteur_pannes")))
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
            
            // Train Selection
            Picker("Sélectionner la Rame", selection: $selectedTrainIndex) {
                ForEach(simulationController.trains.indices, id: \.self) { index in
                    Text(simulationController.trains[index].name).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            Divider()
            
            if simulationController.trains.indices.contains(selectedTrainIndex) {
                let train = simulationController.trains[selectedTrainIndex]
                
                VStack(spacing: 15) {
                    Group {
                        Toggle(isOn: binding(for: \.isDoorFault)) {
                            Label("Panne Portes", systemImage: "door.left.hand.open")
                                .foregroundColor(.red)
                        }
                        
                        Toggle(isOn: binding(for: \.isEngineFault)) {
                            Label("Panne Moteur", systemImage: "engine.combustion")
                                .foregroundColor(.orange)
                        }
                        
                        Toggle(isOn: binding(for: \.isBrakeFault)) {
                            Label("Panne Freinage", systemImage: "exclamationmark.brakesignal")
                                .foregroundColor(.red)
                        }
                        
                        Toggle(isOn: binding(for: \.isSignalFault)) {
                            Label("Perte Signalisation", systemImage: "antenna.radiowaves.left.and.right.slash")
                                .foregroundColor(.purple)
                        }
                        
                        Divider()
                        
                        Toggle(isOn: binding(for: \.isPatinage)) {
                            Label("Patinage (Glissement)", systemImage: "snowflake")
                                .foregroundColor(.cyan)
                        }
                        
                        Toggle(isOn: binding(for: \.isEnrayage)) {
                            Label("Enrayage (Blocage)", systemImage: "exclamationmark.octagon")
                                .foregroundColor(.orange)
                        }
                        
                        Divider()
                        
                        Text(.init(String.loc("section.pneumatiques_fc")))
                            .font(.headline)
                            .padding(.top, 5)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                            ForEach(train.tires.indices, id: \.self) { index in
                                let tire = train.tires[index]
                                Button(action: {
                                    simulationController.cycleTireStatus(for: train.id, at: index)
                                }) {
                                    VStack {
                                        Text("Pneu \(tire.id)")
                                            .font(.caption2)
                                        Circle()
                                            .fill(tireColor(for: tire.status))
                                            .frame(width: 15, height: 15)
                                    }
                                    .padding(5)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(5)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .red))
                    .font(.headline)
                    .padding(.horizontal)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .padding()
                
                Text("État Actuel : \(train.status.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(.init(String.loc("label.aucune_rame")))
            }
            
            Spacer()
        }
        .frame(width: 400, height: 500)
        .padding()
    }
    
    // Helper to bind to the specific train in the array
    private func binding(for keyPath: WritableKeyPath<Train, Bool>) -> Binding<Bool> {
        Binding(
            get: {
                guard simulationController.trains.indices.contains(selectedTrainIndex) else { return false }
                return simulationController.trains[selectedTrainIndex][keyPath: keyPath]
            },
            set: { newValue in
                guard simulationController.trains.indices.contains(selectedTrainIndex) else { return }
                simulationController.trains[selectedTrainIndex][keyPath: keyPath] = newValue
            }
        )
    }
    
    private func tireColor(for status: Train.Tire.TireStatus) -> Color {
        switch status {
        case .ok: return .green
        case .lowPressure: return .orange
        case .puncture: return .red
        case .burst: return .purple
        }
    }
}
