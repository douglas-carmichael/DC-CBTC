import SwiftUI
import SceneKit

struct NetworkView: CrossPlatformViewRepresentable {
    var scene: SCNScene
    var cameraResetTrigger: Int
    
    class Coordinator: NSObject {
        var lastTrigger: Int = 0
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makePlatformView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = PlatformColor.darkGray
        
        // Initialize lastTrigger to avoid immediate reset if not needed
        context.coordinator.lastTrigger = cameraResetTrigger
        
        return view
    }
    
    func updatePlatformView(_ view: SCNView, context: Context) {
        if context.coordinator.lastTrigger != cameraResetTrigger {
            context.coordinator.lastTrigger = cameraResetTrigger
            
            // Force reset camera
            if let cameraNode = scene.rootNode.childNode(withName: "MainCamera", recursively: true) {
                // Toggling allowsCameraControl helps reset the internal controller state
                view.allowsCameraControl = false
                view.pointOfView = cameraNode
                view.allowsCameraControl = true
            }
        }
    }
}
