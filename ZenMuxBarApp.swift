import SwiftUI

@main
struct ZenMuxBarApp: App {
    @StateObject private var client = ZenMuxClient()

    var body: some Scene {
        MenuBarExtra {
            DashboardView(client: client)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "z.circle.fill")
                if let balance = client.paygBalance {
                    Text("$\(String(format: "%.2f", balance.totalCredits))")
                        .font(.system(.caption, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
