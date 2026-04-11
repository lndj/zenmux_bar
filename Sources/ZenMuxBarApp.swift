import SwiftUI

@main
struct ZenMuxBarApp: App {
    @StateObject private var client = ZenMuxClient()

    var body: some Scene {
        MenuBarExtra {
            DashboardView(client: client)
        } label: {
            HStack(spacing: 4) {
                // Optimized Icon: Using a more sophisticated SF Symbol
                Image(systemName: "cpu.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
                
                if client.displayType == .balance {
                    if let balance = client.paygBalance {
                        Text("$\(String(format: "%.2f", balance.totalCredits))")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                    }
                } else if client.displayType == .subscription {
                    if let sub = client.subscriptionDetail {
                        Text("\(Int((sub.quota5Hour?.usagePercentage ?? 0) * 100))%")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                    }
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
