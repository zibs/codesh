import Foundation

struct UsageSnapshot {
    let updatedAt: Date
    let rateLimits: RateLimitSnapshot?

    static let empty = UsageSnapshot(
        updatedAt: Date(timeIntervalSince1970: 0),
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
