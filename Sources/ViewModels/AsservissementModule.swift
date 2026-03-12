import Foundation
import CoreGraphics

struct AsservissementModule {
    let nominalBraking: CGFloat
    let emergencyBraking: CGFloat
    
    init(
        nominalBraking: CGFloat = 0.8,
        emergencyBraking: CGFloat = 1.2
    ) {
        self.nominalBraking = nominalBraking
        self.emergencyBraking = emergencyBraking
    }
    
    func process(
        train: inout Train,
        effectiveDistToMA: CGFloat,
        maxAcceleration: CGFloat
    ) -> CGFloat {
        var consigneVitesse: CGFloat = 0.0
        
        // 1. Calculate Target Speed Profile (Braking Curve)
        let distanceMargin: CGFloat = 1.0
        if effectiveDistToMA > distanceMargin {
            let brakingProfileSpeed = sqrt(2 * nominalBraking * (effectiveDistToMA - distanceMargin))
            consigneVitesse = min(train.targetSpeed, brakingProfileSpeed)
        } else {
            consigneVitesse = 0.0
        }
        
        // 2. Calculate Speed Error
        let speedError = consigneVitesse - train.speed
        
        // 3. Proportional Control
        let Kp: CGFloat = 1.0
        var desiredAcc = Kp * speedError
        
        // 4. Emergency Override
        let safeBrakingDistance = (train.speed * train.speed) / (2 * emergencyBraking)
        if effectiveDistToMA <= safeBrakingDistance + 0.5 {
            desiredAcc = -emergencyBraking
        }
        
        // 5. Environmental/Fault Overrides & Clamping
        if train.isEngineFault {
            desiredAcc = min(desiredAcc, (train.speed > 0) ? -0.1 : 0.0)
        }
        
        if desiredAcc > maxAcceleration {
            desiredAcc = maxAcceleration
        } else if desiredAcc < -emergencyBraking {
            desiredAcc = -emergencyBraking
        }
        
        // Update Train Status
        if abs(train.speed) < 0.05 && consigneVitesse < 0.1 {
            train.status = .stopped
            train.speed = 0
            desiredAcc = 0
        } else {
            train.status = .moving
        }
        
        // Save Telemetry
        train.consigneVitesse = consigneVitesse
        train.speedError = speedError
        train.desiredAcceleration = desiredAcc
        train.distanceToMA = effectiveDistToMA
        
        // Apply Adhesion Loss Logic
        var finalAcceleration = desiredAcc
        
        var totalAdhesionFactor: CGFloat = 0.0
        var totalDragDeceleration: CGFloat = 0.0
        
        for tire in train.tires {
            switch tire.status {
            case .ok:
                totalAdhesionFactor += 1.0
                totalDragDeceleration += 0.0
            case .lowPressure:
                totalAdhesionFactor += 0.9
                totalDragDeceleration += 0.05
            case .puncture:
                totalAdhesionFactor += 0.5
                totalDragDeceleration += 0.2
            case .burst:
                totalAdhesionFactor += 0.1
                totalDragDeceleration += 0.5
            }
        }
        
        let tireCount = train.tires.isEmpty ? 1 : train.tires.count
        let avgAdhesion = totalAdhesionFactor / CGFloat(tireCount)
        
        if finalAcceleration > 0 {
            finalAcceleration *= avgAdhesion
        } else if finalAcceleration < 0 {
            finalAcceleration *= avgAdhesion
        }
        
        if train.isPatinage && finalAcceleration > 0 {
             finalAcceleration *= 0.2
        }
        if train.isEnrayage && finalAcceleration < 0 {
            finalAcceleration *= 0.3
        }
        
        if train.speed > 0 {
            finalAcceleration -= totalDragDeceleration
        } else if train.speed == 0 && finalAcceleration < totalDragDeceleration {
            if finalAcceleration < totalDragDeceleration {
                 finalAcceleration = 0
            } else {
                 finalAcceleration -= totalDragDeceleration
            }
        }
        
        return finalAcceleration
    }
}
