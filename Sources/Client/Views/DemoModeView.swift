import SwiftUI
import SceneKit

struct DemoModeView: View {
    @EnvironmentObject var demoManager: DemoModeManager
    @EnvironmentObject var simulationController: ClientNetworkService
    
    // Timer for auto-hiding overlay controls?
    @State private var showControls: Bool = true
    
    var body: some View {
        ZStack {
            // Background Layer (Black to ensure full coverage)
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Content Layer
            Group {
                switch demoManager.currentView {
                case .network3D:
                    NetworkView(scene: simulationController.scene, cameraResetTrigger: simulationController.cameraResetTrigger)
                        .transition(.opacity)
                case .synoptic:
                    SynopticView()
                        .transition(.opacity)
                case .trainDetail(let id):
                    if let train = simulationController.trains.first(where: { $0.id == id }) {
                        // Wrapping in a GeometryReader to handle layout
                        GeometryReader { _ in
                            TrainDetailView(train: train, onClose: {}, isDemoMode: true)
                                .environmentObject(simulationController)
                        }
                        .transition(.opacity)
                    } else {
                        // Fallback if train removed during demo
                        Text(.init(String.loc("demo.recherche_signal")))
                            .foregroundColor(.green)
                            .font(.custom("VT323-Regular", size: 24))
                    }
                }
            }
            .id(demoManager.currentView) // Force transition on change
            
            // Overlay Layer (Status & Exit)
            VStack {
                HStack {
                    // Demo Status Indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .opacity(blinkOpacity)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                    blinkOpacity = 0.2
                                }
                            }
                        
                        Text(String(format: String.loc("demo.status"), demoManager.demoStatusText))
                            .font(.custom("VT323-Regular", size: 18))
                            .foregroundColor(.red)
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.red, lineWidth: 1))
                    
                    Spacer()
                    
                    // Exit Button
                    Button(action: {
                        withAnimation {
                            demoManager.isEnabled = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text(.init(String.loc("btn.quitter")))
                                .font(.custom("VT323-Regular", size: 18))
                        }
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                
                Spacer()
            }
        }
        .onAppear {
            demoManager.setClientNetworkService(simulationController)
        }
    }
    
    @State private var blinkOpacity: Double = 1.0
}

extension DemoModeManager.DemoViewType: Hashable {
    static func == (lhs: DemoModeManager.DemoViewType, rhs: DemoModeManager.DemoViewType) -> Bool {
        switch (lhs, rhs) {
        case (.network3D, .network3D): return true
        case (.synoptic, .synoptic): return true
        case (.trainDetail(let id1), .trainDetail(let id2)): return id1 == id2
        default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .network3D: hasher.combine(0)
        case .synoptic: hasher.combine(1)
        case .trainDetail(let id): hasher.combine(id)
        }
    }
}
