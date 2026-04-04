import SwiftUI
import Foundation
import Combine

// MARK: - API Data Models
struct CreateCoinPayload: Codable { let coin_id: String; let wallet_id: String; let asset_name: String; let symbol: String; let amount: Double }
struct APICoin: Codable { let coin_id: String; let wallet_id: String; let asset_name: String; let symbol: String; let amount: Double; let disabled: Bool; let transferrable: Bool; let transfer_start_timestamp: Double? }

// MARK: - App Data Models
struct CryptoAsset: Identifiable, Equatable { let id = UUID(); let name: String; let symbol: String; var balance: Double; let color: Color }
enum CoinStatus: String { case initializing = "Initializing..."; case active = "Active"; case disabled = "Disabled"; case error = "Error: Check Connection" }
struct ActivePhysicalCoin: Identifiable, Equatable {
    let id = UUID(); let coinID: String; let assetID: UUID; let assetName: String; let symbol: String; let amount: Double; let color: Color
    var status: CoinStatus = .initializing; var transferModeExpiration: Date? = nil
    var isTransferModeActive: Bool { guard let exp = transferModeExpiration else { return false }; return Date() < exp }
}

// MARK: - The API-Connected ViewModel
@MainActor
class WalletViewModel: ObservableObject {
    
    // We initialize these at 0.0 now, because the API will immediately overwrite them with the truth
    @Published var digitalAssets: [CryptoAsset] = [
        CryptoAsset(name: "Bitcoin", symbol: "BTC", balance: 0.0, color: .orange),
        CryptoAsset(name: "Ethereum", symbol: "ETH", balance: 0.0, color: .purple)
    ]
    
    @Published var activePhysicalCoins: [ActivePhysicalCoin] = []
    @Published var managedCoin: ActivePhysicalCoin? = nil
    @Published var showTransferSuccess: Bool = false
    
    @Published var masterWalletID = "wallet_person_1" {
        didSet { syncEntireWallet() }
    }
    
    private var pollingTimer: AnyCancellable?
    
    // NOTE: Removed "/coins" from the end so we can hit both /coins and /wallets endpoints
    private let apiBaseURL = "https://cheyenne-unfond-tuan.ngrok-free.dev"
    
    init() { syncEntireWallet() }
    
    // MARK: - Master Sync Function
    func syncEntireWallet() {
        fetchDigitalBalances()
        fetchPhysicalCoins()
    }
    
    // MARK: - Fetch Digital Balances (NEW)
    private func fetchDigitalBalances() {
        Task {
            do {
                let url = URL(string: "\(apiBaseURL)/wallets/\(masterWalletID)")!
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
                
                // Decode the dictionary {"BTC": 2.45, "ETH": 14.2}
                let balances = try JSONDecoder().decode([String: Double].self, from: data)
                
                withAnimation {
                    // Update BTC
                    if let btcIndex = digitalAssets.firstIndex(where: { $0.symbol == "BTC" }) {
                        digitalAssets[btcIndex].balance = balances["BTC"] ?? 0.0
                    }
                    // Update ETH
                    if let ethIndex = digitalAssets.firstIndex(where: { $0.symbol == "ETH" }) {
                        digitalAssets[ethIndex].balance = balances["ETH"] ?? 0.0
                    }
                }
            } catch { print("Fetch balances error: \(error)") }
        }
    }
    
    // MARK: - Fetch Physical Coins
    private func fetchPhysicalCoins() {
        Task {
            do {
                let url = URL(string: "\(apiBaseURL)/coins/wallet/\(masterWalletID)")!
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
                let decodedCoins = try JSONDecoder().decode([APICoin].self, from: data)
                
                var fetchedUIModels: [ActivePhysicalCoin] = []
                for apiCoin in decodedCoins {
                    let color: Color = apiCoin.symbol == "BTC" ? .orange : (apiCoin.symbol == "ETH" ? .purple : .blue)
                    let assetID = digitalAssets.first(where: { $0.symbol == apiCoin.symbol })?.id ?? UUID()
                    var status: CoinStatus = .active
                    if apiCoin.disabled { status = .disabled }
                    
                    var expiration: Date? = nil
                    if apiCoin.transferrable, let startStamp = apiCoin.transfer_start_timestamp { expiration = Date(timeIntervalSince1970: startStamp).addingTimeInterval(120) }
                    
                    fetchedUIModels.append(ActivePhysicalCoin(coinID: apiCoin.coin_id, assetID: assetID, assetName: apiCoin.asset_name, symbol: apiCoin.symbol, amount: apiCoin.amount, color: color, status: status, transferModeExpiration: expiration))
                }
                withAnimation { self.activePhysicalCoins = fetchedUIModels }
            } catch { print("Fetch coins error: \(error)") }
        }
    }
    
