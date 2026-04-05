import SwiftUI
import Foundation
import Combine

// MARK: - API Data Models
struct CreateCoinPayload: Codable { let coin_id: String; let wallet_id: String; let asset_name: String; let symbol: String; let amount: Double }
struct APICoin: Codable { let coin_id: String; let wallet_id: String; let asset_name: String; let symbol: String; let amount: Double; let disabled: Bool; let transferrable: Bool; let transfer_start_timestamp: Double?; let pending_transfer_to: String? }
struct RiskAssessment: Codable { let score: Int; let reason: String }

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
    
    @Published var digitalAssets: [CryptoAsset] = [
        CryptoAsset(name: "Bitcoin", symbol: "BTC", balance: 0.0, color: .orange),
        CryptoAsset(name: "Ethereum", symbol: "ETH", balance: 0.0, color: .purple)
    ]
    
    @Published var activePhysicalCoins: [ActivePhysicalCoin] = []
    @Published var managedCoin: ActivePhysicalCoin? = nil
    @Published var showTransferSuccess: Bool = false
    
    @Published var masterWalletID = "wallet_person_1" { didSet { syncEntireWallet() } }
    
    // AI STATE VARIABLES
    @Published var showRiskOverlay = false
    @Published var isCheckingRisk = false
    @Published var riskScore: Int = 0
    @Published var riskReason: String = ""
    @Published var pendingTransferDestination: String = ""
    @Published var pendingTransferCoinID: String = ""
    
    private var pollingTimer: AnyCancellable?
    private let apiBaseURL = "https://cheyenne-unfond-tuan.ngrok-free.dev" // Keep your ngrok URL!
    
    init() { syncEntireWallet() }
    
    func syncEntireWallet() {
        fetchDigitalBalances()
        fetchPhysicalCoins()
    }
    
    func fetchDigitalBalances() {
        Task {
            do {
                let url = URL(string: "\(apiBaseURL)/wallets/\(masterWalletID)")!
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
                
                let balances = try JSONDecoder().decode([String: Double].self, from: data)
                withAnimation {
                    if let btcIndex = digitalAssets.firstIndex(where: { $0.symbol == "BTC" }) { digitalAssets[btcIndex].balance = balances["BTC"] ?? 0.0 }
                    if let ethIndex = digitalAssets.firstIndex(where: { $0.symbol == "ETH" }) { digitalAssets[ethIndex].balance = balances["ETH"] ?? 0.0 }
                }
            } catch { print("Fetch balances error: \(error)") }
        }
    }
    
    func fetchPhysicalCoins() {
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
    
    @Published var btcPrice: Double = 67000.0
    @Published var ethPrice: Double = 2000.0

    func fetchLivePrices() {
        Task {
            do {
                let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=usd")!
                let (data, _) = try await URLSession.shared.data(from: url)
                
                // Decode the nested dictionary
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: Double]] {
                    await MainActor.run {
                        self.btcPrice = json["bitcoin"]?["usd"] ?? 67000.0
                        self.ethPrice = json["ethereum"]?["usd"] ?? 2000.0
                    }
                }
            } catch {
                print("Price fetch failed, using defaults")
            }
        }
    }
    
    // MARK: - AI & Hardware 2FA Flow
    
    func evaluateTransferRisk(coinID: String, destination: String) {
        isCheckingRisk = true
        pendingTransferCoinID = coinID
        pendingTransferDestination = destination
        
        Task {
            do {
                let url = URL(string: "\(apiBaseURL)/wallets/\(destination)/risk")!
                let (data, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let riskData = try JSONDecoder().decode(RiskAssessment.self, from: data)
                    
                    await MainActor.run {
                        self.riskScore = riskData.score
                        self.riskReason = riskData.reason
                        self.isCheckingRisk = false
                        
                        // FIX: Hide the bottom sheet first so the user can see the overlay!
                        self.managedCoin = nil
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                self.showRiskOverlay = true
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run { self.isCheckingRisk = false }
                print("Risk check error: \(error)")
            }
        }
    }
    
    private func startPollingForTransfer(coinID: String) {
        pollingTimer?.cancel()
        pollingTimer = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.checkIfCoinWasTransferred(coinID: coinID) }
    }
    
    private func checkIfCoinWasTransferred(coinID: String) {
        Task {
            do {
                let url = URL(string: "\(apiBaseURL)/coins/\(coinID)")!
                let (data, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let coin = try JSONDecoder().decode(APICoin.self, from: data)
                    
                    if let dest = coin.pending_transfer_to, !dest.isEmpty, self.pendingTransferDestination != dest {
                        await MainActor.run { self.evaluateTransferRisk(coinID: coinID, destination: dest) }
                    }
                    else if coin.wallet_id != self.masterWalletID {
                        self.pollingTimer?.cancel()
                        await MainActor.run {
                            self.showRiskOverlay = false
                            self.managedCoin = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    self.activePhysicalCoins.removeAll(where: { $0.coinID == coinID })
                                    self.showTransferSuccess = true
                                }
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                self.fetchDigitalBalances()
                            }
                        }
                    }
                }
            } catch { print("Polling Error") }
        }
    }
    
    func confirmAndTransfer() {
        Task {
            let payload = ["coin_id": pendingTransferCoinID]
            do {
                var request = URLRequest(url: URL(string: "\(apiBaseURL)/coins/transfer/confirm")!)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                let _ = try await URLSession.shared.data(for: request)
            } catch { print("Confirm error: \(error)") }
        }
    }
    
    func cancelTransfer() {
        Task {
            let payload = ["coin_id": pendingTransferCoinID]
            do {
                var request = URLRequest(url: URL(string: "\(apiBaseURL)/coins/transfer/cancel")!)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                let _ = try await URLSession.shared.data(for: request)
                await MainActor.run {
                    self.showRiskOverlay = false
                    self.pendingTransferDestination = ""
                }
            } catch { print("Cancel error: \(error)") }
        }
    }
    
    // MARK: - Standard Coin Operations
    
    func assignPhysicalCoin(asset: CryptoAsset, coinID: String, amount: Double) {
        guard let index = digitalAssets.firstIndex(where: { $0.id == asset.id }) else { return }
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
                } else { syncEntireWallet() }
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
    
    func reclaimCoin(_ coin: ActivePhysicalCoin) {
        guard let coinIndex = activePhysicalCoins.firstIndex(where: { $0.id == coin.id }) else { return }
        Task {
            do {
                var request = URLRequest(url: URL(string: "\(apiBaseURL)/coins/\(coin.coinID)")!)
                request.httpMethod = "DELETE"
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    await MainActor.run { self.managedCoin = nil }
                    syncEntireWallet()
                }
            } catch { print("Reclaim error") }
        }
    }
}
