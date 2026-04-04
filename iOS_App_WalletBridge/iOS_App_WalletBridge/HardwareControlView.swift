import SwiftUI
import Combine

struct HardwareControlModal: View {
    let coin: ActivePhysicalCoin
    @EnvironmentObject var viewModel: WalletViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            GridBackgroundView()
            VStack(spacing: 25) {
                Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 10)
                VStack(spacing: 8) { Text("Hardware Center").font(.title2.bold()).foregroundColor(.white); Text(coin.coinID).font(.system(size: 14, weight: .medium, design: .monospaced)).foregroundColor(.gray) }.padding(.top, 10)
                
                VStack(spacing: 5) {
                    Text("\(String(format: "%.3f", coin.amount)) \(coin.symbol)").font(.system(size: 40, weight: .semibold, design: .rounded)).foregroundColor(.white)
                    HStack { Circle().fill(statusColor).frame(width: 8, height: 8); Text(coin.status.rawValue).font(.subheadline).foregroundColor(statusColor) }
                }.padding(.vertical, 20)
                
                if coin.status != .initializing {
                    if coin.isTransferModeActive {
                        TransferCountdownView(expirationDate: coin.transferModeExpiration!)
                    } else {
                        Button(action: { viewModel.activateTransferMode(for: coin) }) {
                            HStack { Image(systemName: "wifi"); Text("Unlock Transfer Mode") }.font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 55)
                                .background(LinearGradient(gradient: Gradient(colors: [.red, .orange]), startPoint: .leading, endPoint: .trailing)).cornerRadius(16).opacity(coin.status == .disabled ? 0.3 : 1.0)
                        }.disabled(coin.status == .disabled)
                    }
                    
                    Button(action: { viewModel.toggleStatus(for: coin) }) {
                        Text(coin.status == .active ? "Disable Hardware" : "Enable Hardware").font(.headline).foregroundColor(coin.status == .active ? .orange : .green).frame(maxWidth: .infinity).frame(height: 55).background(Color.white.opacity(0.05)).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    Spacer()
                    Button(action: { viewModel.reclaimCoin(coin); presentationMode.wrappedValue.dismiss() }) {
                        VStack(spacing: 4) { Text("Delete & Reclaim Balance").font(.headline).foregroundColor(.red); Text("Burns physical link, returns funds to digital wallet").font(.caption2).foregroundColor(.gray) }.frame(maxWidth: .infinity).padding(.vertical, 15)
                    }.padding(.bottom, 20)
                } else {
                    Spacer(); ProgressView("Writing to physical chip...").foregroundColor(.gray); Spacer()
                }
            }.padding(.horizontal, 20)
        }.preferredColorScheme(.dark)
    }
    
    var statusColor: Color {
        switch coin.status { case .active: return .green; case .disabled: return .red; case .initializing: return .yellow }
    }
}

struct TransferCountdownView: View {
    let expirationDate: Date
    @State private var timeRemaining: String = "02:00"
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 8) {
            Text("TRANSFER MODE ACTIVE").font(.caption.bold()).foregroundColor(.red)
            Text(timeRemaining).font(.system(size: 48, weight: .black, design: .monospaced)).foregroundColor(.white).onReceive(timer) { _ in updateTime() }.onAppear { updateTime() }
            Text("Coin can be physically spent via NFC").font(.caption2).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 20).background(Color.red.opacity(0.1)).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.3), lineWidth: 2))
    }
    
    func updateTime() {
        let remaining = expirationDate.timeIntervalSince(Date())
        if remaining > 0 {
            let minutes = Int(remaining) / 60; let seconds = Int(remaining) % 60
            timeRemaining = String(format: "%02d:%02d", minutes, seconds)
        } else { timeRemaining = "00:00" }
    }
}
