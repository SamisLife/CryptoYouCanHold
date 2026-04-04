import SwiftUI
import SceneKit

// MARK: - Data Models
struct PhysicalCoin: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let nfcSerial: String // Ties back to your ESP32 project!
    let denomination: Double
    let color: Color
}

let mockWallet = [
    PhysicalCoin(name: "Bitcoin", symbol: "BTC", nfcSerial: "04:6A:B2:99:8A:21", denomination: 0.05, color: .orange),
    PhysicalCoin(name: "Ethereum", symbol: "ETH", nfcSerial: "04:8C:11:F2:3B:10", denomination: 1.5, color: .purple)
]

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
        .preferredColorScheme(.dark) // Forces the dark-themed premium look
        .accentColor(.white)
    }
}

// MARK: - Home View (Big 3D Coin)
struct HomeView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
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

// MARK: - Wallet View (Animated 3D Cards)
struct WalletView: View {
    @State private var isAnimating = false
    @State private var selectedCard: PhysicalCoin?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: -60) { // Negative spacing for overlapping wallet effect
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

// MARK: - Coin Card (Glassmorphism UI)
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
            Color(UIColor.systemBackground).ignoresSafeArea()
            
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
                    DetailRow(title: "Physical Tag ID", value: coin.nfcSerial) // Tie to ESP32!
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
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        let scene = SCNScene()
        
        // 1. Create a flattened cylinder to look like a coin
        let coinGeometry = SCNCylinder(radius: 1.0, height: 0.1)
        
        // 2. Make it look metallic/gold
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemOrange // Golden orange
        material.metalness.contents = 1.0
        material.roughness.contents = 0.2
        material.lightingModel = .physicallyBased
        coinGeometry.materials = [material]
        
        let coinNode = SCNNode(geometry: coinGeometry)
        
        // Tilt it slightly so we see the 3D edge
        coinNode.eulerAngles = SCNVector3(x: .pi / 8, y: 0, z: 0)
        scene.rootNode.addChildNode(coinNode)
        
        // 3. Add ambient lighting
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 200
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        // 4. Add a directional spotlight for shiny reflections
        let spotLight = SCNLight()
        spotLight.type = .directional
        spotLight.intensity = 1000
        let spotNode = SCNNode()
        spotNode.light = spotLight
        spotNode.position = SCNVector3(x: 5, y: 5, z: 5)
        spotNode.look(at: SCNVector3(x: 0, y: 0, z: 0))
        scene.rootNode.addChildNode(spotNode)
        
        // 5. Spin animation
        let spin = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 4.0)
        let repeatSpin = SCNAction.repeatForever(spin)
        coinNode.runAction(repeatSpin)
        
        // 6. Setup the view
        sceneView.scene = scene
        sceneView.allowsCameraControl = true // Lets the user swipe to rotate the coin manually!
        sceneView.backgroundColor = UIColor.clear
        sceneView.autoenablesDefaultLighting = true
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // Handle updates if necessary
    }
}
