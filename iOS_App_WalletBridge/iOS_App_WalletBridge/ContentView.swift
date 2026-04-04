import SwiftUI
import SceneKit
import UIKit

// MARK: - Data Models
struct PhysicalCoin: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let nfcSerial: String
    let denomination: Double
    let color: Color
}

let mockWallet = [
    PhysicalCoin(name: "Bitcoin", symbol: "BTC", nfcSerial: "04:6A:B2:99:8A:21", denomination: 0.05, color: .orange),
    PhysicalCoin(name: "Ethereum", symbol: "ETH", nfcSerial: "04:8C:11:F2:3B:10", denomination: 1.5, color: .purple)
]

// MARK: - Reusable Minimal Grid Background
struct GridBackgroundView: View {
    var body: some View {
        ZStack {
            // Very dark, sophisticated gray
            Color(red: 0.06, green: 0.06, blue: 0.07).ignoresSafeArea()
            
            GeometryReader { geometry in
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let spacing: CGFloat = 35 // Size of the grid squares
                    
                    // Vertical lines
                    for x in stride(from: 0, through: width, by: spacing) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    // Horizontal lines
                    for y in stride(from: 0, through: height, by: spacing) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.04), lineWidth: 1) // Very subtle dim lines
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Main App View
struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            WalletView()
                .tabItem {
                    Image(systemName: "lanyardcard.fill")
                    Text("Wallet")
                }
                .tag(1)
        }
        .preferredColorScheme(.dark)
        .accentColor(.white)
    }
}

