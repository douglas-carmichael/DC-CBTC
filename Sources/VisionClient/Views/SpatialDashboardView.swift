import SwiftUI

struct SpatialDashboardView: View {
    @EnvironmentObject var simulationState: SimulationState
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    enum SidebarItem {
        case dashboard
        case controls
    }
    
    @State private var selection: SidebarItem? = .dashboard
    @State private var isImmersiveSpaceOpen = false
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                NavigationLink(value: SidebarItem.dashboard) {
                    Label("Dashboard", systemImage: "speedometer")
                }
                NavigationLink(value: SidebarItem.controls) {
                    Label("Controls", systemImage: "slider.horizontal.3")
                }
            }
            .navigationTitle("CBTC Vision")
        } detail: {
            if selection == .controls {
                SpatialControlPanelView()
            } else {
                DashboardMainPaneView()
            }
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            HStack(spacing: 20) {
                Button(action: {
                    Task {
                        if isImmersiveSpaceOpen {
                            await dismissImmersiveSpace()
                            isImmersiveSpaceOpen = false
                        } else {
                            let result = await openImmersiveSpace(id: "ImmersiveTrack")
                            switch result {
                            case .opened:
                                isImmersiveSpaceOpen = true
                                print("ImmersiveSpace opened successfully.")
                            case .error:
                                isImmersiveSpaceOpen = false
                                print("ERROR: ImmersiveSpace failed to open.")
                            case .userCancelled:
                                isImmersiveSpaceOpen = false
                                print("ImmersiveSpace opening was cancelled.")
                            @unknown default:
                                isImmersiveSpaceOpen = false
                                print("ImmersiveSpace returned unknown state.")
                            }
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: isImmersiveSpaceOpen ? "cube.transparent.fill" : "cube.transparent")
                        Text(isImmersiveSpaceOpen ? "Exit Simulation" : "Enter Simulation")
                    }
                    .padding()
                }
                .glassBackgroundEffect()
            }
            .padding(.bottom, 20)
        }
    }
}

struct DashboardMainPaneView: View {
    @EnvironmentObject var simulationState: SimulationState
    
    var body: some View {
        VStack(spacing: 30) {
            Text("CBTC Spatial Telemetry")
                .font(.extraLargeTitle)
                .fontWeight(.bold)
            
            if let train = simulationState.trains.first {
                HStack(spacing: 40) {
                    VStack {
                        Text("SPEED")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f km/h", train.speed))
                            .font(.system(size: 60, weight: .bold, design: .monospaced))
                            .foregroundColor(train.speed > train.targetSpeed ? .red : .primary)
                    }
                    .padding(30)
                    .glassBackgroundEffect()
                    
                    VStack {
                        Text("TARGET")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f km/h", train.targetSpeed))
                            .font(.system(size: 60, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                    .padding(30)
                    .glassBackgroundEffect()
                }
                
                HStack(spacing: 40) {
                    VStack {
                        Text("ACCELERATION")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f m/s²", train.acceleration))
                            .font(.title)
                            .monospacedDigit()
                    }
                    .padding(20)
                    .glassBackgroundEffect()
                    
                    VStack {
                        Text("DOORS")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(train.areDoorsOpen ? "OPEN" : "CLOSED")
                            .font(.title)
                            .foregroundColor(train.areDoorsOpen ? .orange : .green)
                    }
                    .padding(20)
                    .glassBackgroundEffect()
                }
            } else if simulationState.isConnected {
                VStack(spacing: 20) {
                    Text("Connected to Zone Controller")
                        .font(.headline)
                    Button("Start Simulation & Add Train") {
                        simulationState.send(command: .startSimulation)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            simulationState.send(command: .addTrain)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                ProgressView("Connecting to Zone Controller...")
                    .controlSize(.large)
            }
        }
        .padding(40)
    }
}
