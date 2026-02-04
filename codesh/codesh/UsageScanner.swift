import Foundation

final class UsageScanner {
    private let fileManager = FileManager.default
    private let calendar = Calendar.current

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

    func scan(days: Int) -> UsageSnapshot {
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let dayKeys = makeDayKeys(days: days, todayStart: todayStart)

        var dailyTotals: [String: Int] = [:]
        dayKeys.forEach { dailyTotals[$0] = 0 }

        var latestSessionTokens = 0
        var latestSessionDate: Date?
        var latestRateLimits: (timestamp: TimeInterval, snapshot: RateLimitSnapshot)?

        let sessionsRoot = resolveSessionsRoot()

        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            let dayURL = dayDirectoryURL(for: day, sessionsRoot: sessionsRoot)

            guard let files = jsonlFiles(in: dayURL) else { continue }

            for fileURL in files {
                let fileTokens = scanFile(
                    fileURL,
                    dailyTotals: &dailyTotals,
                    latestRateLimits: &latestRateLimits
                )

                if let modDate = fileModificationDate(fileURL) {
                    if latestSessionDate == nil || modDate > latestSessionDate! {
                        latestSessionDate = modDate
                        latestSessionTokens = fileTokens
                    }
                }
            }
        }

        let last7DaysTokens = sumTokens(in: Array(dayKeys.prefix(7)), dailyTotals: dailyTotals)
        let last30DaysTokens = sumTokens(in: dayKeys, dailyTotals: dailyTotals)
        let todayTokens = dailyTotals[dayKeys.first ?? ""] ?? 0

        let resolvedRateLimits = latestRateLimits?.snapshot ?? scanLatestRateLimits(sessionsRoot: sessionsRoot)?.snapshot

