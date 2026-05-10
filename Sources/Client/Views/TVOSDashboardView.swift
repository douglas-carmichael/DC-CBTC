import SwiftUI

#if os(tvOS)
struct TVOSDashboardView: View {
    @EnvironmentObject var simulationController: ClientNetworkService
    @EnvironmentObject var demoManager: DemoModeManager
    
    // Grid layout for TV cards
    let columns = [
        GridItem(.adaptive(minimum: 400), spacing: 40)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 50) {
                    
                    // Main Control Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Contrôles Principaux")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: columns, spacing: 30) {
                            
                            Button(action: {
                                if simulationController.isRunning {
                                    simulationController.stopSimulation()
                                } else {
                                    simulationController.startSimulation()
                                }
                            }) {
                                VStack {
                                    Image(systemName: simulationController.isRunning ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 60))
                                    Text(simulationController.isRunning ? "Pause" : "Départ")
                                        .font(.title2)
                                        .padding(.top, 10)
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                            }
                            .buttonStyle(.card)
                            
                            Button(action: {
                                simulationController.toggleEmergencyStop()
                            }) {
                                VStack {
                                    Image(systemName: "exclamationmark.octagon.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(simulationController.isEmergencyState ? .white : .red)
                                    Text(simulationController.isEmergencyState ? "Reprendre" : "Urgence")
                                        .font(.title2)
                                        .padding(.top, 10)
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                                .background(simulationController.isEmergencyState ? Color.green : Color.clear)
                            }
                            .buttonStyle(.card)
                            
                            Button(action: {
                                simulationController.addTrain()
                            }) {
                                VStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 60))
                                    Text("Ajouter Rame")
                                        .font(.title2)
                                        .padding(.top, 10)
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                            }
                            .buttonStyle(.card)
                            
                            Button(action: {
                                if simulationController.isConnected {
                                    simulationController.disconnect()
                                } else {
                                    // Just use localhost/9090 by default for TV for simplicity
                                    simulationController.connect(host: "localhost", port: 9090)
                                }
                            }) {
                                VStack {
                                    Image(systemName: simulationController.isConnected ? "antenna.radiowaves.left.and.right" : "network.slash")
                                        .font(.system(size: 60))
                                    Text(simulationController.isConnected ? "Connecté" : "Connecter (Local)")
                                        .font(.title2)
                                        .padding(.top, 10)
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                            }
                            .buttonStyle(.card)
                        }
                    }
                    .padding(.horizontal, 50)
                    
                    Divider()
                    
                    // Train Telemetry Section
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("Rames en Service")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(simulationController.trains.count) rames")
                                .font(.headline)
                        }
                        
                        if simulationController.trains.isEmpty {
                            Text("Aucune rame en service")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 200)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(16)
                        } else {
                            LazyVGrid(columns: columns, spacing: 30) {
                                ForEach(simulationController.trains) { train in
                                    TVOSTrainCard(train: train, controller: simulationController)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 50)
                }
                .padding(.vertical, 50)
            }
            .navigationTitle("CBTC Control Center")
        }
    }
}

struct TVOSTrainCard: View {
    let train: Train
    let controller: ClientNetworkService
    
    var body: some View {
        Button(action: {}) { // Wrapping in button makes it focusable
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text(train.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Text(train.status.rawValue.uppercased())
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(color(for: train.status))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("VITESSE").font(.caption).foregroundColor(.secondary)
                        Text(String(format: "%.1f m/s", train.speed))
                            .font(.title3)
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("CANTON").font(.caption).foregroundColor(.secondary)
                        Text(controller.getSegmentName(for: train.currentSegmentId))
                            .font(.title3)
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("LMA").font(.caption).foregroundColor(.secondary)
                        Text(String(format: "%.1f m", train.movementAuthority))
                            .font(.title3)
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.card)
    }
    
    func color(for status: Train.TrainStatus) -> Color {
        switch status {
        case .moving: return .green
        case .stopped: return .orange
        case .emergency: return .red
        case .docked: return .blue
        }
    }
}
#endif
