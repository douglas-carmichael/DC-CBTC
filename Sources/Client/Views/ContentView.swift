import SwiftUI
import SceneKit

struct ContentView: View {
    @EnvironmentObject var simulationController: ClientNetworkService
    @EnvironmentObject var demoManager: DemoModeManager // Inject Demo Manager

    var body: some View {
        ZStack {
            // Standard App UI
            #if os(macOS)
            HSplitView {
                NetworkView(scene: simulationController.scene, cameraResetTrigger: simulationController.cameraResetTrigger)
                    .frame(minWidth: 400, minHeight: 400)
                    .layoutPriority(1)
                
                PCCDashboardView()
                    .frame(minWidth: 400, maxWidth: 600)
            }
            .frame(minWidth: 1200, minHeight: 800)
            #else
            HStack {
                NetworkView(scene: simulationController.scene, cameraResetTrigger: simulationController.cameraResetTrigger)
                    .frame(minWidth: 400, minHeight: 400)
                    .layoutPriority(1)
                
                PCCDashboardView()
                    .frame(minWidth: 400, maxWidth: 600)
            }
            .frame(minWidth: 1200, minHeight: 800)
            #endif
            
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