    // MARK: - Create & Assign Coin
    func assignPhysicalCoin(asset: CryptoAsset, coinID: String, amount: Double) {
        guard let index = digitalAssets.firstIndex(where: { $0.id == asset.id }) else { return }
        
        // Optimistic UI Update
        digitalAssets[index].balance -= amount
        let newCoin = ActivePhysicalCoin(coinID: coinID, assetID: asset.id, assetName: asset.name, symbol: asset.symbol, amount: amount, color: asset.color, status: .initializing)
        withAnimation(.spring()) { activePhysicalCoins.insert(newCoin, at: 0) }
        
        Task {
            let payload = CreateCoinPayload(coin_id: coinID, wallet_id: masterWalletID, asset_name: asset.name, symbol: asset.symbol, amount: amount)
            do {
                var request = URLRequest(url: URL(string: "\(apiBaseURL)/coins/")!)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(payload)
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 {
                    if let coinIndex = self.activePhysicalCoins.firstIndex(where: { $0.id == newCoin.id }) { withAnimation { self.activePhysicalCoins[coinIndex].status = .active } }
                } else {
                    // If backend fails, re-sync to fix the optimistic UI deduction
                    syncEntireWallet()
                }
            } catch {
                if let coinIndex = self.activePhysicalCoins.firstIndex(where: { $0.id == newCoin.id }) { withAnimation { self.activePhysicalCoins[coinIndex].status = .error } }
                syncEntireWallet()
            }
        }
    }
    
    func toggleStatus(for coin: ActivePhysicalCoin) {
        guard let index = activePhysicalCoins.firstIndex(where: { $0.id == coin.id }) else { return }
        let targetDisabledState = (activePhysicalCoins[index].status == .active)
        Task {
            do {
                var request = URLRequest(url: URL(string: "\(apiBaseURL)/coins/\(coin.coinID)/status?disabled=\(targetDisabledState)")!)
                request.httpMethod = "PUT"
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    withAnimation { if targetDisabledState { activePhysicalCoins[index].status = .disabled; activePhysicalCoins[index].transferModeExpiration = nil } else { activePhysicalCoins[index].status = .active } }
                }
            } catch { print("Toggle error") }
        }
    }
    
    func activateTransferMode(for coin: ActivePhysicalCoin) {
        guard let index = activePhysicalCoins.firstIndex(where: { $0.id == coin.id }) else { return }
        Task {
            do {
                var request = URLRequest(url: URL(string: "\(apiBaseURL)/coins/\(coin.coinID)/transfer_mode")!)
                request.httpMethod = "PUT"
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    withAnimation { activePhysicalCoins[index].transferModeExpiration = Date().addingTimeInterval(120) }
                    startPollingForTransfer(coinID: coin.coinID)
                }
            } catch { print("Unlock error") }
        }
    }
    
    private func startPollingForTransfer(coinID: String) {
        pollingTimer?.cancel()
        pollingTimer = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.checkIfCoinWasSpent(coinID: coinID) }
    }

    private func checkIfCoinWasSpent(coinID: String) {
        Task {
            do {
                let url = URL(string: "\(apiBaseURL)/coins/\(coinID)")!
                let (_, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                    self.pollingTimer?.cancel()
                    
                    await MainActor.run {
                        self.managedCoin = nil
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                self.activePhysicalCoins.removeAll(where: { $0.coinID == coinID })
                                self.showTransferSuccess = true
                            }
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            
                            // Re-sync balances just in case (though sender's balance doesn't change here,
                            // it's good practice to keep the ledger perfectly in sync).
                            self.fetchDigitalBalances()
                        }
                    }
                }
            } catch { print("Polling Error") }
        }
    }
    
    func reclaimCoin(_ coin: ActivePhysicalCoin) {
        guard let coinIndex = activePhysicalCoins.firstIndex(where: { $0.id == coin.id }) else { return }
        Task {
            do {
                var request = URLRequest(url: URL(string: "\(apiBaseURL)/coins/\(coin.coinID)")!)
                request.httpMethod = "DELETE"
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    // Instead of calculating it locally, we just fetch the fresh truth from the API!
                    syncEntireWallet()
                }
            } catch { print("Reclaim error") }
        }
    }
}
