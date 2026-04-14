 import SwiftUI

@main
struct CBTC_Metro_SimulatorApp: App {
    @StateObject private var simulationController = ClientNetworkService.shared
    @StateObject private var demoManager = DemoModeManager()

    init() {
        FontLoader.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(simulationController)
                .environmentObject(demoManager)
        }
        
        WindowGroup("Train Detail", id: "train-detail", for: UUID.self) { $trainID in
            if let id = trainID {
                TrainDetailViewWrapper(trainID: id)
                    .environmentObject(simulationController)
            } else {
                Text("No Train Selected")
            }
        }
        
        WindowGroup("Failure Injection", id: "failure-panel") {
            FailureControlView()
                .environmentObject(simulationController)
        }
        
        WindowGroup("Manual Control", id: "manual-control", for: UUID.self) { $trainID in
             if let id = trainID {
                 ManualControlView(trainID: id)
                     .environmentObject(simulationController)
             } else {
                 Text("No Train Selected")
             }
        }

        WindowGroup("TCO (Synoptique)", id: "synoptic-view") {
            SynopticView()
                .environmentObject(simulationController)
        }
        
        WindowGroup("Services Provisoires", id: "service-provisoire") {
            ServiceProvisoireView()
                .environmentObject(simulationController)
        }
    }
}
