import Foundation

// MARK: - Format
//
// All display strings for durations, paces, decimals, and dates go through
// these helpers. Never format inline in views — this keeps presentation logic
// in one place and matches the behaviour of Format.swift in the original Swift app.

enum Format {

    // MARK: Duration

    /// Converts a raw second count to a human-readable elapsed string.
    ///
    ///     Format.duration(125)     → "2:05"
    ///     Format.duration(3725)    → "1:02:05"
    static func duration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }

    // MARK: Pace

    /// Converts pace in min/mile to a display string.
    ///
    ///     Format.pace(9.5)   → "9:30 /mi"
    ///     Format.pace(0)     → "--:-- /mi"
    static func pace(_ minPerMile: Double) -> String {
        guard minPerMile > 0, minPerMile < 60 else { return "--:-- /mi" }
        let totalSec = Int(minPerMile * 60)
        let m = totalSec / 60
        let s = totalSec % 60
        return String(format: "%d:%02d /mi", m, s)
    }

    // MARK: Decimal

    /// Formats a Double to a fixed number of decimal places.
    ///
    ///     Format.decimal(3.14159, places: 2)  → "3.14"
    static func decimal(_ value: Double, places: Int) -> String {
        String(format: "%.\(places)f", value)
    }

    // MARK: Dates

    /// Full date + time: "Mar 25, 2026 at 7:00 AM"
    static func date(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    /// Short date only: "Mar 25"
    static func dateShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    /// Relative date string for section headers: "Today", "Yesterday", or "Mar 25"
    static func relativeDayHeader(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return dateShort(date)
    }
}
