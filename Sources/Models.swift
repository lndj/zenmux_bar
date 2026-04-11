import Foundation

struct ZenMuxResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
}

// MARK: - Subscription
struct SubscriptionDetail: Codable {
    let plan: Plan
    let currency: String
    let baseUsdPerFlow: Double
    let effectiveUsdPerFlow: Double
    let accountStatus: String
    let quota5Hour: Quota
    let quota7Day: Quota
    let quotaMonthly: QuotaMonthly

    enum CodingKeys: String, CodingKey {
        case plan, currency
        case baseUsdPerFlow = "base_usd_per_flow"
        case effectiveUsdPerFlow = "effective_usd_per_flow"
        case accountStatus = "account_status"
        case quota5Hour = "quota_5_hour"
        case quota7Day = "quota_7_day"
        case quotaMonthly = "quota_monthly"
    }
}

struct Plan: Codable {
    let tier: String
    let amountUsd: Double
    let interval: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case tier
        case amountUsd = "amount_usd"
        case interval
        case expiresAt = "expires_at"
    }
}

struct Quota: Codable {
    let usagePercentage: Double
    let resetsAt: String
    let maxFlows: Double
    let usedFlows: Double
    let remainingFlows: Double
    let usedValueUsd: Double
    let maxValueUsd: Double

    enum CodingKeys: String, CodingKey {
        case usagePercentage = "usage_percentage"
        case resetsAt = "resets_at"
        case maxFlows = "max_flows"
        case usedFlows = "used_flows"
        case remainingFlows = "remaining_flows"
        case usedValueUsd = "used_value_usd"
        case maxValueUsd = "max_value_usd"
    }
}

struct QuotaMonthly: Codable {
    let maxFlows: Double
    let maxValueUsd: Double

    enum CodingKeys: String, CodingKey {
        case maxFlows = "max_flows"
        case maxValueUsd = "max_value_usd"
    }
}

// MARK: - PAYG Balance
struct PayGBalance: Codable {
    let currency: String
    let totalCredits: Double
    let topUpCredits: Double
    let bonusCredits: Double

    enum CodingKeys: String, CodingKey {
        case currency
        case totalCredits = "total_credits"
        case topUpCredits = "top_up_credits"
        case bonusCredits = "bonus_credits"
    }
}

// MARK: - Flow Rate
struct FlowRate: Codable {
    let currency: String
    let baseUsdPerFlow: Double
    let effectiveUsdPerFlow: Double

    enum CodingKeys: String, CodingKey {
        case currency
        case baseUsdPerFlow = "base_usd_per_flow"
        case effectiveUsdPerFlow = "effective_usd_per_flow"
    }
}
