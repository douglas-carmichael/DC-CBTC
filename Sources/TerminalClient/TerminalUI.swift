import Foundation
import TermKit

class TerminalUI {
    let window: Window
    
    var activeTab: TerminalTab = .networkOverview
    var selectedTrainId: UUID? = nil
    var lastTelemetry: SystemTelemetry?
    
    var statusLabel: Label!
    var simStateLabel: Label!
    var viewHintLabel: Label!
    var regulationView: RegulationDeTraficView!
    var subsystemView: TrainSubsystemTerminalView!
    
    init(window: Window) {
        self.window = window
        buildUI()
        setupMenu()
    }
    
    private func buildUI() {
        statusLabel = Label("STATUS: DISCONNECTED")
        statusLabel.x = Pos.at(1)
        statusLabel.y = Pos.at(1)
        statusLabel.width = Dim.fill(1)
        window.addSubview(statusLabel)
        
        simStateLabel = Label("SIMULATION: STOPPED")
        simStateLabel.x = Pos.at(1)
        simStateLabel.y = Pos.at(2)
        simStateLabel.width = Dim.fill(1)
        window.addSubview(simStateLabel)
        
        viewHintLabel = Label("DISPLAY: Network Overview")
        viewHintLabel.x = Pos.at(1)
        viewHintLabel.y = Pos.at(3)
        viewHintLabel.width = Dim.fill(1)
        window.addSubview(viewHintLabel)
        
        subsystemView = TrainSubsystemTerminalView()
        subsystemView.x = Pos.at(1)
        subsystemView.y = Pos.at(5)
        subsystemView.width = Dim.fill(1)
        subsystemView.height = Dim.fill(1)
        // Hidden by default
        
        regulationView = RegulationDeTraficView()
        regulationView.x = Pos.at(1)
        regulationView.y = Pos.at(5)
        regulationView.width = Dim.fill(1)
        regulationView.height = Dim.fill(1)
        regulationView.height = Dim.fill(1)
        window.addSubview(regulationView)
    }
    
    private func setupMenu() {
        let menu = MenuBar(menus: [
            MenuBarItem(title: "System", children: [
                MenuItem(title: "Start Simulation", action: { TerminalNetworkService.shared.send(command: .startSimulation) }),
                MenuItem(title: "Stop Simulation", action: { TerminalNetworkService.shared.send(command: .stopSimulation) }),
                MenuItem(title: "Emergency Stop", action: { TerminalNetworkService.shared.send(command: .emergencyStop) }),
                MenuItem(title: "Reset", action: { TerminalNetworkService.shared.send(command: .resetSimulation) }),
                nil,
                MenuItem(title: "Quit", action: { Application.requestStop() })
            ]),
            MenuBarItem(title: "Displays", children: [
                MenuItem(title: "1: Network Overview", action: { self.activeTab = .networkOverview }),
                MenuItem(title: "2: Traction", action: { self.activeTab = .traction }),
                MenuItem(title: "3: Auxiliaires", action: { self.activeTab = .auxiliary }),
                MenuItem(title: "4: DCA", action: { self.activeTab = .dca }),
                MenuItem(title: "5: Operations", action: { self.activeTab = .operations }),
                MenuItem(title: "6: Pneumatiques", action: { self.activeTab = .pneumatics }),
                MenuItem(title: "7: Asservissement", action: { self.activeTab = .asservissement })
            ]),
            MenuBarItem(title: "Trains", children: [
                MenuItem(title: "Cycle Selected Train", action: { self.cycleTrain() }),
                MenuItem(title: "Add Train", action: { TerminalNetworkService.shared.send(command: .addTrain) })
            ])
        ])
        Application.top.addSubview(menu)
    }
    
    func cycleTrain() {
        guard let tel = lastTelemetry, !tel.trains.isEmpty else { return }
        if let current = selectedTrainId, let idx = tel.trains.firstIndex(where: { $0.id == current }) {
            let nextIdx = (idx + 1) % tel.trains.count
            selectedTrainId = tel.trains[nextIdx].id
        } else {
            selectedTrainId = tel.trains.first?.id
        }
    }
    
    func start() {
        TerminalNetworkService.shared.onTelemetryReceived = { [weak self] telemetry in
            DispatchQueue.main.async {
                self?.lastTelemetry = telemetry
                self?.draw(telemetry: telemetry)
            }
        }
        
        TerminalNetworkService.shared.onConnectionStateChanged = { [weak self] isConnected in
            DispatchQueue.main.async {
                if isConnected {
                    self?.statusLabel.text = "STATUS: CONNECTED (localhost:9090)"
                } else {
                    self?.statusLabel.text = "STATUS: DISCONNECTED"
                }
                Application.refresh()
            }
        }
        
        TerminalNetworkService.shared.connect()
    }
    
    func draw(telemetry: SystemTelemetry) {
        if telemetry.isRunning {
             simStateLabel.text = telemetry.isEmergencyState ? "SIMULATION: EMERGENCY" : "SIMULATION: RUNNING"
        } else {
             simStateLabel.text = "SIMULATION: STOPPED"
        }
        
        if selectedTrainId == nil, let first = telemetry.trains.first {
            selectedTrainId = first.id
        }
        
        let targetTrainName = telemetry.trains.first(where: { $0.id == selectedTrainId })?.name ?? "..."
        viewHintLabel.text = "DISPLAY: \(activeTab.title)   |   TARGET: \(targetTrainName)"
        
        if activeTab == .networkOverview {
            window.removeSubview(subsystemView)
            if regulationView.superview == nil {
                window.addSubview(regulationView)
            }
            regulationView.draw(telemetry: telemetry)
        } else {
            window.removeSubview(regulationView)
            if subsystemView.superview == nil {
                window.addSubview(subsystemView)
            }
            
            if let trainId = selectedTrainId, let train = telemetry.trains.first(where: { $0.id == trainId }) {
                subsystemView.draw(train: train, tab: activeTab)
            }
        }
        
        Application.refresh()
    }
}
