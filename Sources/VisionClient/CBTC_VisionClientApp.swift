import SwiftUI

@main
struct CBTC_VisionClientApp: App {
    @StateObject private var simulationState = SimulationState()
    
    var body: some Scene {
        WindowGroup(id: "main") {
            SpatialDashboardView()
                .environmentObject(simulationState)
        }
        
        ImmersiveSpace(id: "ImmersiveTrack") {
            ImmersiveTrackView()
                .environmentObject(simulationState)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
