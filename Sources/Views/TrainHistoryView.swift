import SwiftUI
import Charts

struct TrainHistoryView: View {
    let train: Train
    let onClose: () -> Void
    @State private var history: [TrainLogEntry] = []
    static let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("HISTORIQUE: \(train.name)")
                    .font(.custom("VT323-Regular", size: 24))
                    .foregroundColor(.green)
                Spacer()
                
                Button(action: {
                    TrainDataService.shared.clearHistory(for: train.id)
                    loadData()
                }) {
                    Text("EFFACER")
                        .font(.custom("VT323-Regular", size: 14))
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onClose) {
                    Image(systemName: "xmark.square.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 8)
            }
            .padding()
            .background(Color.black)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.green), alignment: .bottom)
            
            ScrollView {
                VStack(spacing: 20) {
                    if history.isEmpty {
                        Text("AUCUNE DONNEE ENREGISTREE")
                            .font(.custom("VT323-Regular", size: 20))
                            .foregroundColor(.gray)
                            .padding(.top, 50)
                    } else {
                        // Speed Chart
                        ChartCard(title: "VITESSE (km/h)") {
                            Chart(history) { entry in
                                LineMark(
                                    x: .value("Time", entry.timestamp),
                                    y: .value("Speed", entry.speed * 3.6) // m/s to km/h
                                )
                                .foregroundStyle(Color.green)
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                        }
                        
                        // Voltage Chart
                        ChartCard(title: "TENSION LIGNE (V)") {
                            Chart(history) { entry in
                                LineMark(
                                    x: .value("Time", entry.timestamp),
                                    y: .value("Voltage", entry.voltage)
                                )
                                .foregroundStyle(Color.yellow)
                            }
                             .chartYAxis {
                                AxisMarks(position: .leading, values: .automatic(desiredCount: 5))
                            }
                            .chartYScale(domain: 700...800)
                        }
                        
                        // Current Chart
                        ChartCard(title: "COURANT TRACTION (A)") {
                            Chart(history) { entry in
                                LineMark(
                                    x: .value("Time", entry.timestamp),
                                    y: .value("Current", entry.current)
                                )
                                .foregroundStyle(Color.blue)
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color.black)
        .onAppear {
            loadData()
        }
        .onReceive(Self.timer) { _ in
            loadData()
        }
    }
    
    private func loadData() {
        let newHistory = TrainDataService.shared.getHistory(trainId: train.id)
        history = newHistory
    }
}

struct ChartCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.custom("VT323-Regular", size: 18))
                .foregroundColor(.green)
                .padding(.bottom, 5)
            
            content
                .frame(height: 200)
                .padding()
                .background(Color.black.opacity(0.5))
                .border(Color.green.opacity(0.5), width: 1)
        }
    }
}
