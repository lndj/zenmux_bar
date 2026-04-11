import SwiftUI

struct DashboardView: View {
    @ObservedObject var client: ZenMuxClient
    @State private var isShowingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if isShowingSettings {
                SettingsView(client: client, isShowingSettings: $isShowingSettings)
                    .transition(.move(edge: .trailing))
            } else {
                MainDashboardContent(client: client, isShowingSettings: $isShowingSettings)
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isShowingSettings)
        .frame(width: 320, height: 460)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
    }
}

struct MainDashboardContent: View {
    @ObservedObject var client: ZenMuxClient
    @Binding var isShowingSettings: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("ZenMux")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                
                if client.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 20, height: 20)
                }
                
                Spacer()
                
                Button(action: { Task { await client.fetchData() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("Refresh now")
                
                Button(action: { isShowingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                .help("Settings")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().opacity(0.1)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if let sub = client.subscriptionDetail {
                        // Plan Highlight
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(sub.plan.tier.uppercased())
                                    .font(.system(size: 10, weight: .black))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                                Spacer()
                                Text("Expires: \(formatDate(sub.plan.expiresAt))")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("$\(Int(sub.plan.amountUsd))")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                Text("/\(sub.plan.interval)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(14)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(12)

                        // Quotas Section
                        VStack(spacing: 12) {
                            SectionHeader(title: "Usage Quotas", icon: "chart.bar.fill")
                            QuotaRow(title: "5 Hour", quota: sub.quota5Hour)
                            QuotaRow(title: "7 Day", quota: sub.quota7Day)
                        }
                        .padding(14)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(12)
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            SectionHeader(title: "PAYG", icon: "dollarsign.circle.fill")
                            if let payg = client.paygBalance {
                                Text("$\(String(format: "%.3f", payg.totalCredits))")
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            SectionHeader(title: "Flow Rate", icon: "bolt.fill")
                            if let flow = client.flowRate {
                                Text("$\(String(format: "%.4f", flow.effectiveUsdPerFlow))")
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(12)
                    }
                }
                .padding(16)
            }

            // Footer
            HStack {
                if let last = client.lastUpdated {
                    Text("Updated \(last.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let error = client.errorMessage {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .help(error)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))
        }
    }
    
    private func formatDate(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        return dateStr
    }
}

struct QuotaRow: View {
    let title: String
    let quota: Quota
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 11, weight: .medium))
                
                // Added Percentage here
                Text("\(String(format: "%.1f", quota.usagePercentage * 100))%")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(quota.usagePercentage > 0.8 ? .orange : .blue)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(3)

                Spacer()
                
                Text("\(Int(quota.usedFlows))/\(Int(quota.maxFlows))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            CustomProgressView(value: quota.usagePercentage)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var client: ZenMuxClient
    @Binding var isShowingSettings: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Back Button
            HStack {
                Button(action: { isShowingSettings = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Preferences")
                    .font(.system(size: 13, weight: .bold))
                
                Spacer()
                
                // Placeholder to balance the layout
                Color.clear.frame(width: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Auth
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AUTHENTICATION").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                        SecureField("Management API Key", text: $client.apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Display & Sync
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DISPLAY & SYNC").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                        
                        // Using a simple HStack + Picker with MenuStyle to avoid popover issues
                        HStack {
                            Text("Refresh Every").font(.system(size: 12))
                            Spacer()
                            Picker("", selection: $client.refreshInterval) {
                                Text("1 min").tag(1.0)
                                Text("5 mins").tag(5.0)
                                Text("15 mins").tag(15.0)
                                Text("30 mins").tag(30.0)
                                Text("1 hour").tag(60.0)
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 100)
                            .onChange(of: client.refreshInterval) { _, _ in client.setupTimer() }
                        }
                        
                        HStack {
                            Text("Menu Bar Style").font(.system(size: 12))
                            Spacer()
                            Picker("", selection: $client.displayType) {
                                ForEach(MenuBarDisplayType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 120)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            
            Divider()

            Button("Done") { isShowingSettings = false }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(16)
        }
    }
}

// Keep helper views...
struct SectionHeader: View {
    let title: String
    let icon: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.blue)
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
        }
    }
}

struct CustomProgressView: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 5)
                Capsule()
                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(min(value, 1.0)), height: 5)
                    .shadow(color: Color.blue.opacity(0.3), radius: 2, x: 0, y: 1)
            }
        }
        .frame(height: 5)
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
