import Foundation

enum TokenFormatters {
    static func full(_ value: Int) -> String {
        NumberFormatters.decimal.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func short(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000.0)
        }
        if value >= 1_000 {
            return String(format: "%.1fk", Double(value) / 1_000.0)
        }
        return String(value)
    }
}

enum PercentFormatters {
    static func percent(_ value: Double?) -> String {
        guard let value else { return "--" }
        let clamped = min(max(Int(round(value)), 0), 100)
        return "\(clamped)%"
    }
}

enum NumberFormatters {
    static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

enum DateFormatters {
    static let menuTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}
