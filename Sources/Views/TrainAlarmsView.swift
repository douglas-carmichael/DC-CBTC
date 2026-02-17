import SwiftUI

struct TrainAlarmsView: View {
    let train: Train
    let onBack: () -> Void
    
    // Retro font simulation
    private let fontName = "VT323-Regular"
    
    // Date formatter for alarm timestamps
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
    
    /// All alarms sorted newest-first
    private var sortedAlarms: [Train.Alarm] {
        train.alarms.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Count of currently active alarms
    private var activeCount: Int {
        train.alarms.filter(\.isActive).count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("RETOUR")
                    }
                    .font(.custom(fontName, size: 18))
                    .foregroundColor(.black)
                    .padding(4)
                    .background(Color.green)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                Text("LISTE DES ALARMES")
                    .font(.custom(fontName, size: 32))
                    .fontWeight(.bold)
                    .foregroundColor(.red) // Red for Alarms
                Spacer()
                
                // Active alarm count badge
                Text("\(activeCount) ACTIVE\(activeCount != 1 ? "S" : "")")
                    .font(.custom(fontName, size: 18))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(activeCount > 0 ? Color.red : Color.green)
                
                Text(parseTrainID(train.name))
                    .font(.custom(fontName, size: 32))
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .padding(.leading, 8)
            }
            .padding(8)
            .background(Color.black)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.white), alignment: .bottom)
            
            // List Header
            HStack {
                Text("HEURE").frame(width: 120, alignment: .leading)
                Text("DESIGNATION").frame(maxWidth: .infinity, alignment: .leading)
                Text("ETAT").frame(width: 100, alignment: .trailing)
            }
            .font(.custom(fontName, size: 20))
            .foregroundColor(.green)
            .padding()
            .background(Color.black)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.green), alignment: .bottom)
            
            // Scrollable Alarm Log
            ScrollView {
                VStack(spacing: 0) {
                    if sortedAlarms.isEmpty {
                        Text("AUCUNE ALARME")
                            .font(.custom(fontName, size: 24))
                            .foregroundColor(.gray)
                            .padding(.top, 50)
                    } else {
                        ForEach(sortedAlarms) { alarm in
                            HStack {
                                Text(Self.timeFormatter.string(from: alarm.timestamp))
                                    .frame(width: 120, alignment: .leading)
                                Text(alarm.label)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(alarm.isActive ? "ACTIVE" : "RESOLUE")
                                    .frame(width: 100, alignment: .trailing)
                                    .fontWeight(.bold)
                            }
                            .font(.custom(fontName, size: 18))
                            .foregroundColor(alarm.isActive ? .red : .gray)
                            .padding()
                            .background(
                                alarm.isActive
                                    ? Color.red.opacity(0.1)
                                    : Color.black
                            )
                            .overlay(Rectangle().frame(height: 1).foregroundColor(.green.opacity(0.3)), alignment: .bottom)
                        }
                    }
                }
            }
            .background(Color.black)
            
            Spacer()
        }
        .background(Color.black)
        .overlay(Rectangle().stroke(Color.red, lineWidth: 2))
    }
    
    private func parseTrainID(_ name: String) -> String {
        return name.components(separatedBy: " ").last ?? "000"
    }
}
