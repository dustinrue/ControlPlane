import Foundation

/// Left-pads or truncates `s` to exactly `width` characters.
func col(_ s: String, _ width: Int) -> String {
    if s.count >= width { return String(s.prefix(width)) }
    return s + String(repeating: " ", count: width - s.count)
}

/// Human-readable relative time string for a past date, e.g. "2 min ago", "just now".
func relativeTime(_ date: Date) -> String {
    let seconds = Int(Date().timeIntervalSince(date))
    switch seconds {
    case ..<5:                return "just now"
    case 5..<60:              return "\(seconds)s ago"
    case 60..<3600:           return "\(seconds / 60)m ago"
    case 3600..<86400:        return "\(seconds / 3600)h ago"
    case 86400..<(86400 * 7): return "\(seconds / 86400)d ago"
    default:
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: date)
    }
}