// MARK: - Home View
struct HomeView: View {
    var body: some View {
        ZStack {
            GridBackgroundView() // Independent Grid Background
            
            VStack {
                Text("Physical Crypto")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 40)
                
                Spacer()
                
                // 3D Coin Interactive View
                Coin3DView()
                    .frame(height: 400)
                
                Spacer()
                
                VStack(spacing: 8) {
                    Text("Tap physical coin to ESP32")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("Awaiting NFC Scan...")
                        .font(.caption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Wallet View
struct WalletView: View {
    @State private var isAnimating = false
    @State private var selectedCard: PhysicalCoin?
    
    var body: some View {
        NavigationView {
            ZStack {
                GridBackgroundView() // Independent Grid Background
                
                ScrollView {
                    VStack(spacing: -60) {
                        ForEach(Array(mockWallet.enumerated()), id: \.element.id) { index, coin in
                            CoinCardView(coin: coin)
                                .rotation3DEffect(
                                    .degrees(isAnimating ? 0 : 45),
                                    axis: (x: 1.0, y: 0.0, z: 0.0)
                                )
                                .offset(y: isAnimating ? 0 : 200)
                                .opacity(isAnimating ? 1 : 0)
                                .animation(
                                    .spring(response: 0.6, dampingFraction: 0.7)
                                    .delay(Double(index) * 0.15),
                                    value: isAnimating
                                )
                                .onTapGesture {
                                    withAnimation {
                                        selectedCard = coin
                                    }
                                }
                        }
                    }
                    .padding(.top, 80)
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Your Vault")
            .onAppear {
                isAnimating = true
            }
            .sheet(item: $selectedCard) { coin in
                CoinDetailView(coin: coin)
            }
        }
    }
}

// MARK: - Coin Card View
struct CoinCardView: View {
    let coin: PhysicalCoin
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [coin.color.opacity(0.8), .black]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .shadow(color: coin.color.opacity(0.3), radius: 15, x: 0, y: 10)
            
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
            
            VStack(alignment: .leading) {
                HStack {
                    Text(coin.name)
                        .font(.title2.bold())
                    Spacer()
                    Text(coin.symbol)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Text("\(String(format: "%.3f", coin.denomination)) \(coin.symbol)")
                    .font(.system(size: 32, weight: .light, design: .rounded))
                
                Text("NFC: \(coin.nfcSerial)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 4)
            }
            .padding(24)
            .foregroundColor(.white)
        }
        .frame(height: 220)
    }
}

// MARK: - Coin Detail View
struct CoinDetailView: View {
    let coin: PhysicalCoin
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            GridBackgroundView() // Independent Grid Background
            
            VStack(spacing: 30) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                
                Circle()
                    .fill(coin.color.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Text(coin.symbol)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(coin.color)
                    )
                
                VStack(spacing: 15) {
                    DetailRow(title: "Asset", value: coin.name)
                    DetailRow(title: "Denomination", value: "\(coin.denomination) \(coin.symbol)")
                    DetailRow(title: "Physical Tag ID", value: coin.nfcSerial)
                    DetailRow(title: "Status", value: "Verified Authentic")
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.05)))
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.system(size: 16, design: .monospaced))
    }
}

// MARK: - SceneKit 3D Coin Implementation
struct Coin3DView: UIViewRepresentable {
    
    // Custom Coordinator to handle manual rotation gestures
    class Coordinator: NSObject {
        var userRotationNode: SCNNode?
        var currentXAngle: Float = Float.pi / 10 // Starts with the initial slight tilt
        var currentYAngle: Float = 0.0
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view as? SCNView, let node = userRotationNode else { return }
            
            let translation = gesture.translation(in: view)
            let panSensitivity: Float = 0.01
            
            // Accumulate the angles based on finger swipe
            currentYAngle += Float(translation.x) * panSensitivity
            currentXAngle += Float(translation.y) * panSensitivity
            
            // Apply directly to the node's Euler Angles for a clean, twist-free rotation
            node.eulerAngles = SCNVector3(currentXAngle, currentYAngle, 0)
            
            // Reset translation so we only deal with deltas
            gesture.setTranslation(.zero, in: view)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        let scene = SCNScene()
        
        let cryptoTexture = generateCryptoTexture()
        
        // 1. Premium Gold Materials
        let faceMaterial = SCNMaterial()
        faceMaterial.diffuse.contents = cryptoTexture
        faceMaterial.metalness.contents = 1.0
        faceMaterial.roughness.contents = 0.18
        faceMaterial.lightingModel = .physicallyBased
        
        let sideMaterial = SCNMaterial()
        sideMaterial.diffuse.contents = UIColor(red: 0.95, green: 0.75, blue: 0.1, alpha: 1.0)
        sideMaterial.metalness.contents = 1.0
        sideMaterial.roughness.contents = 0.18
        sideMaterial.lightingModel = .physicallyBased
        
        // 2. Base Coin Node
        let coinGeometry = SCNCylinder(radius: 1.0, height: 0.1)
        coinGeometry.materials = [sideMaterial, faceMaterial, faceMaterial]
        let coinNode = SCNNode(geometry: coinGeometry)
        
        // 3. Hierarchy Setup for Independent Animations vs Gestures
        let hoverNode = SCNNode()
        hoverNode.addChildNode(coinNode)
        
        let userRotationNode = SCNNode()
        userRotationNode.addChildNode(hoverNode)
        userRotationNode.eulerAngles = SCNVector3(x: Float.pi / 10, y: 0, z: 0) // Initial tilt
        scene.rootNode.addChildNode(userRotationNode)
        
        // Pass the node to our gesture coordinator
        context.coordinator.userRotationNode = userRotationNode
        
        // 4. Locked Lighting (No longer moves when you swipe)
        let keyLight = SCNLight()
        keyLight.type = .spot
        keyLight.color = UIColor(white: 1.0, alpha: 1.0)
        keyLight.intensity = 500
        keyLight.castsShadow = false
        let keyNode = SCNNode()
        keyNode.light = keyLight
        keyNode.position = SCNVector3(x: -2, y: 4, z: 5)
        keyNode.look(at: SCNVector3(0,0,0))
        scene.rootNode.addChildNode(keyNode)
        
        let rimLight = SCNLight()
        rimLight.type = .spot
        rimLight.color = UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1.0)
        rimLight.intensity = 1500
        let rimNode = SCNNode()
        rimNode.light = rimLight
        rimNode.position = SCNVector3(x: 3, y: -2, z: -4)
        rimNode.look(at: SCNVector3(0,0,0))
        scene.rootNode.addChildNode(rimNode)
        
        let fillLight = SCNLight()
        fillLight.type = .ambient
        fillLight.intensity = 350
        let fillNode = SCNNode()
        fillNode.light = fillLight
        scene.rootNode.addChildNode(fillNode)
        
        // 5. Animations
        // Constant slow spin
        let spin = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 8.0)
        coinNode.runAction(SCNAction.repeatForever(spin))
        
        // Hovering physics
        let hoverUp = SCNAction.moveBy(x: 0, y: 0.15, z: 0, duration: 2.5)
        hoverUp.timingMode = .easeInEaseOut
        let hoverDown = SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 2.5)
        hoverDown.timingMode = .easeInEaseOut
        let hoverSequence = SCNAction.sequence([hoverUp, hoverDown])
        hoverNode.runAction(SCNAction.repeatForever(hoverSequence))
        
        // Pulsating light
        let pulseDuration: TimeInterval = 4.0
        let pulseAction = SCNAction.customAction(duration: pulseDuration) { node, elapsedTime in
            let angle = (elapsedTime / pulseDuration) * CGFloat.pi * 2
            let sineValue = (sin(angle - CGFloat.pi / 2) + 1.0) / 2.0
            node.light?.intensity = 500 + (700 * sineValue)
        }
        keyNode.runAction(SCNAction.repeatForever(pulseAction))
        
        // 6. Camera Setup (Static)
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.wantsHDR = true
        camera.exposureOffset = 0.1
        camera.bloomThreshold = 0.6
        camera.bloomIntensity = 0.4
        camera.bloomBlurRadius = 14.0
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 2.8)
        scene.rootNode.addChildNode(cameraNode)
        
