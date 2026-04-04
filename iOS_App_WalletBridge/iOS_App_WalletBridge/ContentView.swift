import SwiftUI
import SceneKit
import UIKit
import Combine

// MARK: - Data Models & State Management
struct CryptoAsset: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let symbol: String
    var balance: Double
    let color: Color
}

enum CoinStatus: String {
    case initializing = "Initializing..."
    case active = "Active"
    case disabled = "Disabled"
}

struct ActivePhysicalCoin: Identifiable, Equatable {
    let id = UUID()
    let coinID: String
    let assetID: UUID // To link back for refunds
    let assetName: String
    let symbol: String
    let amount: Double
    let color: Color
    var status: CoinStatus = .initializing
    var transferModeExpiration: Date? = nil
    
    var isTransferModeActive: Bool {
        guard let exp = transferModeExpiration else { return false }
        return Date() < exp
    }
}

class WalletViewModel: ObservableObject {
    @Published var digitalAssets: [CryptoAsset] = [
        CryptoAsset(name: "Bitcoin", symbol: "BTC", balance: 2.45, color: .orange),
        CryptoAsset(name: "Ethereum", symbol: "ETH", balance: 14.2, color: .purple)
    ]
    
    @Published var activePhysicalCoins: [ActivePhysicalCoin] = []
    
    func assignPhysicalCoin(asset: CryptoAsset, coinID: String, amount: Double) {
        if let index = digitalAssets.firstIndex(where: { $0.id == asset.id }) {
            // Deduct digital balance
            digitalAssets[index].balance -= amount
            
            // Create coin in initializing state
            let newCoin = ActivePhysicalCoin(
                coinID: coinID,
                assetID: asset.id,
                assetName: asset.name,
                symbol: asset.symbol,
                amount: amount,
                color: asset.color,
                status: .initializing
            )
            
            withAnimation(.spring()) {
                activePhysicalCoins.insert(newCoin, at: 0)
            }
            
            // Simulate hardware sync delay, then activate
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if let coinIndex = self.activePhysicalCoins.firstIndex(where: { $0.id == newCoin.id }) {
                    withAnimation {
                        self.activePhysicalCoins[coinIndex].status = .active
                    }
                }
            }
        }
    }
    
    func toggleStatus(for coin: ActivePhysicalCoin) {
        if let index = activePhysicalCoins.firstIndex(where: { $0.id == coin.id }) {
            withAnimation {
                if activePhysicalCoins[index].status == .active {
                    activePhysicalCoins[index].status = .disabled
                    activePhysicalCoins[index].transferModeExpiration = nil // Kill transfer mode if disabled
                } else {
                    activePhysicalCoins[index].status = .active
                }
            }
        }
    }
    
    func reclaimCoin(_ coin: ActivePhysicalCoin) {
        if let coinIndex = activePhysicalCoins.firstIndex(where: { $0.id == coin.id }) {
            // Refund the digital wallet
            if let assetIndex = digitalAssets.firstIndex(where: { $0.id == coin.assetID }) {
                digitalAssets[assetIndex].balance += coin.amount
            }
            // Destroy physical link
            withAnimation {
                activePhysicalCoins.remove(at: coinIndex)
            }
        }
    }
    
    func activateTransferMode(for coin: ActivePhysicalCoin) {
        if let index = activePhysicalCoins.firstIndex(where: { $0.id == coin.id }) {
            withAnimation {
                // Set expiration exactly 2 minutes from now
                activePhysicalCoins[index].transferModeExpiration = Date().addingTimeInterval(120)
            }
        }
    }
}

// MARK: - Reusable Minimal Grid Background
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
                }
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
            }.ignoresSafeArea()
        }
    }
}

// MARK: - Main App View
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

