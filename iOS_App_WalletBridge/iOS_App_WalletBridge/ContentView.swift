import SwiftUI
import SceneKit

struct ContentView: View {
    @StateObject private var viewModel = WalletViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView().tabItem { Image(systemName: "house.fill"); Text("Home") }.tag(0)
            WalletView().environmentObject(viewModel).tabItem { Image(systemName: "lanyardcard.fill"); Text("Wallet") }.tag(1)
        }
        .preferredColorScheme(.dark).accentColor(.white)
    }
}

struct HomeView: View {
    var body: some View {
        NavigationView {
            ZStack {
                GridBackgroundView()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Native 3D Interactive Glass Coin
                    InteractiveGlassCoinView()
                        .frame(width: 250, height: 250)
                    
                    VStack(spacing: 12) {
                        Text("Crypto You Can Hold")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Your digital assets, secured in physical hardware.\nSwipe the coin to interact.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .lineSpacing(4)
                    }
                    
                    Spacer()
                }
            }
        }
    }
}

// MARK: - SceneKit 3D Minimalist Coin Simulator
struct InteractiveGlassCoinView: UIViewRepresentable {
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        
        // Enables touch interaction
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = .clear
        
        let scene = SCNScene()
        view.scene = scene
        
        let cameraNode = SCNNode()
        let camera = SCNCamera()

        camera.fieldOfView = 40
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 4.5)
        scene.rootNode.addChildNode(cameraNode)

        let spinNode = SCNNode()
        scene.rootNode.addChildNode(spinNode)
        
        // 1. Create the physical coin shape
        let coinGeometry = SCNCylinder(radius: 1.0, height: 0.08)
        coinGeometry.radialSegmentCount = 128
        
        // 2. Pure Frosted Glass Material
        let glassMaterial = SCNMaterial()
        glassMaterial.lightingModel = .physicallyBased
        glassMaterial.metalness.contents = 0.9
        glassMaterial.roughness.contents = 0.15
        glassMaterial.diffuse.contents = UIColor(white: 1.0, alpha: 0.1)
        glassMaterial.transparency = 0.5
        glassMaterial.isDoubleSided = true
        coinGeometry.materials = [glassMaterial]
        
        let coinNode = SCNNode(geometry: coinGeometry)
        
        // Tilt 90 degrees so it perfectly faces the camera like a 2D circle
        coinNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        
        // Add coin to the spinning wrapper
        spinNode.addChildNode(coinNode)
        
        // 4. Ultra-Slow Continuous Rotation
        let spin = CABasicAnimation(keyPath: "eulerAngles.y")
        spin.byValue = Float.pi * 2 // Full 360 degree rotation
        spin.duration = 45 // 45 seconds per rotation (very slow and luxurious)
        spin.repeatCount = .infinity
        spinNode.addAnimation(spin, forKey: "slow_spin")
        
        return view
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {}
}
