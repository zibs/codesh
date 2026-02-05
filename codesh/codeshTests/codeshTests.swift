import Foundation
import Testing
@testable import codesh

@Suite("Formatters")
struct FormatterTests {
    @Test func percentFormatting() {
        #expect(PercentFormatters.percent(nil) == "--")
        #expect(PercentFormatters.percent(49.6) == "50%")
        #expect(PercentFormatters.percent(-12) == "0%")
        #expect(PercentFormatters.percent(140) == "100%")
    }
}

@Suite("RateLimitSnapshot")
struct RateLimitSnapshotTests {
    @Test func hasAnyValueReflectsValues() {
        let empty = RateLimitSnapshot(
            sessionUsedPercent: nil,
            weeklyUsedPercent: nil,
            sessionResetsAt: nil,
            weeklyResetsAt: nil
        )
        #expect(empty.hasAnyValue == false)

        let populated = RateLimitSnapshot(
            sessionUsedPercent: 12,
            weeklyUsedPercent: nil,
            sessionResetsAt: nil,
            weeklyResetsAt: nil
        )
        #expect(populated.hasAnyValue == true)
    }
}

@Suite("SettingsStore")
struct SettingsStoreTests {
    @Test func storesAndLoadsRoundTrip() {
        let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create test UserDefaults suite.")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        let sessionReset = Date(timeIntervalSince1970: 1_700_000_000)
        let weeklyReset = Date(timeIntervalSince1970: 1_700_003_600)
        let snapshot = RateLimitSnapshot(
            sessionUsedPercent: 12.5,
            weeklyUsedPercent: 45.0,
            sessionResetsAt: sessionReset,
            weeklyResetsAt: weeklyReset
        )
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_100)

        store.storeRateLimits(snapshot, updatedAt: updatedAt)

        let cached = store.loadCachedRateLimits()
        #expect(cached != nil)
        #expect(cached?.snapshot.sessionUsedPercent == 12.5)
        #expect(cached?.snapshot.weeklyUsedPercent == 45.0)
        #expect(cached?.snapshot.sessionResetsAt == sessionReset)
        #expect(cached?.snapshot.weeklyResetsAt == weeklyReset)
        #expect(cached?.updatedAt == updatedAt)
    }

    @Test func emptySnapshotClearsCache() {
        let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create test UserDefaults suite.")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        let snapshot = RateLimitSnapshot(
            sessionUsedPercent: 25,
            weeklyUsedPercent: 50,
            sessionResetsAt: Date(timeIntervalSince1970: 1_700_000_000),
            weeklyResetsAt: Date(timeIntervalSince1970: 1_700_003_600)
        )
        store.storeRateLimits(snapshot, updatedAt: Date(timeIntervalSince1970: 1_700_000_100))
        #expect(store.loadCachedRateLimits() != nil)

        let emptySnapshot = RateLimitSnapshot(
            sessionUsedPercent: nil,
            weeklyUsedPercent: nil,
            sessionResetsAt: nil,
            weeklyResetsAt: nil
        )
        store.storeRateLimits(emptySnapshot, updatedAt: Date(timeIntervalSince1970: 1_700_000_200))
        #expect(store.loadCachedRateLimits() == nil)
    }
}

