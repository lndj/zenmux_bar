import SwiftUI
import AppKit

struct DashboardView: View {
    @ObservedObject var client: ZenMuxClient
    @State private var isShowingSettings = false

    var body: some View {
        ZStack {
            if isShowingSettings {
                SettingsView(client: client, isShowingSettings: $isShowingSettings)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            } else {
                MainDashboardContent(client: client, isShowingSettings: $isShowingSettings)
                    .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isShowingSettings)
        .frame(width: 300, height: 380)
        .background(VisualEffectView(material: .menu, blendingMode: .behindWindow))
        .onAppear {
            Task {
                await client.fetchData()
            }
        }
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
                            .font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { isShowingSettings = true }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 15)

            Divider().opacity(0.1)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if let sub = client.subscriptionDetail {
                        // Compact Plan Card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(sub.plan.tier.uppercased())
                                    .font(.system(size: 9, weight: .black))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                                
                                Spacer()
                                
                                Text("$\(Int(sub.plan.amountUsd))/\(sub.plan.interval)")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 10))
                                Text("Expires: \(ZenMuxDateFormatting.displayDate(sub.plan.expiresAt))")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                        }
                        .padding(14)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.06), lineWidth: 1))

                        // Quotas Section
                        VStack(spacing: 12) {
                            SectionHeader(title: "QUOTAS", icon: "chart.bar.fill")
                            if let quota5Hour = sub.quota5Hour {
                                QuotaRow(title: "5 Hour", quota: quota5Hour)
                            }
                            if let quota7Day = sub.quota7Day {
                                QuotaRow(title: "7 Day", quota: quota7Day)
                            }
                        }
                        .padding(14)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(12)
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
                        .padding(14)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(12)
                        
                        // Rate
                        VStack(alignment: .leading, spacing: 4) {
                            SectionHeader(title: "RATE", icon: "bolt.fill")
                            if let flow = flowRateValue {
                                Text("$\(String(format: "%.4f", flow))")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(12)
                    }
                }
                .padding(16)
            }
            
            if let error = client.errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.red.opacity(0.8))
                .padding(.bottom, 12)
            }
        }
    }
    
    private var flowRateValue: Double? {
        client.flowRate?.effectiveUsdPerFlow
    }
    
}

struct SettingsView: View {
    @ObservedObject var client: ZenMuxClient
    @Binding var isShowingSettings: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { isShowingSettings = false }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                Text("Settings")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                
                // Balance space
                Color.clear.frame(width: 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 15)
            
            Divider().opacity(0.1)

            VStack(spacing: 24) {
                // API Key Group
                SettingsGroup(title: "AUTHENTICATION", icon: "key.fill") {
                    VStack(alignment: .leading, spacing: 8) {
                        SecureField("Management API Key", text: $client.apiKey)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(6)
                        
                        Text("Obtain this key from your ZenMux dashboard.")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Preferences Group
                SettingsGroup(title: "PREFERENCES", icon: "gearshape.2.fill") {
                    VStack(spacing: 12) {
                        SettingsRow(label: "Refresh Every", icon: "timer") {
                            Picker("", selection: $client.refreshInterval) {
                                Text("1m").tag(1.0)
                                Text("5m").tag(5.0)
                                Text("15m").tag(15.0)
                                Text("30m").tag(30.0)
                                Text("1h").tag(60.0)
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 70)
                            .onChange(of: client.refreshInterval) { _, _ in client.setupTimer() }
                        }
                        
                        SettingsRow(label: "Status Label", icon: "dock.rectangle") {
                            Picker("", selection: $client.displayType) {
                                ForEach(MenuBarDisplayType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 100)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: { isShowingSettings = false }) {
                    Text("Done")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(EscapeKeyHandler { isShowingSettings = false })
        .onExitCommand { isShowingSettings = false }
    }
}

// MARK: - Settings Components
struct SettingsGroup<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 10, weight: .black))
            }
            .foregroundColor(.secondary.opacity(0.8))
            
            content
        }
    }
}

struct SettingsRow<Content: View>: View {
    let label: String
    let icon: String
    let content: Content
    
    init(label: String, icon: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.blue.opacity(0.8))
                .frame(width: 16)
            Text(label)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            content
        }
    }
}

// MARK: - Original Helper Views
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
                Text("Reset: \(ZenMuxDateFormatting.shortResetTime(quota.resetsAt))").font(.system(size: 8))
            }
            .foregroundColor(.secondary.opacity(0.8))
        }
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

struct EscapeKeyHandler: NSViewRepresentable {
    let onEscape: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onEscape: onEscape)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.onEscape = onEscape
        context.coordinator.start()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onEscape = onEscape
        context.coordinator.start()
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var onEscape: () -> Void
        private var monitor: Any?

        init(onEscape: @escaping () -> Void) {
            self.onEscape = onEscape
        }

        func start() {
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == 53 else { return event }
                self?.onEscape()
                return nil
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            stop()
        }
    }
}
