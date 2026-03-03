import SwiftUI
import SceneKit

struct ContentView: View {
    @EnvironmentObject var simulationController: SimulationController
    @EnvironmentObject var demoManager: DemoModeManager // Inject Demo Manager

    var body: some View {
        ZStack {
            // Standard App UI
            HSplitView {
                // 3D Visualization
                NetworkView(scene: simulationController.scene, cameraResetTrigger: simulationController.cameraResetTrigger)
                    .frame(minWidth: 400, minHeight: 400)
                    .layoutPriority(1)
                
                // PCC Interface (Right Side)
                PCCDashboardView()
                    .frame(minWidth: 400, maxWidth: 600)
            }
            .frame(minWidth: 1200, minHeight: 800)
            
            // Demo Mode Overlay
            if demoManager.isEnabled {
                DemoModeView()
                    .environmentObject(simulationController)
                    .environmentObject(demoManager)
                    .transition(.opacity)
                    .zIndex(100) // Ensure it's on top
            }
        }
    }
}