// MARK: - Home View
struct HomeView: View {
    var body: some View {
        ZStack {
            GridBackgroundView()
            VStack {
                Text("Physical Crypto").font(.system(size: 28, weight: .semibold, design: .rounded)).foregroundColor(.white).padding(.top, 40)
                Spacer()
                Coin3DView().frame(height: 400)
                Spacer()
                VStack(spacing: 8) {
                    Text("Tap physical coin to ESP32").font(.subheadline).foregroundColor(.gray)
                    Text("Awaiting NFC Scan...").font(.caption).padding(.horizontal, 16).padding(.vertical, 8).background(Capsule().fill(Color.white.opacity(0.1)))
                }.padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Wallet View
struct WalletView: View {
    @EnvironmentObject var viewModel: WalletViewModel
    @State private var isAnimating = false
    @State private var selectedAsset: CryptoAsset?
    @State private var managedCoin: ActivePhysicalCoin? // For the control center
    
    var body: some View {
        NavigationView {
            ZStack {
                GridBackgroundView()
                ScrollView {
                    VStack(spacing: 30) {
                        // Digital Balances
                        VStack(spacing: -60) {
                            ForEach(Array(viewModel.digitalAssets.enumerated()), id: \.element.id) { index, asset in
                                WalletCardView(asset: asset)
                                    .rotation3DEffect(.degrees(isAnimating ? 0 : 45), axis: (x: 1.0, y: 0.0, z: 0.0))
                                    .offset(y: isAnimating ? 0 : 200).opacity(isAnimating ? 1 : 0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.15), value: isAnimating)
                                    .onTapGesture { withAnimation { selectedAsset = asset } }
                            }
                        }.padding(.top, 40)
                        
                        // Active Hardware Coins
                        if !viewModel.activePhysicalCoins.isEmpty {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Active Hardware Coins").font(.headline).foregroundColor(.gray).padding(.leading, 5).padding(.top, 40)
                                ForEach(viewModel.activePhysicalCoins) { coin in
                                    Button(action: {
                                        managedCoin = coin
                                    }) {
                                        ActiveCoinRow(coin: coin)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                                }
                            }
                        }
                    }.padding(.horizontal, 20).padding(.bottom, 80)
                }
            }
            .navigationTitle("Your Vault")
            .onAppear { isAnimating = true }
            .sheet(item: $selectedAsset) { asset in CoinDetailView(asset: asset).environmentObject(viewModel) }
            .sheet(item: $managedCoin) { coin in
                // We pass a binding to find the freshest state from the array
                if let freshCoin = viewModel.activePhysicalCoins.first(where: { $0.id == coin.id }) {
                    PhysicalCoinControlModal(coin: freshCoin).environmentObject(viewModel)
                }
            }
        }
    }
}

// MARK: - Digital Wallet Card
struct WalletCardView: View {
    let asset: CryptoAsset
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(gradient: Gradient(colors: [asset.color.opacity(0.8), .black]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: asset.color.opacity(0.3), radius: 15, x: 0, y: 10)
            RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 1)
            VStack(alignment: .leading) {
                HStack { Text(asset.name).font(.title2.bold()); Spacer(); Text(asset.symbol).font(.headline).foregroundColor(.white.opacity(0.7)) }
                Spacer()
                Text("Digital Balance").font(.caption).foregroundColor(.white.opacity(0.6))
                Text("\(String(format: "%.4f", asset.balance))").font(.system(size: 36, weight: .light, design: .rounded))
            }.padding(24).foregroundColor(.white)
        }.frame(height: 220)
    }
}

// MARK: - Active Physical Coin Row
struct ActiveCoinRow: View {
    let coin: ActivePhysicalCoin
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(coin.color.opacity(coin.isTransferModeActive ? 0.8 : 0.2))
                .frame(width: 50, height: 50)
                .overlay(Text(coin.symbol.prefix(1)).font(.title3.bold()).foregroundColor(coin.isTransferModeActive ? .black : coin.color))
                .shadow(color: coin.isTransferModeActive ? coin.color : .clear, radius: isPulsing ? 10 : 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("ID: \(coin.coinID)").font(.system(size: 14, weight: .medium, design: .monospaced)).foregroundColor(.white)
                
                HStack {
                    if coin.status == .initializing {
                        ProgressView().scaleEffect(0.6).tint(.gray)
                    } else {
                        Circle().fill(statusColor).frame(width: 6, height: 6)
                    }
                    Text(coin.isTransferModeActive ? "Transfer Mode Active" : coin.status.rawValue)
                        .font(.caption)
                        .foregroundColor(coin.isTransferModeActive ? .red : .gray)
                }
            }
            Spacer()
            Text("\(String(format: "%.3f", coin.amount)) \(coin.symbol)").font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundColor(.white)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(coin.isTransferModeActive ? coin.color.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
        .onAppear {
            if coin.isTransferModeActive {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { isPulsing = true }
            }
        }
    }
    
