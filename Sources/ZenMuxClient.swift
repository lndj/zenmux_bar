import Foundation
import SwiftUI
import Combine
import Security

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

protocol ZenMuxDataLoading {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: ZenMuxDataLoading {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
}

protocol ZenMuxSecretStore {
    func apiKey() -> String
    func setAPIKey(_ apiKey: String)
}

final class KeychainZenMuxSecretStore: ZenMuxSecretStore {
    private let service = "life.workfun.ZenMuxBar"
    private let account = "ZENMUX_API_KEY"

    func apiKey() -> String {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return ""
        }
        return value
    }

    func setAPIKey(_ apiKey: String) {
        guard !apiKey.isEmpty else {
            SecItemDelete(baseQuery() as CFDictionary)
            return
        }

        let data = Data(apiKey.utf8)
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary)
        guard status == errSecItemNotFound else { return }

        var item = baseQuery()
        item[kSecValueData as String] = data
        SecItemAdd(item as CFDictionary, nil)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum ZenMuxDateFormatting {
    static func displayDate(_ dateString: String) -> String {
        guard let date = parseISO8601(dateString) else { return dateString }
        return date.formatted(.dateTime.year().month().day())
    }

    static func shortResetTime(_ dateString: String?) -> String {
        guard let dateString, !dateString.isEmpty else { return "-" }
        guard let date = parseISO8601(dateString) else { return dateString }
        return date.formatted(.dateTime.month().day().hour().minute())
    }

    static func parseISO8601(_ dateString: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: dateString) {
            return date
        }

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: dateString)
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
    @Published var apiKey: String {
        didSet {
            guard oldValue != apiKey else { return }
            secretStore.setAPIKey(apiKey)
            clearAccountData()
            if apiKey.isEmpty {
                errorMessage = ZenMuxError.noApiKey.localizedDescription
            } else {
                errorMessage = nil
            }
        }
    }

    // Settings (Persisted via UserDefaults)
    @AppStorage("ZENMUX_REFRESH_INTERVAL") var refreshInterval: Double = 15 // minutes
    @AppStorage("ZENMUX_DISPLAY_TYPE") var displayType: MenuBarDisplayType = .balance
    
    private var timer: AnyCancellable?
    private let baseURL = "https://zenmux.ai/api/v1/management"
    private let dataLoader: ZenMuxDataLoading
    private let secretStore: ZenMuxSecretStore

    init(
        dataLoader: ZenMuxDataLoading = URLSession.shared,
        secretStore: ZenMuxSecretStore? = nil,
        autoFetch: Bool = true
    ) {
        let resolvedSecretStore = secretStore ?? KeychainZenMuxSecretStore()
        self.dataLoader = dataLoader
        self.secretStore = resolvedSecretStore
        self.apiKey = resolvedSecretStore.apiKey()
        setupTimer()
        if autoFetch {
            Task {
                await fetchData()
            }
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
        let requestAPIKey = apiKey
        guard !requestAPIKey.isEmpty else {
            clearAccountData()
            self.errorMessage = ZenMuxError.noApiKey.localizedDescription
            self.isLoading = false
            return
        }

        self.isLoading = true
        self.errorMessage = nil

        var lastError: Error?
        var hasSuccessfulFetch = false

        do {
            let value = try await fetchSubscription(apiKey: requestAPIKey)
            guard apiKey == requestAPIKey else {
                self.isLoading = false
                return
            }
            self.subscriptionDetail = value
            hasSuccessfulFetch = true
        } catch {
            guard apiKey == requestAPIKey else {
                self.isLoading = false
                return
            }
            self.subscriptionDetail = nil
            lastError = error
        }

        do {
            let value = try await fetchPayGBalance(apiKey: requestAPIKey)
            guard apiKey == requestAPIKey else {
                self.isLoading = false
                return
            }
            self.paygBalance = value
            hasSuccessfulFetch = true
        } catch {
            guard apiKey == requestAPIKey else {
                self.isLoading = false
                return
            }
            self.paygBalance = nil
            lastError = error
        }

        do {
            let value = try await fetchFlowRate(apiKey: requestAPIKey)
            guard apiKey == requestAPIKey else {
                self.isLoading = false
                return
            }
            self.flowRate = value
            hasSuccessfulFetch = true
        } catch {
            guard apiKey == requestAPIKey else {
                self.isLoading = false
                return
            }
            self.flowRate = nil
            lastError = error
        }

        self.lastUpdated = hasSuccessfulFetch ? Date() : nil
        self.isLoading = false

        if !hasSuccessfulFetch {
            self.errorMessage = lastError?.localizedDescription
        }
    }

    private func clearAccountData() {
        subscriptionDetail = nil
        paygBalance = nil
        flowRate = nil
        lastUpdated = nil
    }

    private func fetchSubscription(apiKey: String) async throws -> SubscriptionDetail {
        return try await performRequest(endpoint: "/subscription/detail", apiKey: apiKey)
    }

    private func fetchPayGBalance(apiKey: String) async throws -> PayGBalance {
        return try await performRequest(endpoint: "/payg/balance", apiKey: apiKey)
    }

    private func fetchFlowRate(apiKey: String) async throws -> FlowRate {
        return try await performRequest(endpoint: "/flow_rate", apiKey: apiKey)
    }

    private func performRequest<T: Codable>(endpoint: String, apiKey: String) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else { throw ZenMuxError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await dataLoader.data(for: request)
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