        // 7. Render Configuration & Gestures
        sceneView.scene = scene
        sceneView.pointOfView = cameraNode
        
        // FIX: Disable camera control so the background and lights stay completely locked
        sceneView.allowsCameraControl = false
        
        // Add our custom pan gesture to rotate the coin directly
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        sceneView.addGestureRecognizer(panGesture)
        
        sceneView.backgroundColor = UIColor.clear // Allows the SwiftUI Grid to show through
        sceneView.antialiasingMode = .multisampling4X
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {}
    
    // MARK: - Programmatic Texture Generator
    private func generateCryptoTexture() -> UIImage {
        let size = CGSize(width: 1024, height: 1024)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        
        return renderer.image { ctx in
            UIColor(red: 0.95, green: 0.72, blue: 0.1, alpha: 1.0).setFill()
            ctx.cgContext.fill(CGRect(origin: .zero, size: size))
            
            ctx.cgContext.setStrokeColor(UIColor(white: 0.15, alpha: 1.0).cgColor)
            ctx.cgContext.setLineWidth(25)
            ctx.cgContext.addEllipse(in: CGRect(x: 70, y: 70, width: 884, height: 884))
            ctx.cgContext.strokePath()
            
            ctx.cgContext.setLineDash(phase: 0, lengths: [50, 25])
            ctx.cgContext.setLineWidth(12)
            ctx.cgContext.addEllipse(in: CGRect(x: 140, y: 140, width: 744, height: 744))
            ctx.cgContext.strokePath()
            ctx.cgContext.setLineDash(phase: 0, lengths: [])
            
            let text = "₿"
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 580, weight: .black),
                .foregroundColor: UIColor(white: 0.15, alpha: 1.0),
                .paragraphStyle: paragraphStyle
            ]
            
            let textSize = text.size(withAttributes: attrs)
            let textRect = CGRect(
                x: 0,
                y: (size.height - textSize.height) / 2,
                width: size.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attrs)
        }
    }
}
