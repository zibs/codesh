import Foundation

final class UsageScanner {
    private let fileManager: FileManager
    private let sessionsRootOverride: URL?

    init(fileManager: FileManager = .default, sessionsRootOverride: URL? = nil) {
        self.fileManager = fileManager
        self.sessionsRootOverride = sessionsRootOverride
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatterNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    func scanRateLimitsOnly() -> RateLimitSnapshot? {
        let sessionsRoot = sessionsRootOverride ?? resolveSessionsRoot()
        return scanLatestRateLimits(sessionsRoot: sessionsRoot)?.snapshot
    }

    private func resolveSessionsRoot() -> URL {
        let env = ProcessInfo.processInfo.environment["CODEX_HOME"] ?? ""
        let codexHome: URL
        if !env.isEmpty {
            codexHome = URL(fileURLWithPath: env)
        } else {
            codexHome = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        }
        return codexHome.appendingPathComponent("sessions")
    }

    private func scanLatestRateLimits(sessionsRoot: URL) -> (timestamp: TimeInterval, snapshot: RateLimitSnapshot)? {
        guard let enumerator = fileManager.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var latestFile: URL?
        var latestDate: Date?

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl" else { continue }
            let date = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if latestDate == nil || (date ?? .distantPast) > latestDate! {
                latestDate = date
                latestFile = fileURL
            }
        }

        guard let fileURL = latestFile else { return nil }
        return scanRateLimitsInFile(fileURL, fallbackDate: latestDate)
    }

    private func scanRateLimitsInFile(
        _ url: URL,
        fallbackDate: Date?
    ) -> (timestamp: TimeInterval, snapshot: RateLimitSnapshot)? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        var latest: (timestamp: TimeInterval, snapshot: RateLimitSnapshot)?

        for line in content.split(separator: "\n") {
            guard let data = String(line).data(using: .utf8) else { continue }
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            guard let payload = object["payload"] as? [String: Any] else { continue }

            let timestampMs = readTimestampMs(object["timestamp"]) ?? readTimestampMs(payload["timestamp"])
            let rateLimitsMap = (payload["rate_limits"] as? [String: Any])
                ?? (payload["rateLimits"] as? [String: Any])
                ?? (object["rate_limits"] as? [String: Any])
                ?? (object["rateLimits"] as? [String: Any])

            guard let rateLimits = rateLimitsMap,
                  let snapshot = parseRateLimits(rateLimits) else { continue }

            if let timestampMs {
                if latest == nil || timestampMs > latest!.timestamp {
                    latest = (timestampMs, snapshot)
                }
            } else if latest == nil, let fallbackDate {
                latest = (fallbackDate.timeIntervalSince1970 * 1000.0, snapshot)
            }
        }

        return latest
    }

    private func doubleValue(_ map: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let number = map[key] as? NSNumber {
                return number.doubleValue
            }
            if let string = map[key] as? String, let value = Double(string) {
                return value
            }
        }
        return nil
    }

    private func readTimestampMs(_ value: Any?) -> TimeInterval? {
        if let text = value as? String {
            if let date = UsageScanner.isoFormatter.date(from: text) ?? UsageScanner.isoFormatterNoFraction.date(from: text) {
                return date.timeIntervalSince1970 * 1000.0
            }
            return nil
        }
        if let number = value as? NSNumber {
            var numeric = number.doubleValue
            if numeric > 0 && numeric < 1_000_000_000_000 {
                numeric *= 1000.0
            }
            return numeric > 0 ? numeric : nil
        }
        return nil
    }

    private func parseRateLimits(_ rateLimits: [String: Any]) -> RateLimitSnapshot? {
        let primary = rateLimits["primary"] as? [String: Any]
        let secondary = rateLimits["secondary"] as? [String: Any]

        let sessionPercent = primary.flatMap { doubleValue($0, keys: ["used_percent", "usedPercent"]) }
        let weeklyPercent = secondary.flatMap { doubleValue($0, keys: ["used_percent", "usedPercent"]) }

        let sessionReset = primary.flatMap { dateValue($0, keys: ["resets_at", "resetsAt"]) }
        let weeklyReset = secondary.flatMap { dateValue($0, keys: ["resets_at", "resetsAt"]) }

        if sessionPercent == nil && weeklyPercent == nil && sessionReset == nil && weeklyReset == nil {
            return nil
        }

        return RateLimitSnapshot(
            sessionUsedPercent: sessionPercent,
            weeklyUsedPercent: weeklyPercent,
            sessionResetsAt: sessionReset,
            weeklyResetsAt: weeklyReset
        )
    }

    private func dateValue(_ map: [String: Any], keys: [String]) -> Date? {
        for key in keys {
            if let number = map[key] as? NSNumber {
                var numeric = number.doubleValue
                if numeric > 0 && numeric < 1_000_000_000_000 {
                    numeric *= 1000.0
                }
                if numeric > 0 {
                    return Date(timeIntervalSince1970: numeric / 1000.0)
                }
            }
            if let string = map[key] as? String, let value = Double(string) {
                var numeric = value
                if numeric > 0 && numeric < 1_000_000_000_000 {
                    numeric *= 1000.0
                }
                if numeric > 0 {
                    return Date(timeIntervalSince1970: numeric / 1000.0)
                }
            }
        }
        return nil
    }
}
