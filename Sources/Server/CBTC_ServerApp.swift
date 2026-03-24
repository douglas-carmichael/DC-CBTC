import SwiftUI

@main
struct CBTC_ServerApp: App {
    @StateObject private var simulationController = SimulationController()
    
    var body: some Scene {
        WindowGroup("CBTC Server") {
            ServerDashboardView()
                .environmentObject(simulationController)
        }
    }
}
