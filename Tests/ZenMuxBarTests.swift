import XCTest
@testable import ZenMuxBar

final class ZenMuxBarTests: XCTestCase {
    @MainActor
    func testFailedRefreshClearsStaleAccountDataAndTimestamp() async {
        let loader = MockDataLoader.successful()
        let client = ZenMuxClient(
            dataLoader: loader,
            secretStore: InMemorySecretStore(),
            autoFetch: false
        )
        client.apiKey = "test-token"

        await client.fetchData()
        XCTAssertNotNil(client.subscriptionDetail)
        XCTAssertNotNil(client.paygBalance)
        XCTAssertNotNil(client.flowRate)
        XCTAssertNotNil(client.lastUpdated)

        loader.results = MockDataLoader.failingResults()
        await client.fetchData()

        XCTAssertNil(client.subscriptionDetail)
        XCTAssertNil(client.paygBalance)
        XCTAssertNil(client.flowRate)
        XCTAssertNil(client.lastUpdated)
        XCTAssertEqual(client.errorMessage, URLError(.notConnectedToInternet).localizedDescription)
    }

    @MainActor
    func testClearingAPIKeyClearsAccountData() async {
        let client = ZenMuxClient(
            dataLoader: MockDataLoader.successful(),
            secretStore: InMemorySecretStore(),
            autoFetch: false
        )
        client.apiKey = "test-token"

        await client.fetchData()
        XCTAssertNotNil(client.paygBalance)

        client.apiKey = ""

        XCTAssertNil(client.subscriptionDetail)
        XCTAssertNil(client.paygBalance)
        XCTAssertNil(client.flowRate)
        XCTAssertNil(client.lastUpdated)
        XCTAssertEqual(client.errorMessage, ZenMuxError.noApiKey.localizedDescription)
    }

    @MainActor
    func testChangingAPIKeyClearsAccountData() async {
        let client = ZenMuxClient(
            dataLoader: MockDataLoader.successful(),
            secretStore: InMemorySecretStore(),
            autoFetch: false
        )
        client.apiKey = "first-token"

        await client.fetchData()
        XCTAssertNotNil(client.subscriptionDetail)

        client.apiKey = "second-token"

        XCTAssertNil(client.subscriptionDetail)
        XCTAssertNil(client.paygBalance)
        XCTAssertNil(client.flowRate)
        XCTAssertNil(client.lastUpdated)
        XCTAssertNil(client.errorMessage)
    }

    @MainActor
    func testPartialRefreshFailureClearsOnlyFailedSection() async {
        let loader = MockDataLoader.successful()
        let client = ZenMuxClient(
            dataLoader: loader,
            secretStore: InMemorySecretStore(),
            autoFetch: false
        )
        client.apiKey = "test-token"

        await client.fetchData()
        XCTAssertNotNil(client.subscriptionDetail)

        loader.results["/subscription/detail"] = .failure(URLError(.timedOut))
        await client.fetchData()

        XCTAssertNil(client.subscriptionDetail)
        XCTAssertNotNil(client.paygBalance)
        XCTAssertNotNil(client.flowRate)
        XCTAssertNotNil(client.lastUpdated)
        XCTAssertNil(client.errorMessage)
    }

    func testISO8601ParsingAcceptsFractionalAndWholeSecondTimestamps() {
        XCTAssertNotNil(ZenMuxDateFormatting.parseISO8601("2026-04-17T10:30:00.123Z"))
        XCTAssertNotNil(ZenMuxDateFormatting.parseISO8601("2026-04-17T10:30:00Z"))
        XCTAssertNil(ZenMuxDateFormatting.parseISO8601("not-a-date"))
        XCTAssertEqual(ZenMuxDateFormatting.shortResetTime(nil), "-")
    }
}

private final class MockDataLoader: ZenMuxDataLoading {
    var results: [String: Result<Data, Error>]

    init(results: [String: Result<Data, Error>]) {
        self.results = results
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let path = request.url?.path.replacingOccurrences(of: "/api/v1/management", with: "") ?? ""
        let result = results[path] ?? .failure(URLError(.badURL))
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://zenmux.ai")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        switch result {
        case .success(let data):
            return (data, response)
        case .failure(let error):
            throw error
        }
    }

    static func successful() -> MockDataLoader {
        MockDataLoader(results: [
            "/subscription/detail": .success(subscriptionData),
            "/payg/balance": .success(paygBalanceData),
            "/flow_rate": .success(flowRateData)
        ])
    }

    static func failingResults() -> [String: Result<Data, Error>] {
        [
            "/subscription/detail": .failure(URLError(.notConnectedToInternet)),
            "/payg/balance": .failure(URLError(.notConnectedToInternet)),
            "/flow_rate": .failure(URLError(.notConnectedToInternet))
        ]
    }

    private static let subscriptionData = Data("""
    {
      "success": true,
      "data": {
        "plan": {
          "tier": "pro",
          "amount_usd": 20,
          "interval": "month",
          "expires_at": "2026-04-17T10:30:00Z"
        },
        "currency": "USD",
        "base_usd_per_flow": 0.01,
        "effective_usd_per_flow": 0.008,
        "account_status": "active",
        "quota_5_hour": {
          "usage_percentage": 0.25,
          "resets_at": "2026-04-17T10:30:00Z",
          "max_flows": 100,
          "used_flows": 25,
          "remaining_flows": 75,
          "used_value_usd": 0.25,
          "max_value_usd": 1
        },
        "quota_7_day": null,
        "quota_monthly": {
          "max_flows": 1000,
          "max_value_usd": 10
        }
      }
    }
    """.utf8)

    private static let paygBalanceData = Data("""
    {
      "success": true,
      "data": {
        "currency": "USD",
        "total_credits": 12.34,
        "top_up_credits": 10,
        "bonus_credits": 2.34
      }
    }
    """.utf8)

    private static let flowRateData = Data("""
    {
      "success": true,
      "data": {
        "currency": "USD",
        "base_usd_per_flow": 0.01,
        "effective_usd_per_flow": 0.008
      }
    }
    """.utf8)
}

private final class InMemorySecretStore: ZenMuxSecretStore {
    private var storedAPIKey = ""

    func apiKey() -> String {
        storedAPIKey
    }

    func setAPIKey(_ apiKey: String) {
        storedAPIKey = apiKey
    }
}
