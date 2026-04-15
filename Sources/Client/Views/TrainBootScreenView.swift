import SwiftUI

struct TrainBootScreenView: View {
    let train: Train
    var baseFontSize: CGFloat
    
    private let fontName = "VT323-Regular"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(.init(String.loc("boot.system_title")))
                .font(.custom(fontName, size: baseFontSize * 1.5))
                .foregroundColor(.green)
                .padding(.bottom, 20)
            
            Group {
                Text(.init(String.loc("boot.init_bootloader")))
                if train.startupState.rawValue >= Train.StartupState.memoryCheck.rawValue {
                   Text(.init(String.loc("boot.check_memory")))
                }
                if train.startupState.rawValue >= Train.StartupState.systemsCheck.rawValue {
                   Text(.init(String.loc("boot.init_pneumatique")))
                   Text(.init(String.loc("boot.init_electrique")))
                }
                if train.startupState.rawValue >= Train.StartupState.radioConnect.rawValue {
                   Text(.init(String.loc("boot.recherche_reseau")))
                   Text(.init(String.loc("boot.connexion_etablie")))
                }
            }
            .font(.custom(fontName, size: baseFontSize + 2))
            .foregroundColor(.green)
            
            Spacer()
            
            HStack {
                Text(.init(String.loc("boot.sequence_demarrage")))
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