    var statusColor: Color {
        switch coin.status {
        case .active: return .green
        case .disabled: return .red
        case .initializing: return .yellow
        }
    }
}

// MARK: - Digital Asset Detail & Creation Flow (Unchanged logic, compacted)
struct CoinDetailView: View {
    let asset: CryptoAsset
    @Environment(\.presentationMode) var presentationMode
    @State private var showingAddCoinSheet = false
    var body: some View {
        ZStack {
            GridBackgroundView()
            VStack(spacing: 30) {
                Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 10)
                Circle().fill(asset.color.opacity(0.2)).frame(width: 120, height: 120).overlay(Text(asset.symbol).font(.system(size: 40, weight: .bold)).foregroundColor(asset.color))
                VStack(spacing: 15) {
                    DetailRow(title: "Asset", value: asset.name)
                    DetailRow(title: "Available Balance", value: "\(String(format: "%.4f", asset.balance)) \(asset.symbol)")
                }.padding(20).background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.05))).padding(.horizontal, 20)
                Spacer()
                Button(action: { showingAddCoinSheet = true }) {
                    Text("Assign to Physical Coin").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 55).background(LinearGradient(gradient: Gradient(colors: [asset.color, asset.color.opacity(0.6)]), startPoint: .leading, endPoint: .trailing)).cornerRadius(16)
                }.padding(.horizontal, 20).padding(.bottom, 30)
            }
        }.sheet(isPresented: $showingAddCoinSheet) { AddPhysicalCoinModal(asset: asset) }
    }
}
struct DetailRow: View {
    let title: String; let value: String
    var body: some View { HStack { Text(title).foregroundColor(.gray); Spacer(); Text(value).fontWeight(.medium).foregroundColor(.white) }.font(.system(size: 16, design: .monospaced)) }
}

struct AddPhysicalCoinModal: View {
    let asset: CryptoAsset
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: WalletViewModel
    @State private var inputCoinID: String = ""
    @State private var inputAmount: String = ""
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.09).ignoresSafeArea()
            VStack(spacing: 24) {
                Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 10)
                Text("Initialize Hardware Coin").font(.title2.bold()).foregroundColor(.white).padding(.top, 10)
                VStack(alignment: .leading, spacing: 8) { Text("Coin ID (Type)").font(.caption).foregroundColor(.gray); TextField("e.g. 04:6A:B2...", text: $inputCoinID).padding().background(Color.white.opacity(0.05)).cornerRadius(12).foregroundColor(.white).font(.system(.body, design: .monospaced)) }.padding(.horizontal, 20)
                VStack(alignment: .leading, spacing: 8) { Text("Amount (\(asset.symbol))").font(.caption).foregroundColor(.gray); TextField("0.00", text: $inputAmount).keyboardType(.decimalPad).padding().background(Color.white.opacity(0.05)).cornerRadius(12).foregroundColor(.white).font(.system(.body, design: .monospaced))
                    HStack { Spacer(); Text("Max: \(String(format: "%.4f", asset.balance))").font(.caption2).foregroundColor(asset.color) }
                }.padding(.horizontal, 20)
                Spacer()
                Button(action: {
                    if let amt = Double(inputAmount), amt > 0, amt <= asset.balance, !inputCoinID.isEmpty { viewModel.assignPhysicalCoin(asset: asset, coinID: inputCoinID, amount: amt); presentationMode.wrappedValue.dismiss() }
                }) { Text("Initialize Hardware").font(.headline).foregroundColor(.black).frame(maxWidth: .infinity).frame(height: 55).background(Color.white).cornerRadius(16) }
                .padding(.horizontal, 20).padding(.bottom, 30).disabled(inputCoinID.isEmpty || inputAmount.isEmpty || (Double(inputAmount) ?? 0) > asset.balance).opacity((inputCoinID.isEmpty || inputAmount.isEmpty || (Double(inputAmount) ?? 0) > asset.balance) ? 0.5 : 1.0)
            }
        }.preferredColorScheme(.dark)
    }
}

// MARK: - Hardware Coin Control Center (NEW)
struct PhysicalCoinControlModal: View {
    let coin: ActivePhysicalCoin
    @EnvironmentObject var viewModel: WalletViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            GridBackgroundView()
            
            VStack(spacing: 25) {
                Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 10)
                
                // Header
                VStack(spacing: 8) {
                    Text("Hardware Center")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text(coin.coinID)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                }.padding(.top, 10)
                
                // Value Display
                VStack(spacing: 5) {
                    Text("\(String(format: "%.3f", coin.amount)) \(coin.symbol)")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    HStack {
                        Circle().fill(statusColor).frame(width: 8, height: 8)
                        Text(coin.status.rawValue)
                            .font(.subheadline)
                            .foregroundColor(statusColor)
                    }
                }
                .padding(.vertical, 20)
                
