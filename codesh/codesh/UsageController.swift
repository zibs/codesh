import Foundation

final class UsageController {
    private let scanner = UsageScanner()
    private let queue = DispatchQueue(label: "codex.usage.scan", qos: .utility)
    private var timer: Timer?
    private var isRefreshing = false

    var onUpdate: ((UsageSnapshot) -> Void)?

    func start() {
        refreshRateLimits()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        refreshRateLimits()
    }

    private func refreshRateLimits() {
        guard !isRefreshing else { return }
        isRefreshing = true

        queue.async { [weak self] in
            guard let self else { return }

            let rateLimits = self.scanner.scanRateLimitsOnly()
            let snapshot = UsageSnapshot(
                updatedAt: Date(),
                rateLimits: rateLimits
            )

            DispatchQueue.main.async { [weak self] in
                self?.onUpdate?(snapshot)
                self?.isRefreshing = false
            }
        }
    }
}
