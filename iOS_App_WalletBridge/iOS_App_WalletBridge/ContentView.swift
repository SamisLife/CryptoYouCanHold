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
