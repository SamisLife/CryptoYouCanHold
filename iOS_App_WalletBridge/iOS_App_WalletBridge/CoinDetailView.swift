import SwiftUI

// MARK: - Digital Asset Detail Flow
struct CoinDetailView: View {
    let asset: CryptoAsset
    @Environment(\.presentationMode) var presentationMode
    
    // UI Routing States
    @State private var showingChoiceOverlay = false
    @State private var showingManualEntrySheet = false
    @State private var showingNFCSimulation = false
    
    var body: some View {
        ZStack {
            GridBackgroundView()
            
            VStack(spacing: 30) {
                Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 10)
                
                Circle().fill(asset.color.opacity(0.2)).frame(width: 120, height: 120)
                    .overlay(Text(asset.symbol).font(.system(size: 40, weight: .bold)).foregroundColor(asset.color))
                
                VStack(spacing: 15) {
                    HStack { Text("Asset").foregroundColor(.gray); Spacer(); Text(asset.name).fontWeight(.medium).foregroundColor(.white) }.font(.system(size: 16, design: .monospaced))
                    HStack { Text("Available Balance").foregroundColor(.gray); Spacer(); Text("\(String(format: "%.4f", asset.balance)) \(asset.symbol)").fontWeight(.medium).foregroundColor(.white) }.font(.system(size: 16, design: .monospaced))
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.05)))
                .padding(.horizontal, 20)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingChoiceOverlay = true
                    }
                }) {
                    Text("Assign to Physical Coin")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(LinearGradient(gradient: Gradient(colors: [asset.color, asset.color.opacity(0.6)]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            
            // ===== THE PREMIUM CHOICE OVERLAY =====
            if showingChoiceOverlay {
                AssignChoiceOverlay(
                    onNFCScan: {
                        withAnimation { showingChoiceOverlay = false }
                        // Wait a tiny bit for the menu to fade before opening the scanner
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation { showingNFCSimulation = true }
                        }
                    },
                    onManualEntry: {
                        withAnimation { showingChoiceOverlay = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showingManualEntrySheet = true
                        }
                    },
                    onCancel: {
                        withAnimation { showingChoiceOverlay = false }
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(2)
            }
            
            // ===== THE CONCEPTUAL NFC SCANNER =====
            if showingNFCSimulation {
                NFCSimulationOverlay(
                    asset: asset,
                    onComplete: {
                        withAnimation { showingNFCSimulation = false }
                        presentationMode.wrappedValue.dismiss() // Closes the whole detail view!
                    },
                    onCancel: {
                        withAnimation { showingNFCSimulation = false }
                    }
                )
                .transition(.opacity)
                .zIndex(3)
            }
        }
        .sheet(isPresented: $showingManualEntrySheet) {
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

// MARK: - Premium Choice Menu
struct AssignChoiceOverlay: View {
    var onNFCScan: () -> Void
    var onManualEntry: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { onCancel() }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 20) {
                    Capsule().fill(Color.gray.opacity(0.4)).frame(width: 40, height: 5).padding(.top, 10)
                    
                    Text("Hardware Initialization")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    
                    // NFC Option Tile
                    Button(action: onNFCScan) {
                        HStack(spacing: 20) {
                            ZStack {
                                Circle().fill(LinearGradient(gradient: Gradient(colors: [.blue, .cyan]), startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 50, height: 50)
                                Image(systemName: "wave.3.right").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Hold Coin Near iPhone").font(.headline).foregroundColor(.white)
                                Text("Uses near-field communication").font(.caption).foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.5))
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Manual Option Tile
                    Button(action: onManualEntry) {
                        HStack(spacing: 20) {
                            ZStack {
                                Circle().fill(Color.white.opacity(0.1)).frame(width: 50, height: 50)
                                Image(systemName: "keyboard").font(.system(size: 20, weight: .medium)).foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enter ID Manually").font(.headline).foregroundColor(.white)
                                Text("Type the coin serial number").font(.caption).foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.5))
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: onCancel) {
                        Text("Cancel").font(.headline).foregroundColor(.gray).padding(.top, 10)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(.ultraThinMaterial)
                        .colorScheme(.dark)
                        .ignoresSafeArea(edges: .bottom)
                )
                .shadow(color: .black.opacity(0.5), radius: 20, y: -5)
            }
        }
    }
}

// MARK: - Conceptual NFC Scanner Simulation
struct NFCSimulationOverlay: View {
    let asset: CryptoAsset
    var onComplete: () -> Void
    var onCancel: () -> Void
    
    @State private var isPulsing = false
    @State private var scanSuccess = false
    @EnvironmentObject var viewModel: WalletViewModel // So we can artificially assign a coin if we want
    
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).colorScheme(.dark).ignoresSafeArea()
            
            VStack(spacing: 40) {
                HStack {
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill").font(.title).foregroundColor(.gray).opacity(scanSuccess ? 0 : 1)
                    }.padding()
                }
                Spacer()
                
                ZStack {
                    // Radiating rings
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(scanSuccess ? Color.green : Color.blue, lineWidth: 2)
                            .frame(width: 100, height: 100)
                            .scaleEffect(isPulsing ? 2.5 : 1.0)
                            .opacity(isPulsing ? 0.0 : (scanSuccess ? 0 : 0.8))
                            .animation(
                                scanSuccess ? .none : .easeOut(duration: 2.0).repeatForever(autoreverses: false).delay(Double(i) * 0.4),
                                value: isPulsing
                            )
                    }
                    
                    // Center Icon
                    if scanSuccess {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 100, height: 100)
                            .shadow(color: Color.green.opacity(0.5), radius: 20)
                    } else {
                        Circle()
                            .fill(LinearGradient(gradient: Gradient(colors: [.blue, .cyan]), startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 100, height: 100)
                            .shadow(color: Color.blue.opacity(0.5), radius: 20)
                    }
                    
                    Image(systemName: scanSuccess ? "checkmark" : "wave.3.right")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 8) {
                    Text(scanSuccess ? "Hardware Linked" : "Ready to Scan")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text(scanSuccess ? "Returning to vault..." : "Hold hardware coin near iPhone\n(Conceptual Demo)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
        }
        .onAppear {
            isPulsing = true
            
            // Trigger initial haptic
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Simulate a successful scan after 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.spring()) {
                    scanSuccess = true
                    isPulsing = false
                }
                
                // Success haptic
                let successGen = UINotificationFeedbackGenerator()
                successGen.notificationOccurred(.success)
                
                // (Optional) Automatically assign a dummy coin to the wallet here for the demo effect
                // viewModel.assignPhysicalCoin(asset: asset, coinID: "NFC-\(Int.random(in: 100...999))", amount: 0.1)
                
                // Dismiss after showing success
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onComplete()
                }
            }
        }
    }
}
