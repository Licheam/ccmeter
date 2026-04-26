import AppKit

enum Formatting {

    static func compactCost(_ cost: Double) -> String {
        if cost <= 0 { return "$0.00" }
        if cost >= 1000 {
            return String(format: "$%.1fk", cost / 1000)
        }
        return String(format: "$%.2f", cost)
    }

    static func compactTokens(_ tokens: Int) -> String {
        let t = Double(tokens)
        if tokens < 10_000 {
            let f = NumberFormatter()
            f.groupingSeparator = ","
            f.numberStyle = .decimal
            return f.string(from: NSNumber(value: tokens)) ?? "\(tokens)"
        }
        if tokens < 1_000_000 {
            return String(format: "%.0fk", t / 1_000)
        }
        return String(format: "%.1fM", t / 1_000_000)
    }

    static func fullCost(_ cost: Double) -> String {
        String(format: "$%.2f", cost)
    }

    static func fullTokens(_ tokens: Int) -> String {
        let f = NumberFormatter()
        f.groupingSeparator = ","
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: tokens)) ?? "\(tokens)"
    }

    static func remainingMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m left" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h left" : "\(h)h \(m)m left"
    }

    static func relativeTime(from iso: String) -> String? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) else { return nil }
        let r = RelativeDateTimeFormatter()
        r.unitsStyle = .abbreviated
        return r.localizedString(for: date, relativeTo: Date())
    }

    static func statusBarAttributed(_ text: String) -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        return NSAttributedString(string: text, attributes: [.font: font])
    }
}
