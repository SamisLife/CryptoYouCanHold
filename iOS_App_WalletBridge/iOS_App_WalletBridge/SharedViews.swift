import SwiftUI
import SceneKit
import UIKit

struct GridBackgroundView: View {
    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.07).ignoresSafeArea()
            GeometryReader { geometry in
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let spacing: CGFloat = 35
                    for x in stride(from: 0, through: width, by: spacing) {
                        path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: height))
                    }
                    for y in stride(from: 0, through: height, by: spacing) {
                        path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: width, y: y))
                    }
                }.stroke(Color.white.opacity(0.04), lineWidth: 1)
            }.ignoresSafeArea()
        }
    }
}

struct Coin3DView: UIViewRepresentable {
    class Coordinator: NSObject {
        var userRotationNode: SCNNode?
        var currentXAngle: Float = Float.pi / 10
        var currentYAngle: Float = 0.0
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view as? SCNView, let node = userRotationNode else { return }
            let translation = gesture.translation(in: view)
            currentYAngle += Float(translation.x) * 0.01
            currentXAngle += Float(translation.y) * 0.01
            node.eulerAngles = SCNVector3(currentXAngle, currentYAngle, 0)
            gesture.setTranslation(.zero, in: view)
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView(); let scene = SCNScene()
        
        let faceMaterial = SCNMaterial()
        faceMaterial.diffuse.contents = generateCryptoTexture()
        faceMaterial.metalness.contents = 1.0; faceMaterial.roughness.contents = 0.18; faceMaterial.lightingModel = .physicallyBased
        
        let sideMaterial = SCNMaterial()
        sideMaterial.diffuse.contents = UIColor(red: 0.95, green: 0.75, blue: 0.1, alpha: 1.0)
        sideMaterial.metalness.contents = 1.0; sideMaterial.roughness.contents = 0.18; sideMaterial.lightingModel = .physicallyBased
        
        let coinNode = SCNNode(geometry: SCNCylinder(radius: 1.0, height: 0.1))
        coinNode.geometry?.materials = [sideMaterial, faceMaterial, faceMaterial]
        
        let hoverNode = SCNNode(); hoverNode.addChildNode(coinNode)
        let userRotationNode = SCNNode(); userRotationNode.addChildNode(hoverNode)
        userRotationNode.eulerAngles = SCNVector3(x: Float.pi / 10, y: 0, z: 0)
        scene.rootNode.addChildNode(userRotationNode)
        context.coordinator.userRotationNode = userRotationNode
        
        // Lighting setup
        let keyNode = SCNNode(); keyNode.light = SCNLight(); keyNode.light?.type = .spot; keyNode.light?.intensity = 500
        keyNode.position = SCNVector3(x: -2, y: 4, z: 5); keyNode.look(at: SCNVector3(0,0,0)); scene.rootNode.addChildNode(keyNode)
        
        let rimNode = SCNNode(); rimNode.light = SCNLight(); rimNode.light?.type = .spot; rimNode.light?.color = UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1.0)
        rimNode.light?.intensity = 1500; rimNode.position = SCNVector3(x: 3, y: -2, z: -4); rimNode.look(at: SCNVector3(0,0,0)); scene.rootNode.addChildNode(rimNode)
        
        let fillNode = SCNNode(); fillNode.light = SCNLight(); fillNode.light?.type = .ambient; fillNode.light?.intensity = 350; scene.rootNode.addChildNode(fillNode)
        
        // Animations
        coinNode.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 8.0)))
        let hoverSequence = SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 0.15, z: 0, duration: 2.5).apply { $0.timingMode = .easeInEaseOut },
            SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 2.5).apply { $0.timingMode = .easeInEaseOut }
        ])
        hoverNode.runAction(SCNAction.repeatForever(hoverSequence))
        
        let pulseAction = SCNAction.customAction(duration: 4.0) { node, elapsedTime in
            let sineValue = (sin((elapsedTime / 4.0) * CGFloat.pi * 2 - CGFloat.pi / 2) + 1.0) / 2.0
            node.light?.intensity = 500 + (700 * sineValue)
        }
        keyNode.runAction(SCNAction.repeatForever(pulseAction))
        
        // Camera
        let cameraNode = SCNNode(); let camera = SCNCamera()
        camera.wantsHDR = true; camera.exposureOffset = 0.1; camera.bloomThreshold = 0.6; camera.bloomIntensity = 0.4; camera.bloomBlurRadius = 14.0
        cameraNode.camera = camera; cameraNode.position = SCNVector3(0, 0, 2.8)
        scene.rootNode.addChildNode(cameraNode)
        
        sceneView.scene = scene; sceneView.pointOfView = cameraNode; sceneView.allowsCameraControl = false
        sceneView.addGestureRecognizer(UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:))))
        sceneView.backgroundColor = UIColor.clear; sceneView.antialiasingMode = .multisampling4X
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {}
    
    private func generateCryptoTexture() -> UIImage {
        let size = CGSize(width: 1024, height: 1024); let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(red: 0.95, green: 0.72, blue: 0.1, alpha: 1.0).setFill(); ctx.cgContext.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.setStrokeColor(UIColor(white: 0.15, alpha: 1.0).cgColor); ctx.cgContext.setLineWidth(25); ctx.cgContext.addEllipse(in: CGRect(x: 70, y: 70, width: 884, height: 884)); ctx.cgContext.strokePath()
            ctx.cgContext.setLineDash(phase: 0, lengths: [50, 25]); ctx.cgContext.setLineWidth(12); ctx.cgContext.addEllipse(in: CGRect(x: 140, y: 140, width: 744, height: 744)); ctx.cgContext.strokePath(); ctx.cgContext.setLineDash(phase: 0, lengths: [])
            let text = "₿"; let style = NSMutableParagraphStyle(); style.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 580, weight: .black), .foregroundColor: UIColor(white: 0.15, alpha: 1.0), .paragraphStyle: style]
            text.draw(in: CGRect(x: 0, y: (size.height - text.size(withAttributes: attrs).height) / 2, width: size.width, height: text.size(withAttributes: attrs).height), withAttributes: attrs)
        }
    }
}

// Helper extension for SceneKit timing mode
extension SCNAction {
    func apply(_ block: (SCNAction) -> Void) -> SCNAction { block(self); return self }
}
