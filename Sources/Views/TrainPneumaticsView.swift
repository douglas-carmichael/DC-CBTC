import SwiftUI

struct TrainPneumaticsView: View {
    @Environment(\.dynamicScale) var dynamicScale

    let train: Train
    let onBack: () -> Void
    @EnvironmentObject var simulationController: SimulationController
    
    // Retro font simulation
    private let fontName = "VT323-Regular"
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("RETOUR")
                    }
                    .font(.custom(fontName, size: 18 * dynamicScale))
                    .foregroundColor(.black)
                    .padding(4)
                    .background(Color.green)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                Text("PNEUMATIQUES")
                    .font(.custom(fontName, size: 32 * dynamicScale))
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Spacer()
                Text(parseTrainID(train.name))
                    .font(.custom(fontName, size: 32 * dynamicScale))
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            .padding(8)
            .background(Color.black)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.white), alignment: .bottom)
            
            // Content
            GeometryReader { geometry in
                HStack(spacing: 20) {
                    // Left Bogie (Tires 1-4)
                    VStack {
                        Text("BOGIE 1")
                            .font(.custom(fontName, size: 24 * dynamicScale))
                            .foregroundColor(.green)
                            .padding(.bottom, 20)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            ForEach(train.tires.filter { $0.id <= 4 }) { tire in
                                Button(action: {
                                    simulationController.cycleTireStatus(for: train.id, at: tire.id - 1)
                                }) {
                                    TireView(tire: tire)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider().background(Color.green)
                    
                    // Right Bogie (Tires 5-8)
                    VStack {
                        Text("BOGIE 2")
                            .font(.custom(fontName, size: 24 * dynamicScale))
                            .foregroundColor(.green)
                            .padding(.bottom, 20)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            ForEach(train.tires.filter { $0.id > 4 }) { tire in
                                Button(action: {
                                    simulationController.cycleTireStatus(for: train.id, at: tire.id - 1)
                                }) {
                                    TireView(tire: tire)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .background(Color.black)
            
        }
        .background(Color.black)
        .overlay(Rectangle().stroke(Color.green, lineWidth: 2))
    }
    
    private func parseTrainID(_ name: String) -> String {
        return name.components(separatedBy: " ").last ?? "000"
    }
    
    struct TireView: View {
    @Environment(\.dynamicScale) var dynamicScale

        let tire: Train.Tire
        private let fontName = "VT323-Regular"
        
        var statusColor: Color {
            switch tire.status {
            case .ok: return .green
            case .lowPressure: return .orange
            case .puncture: return .red
            case .burst: return .purple
            }
        }
        
        var body: some View {
            VStack {
                Text("PNEU \(tire.id)")
                    .font(.custom(fontName, size: 18 * dynamicScale))
                    .foregroundColor(statusColor)
                
                ZStack {
                    Circle()
                        .stroke(statusColor, lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    VStack {
                        Text(String(format: "%.1f", tire.pressure))
                            .font(.custom(fontName, size: 24 * dynamicScale))
                            .fontWeight(.bold)
                            .foregroundColor(statusColor)
                        Text("bar")
                            .font(.custom(fontName, size: 14 * dynamicScale))
                            .foregroundColor(statusColor)
                    }
                }
                
                Text(tire.status.rawValue.uppercased())
                    .font(.custom(fontName, size: 14 * dynamicScale))
                    .foregroundColor(statusColor)
            }
            .padding()
            .background(Color.black)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(statusColor.opacity(0.5), lineWidth: 1))
        }
    }
}
