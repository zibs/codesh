import Foundation

enum PercentFormatters {
    static func percent(_ value: Double?) -> String {
        guard let value else { return "--" }
        let clamped = min(max(Int(round(value)), 0), 100)
        return "\(clamped)%"
    }
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
