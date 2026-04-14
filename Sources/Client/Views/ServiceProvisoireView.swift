import SwiftUI

struct ServiceProvisoireView: View {
    @EnvironmentObject var controller: ClientNetworkService
    @Environment(\.dismiss) var dismiss
    
    @State private var startStationId: UUID?
    @State private var endStationId: UUID?
    @State private var selectedIntervalle: TimeInterval = 60.0
    
    private let availableIntervals: [TimeInterval] = [30.0, 60.0, 90.0, 120.0, 180.0, 240.0]
    private let fontName = "VT323-Regular"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(">>> CONFIGURATION SERVICE PROVISOIRE <<<")
                .font(.custom(fontName, size: 24))
                .foregroundColor(.green)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 10)
            
            Text("SELECTION INTERSTATION:")
                .font(.custom(fontName, size: 18))
                .foregroundColor(.green)
            
            HStack(spacing: 20) {
                // Start Station
                VStack(alignment: .leading, spacing: 10) {
                    Text("TERMINUS A:")
                        .font(.custom(fontName, size: 16))
                        .foregroundColor(.green)
                    
                    HStack(spacing: 8) {
                        Button("<") { cycleStartStation(forward: false) }
                            .buttonStyle(RetroCyclerStyle())
                        
                        Text(stationName(for: startStationId).uppercased())
                            .font(.custom(fontName, size: 18))
                            .foregroundColor(.white)
                            .frame(width: 170, alignment: .center)
                            .padding(.vertical, 5)
                            .background(Color.black)
                            .border(Color.green, width: 1)
                        
                        Button(">") { cycleStartStation(forward: true) }
                            .buttonStyle(RetroCyclerStyle())
                    }
                }
                
                // End Station
                VStack(alignment: .leading, spacing: 10) {
                    Text("TERMINUS B:")
                        .font(.custom(fontName, size: 16))
                        .foregroundColor(.green)
                    
                    HStack(spacing: 8) {
                        Button("<") { cycleEndStation(forward: false) }
                            .buttonStyle(RetroCyclerStyle())
                        
                        Text(stationName(for: endStationId).uppercased())
                            .font(.custom(fontName, size: 18))
                            .foregroundColor(.white)
                            .frame(width: 170, alignment: .center)
                            .padding(.vertical, 5)
                            .background(Color.black)
                            .border(Color.green, width: 1)
                        
                        Button(">") { cycleEndStation(forward: true) }
                            .buttonStyle(RetroCyclerStyle())
                    }
                }
            }
            .padding()
            .border(Color.green, width: 2)
            
            // Interval Selection
            HStack(spacing: 20) {
                Text("INTERVALLE:")
                    .font(.custom(fontName, size: 18))
                    .foregroundColor(.green)
                
                Button("<") { cycleInterval(forward: false) }
                    .buttonStyle(RetroCyclerStyle())
                
                Text("\(Int(selectedIntervalle)) SEC.")
                    .font(.custom(fontName, size: 18))
                    .foregroundColor(.white)
                    .frame(width: 100, alignment: .center)
                    .padding(.vertical, 5)
                    .background(Color.black)
                    .border(Color.green, width: 1)
                
                Button(">") { cycleInterval(forward: true) }
                    .buttonStyle(RetroCyclerStyle())
            }
            .padding(.top, 10)
            
            Spacer()
            
            // Current Status Map
            if let activeSP = controller.activeServiceProvisoire {
                let startName = stationName(for: activeSP.startStationId)
                let endName = stationName(for: activeSP.endStationId)
                
                Text("ACHEVEMENT: SERVICE PROVISOIRE ACTIF")
                    .font(.custom(fontName, size: 16))
                    .foregroundColor(.orange)
                Text("[\(startName)] <---> [\(endName)]")
                    .font(.custom(fontName, size: 18))
                    .foregroundColor(.yellow)
            } else {
                Text("ETAT: RESEAU COMPLET ACTIF")
                    .font(.custom(fontName, size: 16))
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            HStack(spacing: 20) {
                Button(action: {
                    if let s = startStationId, let e = endStationId, s != e {
                        let sp = ServiceProvisoire(startStationId: s, endStationId: e, intervalle: selectedIntervalle)
                        controller.setServiceProvisoire(sp)
                        dismiss()
                    }
                }) {
                    Text("ACTIVER S.P.")
                        .font(.custom(fontName, size: 18))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.black)
                }
                .disabled(startStationId == nil || endStationId == nil || startStationId == endStationId)
                .opacity((startStationId == nil || endStationId == nil || startStationId == endStationId) ? 0.3 : 1.0)
                
                Button(action: {
                    controller.setServiceProvisoire(nil)
                    startStationId = nil
                    endStationId = nil
                    dismiss()
                }) {
                    Text("RETABLIR LIGNE")
                        .font(.custom(fontName, size: 18))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .foregroundColor(.black)
                }
                
                Button(action: {
                    dismiss()
                }) {
                    Text("FERMER")
                        .font(.custom(fontName, size: 18))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray)
                        .foregroundColor(.black)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(30)
        .frame(minWidth: 500, minHeight: 400)
        .background(Color.black)
        .onAppear {
            if let activeSp = controller.activeServiceProvisoire {
                self.startStationId = activeSp.startStationId
                self.endStationId = activeSp.endStationId
                self.selectedIntervalle = activeSp.intervalle
            }
        }
    }
    
    private func stationName(for id: UUID?) -> String {
        guard let id = id else { return "---" }
        return controller.stations.first(where: { $0.id == id })?.name ?? "INCONNU"
    }

    private func cycleStartStation(forward: Bool) {
        cycle(selection: $startStationId, forward: forward)
    }

    private func cycleEndStation(forward: Bool) {
        cycle(selection: $endStationId, forward: forward)
    }
    
    private func cycle(selection: Binding<UUID?>, forward: Bool) {
        let allIds = [UUID?.none] + controller.stations.map { $0.id }
        let currentIdx = allIds.firstIndex(of: selection.wrappedValue) ?? 0
        var nextIdx = forward ? currentIdx + 1 : currentIdx - 1
        if nextIdx < 0 { nextIdx = allIds.count - 1 }
        if nextIdx >= allIds.count { nextIdx = 0 }
        selection.wrappedValue = allIds[nextIdx]
    }
    
    private func cycleInterval(forward: Bool) {
        let currentIdx = availableIntervals.firstIndex(of: selectedIntervalle) ?? 1
        var nextIdx = forward ? currentIdx + 1 : currentIdx - 1
        if nextIdx < 0 { nextIdx = availableIntervals.count - 1 }
        if nextIdx >= availableIntervals.count { nextIdx = 0 }
        selectedIntervalle = availableIntervals[nextIdx]
    }
}

struct RetroCyclerStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("VT323-Regular", size: 18))
            .foregroundColor(configuration.isPressed ? .black : .green)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(configuration.isPressed ? Color.green : Color.black)
            .border(Color.green, width: 1)
    }
}
