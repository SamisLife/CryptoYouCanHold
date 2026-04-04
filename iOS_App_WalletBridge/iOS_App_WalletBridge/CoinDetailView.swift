import SwiftUI

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
                    HStack { Text("Asset").foregroundColor(.gray); Spacer(); Text(asset.name).fontWeight(.medium).foregroundColor(.white) }.font(.system(size: 16, design: .monospaced))
                    HStack { Text("Available Balance").foregroundColor(.gray); Spacer(); Text("\(String(format: "%.4f", asset.balance)) \(asset.symbol)").fontWeight(.medium).foregroundColor(.white) }.font(.system(size: 16, design: .monospaced))
                }.padding(20).background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.05))).padding(.horizontal, 20)
                Spacer()
                Button(action: { showingAddCoinSheet = true }) {
                    Text("Assign to Physical Coin").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 55).background(LinearGradient(gradient: Gradient(colors: [asset.color, asset.color.opacity(0.6)]), startPoint: .leading, endPoint: .trailing)).cornerRadius(16)
                }.padding(.horizontal, 20).padding(.bottom, 30)
            }
        }.sheet(isPresented: $showingAddCoinSheet) {
            // Callback to dismiss both this view and the modal upon successful addition
            AddPhysicalCoinModal(asset: asset) {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct AddPhysicalCoinModal: View {
    let asset: CryptoAsset
    var onCoinAdded: () -> Void // The callback closure
    
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
                    if let amt = Double(inputAmount), amt > 0, amt <= asset.balance, !inputCoinID.isEmpty {
                        viewModel.assignPhysicalCoin(asset: asset, coinID: inputCoinID, amount: amt)
                        presentationMode.wrappedValue.dismiss()
                        // Wait a tiny fraction of a second before dismissing the parent view for a smoother animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onCoinAdded()
                        }
                    }
                }) { Text("Initialize Hardware").font(.headline).foregroundColor(.black).frame(maxWidth: .infinity).frame(height: 55).background(Color.white).cornerRadius(16) }
                .padding(.horizontal, 20).padding(.bottom, 30).disabled(inputCoinID.isEmpty || inputAmount.isEmpty || (Double(inputAmount) ?? 0) > asset.balance).opacity((inputCoinID.isEmpty || inputAmount.isEmpty || (Double(inputAmount) ?? 0) > asset.balance) ? 0.5 : 1.0)
            }
        }.preferredColorScheme(.dark)
    }
}
