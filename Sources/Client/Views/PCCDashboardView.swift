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
                Text(.init(String.loc("pcc.title")))
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
                        Text(.init(simulationController.isRunning ? String.loc("btn.pause") : String.loc("btn.depart_auto")))
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
                        Text(.init(simulationController.isEmergencyState ? String.loc("btn.reprendre") : String.loc("btn.arret_urgence")))
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
                        Text(.init(String.loc("btn.add_rame")))
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
                        Text(.init(String.loc("btn.pannes")))
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
                        Text(.init(String.loc("btn.reinit")))
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
                            Text(.init(String.loc("btn.mode_pannes_aleatoires")))
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
                             Text(.init(String.loc("btn.reset_vue")))
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
                             Text(.init(String.loc("btn.services_provisoires")))
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
                            Text(.init(String.loc("btn.synoptique")))
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
                            Text(.init(String.loc("btn.mode_demo")))
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
                            Text(.init(simulationController.isConnected ? String.loc("btn.connected") : String.loc("btn.connect")))
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
            .alert(String.loc("alert.connect_title"), isPresented: $showingConnectDialog) {
                TextField(String.loc("tf.server_address"), text: $host)
                TextField(String.loc("tf.port_number"), text: $port)
                Button(String.loc("btn.connect_action")) {
                    if let portNum = UInt16(port) {
                        simulationController.connect(host: host, port: portNum)
                    }
                }
                Button(String.loc("btn.cancel"), role: .cancel) { }
            } message: {
                Text(.init(String.loc("alert.connect_message")))
            }
            
            // Status List
            List {
                Section(header: Text(.init(String.loc("label.trafic_temps_reel"))).font(.headline)) {
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
                                    Label(String.loc("ctx.mode_manuel"), systemImage: "steeringwheel")
                                }
                                
                                Button(role: .destructive, action: {
                                    simulationController.removeTrain(id: train.id)
                                }) {
                                    Label(String.loc("ctx.supprimer_rame"), systemImage: "trash")
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
                    Text(.init(String.loc("label.vitesse"))).font(.caption).foregroundColor(.secondary)
                    Text(String(format: "%.1f m/s", train.speed))
                        .font(.custom("VT323-Regular", size: 16))
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text(.init(String.loc("label.canton"))).font(.caption).foregroundColor(.secondary)
                    Text(controller.getSegmentName(for: train.currentSegmentId))
                        .font(.custom("VT323-Regular", size: 16))
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text(.init(String.loc("label.lma"))).font(.caption).foregroundColor(.secondary)
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