                // --- Actions ---
                
                if coin.status != .initializing {
                    
                    // 1. Transfer Mode Countdown/Activation
                    if coin.isTransferModeActive {
                        TransferCountdownView(expirationDate: coin.transferModeExpiration!)
                    } else {
                        Button(action: {
                            viewModel.activateTransferMode(for: coin)
                        }) {
                            HStack {
                                Image(systemName: "wifi")
                                Text("Unlock Transfer Mode")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            // Red gradient for dangerous/active actions
                            .background(LinearGradient(gradient: Gradient(colors: [.red, .orange]), startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(16)
                            .opacity(coin.status == .disabled ? 0.3 : 1.0)
                        }
                        .disabled(coin.status == .disabled)
                    }
                    
                    // 2. Enable / Disable
                    Button(action: { viewModel.toggleStatus(for: coin) }) {
                        Text(coin.status == .active ? "Disable Hardware" : "Enable Hardware")
                            .font(.headline)
                            .foregroundColor(coin.status == .active ? .orange : .green)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    
                    Spacer()
                    
                    // 3. Delete & Reclaim
                    Button(action: {
                        viewModel.reclaimCoin(coin)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        VStack(spacing: 4) {
                            Text("Delete & Reclaim Balance")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text("Burns physical link, returns funds to digital wallet")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                    }
                    .padding(.bottom, 20)
                } else {
                    Spacer()
                    ProgressView("Writing to physical chip...")
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
        }
        .preferredColorScheme(.dark)
    }
    
    var statusColor: Color {
        switch coin.status {
        case .active: return .green
        case .disabled: return .red
        case .initializing: return .yellow
        }
    }
}

// MARK: - Live Countdown Timer View
struct TransferCountdownView: View {
    let expirationDate: Date
    @State private var timeRemaining: String = "02:00"
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 8) {
            Text("TRANSFER MODE ACTIVE")
                .font(.caption.bold())
                .foregroundColor(.red)
            
            Text(timeRemaining)
                .font(.system(size: 48, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .onReceive(timer) { _ in updateTime() }
                .onAppear { updateTime() }
            
            Text("Coin can be physically spent via NFC")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.red.opacity(0.1))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.3), lineWidth: 2))
    }
    
    func updateTime() {
        let remaining = expirationDate.timeIntervalSince(Date())
        if remaining > 0 {
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            timeRemaining = String(format: "%02d:%02d", minutes, seconds)
        } else {
            timeRemaining = "00:00"
            // The UI will re-render automatically because isTransferModeActive becomes false
        }
    }
}


// MARK: - SceneKit 3D Coin Implementation (Unchanged)
struct Coin3DView: UIViewRepresentable {
    class Coordinator: NSObject {
        var userRotationNode: SCNNode?
        var currentXAngle: Float = Float.pi / 10
        var currentYAngle: Float = 0.0
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view as? SCNView, let node = userRotationNode else { return }
            let translation = gesture.translation(in: view)
            let panSensitivity: Float = 0.01
            currentYAngle += Float(translation.x) * panSensitivity
            currentXAngle += Float(translation.y) * panSensitivity
            node.eulerAngles = SCNVector3(currentXAngle, currentYAngle, 0)
            gesture.setTranslation(.zero, in: view)
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        let scene = SCNScene()
        let cryptoTexture = generateCryptoTexture()
        let faceMaterial = SCNMaterial()
        faceMaterial.diffuse.contents = cryptoTexture; faceMaterial.metalness.contents = 1.0; faceMaterial.roughness.contents = 0.18; faceMaterial.lightingModel = .physicallyBased
        let sideMaterial = SCNMaterial()
        sideMaterial.diffuse.contents = UIColor(red: 0.95, green: 0.75, blue: 0.1, alpha: 1.0); sideMaterial.metalness.contents = 1.0; sideMaterial.roughness.contents = 0.18; sideMaterial.lightingModel = .physicallyBased
        let coinGeometry = SCNCylinder(radius: 1.0, height: 0.1)
        coinGeometry.materials = [sideMaterial, faceMaterial, faceMaterial]
        let coinNode = SCNNode(geometry: coinGeometry)
        let hoverNode = SCNNode(); hoverNode.addChildNode(coinNode)
        let userRotationNode = SCNNode(); userRotationNode.addChildNode(hoverNode)
        userRotationNode.eulerAngles = SCNVector3(x: Float.pi / 10, y: 0, z: 0)
        scene.rootNode.addChildNode(userRotationNode)
        context.coordinator.userRotationNode = userRotationNode
        let keyLight = SCNLight(); keyLight.type = .spot; keyLight.color = UIColor(white: 1.0, alpha: 1.0); keyLight.intensity = 500; keyLight.castsShadow = false
        let keyNode = SCNNode(); keyNode.light = keyLight; keyNode.position = SCNVector3(x: -2, y: 4, z: 5); keyNode.look(at: SCNVector3(0,0,0)); scene.rootNode.addChildNode(keyNode)
        let rimLight = SCNLight(); rimLight.type = .spot; rimLight.color = UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1.0); rimLight.intensity = 1500
        let rimNode = SCNNode(); rimNode.light = rimLight; rimNode.position = SCNVector3(x: 3, y: -2, z: -4); rimNode.look(at: SCNVector3(0,0,0)); scene.rootNode.addChildNode(rimNode)
        let fillLight = SCNLight(); fillLight.type = .ambient; fillLight.intensity = 350
        let fillNode = SCNNode(); fillNode.light = fillLight; scene.rootNode.addChildNode(fillNode)
        let spin = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 8.0)
        coinNode.runAction(SCNAction.repeatForever(spin))
        let hoverUp = SCNAction.moveBy(x: 0, y: 0.15, z: 0, duration: 2.5); hoverUp.timingMode = .easeInEaseOut
        let hoverDown = SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 2.5); hoverDown.timingMode = .easeInEaseOut
        let hoverSequence = SCNAction.sequence([hoverUp, hoverDown])
        hoverNode.runAction(SCNAction.repeatForever(hoverSequence))
        let pulseDuration: TimeInterval = 4.0
        let pulseAction = SCNAction.customAction(duration: pulseDuration) { node, elapsedTime in let angle = (elapsedTime / pulseDuration) * CGFloat.pi * 2; let sineValue = (sin(angle - CGFloat.pi / 2) + 1.0) / 2.0; node.light?.intensity = 500 + (700 * sineValue) }
        keyNode.runAction(SCNAction.repeatForever(pulseAction))
        let cameraNode = SCNNode(); let camera = SCNCamera()
        camera.wantsHDR = true; camera.exposureOffset = 0.1; camera.bloomThreshold = 0.6; camera.bloomIntensity = 0.4; camera.bloomBlurRadius = 14.0
        cameraNode.camera = camera; cameraNode.position = SCNVector3(0, 0, 2.8)
        scene.rootNode.addChildNode(cameraNode)
        sceneView.scene = scene; sceneView.pointOfView = cameraNode; sceneView.allowsCameraControl = false
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        sceneView.addGestureRecognizer(panGesture)
        sceneView.backgroundColor = UIColor.clear; sceneView.antialiasingMode = .multisampling4X
        return sceneView
    }
    func updateUIView(_ uiView: SCNView, context: Context) {}
    private func generateCryptoTexture() -> UIImage {
        let size = CGSize(width: 1024, height: 1024); let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            UIColor(red: 0.95, green: 0.72, blue: 0.1, alpha: 1.0).setFill(); ctx.cgContext.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.setStrokeColor(UIColor(white: 0.15, alpha: 1.0).cgColor); ctx.cgContext.setLineWidth(25); ctx.cgContext.addEllipse(in: CGRect(x: 70, y: 70, width: 884, height: 884)); ctx.cgContext.strokePath()
            ctx.cgContext.setLineDash(phase: 0, lengths: [50, 25]); ctx.cgContext.setLineWidth(12); ctx.cgContext.addEllipse(in: CGRect(x: 140, y: 140, width: 744, height: 744)); ctx.cgContext.strokePath()
            ctx.cgContext.setLineDash(phase: 0, lengths: []); let text = "₿"; let paragraphStyle = NSMutableParagraphStyle(); paragraphStyle.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 580, weight: .black), .foregroundColor: UIColor(white: 0.15, alpha: 1.0), .paragraphStyle: paragraphStyle]
            let textSize = text.size(withAttributes: attrs); let textRect = CGRect(x: 0, y: (size.height - textSize.height) / 2, width: size.width, height: textSize.height); text.draw(in: textRect, withAttributes: attrs)
        }
    }
}
