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
            TabView {
                ZStack(alignment: .bottomTrailing) {
                    NetworkView(scene: simulationController.scene, cameraResetTrigger: simulationController.cameraResetTrigger)
                        .edgesIgnoringSafeArea(.all)
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            simulationController.rotateCamera(left: true)
                        }) {
                            Image(systemName: "rotate.left")
                                .font(.system(size: 40))
                                .padding()
                        }
                        .buttonStyle(.card)
                        
                        Button(action: {
                            simulationController.rotateCamera(left: false)
                        }) {
                            Image(systemName: "rotate.right")
                                .font(.system(size: 40))
                                .padding()
                        }
                        .buttonStyle(.card)
                        
                        Button(action: {
                            simulationController.zoomCamera(in: false)
                        }) {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.system(size: 40))
                                .padding()
                        }
                        .buttonStyle(.card)
                        
                        Button(action: {
                            simulationController.zoomCamera(in: true)
                        }) {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.system(size: 40))
                                .padding()
                        }
                        .buttonStyle(.card)
                    }
                    .padding(50)
                }
                .tabItem {
                    Label("Map 3D", systemImage: "map.fill")
                }
                
                TVOSDashboardView()
                    .tabItem {
                        Label("Control Center", systemImage: "slider.horizontal.3")
                    }
            }
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
