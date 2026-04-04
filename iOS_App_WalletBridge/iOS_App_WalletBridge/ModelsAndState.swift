import SwiftUI
import Foundation

// MARK: - API Data Models
// This struct matches the expected JSON body for the Python API
struct CreateCoinPayload: Codable {
    let coin_id: String
    let wallet_id: String
    let asset_name: String
    let symbol: String
    let amount: Double
}

// MARK: - App Data Models
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
    case error = "Error: Check Connection"
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

// MARK: - The API-Connected ViewModel
@MainActor // Ensures all UI updates happen on the main thread
class WalletViewModel: ObservableObject {
    @Published var digitalAssets: [CryptoAsset] = [
        CryptoAsset(name: "Bitcoin", symbol: "BTC", balance: 2.45, color: .orange),
        CryptoAsset(name: "Ethereum", symbol: "ETH", balance: 14.2, color: .purple)
    ]
    
    @Published var activePhysicalCoins: [ActivePhysicalCoin] = []
    
    // --- API CONFIGURATION ---
    // Change this to your Mac's IP (e.g. http://192.168.X.X:8000) if testing on a real iPhone!
    private let baseURL = "https://cheyenne-unfond-tuan.ngrok-free.dev/coins"
    
    // The master wallet ID tying these assets together
    private let masterWalletID = "wallet_main_alpha"
    
    // MARK: - Create & Assign Coin
    func assignPhysicalCoin(asset: CryptoAsset, coinID: String, amount: Double) {
        guard let index = digitalAssets.firstIndex(where: { $0.id == asset.id }) else { return }
        
        // 1. Optimistic UI Update: Deduct balance & show initializing state instantly
        digitalAssets[index].balance -= amount
        let newCoin = ActivePhysicalCoin(
            coinID: coinID, assetID: asset.id, assetName: asset.name,
            symbol: asset.symbol, amount: amount, color: asset.color, status: .initializing
        )
        
        withAnimation(.spring()) {
            activePhysicalCoins.insert(newCoin, at: 0)
        }
        
        // 2. Call the Python API
        Task {
            let payload = CreateCoinPayload(
                coin_id: coinID,
                wallet_id: masterWalletID,
                asset_name: asset.name,
                symbol: asset.symbol,
                amount: amount
            )
            
            do {
                var request = URLRequest(url: URL(string: "\(baseURL)/")!)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(payload)
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 {
                    // Success! Activate the coin in the UI
                    if let coinIndex = self.activePhysicalCoins.firstIndex(where: { $0.id == newCoin.id }) {
                        withAnimation { self.activePhysicalCoins[coinIndex].status = .active }
                    }
                } else {
                    throw URLError(.badServerResponse)
                }
            } catch {
                print("API Error (Create): \(error)")
                // Fail gracefully: Show error status, or refund the balance
                if let coinIndex = self.activePhysicalCoins.firstIndex(where: { $0.id == newCoin.id }) {
                    withAnimation { self.activePhysicalCoins[coinIndex].status = .error }
                }
            }
        }
    }
    
    // MARK: - Enable / Disable Hardware
    func toggleStatus(for coin: ActivePhysicalCoin) {
        guard let index = activePhysicalCoins.firstIndex(where: { $0.id == coin.id }) else { return }
        let currentStatus = activePhysicalCoins[index].status
        let targetDisabledState = (currentStatus == .active) // If active, we want to disable
        
        Task {
            do {
                var request = URLRequest(url: URL(string: "\(baseURL)/\(coin.coinID)/status?disabled=\(targetDisabledState)")!)
                request.httpMethod = "PUT"
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    // Success! Update UI
                    withAnimation {
                        if targetDisabledState {
                            activePhysicalCoins[index].status = .disabled
                            activePhysicalCoins[index].transferModeExpiration = nil
                        } else {
                            activePhysicalCoins[index].status = .active
                        }
                    }
                }
            } catch {
                print("API Error (Toggle Status): \(error)")
            }
        }
    }
    
    // MARK: - Unlock Transfer Mode
    func activateTransferMode(for coin: ActivePhysicalCoin) {
        guard let index = activePhysicalCoins.firstIndex(where: { $0.id == coin.id }) else { return }
        
        Task {
            do {
                var request = URLRequest(url: URL(string: "\(baseURL)/\(coin.coinID)/transfer_mode")!)
                request.httpMethod = "PUT"
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    // API started the timer, sync the UI!
                    withAnimation {
                        activePhysicalCoins[index].transferModeExpiration = Date().addingTimeInterval(120)
                    }
                }
            } catch {
                print("API Error (Unlock Transfer): \(error)")
            }
        }
    }
    
    // MARK: - Delete & Reclaim Balance
    func reclaimCoin(_ coin: ActivePhysicalCoin) {
        guard let coinIndex = activePhysicalCoins.firstIndex(where: { $0.id == coin.id }) else { return }
        
        Task {
            do {
                var request = URLRequest(url: URL(string: "\(baseURL)/\(coin.coinID)")!)
                request.httpMethod = "DELETE"
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    // Successfully deleted from backend. Refund the digital wallet.
                    if let assetIndex = digitalAssets.firstIndex(where: { $0.id == coin.assetID }) {
                        withAnimation {
                            digitalAssets[assetIndex].balance += coin.amount
                            activePhysicalCoins.remove(at: coinIndex)
                        }
                    }
                }
            } catch {
                print("API Error (Reclaim): \(error)")
            }
        }
    }
}
