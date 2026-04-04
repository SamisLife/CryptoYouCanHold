import SwiftUI

struct WalletView: View {
    @EnvironmentObject var viewModel: WalletViewModel
    @State private var isAnimating = false
    @State private var selectedAsset: CryptoAsset?
    @State private var managedCoin: ActivePhysicalCoin?
    
    var body: some View {
        NavigationView {
            ZStack {
                GridBackgroundView()
                ScrollView {
                    VStack(spacing: 30) {
                        VStack(spacing: -60) {
                            ForEach(Array(viewModel.digitalAssets.enumerated()), id: \.element.id) { index, asset in
                                WalletCardView(asset: asset)
                                    .rotation3DEffect(.degrees(isAnimating ? 0 : 45), axis: (x: 1.0, y: 0.0, z: 0.0))
                                    .offset(y: isAnimating ? 0 : 200).opacity(isAnimating ? 1 : 0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.15), value: isAnimating)
                                    .onTapGesture { withAnimation { selectedAsset = asset } }
                            }
                        }.padding(.top, 40)
                        
                        if !viewModel.activePhysicalCoins.isEmpty {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Active Hardware Coins").font(.headline).foregroundColor(.gray).padding(.leading, 5).padding(.top, 40)
                                ForEach(viewModel.activePhysicalCoins) { coin in
                                    Button(action: { managedCoin = coin }) { ActiveCoinRow(coin: coin) }
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
                if let freshCoin = viewModel.activePhysicalCoins.first(where: { $0.id == coin.id }) {
                    HardwareControlModal(coin: freshCoin).environmentObject(viewModel)
                }
            }
        }
    }
}

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
        switch coin.status {
        case .active: return .green
        case .disabled: return .red
        case .initializing: return .yellow
        case .error: return .orange // <-- Added this to fix the crash!
        }
    }
}
