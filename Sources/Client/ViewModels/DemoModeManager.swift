import SwiftUI
import Combine

class DemoModeManager: ObservableObject {
    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                startDemo()
            } else {
                stopDemo()
            }
        }
    }
    
    enum DemoViewType: Equatable {
        case network3D
        case synoptic
        case trainDetail(UUID)
    }
    
    @Published var currentView: DemoViewType = .network3D
    @Published var demoStatusText: String = ""
    
    private var timer: Timer?
    private var cycleIndex: Int = 0
    private var simulationController: ClientNetworkService?
    
    // Configuration
    private let viewDuration: TimeInterval = 10.0 // Seconds per view
    
    func setClientNetworkService(_ controller: ClientNetworkService) {
        self.simulationController = controller
    }
    
    private func startDemo() {
        print("Demo Mode Started")
        cycleIndex = 0
        currentView = .network3D
        updateStatusText()
        
        // Schedule timer
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: viewDuration, repeats: true) { [weak self] _ in
            self?.advanceCycle()
        }
    }
    
    private func stopDemo() {
        print("Demo Mode Stopped")
        timer?.invalidate()
        timer = nil
    }
    
    private func advanceCycle() {
        guard let controller = simulationController else { return }
        
        // Cycle: 3D -> Synoptic -> Train 1 -> ... -> Train N -> Repeat
        
        // Determine the sequence
        var sequence: [DemoViewType] = [.network3D, .synoptic]
        
        // Add active trains to sequence
        // We sort by name for consistent order
        let sortedTrains = controller.trains.sorted { $0.name < $1.name }
        for train in sortedTrains {
            sequence.append(.trainDetail(train.id))
        }
        
        // Advance index
        cycleIndex = (cycleIndex + 1) % sequence.count
        
        // Update View
        withAnimation(.easeInOut(duration: 1.0)) {
            currentView = sequence[cycleIndex]
        }
        
        updateStatusText()
    }
    
    private func updateStatusText() {
        switch currentView {
        case .network3D:
            demoStatusText = "VUE GLOBALE 3D"
        case .synoptic:
            demoStatusText = "TABLEAU DE CONTROLE OPTIQUE"
        case .trainDetail(let id):
            if let train = simulationController?.trains.first(where: { $0.id == id }) {
                demoStatusText = "DETAIL: \(train.name.uppercased())"
            } else {
                demoStatusText = "DETAIL RAME"
            }
        }
    }
}
