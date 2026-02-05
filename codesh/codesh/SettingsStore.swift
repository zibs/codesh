import AppKit
import Foundation

final class SettingsStore {
    static let shared = SettingsStore()

    private let defaults: UserDefaults
    private let sessionPercentKey = "cachedSessionPercent"
    private let weeklyPercentKey = "cachedWeeklyPercent"
    private let sessionResetKey = "cachedSessionResetAt"
    private let weeklyResetKey = "cachedWeeklyResetAt"
    private let rateLimitsUpdatedAtKey = "cachedRateLimitsUpdatedAt"
    private let sessionLightColorKey = "sessionColorLight"
    private let sessionDarkColorKey = "sessionColorDark"
    private let weeklyLightColorKey = "weeklyColorLight"
    private let weeklyDarkColorKey = "weeklyColorDark"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    struct CachedRateLimits {
        let snapshot: RateLimitSnapshot
        let updatedAt: Date
    }

    enum ColorRole: CaseIterable {
        case sessionLight
        case sessionDark
        case weeklyLight
        case weeklyDark
    }

    static let defaultSessionLightColor = NSColor(srgbRed: 0.0, green: 0.62, blue: 0.28, alpha: 1.0)
    static let defaultSessionDarkColor = NSColor(srgbRed: 0.25, green: 1.0, blue: 0.55, alpha: 1.0)
    static let defaultWeeklyLightColor = NSColor(srgbRed: 0.05, green: 0.5, blue: 0.9, alpha: 1.0)
    static let defaultWeeklyDarkColor = NSColor(srgbRed: 0.35, green: 0.78, blue: 1.0, alpha: 1.0)

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

    func color(for role: ColorRole) -> NSColor? {
        loadColor(forKey: colorKey(for: role))
    }

    func resolvedColor(for role: ColorRole) -> NSColor {
        color(for: role) ?? defaultColor(for: role)
    }

    func setColor(_ color: NSColor?, for role: ColorRole) {
        storeColor(color, forKey: colorKey(for: role))
    }

    func resetColorsToDefaults() {
        for role in ColorRole.allCases {
            defaults.removeObject(forKey: colorKey(for: role))
        }
    }

    private func colorKey(for role: ColorRole) -> String {
        switch role {
        case .sessionLight:
            return sessionLightColorKey
        case .sessionDark:
            return sessionDarkColorKey
        case .weeklyLight:
            return weeklyLightColorKey
        case .weeklyDark:
            return weeklyDarkColorKey
        }
    }

    private func defaultColor(for role: ColorRole) -> NSColor {
        switch role {
        case .sessionLight:
            return SettingsStore.defaultSessionLightColor
        case .sessionDark:
            return SettingsStore.defaultSessionDarkColor
        case .weeklyLight:
            return SettingsStore.defaultWeeklyLightColor
        case .weeklyDark:
            return SettingsStore.defaultWeeklyDarkColor
        }
    }

    private struct StoredColor: Codable {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
    }

    private func loadColor(forKey key: String) -> NSColor? {
        guard let data = defaults.data(forKey: key),
              let stored = try? JSONDecoder().decode(StoredColor.self, from: data) else {
            return nil
        }
        return NSColor(srgbRed: stored.red, green: stored.green, blue: stored.blue, alpha: stored.alpha)
    }

    private func storeColor(_ color: NSColor?, forKey key: String) {
        guard let color else {
            defaults.removeObject(forKey: key)
            return
        }
        guard let rgb = color.usingColorSpace(.sRGB) else { return }
        let stored = StoredColor(
            red: Double(rgb.redComponent),
            green: Double(rgb.greenComponent),
            blue: Double(rgb.blueComponent),
            alpha: Double(rgb.alphaComponent)
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: key)
    }
}
