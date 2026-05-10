import Foundation
import TermKit

class RegulationDeTraficView: View {
    var telemetry: SystemTelemetry?
    
    var cyanScheme: ColorScheme!
    var greenScheme: ColorScheme!
    var redScheme: ColorScheme!
    
    var timeLabel: Label!
    var trainsOnlineLabel: Label!
    
    var leftCol: View!
    var rightCol: View!
    var sens1Frame: Frame!
    var sens2Frame: Frame!
    
    public override init() {
        super.init()
        self.width = Dim.fill()
        self.height = Dim.fill()
        
        let attrCyan = Application.driver.makeAttribute(fore: .cyan, back: .black)
        cyanScheme = ColorScheme(normal: attrCyan, focus: attrCyan, hotNormal: attrCyan, hotFocus: attrCyan)
        
        let attrGreen = Application.driver.makeAttribute(fore: .brightGreen, back: .black)
        greenScheme = ColorScheme(normal: attrGreen, focus: attrGreen, hotNormal: attrGreen, hotFocus: attrGreen)
        
        // Emulate Orange/Red blocks via background color with white text
        let attrRed = Application.driver.makeAttribute(fore: .white, back: .brightRed)
        redScheme = ColorScheme(normal: attrRed, focus: attrRed, hotNormal: attrRed, hotFocus: attrRed)
        
        buildLeftColumn()
        buildRightColumn()
    }
    
    private func buildLeftColumn() {
        leftCol = View()
        leftCol.x = Pos.at(0)
        leftCol.y = Pos.at(0)
        leftCol.width = try! Dim.percent(n: 45)
        leftCol.height = Dim.fill()
        self.addSubview(leftCol)
        
        let title = Label("REGULATION DE TRAFIC")
        title.colorScheme = cyanScheme
        title.x = Pos.center()
        title.y = Pos.at(0)
        leftCol.addSubview(title)
        
        let dbl1 = Label("DECALAGE C / HORAIRE\n  RECALAGE")
        dbl1.colorScheme = cyanScheme
        dbl1.x = Pos.at(2)
        dbl1.y = Pos.at(3)
        leftCol.addSubview(dbl1)
        
        let dbl2 = Label("AVANCE / RETARD")
        dbl2.colorScheme = cyanScheme
        dbl2.x = Pos.at(2)
        dbl2.y = Pos.at(6)
        leftCol.addSubview(dbl2)
        
        let dbl3 = Label("VEHICULES EN LIGNE - NOMBRE NORMAL")
        dbl3.colorScheme = cyanScheme
        dbl3.x = Pos.at(2)
        dbl3.y = Pos.at(8)
        leftCol.addSubview(dbl3)
        
        trainsOnlineLabel = Label("0")
        trainsOnlineLabel.x = Pos.at(40)
        trainsOnlineLabel.y = Pos.at(8)
        leftCol.addSubview(trainsOnlineLabel)
        
        let dbl4 = Label("HORAIRES\n  HEURES DE BASE")
        dbl4.colorScheme = cyanScheme
        dbl4.x = Pos.at(2)
        dbl4.y = Pos.at(10)
        leftCol.addSubview(dbl4)
        
        timeLabel = Label("...")
        timeLabel.x = Pos.at(20)
        timeLabel.y = Pos.at(11)
        leftCol.addSubview(timeLabel)
        
        let dbl5 = Label("BATTEMENT     NORMAL:    PROLONGE:")
        dbl5.colorScheme = cyanScheme
        dbl5.x = Pos.at(2)
        dbl5.y = Pos.at(14)
        leftCol.addSubview(dbl5)
    }
    
    private func buildRightColumn() {
        rightCol = View()
        rightCol.x = try! Pos.percent(n: 48)
        rightCol.y = Pos.at(1)
        rightCol.width = Dim.fill()
        rightCol.height = Dim.fill()
        self.addSubview(rightCol)
        
        sens1Frame = Frame(" SENS 1 (<--) ")
        sens1Frame.colorScheme = greenScheme
        sens1Frame.x = Pos.at(0)
        sens1Frame.y = Pos.at(0)
        sens1Frame.width = try! Dim.percent(n: 48)
        sens1Frame.height = Dim.fill()
        rightCol.addSubview(sens1Frame)
        
        sens2Frame = Frame(" SENS 2 (-->) ")
        sens2Frame.colorScheme = greenScheme
        sens2Frame.x = try! Pos.percent(n: 52)
        sens2Frame.y = Pos.at(0)
        sens2Frame.width = Dim.fill()
        sens2Frame.height = Dim.fill()
        rightCol.addSubview(sens2Frame)
    }
    
    func draw(telemetry: SystemTelemetry) {
        self.telemetry = telemetry
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        timeLabel.text = df.string(from: Date())
        trainsOnlineLabel.text = "\(telemetry.trains.count)"
        
        // Purge old frames to rebuild dynamically
        sens1Frame.removeAllSubviews()
        sens2Frame.removeAllSubviews()
        
        // Rebuild Train synoptic blocks
        var rowSens1 = 0
        var rowSens2 = 0
        
        for train in telemetry.trains {
            let frame = Frame(" \(train.name) ")
            frame.colorScheme = greenScheme
            frame.width = Dim.fill()
            frame.height = Dim.sized(7)
            
            // "Norm" or "Hors" status tag (Orange/Red styling mapped to RedScheme)
            let statusText = train.status == .stopped ? " HORS " : " NORM "
            let status = Label(statusText)
            status.colorScheme = train.status == .stopped ? redScheme : cyanScheme
            status.x = Pos.center()
            status.y = Pos.at(1)
            frame.addSubview(status)
            
            // Mode tag
            let modeStr = (train.mode == .auto ? "AUTO" : "MANU")
            let modeLabel = Label(modeStr)
            modeLabel.colorScheme = cyanScheme
            modeLabel.x = Pos.at(2)
            modeLabel.y = Pos.at(3)
            frame.addSubview(modeLabel)
            
            let posLabel = Label(String(format: "P: %.0f m", train.position))
            // posLabel.colorScheme = cyanScheme
            posLabel.x = Pos.at(10)
            posLabel.y = Pos.at(3)
            frame.addSubview(posLabel)
            
            let speedLabel = Label(String(format: "V: %.1f km/h", train.speed * 3.6))
            speedLabel.x = Pos.at(10)
            speedLabel.y = Pos.at(4)
            frame.addSubview(speedLabel)
            
            if train.travelDirection == .forward {
                frame.x = Pos.at(1)
                frame.y = Pos.at(rowSens1 * 8)
                sens1Frame.addSubview(frame)
                rowSens1 += 1
            } else {
                frame.x = Pos.at(1)
                frame.y = Pos.at(rowSens2 * 8)
                sens2Frame.addSubview(frame)
                rowSens2 += 1
            }
        }
        
        self.setNeedsDisplay()
    }
}
