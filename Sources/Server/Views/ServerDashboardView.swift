import SwiftUI

struct ServerDashboardView: View {
    @EnvironmentObject var simulationController: SimulationController
    @ObservedObject var networkService = ServerNetworkService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("CBTC Metro Simulation Server")
                .font(.largeTitle)
                .bold()
            
            HStack {
                Text("Status:")
                Text(simulationController.isRunning ? "Running" : "Stopped")
                    .foregroundColor(simulationController.isRunning ? .green : .red)
                    .bold()
            }
            
            HStack {
                Text("Trains Active:")
                Text("\(simulationController.trains.count)")
                    .bold()
            }
            
            HStack {
                Text("Connected Clients:")
                Text("\(networkService.connectedClientCount)")
                    .bold()
            }
            

            
            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 400)
    }
}