        return UsageSnapshot(
            updatedAt: now,
            last7DaysTokens: last7DaysTokens,
            last30DaysTokens: last30DaysTokens,
            todayTokens: todayTokens,
            latestSessionTokens: latestSessionTokens,
            rateLimits: resolvedRateLimits
        )
    }

    func scanRateLimitsOnly() -> RateLimitSnapshot? {
        let sessionsRoot = resolveSessionsRoot()
        return scanLatestRateLimits(sessionsRoot: sessionsRoot)?.snapshot
    }

    private struct UsageTotals {
        var input: Int
        var cached: Int
        var output: Int
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

    private func makeDayKeys(days: Int, todayStart: Date) -> [String] {
        var keys: [String] = []
        keys.reserveCapacity(days)
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            keys.append(dayKey(for: day))
        }
        return keys
    }

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = String(format: "%04d", components.year ?? 0)
        let month = String(format: "%02d", components.month ?? 0)
        let day = String(format: "%02d", components.day ?? 0)
        return "\(year)-\(month)-\(day)"
    }

    private func dayDirectoryURL(for date: Date, sessionsRoot: URL) -> URL {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = String(format: "%04d", components.year ?? 0)
        let month = String(format: "%02d", components.month ?? 0)
        let day = String(format: "%02d", components.day ?? 0)
        return sessionsRoot
            .appendingPathComponent(year)
            .appendingPathComponent(month)
            .appendingPathComponent(day)
    }

    private func jsonlFiles(in folderURL: URL) -> [URL]? {
        let fileURLs = (try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)) ?? []
        let jsonlFiles = fileURLs.filter { $0.pathExtension == "jsonl" }
        return jsonlFiles.isEmpty ? nil : jsonlFiles
    }

    private func scanFile(
        _ url: URL,
        dailyTotals: inout [String: Int],
        latestRateLimits: inout (timestamp: TimeInterval, snapshot: RateLimitSnapshot)?
    ) -> Int {
        guard let content = try? String(contentsOf: url) else { return 0 }

        var fileTokens = 0
        var previousTotals: UsageTotals?

        for line in content.split(separator: "\n") {
            guard let data = String(line).data(using: .utf8) else { continue }
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            guard let payload = object["payload"] as? [String: Any] else { continue }

            let timestampMs = readTimestampMs(object["timestamp"]) ?? readTimestampMs(payload["timestamp"])

            let rateLimitsMap = (payload["rate_limits"] as? [String: Any]) ?? (payload["rateLimits"] as? [String: Any]) ?? (object["rate_limits"] as? [String: Any]) ?? (object["rateLimits"] as? [String: Any])

            if let rateLimits = rateLimitsMap,
               let snapshot = parseRateLimits(rateLimits),
               let timestampMs {
                if latestRateLimits == nil || timestampMs > latestRateLimits!.timestamp {
                    latestRateLimits = (timestampMs, snapshot)
                }
            } else if let rateLimits = rateLimitsMap,
                      let snapshot = parseRateLimits(rateLimits),
                      latestRateLimits == nil {
                latestRateLimits = (0, snapshot)
            }

            guard let payloadType = payload["type"] as? String, payloadType == "token_count" else { continue }
            guard let info = payload["info"] as? [String: Any] else { continue }
            guard let usage = extractUsage(info: info) else { continue }

            let (input, cached, output, isTotal) = usage
            var delta = UsageTotals(input: input, cached: cached, output: output)

            if isTotal {
                let prev = previousTotals ?? UsageTotals(input: 0, cached: 0, output: 0)
                delta = UsageTotals(
                    input: max(input - prev.input, 0),
                    cached: max(cached - prev.cached, 0),
                    output: max(output - prev.output, 0)
                )
                previousTotals = UsageTotals(input: input, cached: cached, output: output)
            } else {
                var next = previousTotals ?? UsageTotals(input: 0, cached: 0, output: 0)
                next.input += delta.input
                next.cached += delta.cached
                next.output += delta.output
                previousTotals = next
            }

            if delta.input == 0 && delta.cached == 0 && delta.output == 0 {
                continue
            }

            let tokenDelta = max(0, delta.input) + max(0, delta.output)
            fileTokens += tokenDelta

            if let timestampMs,
               let dayKey = dayKey(forTimestampMs: timestampMs),
               dailyTotals[dayKey] != nil {
                dailyTotals[dayKey, default: 0] += tokenDelta
            }
        }

        return fileTokens
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
        guard let content = try? String(contentsOf: url) else { return nil }

        var latest: (timestamp: TimeInterval, snapshot: RateLimitSnapshot)?

        for line in content.split(separator: "\n") {
            guard let data = String(line).data(using: .utf8) else { continue }
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            guard let payload = object["payload"] as? [String: Any] else { continue }

            let timestampMs = readTimestampMs(object["timestamp"]) ?? readTimestampMs(payload["timestamp"])
            let rateLimitsMap = (payload["rate_limits"] as? [String: Any]) ?? (payload["rateLimits"] as? [String: Any]) ?? (object["rate_limits"] as? [String: Any]) ?? (object["rateLimits"] as? [String: Any])

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

    private func extractUsage(info: [String: Any]) -> (Int, Int, Int, Bool)? {
        if let total = usageMap(info: info, keys: ["total_token_usage", "totalTokenUsage"]) {
            return (
                intValue(total, keys: ["input_tokens", "inputTokens"]),
                intValue(total, keys: ["cached_input_tokens", "cache_read_input_tokens", "cachedInputTokens", "cacheReadInputTokens"]),
                intValue(total, keys: ["output_tokens", "outputTokens"]),
                true
            )
        }
        if let last = usageMap(info: info, keys: ["last_token_usage", "lastTokenUsage"]) {
            return (
                intValue(last, keys: ["input_tokens", "inputTokens"]),
                intValue(last, keys: ["cached_input_tokens", "cache_read_input_tokens", "cachedInputTokens", "cacheReadInputTokens"]),
                intValue(last, keys: ["output_tokens", "outputTokens"]),
                false
            )
        }
        return nil
    }

    private func usageMap(info: [String: Any], keys: [String]) -> [String: Any]? {
        for key in keys {
            if let map = info[key] as? [String: Any] {
                return map
            }
        }
        return nil
    }

    private func intValue(_ map: [String: Any], keys: [String]) -> Int {
        for key in keys {
            if let number = map[key] as? NSNumber {
                return number.intValue
            }
            if let string = map[key] as? String, let intValue = Int(string) {
                return intValue
            }
        }
        return 0
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

    private func dayKey(forTimestampMs timestampMs: TimeInterval) -> String? {
        guard timestampMs > 0 else { return nil }
        let date = Date(timeIntervalSince1970: timestampMs / 1000.0)
        return dayKey(for: date)
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

    private func sumTokens(in keys: [String], dailyTotals: [String: Int]) -> Int {
        keys.reduce(0) { $0 + (dailyTotals[$1] ?? 0) }
    }

    private func fileModificationDate(_ url: URL) -> Date? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else { return nil }
        return attributes[.modificationDate] as? Date
    }
}
