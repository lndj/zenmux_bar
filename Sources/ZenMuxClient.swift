import Foundation
import SwiftUI
import Combine

enum MenuBarDisplayType: String, CaseIterable {
    case balance = "Balance"
    case subscription = "Subscription"
    case iconOnly = "Icon Only"
}

enum ZenMuxError: Error {
    case invalidURL
    case noApiKey
    case requestFailed(Int)
    case decodingError(Error)
}

@MainActor
class ZenMuxClient: ObservableObject {
    @Published var subscriptionDetail: SubscriptionDetail?
    @Published var paygBalance: PayGBalance?
    @Published var flowRate: FlowRate?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    // Settings (Persisted via UserDefaults)
    @AppStorage("ZENMUX_API_KEY") var apiKey: String = ""
    @AppStorage("ZENMUX_REFRESH_INTERVAL") var refreshInterval: Double = 15 // minutes
    @AppStorage("ZENMUX_DISPLAY_TYPE") var displayType: MenuBarDisplayType = .balance
    
    private var timer: AnyCancellable?
    private let baseURL = "https://zenmux.ai/api/v1/management"

    init() {
        setupTimer()
        Task {
            await fetchData()
        }
    }

    func setupTimer() {
        timer?.cancel()
        guard refreshInterval > 0 else { return }
        
        timer = Timer.publish(every: refreshInterval * 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.fetchData()
                }
            }
    }

    func fetchData() async {
        guard !apiKey.isEmpty else {
            self.errorMessage = "API Key not set"
            return
        }

        self.isLoading = true
        self.errorMessage = nil

        do {
            async let sub = fetchSubscription()
            async let balance = fetchPayGBalance()
            async let flow = fetchFlowRate()

            let (s, b, f) = try await (sub, balance, flow)

            self.subscriptionDetail = s
            self.paygBalance = b
            self.flowRate = f
            self.lastUpdated = Date()
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    private func fetchSubscription() async throws -> SubscriptionDetail {
        return try await performRequest(endpoint: "/subscription/detail")
    }

    private func fetchPayGBalance() async throws -> PayGBalance {
        return try await performRequest(endpoint: "/payg/balance")
    }

    private func fetchFlowRate() async throws -> FlowRate {
        return try await performRequest(endpoint: "/flow_rate")
    }

    private func performRequest<T: Codable>(endpoint: String) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else { throw ZenMuxError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw ZenMuxError.requestFailed(0) }
        guard (200...299).contains(httpResponse.statusCode) else { throw ZenMuxError.requestFailed(httpResponse.statusCode) }
        
        do {
            let result = try JSONDecoder().decode(ZenMuxResponse<T>.self, from: data)
            return result.data
        } catch {
            throw ZenMuxError.decodingError(error)
        }
    }
}
