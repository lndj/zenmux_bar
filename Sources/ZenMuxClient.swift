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
    case apiError(String)
    case decodingError(Error)
    case missingData(String)
}

extension ZenMuxError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Request URL is invalid."
        case .noApiKey:
            return "API Key not set."
        case .requestFailed(let statusCode):
            return "Request failed with status code \(statusCode)."
        case .apiError(let message):
            return message
        case .decodingError(let error):
            return "Failed to parse server response: \(error.localizedDescription)"
        case .missingData(let endpoint):
            return "Response from \(endpoint) does not contain expected data."
        }
    }
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
            self.errorMessage = ZenMuxError.noApiKey.localizedDescription
            return
        }

        self.isLoading = true
        self.errorMessage = nil

        var lastError: Error?

        do {
            self.subscriptionDetail = try await fetchSubscription()
        } catch {
            lastError = error
        }

        do {
            self.paygBalance = try await fetchPayGBalance()
        } catch {
            lastError = error
        }

        do {
            self.flowRate = try await fetchFlowRate()
        } catch {
            lastError = error
        }

        self.lastUpdated = Date()
        self.isLoading = false

        if self.subscriptionDetail == nil && self.paygBalance == nil && self.flowRate == nil {
            self.errorMessage = lastError?.localizedDescription
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
            if result.success == false {
                let message = result.message ?? "Server returned an error for \(endpoint)."
                throw ZenMuxError.apiError(message)
            }
            guard let payload = result.data else {
                throw ZenMuxError.missingData(endpoint)
            }
            return payload
        } catch {
            if let zenMuxError = error as? ZenMuxError {
                throw zenMuxError
            }

            if let apiError = try? JSONDecoder().decode(ZenMuxAPIErrorResponse.self, from: data) {
                let message = apiError.message ?? apiError.error
                if let message, !message.isEmpty {
                    throw ZenMuxError.apiError(message)
                }
            }

            let bodyPreview = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(220) ?? ""
            let detail = NSError(
                domain: "ZenMux.Decoding",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Endpoint: \(endpoint), Body: \(bodyPreview)"]
            )
            throw ZenMuxError.decodingError(detail)
        }
    }
}
