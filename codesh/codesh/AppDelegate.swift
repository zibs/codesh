import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore.shared
    private let usageController = UsageController()
    private var snapshot = UsageSnapshot.empty

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let popover = NSPopover()

    private let updatedItem = NSMenuItem(title: "Last updated: --", action: nil, keyEquivalent: "")
    private let sessionPercentItem = NSMenuItem(title: "Session: --", action: nil, keyEquivalent: "")
    private let weeklyPercentItem = NSMenuItem(title: "Weekly: --", action: nil, keyEquivalent: "")

    private let colorSettingsItem = NSMenuItem(
        title: "Customize Colors…",
        action: #selector(toggleColorPopover),
        keyEquivalent: ","
    )
    private let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshNow), keyEquivalent: "r")
    private let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setStatusTitle(sessionText: "--", weeklyText: "--")

        configurePopover()
        if let cached = settings.loadCachedRateLimits() {
            snapshot = UsageSnapshot(
                updatedAt: cached.updatedAt,
                rateLimits: cached.snapshot
            )
        }

        buildMenu()
        statusItem.menu = menu

        usageController.onUpdate = { [weak self] snapshot in
            self?.snapshot = snapshot
            if let rateLimits = snapshot.rateLimits, rateLimits.hasAnyValue {
                self?.settings.storeRateLimits(rateLimits, updatedAt: snapshot.updatedAt)
            }
            self?.updateUI()
        }
        usageController.start()
    }

    private func buildMenu() {
        menu.autoenablesItems = false

        let headerItem = NSMenuItem(title: "Codex Usage", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false

        updatedItem.isEnabled = false
        sessionPercentItem.isEnabled = false
        weeklyPercentItem.isEnabled = false

        colorSettingsItem.target = self
        colorSettingsItem.keyEquivalentModifierMask = [.command]
        refreshItem.target = self
        quitItem.target = self

        menu.addItem(headerItem)
        menu.addItem(updatedItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(sessionPercentItem)
        menu.addItem(weeklyPercentItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(colorSettingsItem)
        menu.addItem(refreshItem)
        menu.addItem(quitItem)

        updateUI()
    }

    private func updateUI() {
        if snapshot.updatedAt.timeIntervalSince1970 <= 0 {
            updatedItem.title = "Last updated: --"
        } else {
            updatedItem.title = "Last updated: \(DateFormatters.menuTime.string(from: snapshot.updatedAt))"
        }

        let rateLimits = snapshot.rateLimits
        sessionPercentItem.title = "Session: \(PercentFormatters.percent(rateLimits?.sessionUsedPercent))\(resetLabel(rateLimits?.sessionResetsAt))"
        weeklyPercentItem.title = "Weekly: \(PercentFormatters.percent(rateLimits?.weeklyUsedPercent))\(resetLabel(rateLimits?.weeklyResetsAt))"
        updateStatusTitle()
    }

    private func updateStatusTitle() {
        let rateLimits = snapshot.rateLimits
        let sessionText = PercentFormatters.percent(rateLimits?.sessionUsedPercent)
        let weeklyText = PercentFormatters.percent(rateLimits?.weeklyUsedPercent)
        if rateLimits?.sessionUsedPercent != nil || rateLimits?.weeklyUsedPercent != nil {
            setStatusTitle(sessionText: sessionText, weeklyText: weeklyText)
        } else {
            setStatusTitle(sessionText: "--", weeklyText: "--")
        }
    }

    private func setStatusTitle(sessionText: String, weeklyText: String) {
        guard let button = statusItem.button else { return }
        let font = NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold)
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: -0.2
        ]

        let sessionAttributes = baseAttributes.merging([.foregroundColor: sessionAccentColor()]) { $1 }
        let weeklyAttributes = baseAttributes.merging([.foregroundColor: weeklyAccentColor()]) { $1 }
        let separatorAttributes = baseAttributes.merging([.foregroundColor: NSColor.secondaryLabelColor]) { $1 }

        let title = NSMutableAttributedString()
        title.append(NSAttributedString(string: sessionText, attributes: sessionAttributes))
        title.append(NSAttributedString(string: "/", attributes: separatorAttributes))
        title.append(NSAttributedString(string: weeklyText, attributes: weeklyAttributes))

        button.attributedTitle = title
    }

    private func sessionAccentColor() -> NSColor {
        NSColor(name: nil) { [settings] appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return settings.resolvedColor(for: .sessionDark)
            }
            return settings.resolvedColor(for: .sessionLight)
        }
    }

    private func weeklyAccentColor() -> NSColor {
        NSColor(name: nil) { [settings] appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return settings.resolvedColor(for: .weeklyDark)
            }
            return settings.resolvedColor(for: .weeklyLight)
        }
    }

    private func resetLabel(_ date: Date?) -> String {
        guard let date else { return "" }
        let relative = DateFormatters.relative.localizedString(for: date, relativeTo: Date())
        return " · Resets \(relative)"
    }

    @objc private func refreshNow() {
        usageController.refresh()
    }

    @objc private func toggleColorPopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            DispatchQueue.main.async { [weak self] in
                self?.popover.contentViewController?.view.window?.makeKey()
            }
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func configurePopover() {
        popover.behavior = .semitransient
        popover.animates = true
        popover.contentSize = NSSize(width: 320, height: 280)
        popover.contentViewController = NSHostingController(
            rootView: ColorPreferencesView { [weak self] in
                self?.updateUI()
            }
        )
    }
}
