import SwiftUI
import SceneKit

struct NetworkView: NSViewRepresentable {
    var scene: SCNScene
    var cameraResetTrigger: Int
    
    class Coordinator: NSObject {
        var lastTrigger: Int = 0
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = NSColor.darkGray
        
        // Initialize lastTrigger to avoid immediate reset if not needed
        context.coordinator.lastTrigger = cameraResetTrigger
        
        return view
    }
    
    func updateNSView(_ nsView: SCNView, context: Context) {
        if context.coordinator.lastTrigger != cameraResetTrigger {
            context.coordinator.lastTrigger = cameraResetTrigger
            
            // Force reset camera
            if let cameraNode = scene.rootNode.childNode(withName: "MainCamera", recursively: true) {
                // Toggling allowsCameraControl helps reset the internal controller state
                nsView.allowsCameraControl = false
                nsView.pointOfView = cameraNode
                nsView.allowsCameraControl = true
            }
        }
    }
}
