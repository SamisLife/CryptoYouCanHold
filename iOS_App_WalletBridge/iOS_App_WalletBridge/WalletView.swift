import SwiftUI

struct WalletView: View {
    @EnvironmentObject var viewModel: WalletViewModel
    @State private var isAnimating = false
    @State private var selectedAsset: CryptoAsset?
    
    @Namespace private var animation
    
    var body: some View {
        NavigationView {
            ZStack {
                GridBackgroundView()
                
                ScrollView {
                    VStack(spacing: 30) {
                        
                        // ===== PREMIUM VAULT SWITCHER =====
                        HStack(spacing: 0) {
                            // UPDATED NAMES HERE!
                            let options = [("wallet_person_1", "Person 1"), ("wallet_person_2", "Person 2")]
                            
                            ForEach(options, id: \.0) { option in
                                Text(option.1)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(viewModel.masterWalletID == option.0 ? .black : .gray)
                                    .frame(height: 44)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        ZStack {
                                            if viewModel.masterWalletID == option.0 {
                                                Capsule()
                                                    .fill(Color.white)
                                                    .shadow(color: .white.opacity(0.2), radius: 5, x: 0, y: 2)
                                                    .matchedGeometryEffect(id: "TAB", in: animation)
                                            }
                                        }
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                            viewModel.masterWalletID = option.0
                                        }
                                    }
                            }
                        }
                        .padding(4)
                        .background(Capsule().fill(Color.white.opacity(0.05)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Digital Balances
                        VStack(spacing: -60) {
                            ForEach(Array(viewModel.digitalAssets.enumerated()), id: \.element.id) { index, asset in
                                WalletCardView(asset: asset)
                                    .rotation3DEffect(.degrees(isAnimating ? 0 : 45), axis: (x: 1.0, y: 0.0, z: 0.0))
                                    .offset(y: isAnimating ? 0 : 200).opacity(isAnimating ? 1 : 0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.15), value: isAnimating)
                                    .onTapGesture { withAnimation { selectedAsset = asset } }
                            }
                        }.padding(.top, 10)
                        
                        // Active Hardware Coins
                        if !viewModel.activePhysicalCoins.isEmpty {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Active Hardware Coins")
                                    .font(.headline).foregroundColor(.gray).padding(.leading, 5).padding(.top, 40)
                                ForEach(viewModel.activePhysicalCoins) { coin in
                                    Button(action: { viewModel.managedCoin = coin }) { ActiveCoinRow(coin: coin) }
                                    .buttonStyle(PlainButtonStyle())
                                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                                }
                            }
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "tray").font(.system(size: 40)).foregroundColor(.gray.opacity(0.5))
                                Text("No hardware coins in this vault.").font(.subheadline).foregroundColor(.gray)
                            }.padding(.top, 60)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 80)
                }
                
                // ===== PREMIUM SUCCESS OVERLAY =====
                if viewModel.showTransferSuccess {
                    TransferSuccessOverlay()
                        .transition(.opacity)
                        .zIndex(2)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                withAnimation(.easeIn(duration: 0.3)) { viewModel.showTransferSuccess = false }
                            }
                        }
                }
            }
            .navigationTitle("Your Vault")
            .onAppear { isAnimating = true }
            .sheet(item: $selectedAsset) { asset in CoinDetailView(asset: asset).environmentObject(viewModel) }
            .sheet(item: $viewModel.managedCoin) { coin in
                if let freshCoin = viewModel.activePhysicalCoins.first(where: { $0.id == coin.id }) {
                    HardwareControlModal(coin: freshCoin).environmentObject(viewModel)
                }
            }
        }
    }
}

// MARK: - Premium Wallet Card View
struct WalletCardView: View {
    let asset: CryptoAsset
    var body: some View {
        ZStack {
            // Deep Matte Base
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(white: 0.05))
            
            // Subtle Radial Glow matching the crypto color
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(RadialGradient(gradient: Gradient(colors: [asset.color.opacity(0.3), .clear]), center: .topLeading, startRadius: 0, endRadius: 300))
            
            // Ultra-thin Glass Border
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.4), Color.white.opacity(0.0)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(asset.name)
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.white)
                        Text(asset.symbol)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    // Premium Hardware "Smart Chip" Icon
                    Image(systemName: "cpu")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(asset.color.opacity(0.8))
                        .rotationEffect(.degrees(90))
                }
                
                Spacer()
                
                Text("DIGITAL LEDGER")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.bottom, 4)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(String(format: "%.4f", asset.balance))")
                        .font(.system(size: 42, weight: .light, design: .rounded))
                        .foregroundColor(.white)
                    Text(asset.symbol)
                        .font(.headline.weight(.medium))
                        .foregroundColor(asset.color)
                }
            }
            .padding(24)
        }
        .frame(height: 220)
        .shadow(color: asset.color.opacity(0.15), radius: 25, x: 0, y: 15)
    }
}

// MARK: - Premium Success Animation View
struct TransferSuccessOverlay: View {
    @State private var drawRing = false
    @State private var popIcon = false
    @State private var slideText = false
    
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).colorScheme(.dark).ignoresSafeArea()
            VStack(spacing: 24) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 4).frame(width: 90, height: 90)
                    Circle().trim(from: 0, to: drawRing ? 1 : 0).stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round)).frame(width: 90, height: 90).rotationEffect(.degrees(-90))
                    Image(systemName: "checkmark").font(.system(size: 34, weight: .light)).foregroundColor(.white).opacity(popIcon ? 1 : 0).scaleEffect(popIcon ? 1 : 0.4)
                }
                VStack(spacing: 8) {
                    Text("Transfer Complete").font(.title2.bold()).foregroundColor(.white)
                    Text("Funds securely moved to external ledger").font(.subheadline).foregroundColor(.gray)
                }.opacity(slideText ? 1 : 0).offset(y: slideText ? 0 : 10)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).delay(0.1)) { drawRing = true }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.5)) { popIcon = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) { slideText = true }
        }
    }
}

// MARK: - Active Coin Row
struct ActiveCoinRow: View {
    let coin: ActivePhysicalCoin
    @State private var isPulsing = false
    var body: some View {
        HStack(spacing: 16) {
            Circle().fill(coin.color.opacity(coin.isTransferModeActive ? 0.8 : 0.2)).frame(width: 50, height: 50)
                .overlay(Text(coin.symbol.prefix(1)).font(.title3.bold()).foregroundColor(coin.isTransferModeActive ? .black : coin.color))
                .shadow(color: coin.isTransferModeActive ? coin.color : .clear, radius: isPulsing ? 10 : 2)
            VStack(alignment: .leading, spacing: 4) {
                Text("ID: \(coin.coinID)").font(.system(size: 14, weight: .medium, design: .monospaced)).foregroundColor(.white)
                HStack {
                    if coin.status == .initializing { ProgressView().scaleEffect(0.6).tint(.gray) }
                    else { Circle().fill(statusColor).frame(width: 6, height: 6) }
                    Text(coin.isTransferModeActive ? "Transfer Mode Active" : coin.status.rawValue).font(.caption).foregroundColor(coin.isTransferModeActive ? .red : .gray)
                }
            }
            Spacer()
            Text("\(String(format: "%.3f", coin.amount)) \(coin.symbol)").font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundColor(.white)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(coin.isTransferModeActive ? coin.color.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
        .onAppear { if coin.isTransferModeActive { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { isPulsing = true } } }
    }
    var statusColor: Color {
        switch coin.status { case .active: return .green; case .disabled: return .red; case .initializing: return .yellow; case .error: return .orange }
    }
}
