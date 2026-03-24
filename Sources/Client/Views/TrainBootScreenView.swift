import SwiftUI

struct TrainBootScreenView: View {
    let train: Train
    var baseFontSize: CGFloat
    
    private let fontName = "VT323-Regular"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("SYSTEME DE CONTROLE TRAIN - V3.42")
                .font(.custom(fontName, size: baseFontSize * 1.5))
                .foregroundColor(.green)
                .padding(.bottom, 20)
            
            Group {
                Text("INITIALISATION BOOTLOADER... OK")
                if train.startupState.rawValue >= Train.StartupState.memoryCheck.rawValue {
                   Text("VERIFICATION MEMOIRE... 64MB OK")
                }
                if train.startupState.rawValue >= Train.StartupState.systemsCheck.rawValue {
                   Text("INITIALISATION PNEUMATIQUE... OK")
                   Text("INITIALISATION ELECTRIQUE... OK")
                }
                if train.startupState.rawValue >= Train.StartupState.radioConnect.rawValue {
                   Text("RECHERCHE RESEAU PCC...")
                   Text("CONNEXION ETABLIE.")
                }
            }
            .font(.custom(fontName, size: baseFontSize + 2))
            .foregroundColor(.green)
            
            Spacer()
            
            HStack {
                Text("SEQUENCE DE DEMARRAGE EN COURS...")
                Spacer()
                if train.startupState == .radioConnect {
                     ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .green))
                        .scaleEffect(0.5)
                }
            }
            .font(.custom(fontName, size: baseFontSize + 2))
            .foregroundColor(.green)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .padding()
    }
}
