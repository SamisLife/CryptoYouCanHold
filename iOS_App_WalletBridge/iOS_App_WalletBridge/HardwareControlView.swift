import SwiftUI
import Combine

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
