import Foundation
import TermKit

enum TerminalTab: Int, CaseIterable {
    case networkOverview = 1
    case traction = 2
    case auxiliary = 3
    case dca = 4
    case operations = 5
    case pneumatics = 6
    case asservissement = 7
    
    var title: String {
        switch self {
        case .networkOverview: return "Network Overview"
        case .traction: return "Traction / Freinage"
        case .auxiliary: return "Auxiliaires"
        case .dca: return "DCA"
        case .operations: return "Operations"
        case .pneumatics: return "Pneumatiques"
        case .asservissement: return "Asservissement"
        }
    }
}

class TrainSubsystemTerminalView: View {
    var cyanScheme: ColorScheme!
    var greenScheme: ColorScheme!
    var redScheme: ColorScheme!
    
    var titleFrame: Frame!
    
    public override init() {
        super.init()
        self.width = Dim.fill()
        self.height = Dim.fill()
        
        let attrCyan = Application.driver.makeAttribute(fore: .cyan, back: .black)
        cyanScheme = ColorScheme(normal: attrCyan, focus: attrCyan, hotNormal: attrCyan, hotFocus: attrCyan)
        
        let attrGreen = Application.driver.makeAttribute(fore: .brightGreen, back: .black)
        greenScheme = ColorScheme(normal: attrGreen, focus: attrGreen, hotNormal: attrGreen, hotFocus: attrGreen)
        
        let attrRed = Application.driver.makeAttribute(fore: .white, back: .brightRed)
        redScheme = ColorScheme(normal: attrRed, focus: attrRed, hotNormal: attrRed, hotFocus: attrRed)
        
        titleFrame = Frame("")
        titleFrame.colorScheme = greenScheme
        titleFrame.x = Pos.at(2)
        titleFrame.y = Pos.at(1)
        titleFrame.width = try! Dim.percent(n: 90)
        titleFrame.height = try! Dim.percent(n: 90)
        self.addSubview(titleFrame)
    }
    
    func draw(train: Train, tab: TerminalTab) {
        let dirLabel = train.travelDirection == .forward ? "SENS 1" : "SENS 2"
        titleFrame.title = " \(tab.title.uppercased()) - \(train.name) (\(dirLabel)) "
        titleFrame.removeAllSubviews()
        
        var yPos = 1
        
        func addRow(_ key: String, _ val: String, isAlarm: Bool = false) {
            let keyLabel = Label(key)
            keyLabel.colorScheme = cyanScheme
            keyLabel.x = Pos.at(2)
            keyLabel.y = Pos.at(yPos)
            
            let valLabel = Label(isAlarm ? " \(val) " : val)
            valLabel.colorScheme = isAlarm ? redScheme : cyanScheme
            valLabel.x = Pos.at(35)
            valLabel.y = Pos.at(yPos)
            
            titleFrame.addSubview(keyLabel)
            titleFrame.addSubview(valLabel)
            yPos += 2
        }
        
        switch tab {
        case .traction:
            addRow("TRACTION CURRENT", String(format: "%.1f A", train.tractionCurrent))
            addRow("TRACTION TORQUE", String(format: "%.1f %%", train.tractionTorque))
            addRow("WHEEL SLIP (PATINAGE)", train.isPatinage ? "ACTIVE" : "NORMAL", isAlarm: train.isPatinage)
            addRow("WHEEL SLIDE (ENRAYAGE)", train.isEnrayage ? "ACTIVE" : "NORMAL", isAlarm: train.isEnrayage)
            addRow("ENGINE FAULT", train.isEngineFault ? "FAULT" : "NORMAL", isAlarm: train.isEngineFault)
            addRow("BRAKE FAULT", train.isBrakeFault ? "FAULT" : "NORMAL", isAlarm: train.isBrakeFault)
            addRow("EMERGENCY BRAKE COUNTS", "\(train.emergencyBrakeCounter)", isAlarm: train.emergencyBrakeCounter > 0)
            
        case .auxiliary:
            addRow("MAIN VOLTAGE (750v)", String(format: "%.1f V", train.mainVoltage))
            addRow("BATTERY VOLTAGE", String(format: "%.1f V", train.batteryVoltage))
            addRow("CVS OUTPUT", String(format: "%.1f V", train.cvsOutputVoltage))
            addRow("COMPRESSOR (8.5 Bar)", String(format: "%.1f BAR", train.compressorPressure))
            addRow("LIGHTING CURRENT", String(format: "%.1f A", train.lightingCurrent))
            addRow("VENTILATION", train.areVentilated ? "ACTIVATED" : "INACTIVE")
            addRow("LOAD SHEDDING (BT)", train.isLoadSheddingActive ? "YES" : "NO", isAlarm: train.isLoadSheddingActive)
            addRow("CABIN TEMP", String(format: "%.1f °C [T: %.1f]", train.interiorTemperature, train.targetTemperature))
            
        case .dca:
            addRow("DCA MODE", train.mode == .manual ? "MANUAL OVERRIDE" : "AUTOMATIC (CVS)", isAlarm: train.mode == .manual)
            addRow("SPEED REQUEST", String(format: "%.1f km/h", train.manualSpeedRequest * 3.6))
            addRow("RADIO SYNC FAULT", train.isSignalFault ? "LOSS" : "NORMAL", isAlarm: train.isSignalFault)
            addRow("DOORS STATE", train.areDoorsOpen ? "OPEN" : "CLOSED")
            addRow("DOOR OBSTRUCTION", train.isDoorFault ? "FAULT" : "NORMAL", isAlarm: train.isDoorFault)
            
        case .operations:
            addRow("STARTUP STATE", String(describing: train.startupState))
            addRow("VIDEO SYSTEM", train.isVideoSystemInitialized ? "OK" : "INITIALIZING")
            addRow("AUDIO SYSTEM", train.isSoundSystemActive ? "OK" : "FAILED", isAlarm: !train.isSoundSystemActive)
            addRow("MULTIMEDIA RESET", train.isMultimediaResetting ? "IN PROGRESS" : "NO")
            addRow("DAM ARCHIVE", train.isArchiving ? "RECORDING" : "IDLE")
            addRow("LAST STATION ID", train.lastServicedStationId?.uuidString ?? "N/A")
            addRow("PASSENGER LOAD", "\(train.passengerCount)")
            
        case .pneumatics:
            for tire in train.tires {
                let pStr = String(format: "%.1f bar", tire.pressure)
                addRow("TIRE \(tire.id)", "[\(tire.status.rawValue.uppercased())] \(pStr)", isAlarm: tire.status != .ok)
            }
            
        case .asservissement:
            addRow("CONSIGNE VITESSE", String(format: "%.1f km/h", train.consigneVitesse * 3.6))
            addRow("TARGET SPEED", String(format: "%.1f km/h", train.speed * 3.6))
            addRow("SPEED ERROR", String(format: "%.1f km/h", train.speedError * 3.6))
            addRow("TARGET ACCELERATION", String(format: "%.2f m/s²", train.desiredAcceleration))
            addRow("CURRENT ACCELERATION", String(format: "%.2f m/s²", train.acceleration))
            addRow("LMA (DISTANCE TO MA)", String(format: "%.1f m", train.distanceToMA))
            
        default:
            addRow("STATUS", "NO DATA EXPECTED")
        }
        
        self.setNeedsDisplay()
    }
}
