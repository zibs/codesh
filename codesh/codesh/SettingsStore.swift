import Foundation

final class SettingsStore {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard
    private let sessionPercentKey = "cachedSessionPercent"
    private let weeklyPercentKey = "cachedWeeklyPercent"
    private let sessionResetKey = "cachedSessionResetAt"
    private let weeklyResetKey = "cachedWeeklyResetAt"
    private let rateLimitsUpdatedAtKey = "cachedRateLimitsUpdatedAt"

    struct CachedRateLimits {
        let snapshot: RateLimitSnapshot
        let updatedAt: Date
    }

    func loadCachedRateLimits() -> CachedRateLimits? {
        let sessionPercent = defaults.object(forKey: sessionPercentKey) as? Double
        let weeklyPercent = defaults.object(forKey: weeklyPercentKey) as? Double
        let sessionReset = defaults.object(forKey: sessionResetKey) as? Date
        let weeklyReset = defaults.object(forKey: weeklyResetKey) as? Date
        let updatedAt = defaults.object(forKey: rateLimitsUpdatedAtKey) as? Date

        if sessionPercent == nil, weeklyPercent == nil, sessionReset == nil, weeklyReset == nil {
            return nil
        }

        let snapshot = RateLimitSnapshot(
            sessionUsedPercent: sessionPercent,
            weeklyUsedPercent: weeklyPercent,
            sessionResetsAt: sessionReset,
            weeklyResetsAt: weeklyReset
        )

        return CachedRateLimits(snapshot: snapshot, updatedAt: updatedAt ?? Date(timeIntervalSince1970: 0))
    }

    func storeRateLimits(_ snapshot: RateLimitSnapshot, updatedAt: Date) {
        if let value = snapshot.sessionUsedPercent {
            defaults.set(value, forKey: sessionPercentKey)
        } else {
            defaults.removeObject(forKey: sessionPercentKey)
        }

        if let value = snapshot.weeklyUsedPercent {
            defaults.set(value, forKey: weeklyPercentKey)
        } else {
            defaults.removeObject(forKey: weeklyPercentKey)
        }

        if let value = snapshot.sessionResetsAt {
            defaults.set(value, forKey: sessionResetKey)
        } else {
            defaults.removeObject(forKey: sessionResetKey)
        }

        if let value = snapshot.weeklyResetsAt {
            defaults.set(value, forKey: weeklyResetKey)
        } else {
            defaults.removeObject(forKey: weeklyResetKey)
        }

        defaults.set(updatedAt, forKey: rateLimitsUpdatedAtKey)
    }
}
