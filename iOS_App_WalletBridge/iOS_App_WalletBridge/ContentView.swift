import SwiftUI

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

struct HomeView: View {
    var body: some View {
        NavigationView {
            ZStack {
                GridBackgroundView() // Keeps your cool background
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Premium Hero Icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.03))
                            .frame(width: 160, height: 160)
                        
                        Circle()
                            .stroke(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.2), .clear]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                            .frame(width: 160, height: 160)
                        
                        Image(systemName: "sensor.tag.radiowaves.forward")
                            .font(.system(size: 60, weight: .ultraLight))
                            .foregroundStyle(LinearGradient(colors: [.white, .gray], startPoint: .top, endPoint: .bottom))
                    }
                    
                    VStack(spacing: 12) {
                        Text("Crypto You Can Hold")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Your digital assets, secured in physical hardware. Tap the Wallet tab to manage your vault.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .lineSpacing(4)
                    }
                    
                    Spacer()
                }
            }
        }
    }
}
