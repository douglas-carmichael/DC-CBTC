import SwiftUI

struct PCCDashboardView: View {
    @EnvironmentObject var simulationController: ClientNetworkService
    @EnvironmentObject var demoManager: DemoModeManager
    @Environment(\.openWindow) var openWindow
    
    @State private var showingConnectDialog = false
    @State private var host = "localhost"
    @State private var port = "9090"
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("PCC - LIGNE 1")
                    .font(.custom("VT323-Regular", size: 24))
                    .foregroundColor(.green)
                Spacer()
                ClockView(fontName: "VT323-Regular", size: 18, color: .green)
            }
            .padding()
            .background(Color.black)
            
            Divider()
                .background(Color.green)
            
            // Global Controls
            VStack(spacing: 12) {
                // Row 1: Primary Controls
                HStack(spacing: 20) {
                    Button(action: {
                        if simulationController.isRunning {
                            simulationController.stopSimulation()
                        } else {
                            simulationController.startSimulation()
                        }
                    }) {
                        Text(simulationController.isRunning ? "PAUSE" : "DÉPART AUTO")
                            .font(.custom("VT323-Regular", size: 18))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(simulationController.isRunning ? Color.orange : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        simulationController.toggleEmergencyStop()
                    }) {
                        Text(simulationController.isEmergencyState ? "REPRENDRE" : "ARRÊT D'URGENCE")
                            .font(.custom("VT323-Regular", size: 18))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(simulationController.isEmergencyState ? Color.green : Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Row 2: Secondary Controls
                HStack(spacing: 20) {
                    Button(action: {
                        simulationController.addTrain()
                    }) {
                        Text("+ RAME")
                            .font(.custom("VT323-Regular", size: 18))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        openWindow(id: "failure-panel")
                    }) {
                        Text("PANNES")
                            .font(.custom("VT323-Regular", size: 18))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        simulationController.resetSimulation()
                    }) {
                        Text("RÉINIT.")
                            .font(.custom("VT323-Regular", size: 18))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Row 3: Random Fault Toggle
                HStack {
                    Button(action: {
                        simulationController.isRandomFaultModeEnabled.toggle()
                    }) {
                        HStack {
                            Image(systemName: simulationController.isRandomFaultModeEnabled ? "bolt.fill" : "bolt.slash")
                            Text("MODE PANNES ALEATOIRES")
                                .font(.custom("VT323-Regular", size: 18))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(simulationController.isRandomFaultModeEnabled ? Color.red : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                 // Row 4: Camera Reset & Service Provisoire
                 HStack(spacing: 20) {
                     Button(action: {
                         simulationController.resetCamera()
                     }) {
                         HStack {
                             Image(systemName: "camera.fill")
                             Text("RESET VUE")
                                 .font(.custom("VT323-Regular", size: 18))
                         }
                         .frame(maxWidth: .infinity)
                         .padding()
                         .background(Color.gray)
                         .foregroundColor(.white)
                         .cornerRadius(8)
                     }
                     .buttonStyle(PlainButtonStyle())
                     
                     Button(action: {
                         openWindow(id: "service-provisoire")
                     }) {
                         HStack {
                             Image(systemName: "exclamationmark.triangle.fill")
                             Text("SERVICES PROVISOIRES")
                                 .font(.custom("VT323-Regular", size: 18))
                         }
                         .frame(maxWidth: .infinity)
                         .padding()
                         .background(Color.orange)
                         .foregroundColor(.white)
                         .cornerRadius(8)
                     }
                     .buttonStyle(PlainButtonStyle())
                 }
                
                // Row 5: Synoptic View & Demo Mode
                HStack(spacing: 20) {
                    Button(action: {
                        openWindow(id: "synoptic-view")
                    }) {
                        HStack {
                            Image(systemName: "map.fill")
                            Text("SYNOPTIQUE (TCO)")
                                .font(.custom("VT323-Regular", size: 18))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        withAnimation {
                             demoManager.isEnabled.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.rectangle.fill")
                            Text("MODE DEMO")
                                .font(.custom("VT323-Regular", size: 18))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(demoManager.isEnabled ? Color.red : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Row 6: Server Connection
                HStack {
                    Button(action: {
                        if simulationController.isConnected {
                            simulationController.disconnect()
                        } else {
                            showingConnectDialog = true
                        }
                    }) {
                        HStack {
                            Image(systemName: simulationController.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            Text(simulationController.isConnected ? "CONNECTED TO SERVER" : "CONNECT TO SERVER (9090)")
                                .font(.custom("VT323-Regular", size: 18))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(simulationController.isConnected ? Color.purple : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .alert("Connect to Server", isPresented: $showingConnectDialog) {
                TextField("Server Address", text: $host)
                TextField("Port Number (e.g. 9090)", text: $port)
                Button("Connect") {
                    if let portNum = UInt16(port) {
                        simulationController.connect(host: host, port: portNum)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter the remote server address and network port to stream CBTC telemetry.")
            }
            
            // Status List
            List {
                Section(header: Text("Trafic en Temps Réel").font(.headline)) {
                    ForEach(simulationController.trains) { train in
                        TrainRow(train: train, controller: simulationController)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                openWindow(id: "train-detail", value: train.id)
                            }
                            .contextMenu {
                                Button(action: {
                                    openWindow(id: "manual-control", value: train.id)
                                }) {
                                    Label("Mode Manuel", systemImage: "steeringwheel")
                                }
                                
                                Button(role: .destructive, action: {
                                    simulationController.removeTrain(id: train.id)
                                }) {
                                    Label("Supprimer Rame", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .listStyle(.inset)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct TrainRow: View {
    let train: Train
    let controller: ClientNetworkService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(train.name)
                    .font(.headline)
                Spacer()
                statusBadge(for: train.status)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Vitesse").font(.caption).foregroundColor(.secondary)
                    Text(String(format: "%.1f m/s", train.speed))
                        .font(.custom("VT323-Regular", size: 16))
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("Canton").font(.caption).foregroundColor(.secondary)
                    Text(controller.getSegmentName(for: train.currentSegmentId))
                        .font(.custom("VT323-Regular", size: 16))
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("LMA").font(.caption).foregroundColor(.secondary)
                    Text(String(format: "%.1f m", train.movementAuthority))
                        .font(.custom("VT323-Regular", size: 16))
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    func statusBadge(for status: Train.TrainStatus) -> some View {
        Text(status.rawValue.uppercased())
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color(for: status))
            .foregroundColor(.white)
            .cornerRadius(4)
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


