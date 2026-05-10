import SwiftUI
import RealityKit

struct ImmersiveTrackView: View {
    @EnvironmentObject var simulationState: SimulationState
    
    // Scale factor: 1 meter in simulation = 0.005 meters in RealityKit (1:200 scale)
    // Radius of 159m -> 0.79m radius in physical space.
    let scale: Float = 0.005
    
    var body: some View {
        RealityView { content in
            let root = Entity()
            root.name = "Root"
            // Position the root at coffee-table height (0.5m), positioned 0.9m in front of the user
            // This places the front edge of the track right in front of the user, keeping it visible
            // between the user and the dashboard.
            root.position = [0, 0.5, -0.9]
            
            drawTrack(root: root)
            drawStations(root: root, stations: simulationState.stations)
            
            content.add(root)
            
        } update: { content in
            guard let root = content.entities.first(where: { $0.name == "Root" }) else { return }
            
            updateTrains(root: root, trains: simulationState.trains)
        }
    }
    
    private func drawTrack(root: Entity) {
        let trackMaterial = SimpleMaterial(color: .lightGray, isMetallic: false)
        
        let trackLength: CGFloat = 1000.0 // 10 segments of 100m
        let radius = Float(trackLength / (2 * .pi)) * scale
        
        let numBoxes = 100
        let boxWidth = Float(trackLength) * scale / Float(numBoxes)
        let boxMesh = MeshResource.generateBox(width: boxWidth + 0.005, height: 0.02, depth: 0.1)
        
        for i in 0..<numBoxes {
            let entity = ModelEntity(mesh: boxMesh, materials: [trackMaterial])
            let progress = Float(i) / Float(numBoxes)
            let angle = progress * 2 * .pi
            
            let x = radius * cos(angle)
            let z = radius * sin(angle)
            
            entity.position = [x, 0, z]
            entity.orientation = simd_quatf(angle: -angle - .pi/2, axis: [0, 1, 0])
            root.addChild(entity)
        }
    }
    
    private func drawStations(root: Entity, stations: [Station]) {
        let stationMaterial = SimpleMaterial(color: .white, isMetallic: false)
        let trackLength: CGFloat = 1000.0
        let radius = Float(trackLength / (2 * .pi)) * scale
        
        let platformMesh = MeshResource.generateBox(width: 0.4, height: 0.05, depth: 0.2)
        
        for station in stations {
            let entity = ModelEntity(mesh: platformMesh, materials: [stationMaterial])
            let progress = Float(station.position / trackLength)
            let angle = progress * 2 * .pi
            
            // Offset the platform to the side of the track
            let offset: Float = station.platformSide == .right ? 0.15 : -0.15
            let r = radius + offset
            
            entity.position = [r * cos(angle), 0.025, r * sin(angle)]
            entity.orientation = simd_quatf(angle: -angle - .pi/2, axis: [0, 1, 0])
            
            root.addChild(entity)
        }
    }
    
    private func updateTrains(root: Entity, trains: [Train]) {
        let trackLength: CGFloat = 1000.0
        let radius = Float(trackLength / (2 * .pi)) * scale
        
        let currentTrainIds = Set(trains.map { $0.id.uuidString })
        for child in root.children {
            if child.name.starts(with: "train_") && !currentTrainIds.contains(String(child.name.dropFirst(6))) {
                child.removeFromParent()
            }
        }
        
        for train in trains {
            let trainName = "train_\(train.id.uuidString)"
            var trainEntity: ModelEntity
            
            if let existing = root.findEntity(named: trainName) as? ModelEntity {
                trainEntity = existing
            } else {
                let mesh = MeshResource.generateBox(width: 0.15, height: 0.06, depth: 0.08)
                trainEntity = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: .blue, isMetallic: false)])
                trainEntity.name = trainName
                root.addChild(trainEntity)
            }
            
            var color: UIColor = .green
            if train.isLoadSheddingActive {
                color = .orange
            } else if train.status == .stopped || train.status == .docked {
                color = .red
            }
            trainEntity.model?.materials = [SimpleMaterial(color: color, isMetallic: false)]
            
            let progress = Float(train.position / trackLength)
            let angle = progress * 2 * .pi
            
            trainEntity.position = [radius * cos(angle), 0.04, radius * sin(angle)]
            trainEntity.orientation = simd_quatf(angle: -angle - .pi/2, axis: [0, 1, 0])
        }
    }
}
