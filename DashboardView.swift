import SwiftUI

struct DashboardView: View {
    @ObservedObject var client: ZenMuxClient
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("ZenMux")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Button(action: {
                    Task {
                        await client.fetchData()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    showingSettings.toggle()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            if client.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = client.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if error.contains("API Key") {
                        Button("Go to Settings") {
                            showingSettings.toggle()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Plan Summary
                        if let sub = client.subscriptionDetail {
                            CardView(title: "Subscription Plan", icon: "creditcard.fill", color: .blue) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(sub.plan.tier.uppercased())
                                            .font(.system(size: 24, weight: .black, design: .rounded))
                                        Spacer()
                                        Text("$\(String(format: "%.2f", sub.plan.amountUsd))/\(sub.plan.interval)")
                                            .font(.headline)
                                    }
                                    
                                    Text("Expires: \(formatDate(sub.plan.expiresAt))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            // Quotas
                            CardView(title: "Usage Quotas", icon: "chart.bar.fill", color: .purple) {
                                VStack(spacing: 12) {
                                    QuotaRow(title: "5 Hour Quota", quota: sub.quota5Hour)
                                    Divider()
                                    QuotaRow(title: "7 Day Quota", quota: sub.quota7Day)
                                }
                            }
                        }

                        // PAYG Balance
                        if let payg = client.paygBalance {
                            CardView(title: "PAYG Balance", icon: "dollarsign.circle.fill", color: .green) {
                                HStack(alignment: .lastTextBaseline) {
                                    Text("$\(String(format: "%.4f", payg.totalCredits))")
                                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    Text(payg.currency.uppercased())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                        }

                        // Flow Rate
                        if let flow = client.flowRate {
                            CardView(title: "Flow Rate", icon: "bolt.fill", color: .orange) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Base: $\(String(format: "%.5f", flow.baseUsdPerFlow))")
                                        Text("Effective: $\(String(format: "%.5f", flow.effectiveUsdPerFlow))")
                                            .fontWeight(.bold)
                                    }
                                    .font(.system(size: 14, design: .monospaced))
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(width: 320, height: 480)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
        .sheet(isPresented: $showingSettings) {
            SettingsView(client: client)
        }
        .onAppear {
            Task {
                await client.fetchData()
            }
        }
    }
    
    private func formatDate(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateStr
    }
}

struct CardView<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content

    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            content
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct QuotaRow: View {
    let title: String
    let quota: Quota

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(quota.usedFlows)) / \(Int(quota.maxFlows)) flows")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geo in
                NickProgressView(percentage: quota.usagePercentage)
            }
            .frame(height: 6)
            
            Text("Resets: \(formatTime(quota.resetsAt))")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
    
    private func formatTime(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .none
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateStr
    }
}

struct NickProgressView: View {
    let percentage: Double
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.1))
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(min(percentage, 1.0)))
            }
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

struct SettingsView: View {
    @ObservedObject var client: ZenMuxClient
    @Environment(\.dismiss) var dismiss
    @State private var apiKey: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.headline)
            
            VStack(alignment: .leading) {
                Text("Management API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("Enter your API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("Save") {
                    UserDefaults.standard.set(apiKey, forKey: "ZENMUX_API_KEY")
                    Task {
                        await client.fetchData()
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            apiKey = UserDefaults.standard.string(forKey: "ZENMUX_API_KEY") ?? ""
        }
    }
}
