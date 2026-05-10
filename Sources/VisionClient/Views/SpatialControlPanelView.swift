import SwiftUI

struct SpatialControlPanelView: View {
    @EnvironmentObject var simulationState: SimulationState
    @State private var selectedTrainId: UUID?
    @State private var localSpeedRequest: Double = 0.0

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            // Left Column: Global Controls
            VStack(alignment: .leading, spacing: 30) {
                Text("Global Controls")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(spacing: 20) {
                    Button(action: { simulationState.startSimulation() }) {
                        Label("Start Simulation", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    
                    Button(action: { simulationState.stopSimulation() }) {
                        Label("Stop Simulation", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    
                    Button(action: { simulationState.emergencyStop() }) {
                        Label("Emergency Stop", systemImage: "exclamationmark.octagon.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    
                    Divider()
                    
                    Button(action: { simulationState.resetSimulation() }) {
                        Label("Reset Simulation", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { simulationState.addTrain() }) {
                        Label("Add Train", systemImage: "tram.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .glassBackgroundEffect()
            }
            .frame(width: 300)
            
            // Right Column: Train Controls
            VStack(alignment: .leading, spacing: 30) {
                Text("Train Controls")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if simulationState.trains.isEmpty {
                    VStack {
                        Spacer()
                        Text("No trains available")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glassBackgroundEffect()
                } else {
                    VStack(spacing: 30) {
                        Picker("Select Train", selection: $selectedTrainId) {
                            ForEach(simulationState.trains) { train in
                                Text(train.name).tag(train.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding()
                        .glassBackgroundEffect()
                        
                        if let trainId = selectedTrainId ?? simulationState.trains.first?.id,
                           let train = simulationState.trains.first(where: { $0.id == trainId }) {
                            
                            // Mode Selection
                            VStack(alignment: .leading) {
                                Text("Operation Mode").font(.headline)
                                Picker("Mode", selection: Binding(
                                    get: { train.mode },
                                    set: { newMode in
                                        simulationState.setTrainMode(id: train.id, mode: newMode)
                                        if newMode == .manual {
                                            localSpeedRequest = train.targetSpeed
                                        }
                                    }
                                )) {
                                    ForEach(Train.TrainMode.allCases, id: \.self) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding()
                            .glassBackgroundEffect()
                            
                            // Manual Controls
                            if train.mode == .manual {
                                VStack(alignment: .leading, spacing: 20) {
                                    Text("Manual Speed: \(Int(localSpeedRequest)) km/h").font(.headline)
                                    Slider(value: Binding(
                                        get: { localSpeedRequest },
                                        set: { val in
                                            localSpeedRequest = val
                                            simulationState.setManualSpeed(id: train.id, speed: val)
                                        }
                                    ), in: 0...25, step: 1)
                                }
                                .padding()
                                .glassBackgroundEffect()
                            }
                            
                            // Action Buttons
                            HStack(spacing: 20) {
                                Button(action: {
                                    simulationState.executeTrainCommand(id: train.id, command: "INTER OUV PORTE")
                                }) {
                                    VStack {
                                        Image(systemName: train.areDoorsOpen ? "door.left.hand.open" : "door.left.hand.closed")
                                            .font(.system(size: 40))
                                            .foregroundColor(train.areDoorsOpen ? .red : .green)
                                        Text("Doors")
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .glassBackgroundEffect()
                                .hoverEffect()
                                
                                Button(action: {
                                    simulationState.executeTrainCommand(id: train.id, command: "ACQUIT. COMPTEUR FU")
                                }) {
                                    VStack {
                                        Image(systemName: "exclamationmark.octagon.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.red)
                                        Text("Urg. Reset")
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .glassBackgroundEffect()
                                .hoverEffect()
                            }
                        }
                    }
                }
            }
            .frame(width: 400)
        }
        .padding(40)
        .onAppear {
            if selectedTrainId == nil {
                selectedTrainId = simulationState.trains.first?.id
            }
        }
    }
}
