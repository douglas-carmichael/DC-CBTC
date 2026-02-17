import SwiftUI
import SceneKit

struct ContentView: View {
    @EnvironmentObject var simulationController: SimulationController

    var body: some View {
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
    }
}