@Suite("UsageScanner")
struct UsageScannerTests {
    @Test func scanSelectsLatestLineFromNewestFile() throws {
        let (root, sessions) = try makeSessionsRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let fileA = sessions.appendingPathComponent("2026/02/03/a.jsonl")
        let fileB = sessions.appendingPathComponent("2026/02/04/b.jsonl")
        try FileManager.default.createDirectory(
            at: fileA.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: fileB.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let lineA: [String: Any] = [
            "timestamp": 1_700_000_000_000 as NSNumber,
            "payload": [
                "rate_limits": [
                    "primary": ["used_percent": 11],
                    "secondary": ["used_percent": 22]
                ]
            ]
        ]
        let lineB1: [String: Any] = [
            "timestamp": 1_700_000_001_000 as NSNumber,
            "payload": [
                "rate_limits": [
                    "primary": ["used_percent": 33],
                    "secondary": ["used_percent": 44]
                ]
            ]
        ]
        let lineB2: [String: Any] = [
            "timestamp": 1_700_000_002_000 as NSNumber,
            "payload": [
                "rate_limits": [
                    "primary": ["used_percent": 55],
                    "secondary": ["used_percent": 66]
                ]
            ]
        ]

        try writeJSONLines([lineA], to: fileA)
        try writeJSONLines([lineB1, lineB2], to: fileB)
        try setModificationDate(Date(timeIntervalSince1970: 1), for: fileA)
        try setModificationDate(Date(timeIntervalSince1970: 2), for: fileB)

        let scanner = UsageScanner(sessionsRootOverride: sessions)
        let snapshot = scanner.scanRateLimitsOnly()

        #expect(snapshot?.sessionUsedPercent == 55)
        #expect(snapshot?.weeklyUsedPercent == 66)
    }

    @Test func scanParsesCamelCaseAndResetDates() throws {
        let (root, sessions) = try makeSessionsRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let file = sessions.appendingPathComponent("2026/02/04/one.jsonl")
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let line: [String: Any] = [
            "timestamp": "2026-02-04T12:00:00Z",
            "payload": [
                "rateLimits": [
                    "primary": [
                        "usedPercent": "12.5",
                        "resetsAt": "1700000000"
                    ],
                    "secondary": [
                        "usedPercent": 50,
                        "resetsAt": 1_700_003_600_000 as NSNumber
                    ]
                ]
            ]
        ]
        try writeJSONLines([line], to: file)

        let scanner = UsageScanner(sessionsRootOverride: sessions)
        let snapshot = scanner.scanRateLimitsOnly()

        #expect(snapshot?.sessionUsedPercent == 12.5)
        #expect(snapshot?.weeklyUsedPercent == 50)

        let sessionReset = snapshot?.sessionResetsAt
        let weeklyReset = snapshot?.weeklyResetsAt
        #expect(sessionReset != nil)
        #expect(weeklyReset != nil)

        if let sessionReset {
            #expect(abs(sessionReset.timeIntervalSince1970 - 1_700_000_000) < 0.1)
        }
        if let weeklyReset {
            #expect(abs(weeklyReset.timeIntervalSince1970 - 1_700_003_600) < 0.1)
        }
    }

    @Test func scanFallsBackToFileDateWhenMissingTimestamp() throws {
        let (root, sessions) = try makeSessionsRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let file = sessions.appendingPathComponent("2026/02/05/missing.jsonl")
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let line: [String: Any] = [
            "payload": [
                "rate_limits": [
                    "primary": ["used_percent": 9]
                ]
            ]
        ]

        try writeJSONLines([line], to: file)
        try setModificationDate(Date(timeIntervalSince1970: 3), for: file)

        let scanner = UsageScanner(sessionsRootOverride: sessions)
        let snapshot = scanner.scanRateLimitsOnly()

        #expect(snapshot?.sessionUsedPercent == 9)
    }

    private func makeSessionsRoot() throws -> (root: URL, sessions: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codesh-tests")
            .appendingPathComponent(UUID().uuidString)
        let sessions = root.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        return (root, sessions)
    }

    private func writeJSONLines(_ lines: [[String: Any]], to url: URL) throws {
        let strings = try lines.map { line -> String in
            let data = try JSONSerialization.data(withJSONObject: line, options: [])
            if let string = String(data: data, encoding: .utf8) {
                return string
            }
            throw NSError(domain: "codeshTests", code: 1)
        }
        let payload = strings.joined(separator: "\n")
        try payload.write(to: url, atomically: true, encoding: .utf8)
    }

    private func setModificationDate(_ date: Date, for url: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }
}
