import SwiftUI

struct DashboardView: View {
    @ObservedObject var client: ZenMuxClient
    @State private var isShowingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if isShowingSettings {
                SettingsView(client: client, isShowingSettings: $isShowingSettings)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            } else {
                MainDashboardContent(client: client, isShowingSettings: $isShowingSettings)
                    .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isShowingSettings)
        .frame(width: 300, height: 380) // Reduced height to eliminate empty space
        .background(VisualEffectView(material: .menu, blendingMode: .behindWindow))
    }
}

struct MainDashboardContent: View {
    @ObservedObject var client: ZenMuxClient
    @Binding var isShowingSettings: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ZenMux")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                    if let last = client.lastUpdated {
                        Text("Updated \(last.formatted(.dateTime.hour().minute()))")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                
                if client.isLoading {
                    ProgressView()
                        .scaleEffect(0.4)
                        .frame(width: 16, height: 16)
                        .padding(.leading, 4)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: { Task { await client.fetchData() } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { isShowingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().opacity(0.1)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if let sub = client.subscriptionDetail {
                        // Compact Plan Card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(sub.plan.tier.uppercased())
                                    .font(.system(size: 9, weight: .black))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                                
                                Spacer()
                                
                                Text("$\(Int(sub.plan.amountUsd))/\(sub.plan.interval)")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            
                            // Improved Expiry Display
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 10))
                                Text("Expires: \(formatDate(sub.plan.expiresAt))")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.05), lineWidth: 0.5))

                        // Quotas Section
                        VStack(spacing: 10) {
                            SectionHeader(title: "QUOTAS", icon: "chart.bar.fill")
                            QuotaRow(title: "5 Hour", quota: sub.quota5Hour)
                            QuotaRow(title: "7 Day", quota: sub.quota7Day)
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(10)
                    }

                    HStack(spacing: 10) {
                        // Balance
                        VStack(alignment: .leading, spacing: 4) {
                            SectionHeader(title: "CREDITS", icon: "dollarsign.circle.fill")
                            if let payg = client.paygBalance {
                                Text("$\(String(format: "%.3f", payg.totalCredits))")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(10)
                        
                        // Rate
                        VStack(alignment: .leading, spacing: 4) {
                            SectionHeader(title: "RATE", icon: "bolt.fill")
                            if let flow = client.flowRate {
                                Text("$\(String(format: "%.4f", flow.effectiveUsdPerFlow))")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(10)
                    }
                }
                .padding(16)
            }
            
            if let error = client.errorMessage {
                Text(error)
                    .font(.system(size: 9))
                    .foregroundColor(.red)
                    .padding(.bottom, 8)
            }
        }
    }
    
    private func formatDate(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateStr) {
            return date.formatted(.dateTime.year().month().day().hour().minute())
        }
        return dateStr
    }
}

struct QuotaRow: View {
    let title: String
    let quota: Quota
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: "%.1f", quota.usagePercentage * 100))%")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(quota.usagePercentage > 0.8 ? .orange : .blue)
            }
            CustomProgressView(value: quota.usagePercentage)
            HStack {
                Text("Used \(Int(quota.usedFlows))/\(Int(quota.maxFlows))").font(.system(size: 8))
                Spacer()
                Text("Reset: \(formatShortTime(quota.resetsAt))").font(.system(size: 8))
            }
            .foregroundColor(.secondary.opacity(0.8))
        }
    }
    
    private func formatShortTime(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateStr) {
            return date.formatted(.dateTime.month().day().hour().minute())
        }
        return dateStr
    }
}

struct SettingsView: View {
    @ObservedObject var client: ZenMuxClient
    @Binding var isShowingSettings: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { isShowingSettings = false }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Preferences").font(.system(size: 12, weight: .bold))
                Spacer()
                Color.clear.frame(width: 20)
            }
            .padding(16)
            
            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MANAGEMENT API KEY").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                        SecureField("sk-mg-v1-...", text: $client.apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("REFRESH INTERVAL").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                        Picker("", selection: $client.refreshInterval) {
                            Text("1 minute").tag(1.0)
                            Text("15 minutes").tag(15.0)
                            Text("1 hour").tag(60.0)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .onChange(of: client.refreshInterval) { _, _ in client.setupTimer() }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("MENU BAR STYLE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                        Picker("", selection: $client.displayType) {
                            ForEach(MenuBarDisplayType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
                .padding(16)
            }
            
            Divider()

            Button("Done") { isShowingSettings = false }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(12)
        }
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 8))
            Text(title).font(.system(size: 9, weight: .black))
        }
        .foregroundColor(.secondary.opacity(0.7))
    }
}

struct CustomProgressView: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.05)).frame(height: 4)
                Capsule()
                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(min(value, 1.0)), height: 4)
            }
        }
        .frame(height: 4)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
