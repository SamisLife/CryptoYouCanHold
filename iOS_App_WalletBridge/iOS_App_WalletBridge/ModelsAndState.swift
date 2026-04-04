import SwiftUI

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
    let assetID: UUID
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
            digitalAssets[index].balance -= amount
            let newCoin = ActivePhysicalCoin(
                coinID: coinID, assetID: asset.id, assetName: asset.name,
                symbol: asset.symbol, amount: amount, color: asset.color, status: .initializing
            )
            
            withAnimation(.spring()) {
                activePhysicalCoins.insert(newCoin, at: 0)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if let coinIndex = self.activePhysicalCoins.firstIndex(where: { $0.id == newCoin.id }) {
                    withAnimation { self.activePhysicalCoins[coinIndex].status = .active }
                }
            }
        }
    }
    
    func toggleStatus(for coin: ActivePhysicalCoin) {
        if let index = activePhysicalCoins.firstIndex(where: { $0.id == coin.id }) {
            withAnimation {
                if activePhysicalCoins[index].status == .active {
                    activePhysicalCoins[index].status = .disabled
                    activePhysicalCoins[index].transferModeExpiration = nil
                } else {
                    activePhysicalCoins[index].status = .active
                }
            }
        }
    }
    
    func reclaimCoin(_ coin: ActivePhysicalCoin) {
        if let coinIndex = activePhysicalCoins.firstIndex(where: { $0.id == coin.id }) {
            if let assetIndex = digitalAssets.firstIndex(where: { $0.id == coin.assetID }) {
                digitalAssets[assetIndex].balance += coin.amount
            }
            withAnimation { activePhysicalCoins.remove(at: coinIndex) }
        }
    }
    
    func activateTransferMode(for coin: ActivePhysicalCoin) {
        if let index = activePhysicalCoins.firstIndex(where: { $0.id == coin.id }) {
            withAnimation { activePhysicalCoins[index].transferModeExpiration = Date().addingTimeInterval(120) }
        }
    }
}
