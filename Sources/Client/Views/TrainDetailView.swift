import SwiftUI

struct TrainDetailViewWrapper: View {
    let trainID: UUID
    @EnvironmentObject var simulationController: ClientNetworkService
    
    var body: some View {
        if let train = simulationController.trains.first(where: { $0.id == trainID }) {
            TrainDetailView(train: train, onClose: {
                // In a separate window, close might mean closing the window, 
                // but standard macOS windows have a close button.
                // We can leave this empty or use proper window closing env if needed.
            })
            .frame(minWidth: 600, minHeight: 450)
        } else {
            Text(String.loc("train.signal_lost", trainID.uuidString))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
    }
}

struct TrainDetailView: View {
    let train: Train
    let onClose: () -> Void
    var isDemoMode: Bool = false // Add optional parameter
    @EnvironmentObject var simulationController: ClientNetworkService // Injected
    
    // Retro font simulation
    private let fontName = "VT323-Regular" // Or another monospaced font
    private var defaultBaseFontSize: CGFloat {
        return isDemoMode ? 18 : 12 // Scale up for demo mode
    }
    
    enum DrillDownView: String, CaseIterable {
        case none
        case traction       // Traction / Braking / Tires
        case signaling      // Alarms / Position / SEC
        case dca            // DCA / PA
        case operations     // Exploitation / Doors / Prep
        case auxiliary      // Auxiliaries
        case alarms         // Dedicated Alarms Page
        case pneumatics     // Dedicated Pneumatics Page
        case security       // Dedicated Security Page
        case telecommands   // Dedicated Telecommands Page
        case history        // Dedicated History Page
        case asservissement // Asservissement Telemetry Page
    }
    
    @State private var currentView: DrillDownView = .none
    @State private var selectedAuxiliary: String? // Search/Drill-down state
    
    // Type alias for status items to ensure consistency
    typealias StatusItem = (label: String, color: Color, active: Bool, value: String?, faultKey: FaultType?)
    
    var body: some View {
        GeometryReader { geometry in
            // 1000x700 is the estimated "standard" width/height for the 12pt layout
            let scaleW = geometry.size.width / 1000.0
            let scaleH = geometry.size.height / 700.0
            let scale = max(0.5, min(scaleW, scaleH))
            let dynamicFontSize = defaultBaseFontSize * scale
            
            Group {
                switch currentView {
                case .traction:
                    TrainTractionView(train: train, selectedSystem: $selectedAuxiliary, onBack: { currentView = .none })
                case .signaling:
                    TrainSignalingView(train: train, selectedSystem: $selectedAuxiliary, onBack: { currentView = .none })
                case .dca:
                    TrainDCAView(train: train, selectedSystem: $selectedAuxiliary, onBack: { currentView = .none })
                case .operations:
                    TrainOperationsView(train: train, selectedSystem: $selectedAuxiliary, onBack: { currentView = .none })
                case .auxiliary:
                    TrainAuxiliaryView(train: train, selectedSystem: $selectedAuxiliary, onBack: { 
                        currentView = .none
                        selectedAuxiliary = nil
                    })
                case .alarms:
                    TrainAlarmsView(train: train, onBack: { currentView = .none })
                case .pneumatics:
                    TrainPneumaticsView(train: train, onBack: { currentView = .none })
                case .security:
                    TrainSecurityView(train: train, onBack: { currentView = .none })
                case .telecommands:
                    TrainTelecommandsView(train: train, onBack: { currentView = .none })
                case .history:
                    TrainHistoryView(train: train, onClose: { currentView = .none })
                case .asservissement:
                    TrainAsservissementView(train: train, onBack: { currentView = .none })
                case .none:
                    TrainMainDashboardView(
                        train: train,
                        currentView: $currentView,
                        selectedAuxiliary: $selectedAuxiliary,
                        baseFontSize: dynamicFontSize
                    )
                } // Close switch
            } // Close Group
            .environment(\.dynamicScale, scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } // Close GeometryReader
    } // Close body
}

struct DynamicScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var dynamicScale: CGFloat {
        get { self[DynamicScaleKey.self] }
        set { self[DynamicScaleKey.self] = newValue }
    }
}
