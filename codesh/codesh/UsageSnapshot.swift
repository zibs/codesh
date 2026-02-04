import Foundation

struct UsageSnapshot {
    let updatedAt: Date
    let last7DaysTokens: Int
    let last30DaysTokens: Int
    let todayTokens: Int
    let latestSessionTokens: Int
    let rateLimits: RateLimitSnapshot?

    static let empty = UsageSnapshot(
        updatedAt: Date(timeIntervalSince1970: 0),
        last7DaysTokens: 0,
        last30DaysTokens: 0,
        todayTokens: 0,
        latestSessionTokens: 0,
        rateLimits: nil
    )
}

struct RateLimitSnapshot {
    let sessionUsedPercent: Double?
    let weeklyUsedPercent: Double?
    let sessionResetsAt: Date?
    let weeklyResetsAt: Date?

    var hasAnyValue: Bool {
        sessionUsedPercent != nil || weeklyUsedPercent != nil || sessionResetsAt != nil || weeklyResetsAt != nil
    }
}
