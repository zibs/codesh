import Foundation

final class UsageController {
    private let scanner = UsageScanner()
    private let queue = DispatchQueue(label: "codex.usage.scan", qos: .utility)
    private var timer: Timer?

    var onUpdate: ((UsageSnapshot) -> Void)?

    func start() {
        refreshRateLimitsFast()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        queue.async { [weak self] in
            guard let self else { return }
            let snapshot = self.scanner.scan(days: 30)
            DispatchQueue.main.async {
                self.onUpdate?(snapshot)
            }
        }
    }

    private func refreshRateLimitsFast() {
        queue.async { [weak self] in
            guard let self else { return }
            guard let rateLimits = self.scanner.scanRateLimitsOnly() else { return }

            let snapshot = UsageSnapshot(
                updatedAt: Date(),
                last7DaysTokens: 0,
                last30DaysTokens: 0,
                todayTokens: 0,
                latestSessionTokens: 0,
                rateLimits: rateLimits
            )

            DispatchQueue.main.async {
                self.onUpdate?(snapshot)
            }
        }
    }
}
