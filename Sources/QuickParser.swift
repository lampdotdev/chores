import Foundation

/// Reads a line like "pay the bills today 5pm p1 #Home @errands" with plain rules (no AI):
/// p0–p3 for priority, #project, @label, and dates and times in everyday words.
struct ParsedTask: Equatable {
    var title = ""
    var due: Date? = nil
    var hasTime = false
    var priority: Int? = nil
    var project: String? = nil
    var labels: [String] = []
}

enum QuickParser {
    private static let weekdays: [String: Int] = [
        "sun": 1, "sunday": 1, "mon": 2, "monday": 2, "tue": 3, "tues": 3, "tuesday": 3,
        "wed": 4, "weds": 4, "wednesday": 4, "thu": 5, "thur": 5, "thurs": 5, "thursday": 5,
        "fri": 6, "friday": 6, "sat": 7, "saturday": 7,
    ]
    private static let months: [String: Int] = [
        "jan": 1, "january": 1, "feb": 2, "february": 2, "mar": 3, "march": 3, "apr": 4, "april": 4,
        "may": 5, "jun": 6, "june": 6, "jul": 7, "july": 7, "aug": 8, "august": 8,
        "sep": 9, "sept": 9, "september": 9, "oct": 10, "october": 10, "nov": 11, "november": 11,
        "dec": 12, "december": 12,
    ]

    static func parse(_ input: String, now: Date = Date()) -> ParsedTask {
        let cal = Calendar.current
        let today = now.startOfDay
        let words = input.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let lower = words.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ",.;")) }
        var used = Array(repeating: false, count: words.count)
        var result = ParsedTask()
        var day: Date? = nil
        var time: (Int, Int)? = nil

        func word(_ i: Int) -> String? { i >= 0 && i < lower.count && !used[i] ? lower[i] : nil }
        func use(_ r: ClosedRange<Int>) { for i in r { used[i] = true } }
        func adding(_ c: Calendar.Component, _ n: Int) -> Date { cal.date(byAdding: c, value: n, to: today)! }
        func next(weekday: Int, skipThisWeek: Bool) -> Date {
            let current = cal.component(.weekday, from: today)
            var diff = (weekday - current + 7) % 7
            if diff == 0 { diff = 7 }
            if skipThisWeek && diff < 7 && weekday > current { diff += 7 }
            return adding(.day, diff)
        }

        func matchDate(at i: Int) -> (Date, Int)? {
            guard let w = word(i) else { return nil }
            switch w {
            case "today", "tod": return (today, 1)
            case "tonight": time = time ?? (20, 0); return (today, 1)
            case "tomorrow", "tmr", "tmrw", "tom": return (adding(.day, 1), 1)
            case "weekend": return (next(weekday: 7, skipThisWeek: false), 1)
            default: break
            }
            if w == "this", let n = word(i + 1) {
                if n == "weekend" { return (cal.component(.weekday, from: today) == 7 ? today : next(weekday: 7, skipThisWeek: false), 2) }
                if let wd = weekdays[n] { return (cal.component(.weekday, from: today) == wd ? today : next(weekday: wd, skipThisWeek: false), 2) }
            }
            if w == "next", let n = word(i + 1) {
                switch n {
                case "week": return (next(weekday: 2, skipThisWeek: false), 2)
                case "month":
                    let m = cal.date(byAdding: .month, value: 1, to: today)!
                    return (cal.date(from: cal.dateComponents([.year, .month], from: m))!, 2)
                case "year": return (adding(.year, 1), 2)
                default: if let wd = weekdays[n] { return (next(weekday: wd, skipThisWeek: true), 2) }
                }
            }
            if w == "in", let n = word(i + 1), let unit = word(i + 2) {
                let count = Int(n) ?? (["a", "an", "one"].contains(n) ? 1 : nil)
                if let count {
                    let u = unit.hasSuffix("s") ? String(unit.dropLast()) : unit
                    switch u {
                    case "day": return (adding(.day, count), 3)
                    case "week": return (adding(.day, 7 * count), 3)
                    case "month": return (adding(.month, count), 3)
                    case "year": return (adding(.year, count), 3)
                    default: break
                    }
                }
            }
            if let wd = weekdays[w] { return (next(weekday: wd, skipThisWeek: false), 1) }
            // "jan 5", "january 5th"
            if let m = months[w], let dn = word(i + 1), let d = dayNumber(dn) { return (dated(m, d), 2) }
            // "5 jan", "5th of january"
            if let d = dayNumber(w) {
                if let mw = word(i + 1), let m = months[mw] { return (dated(m, d), 2) }
                if word(i + 1) == "of", let mw = word(i + 2), let m = months[mw] { return (dated(m, d), 3) }
            }
            // "11/14" or "11/14/2027"
            let parts = w.split(separator: "/").compactMap { Int($0) }
            if parts.count >= 2, parts.count == w.split(separator: "/").count,
               (1...12).contains(parts[0]), (1...31).contains(parts[1]) {
                if parts.count == 3 {
                    let y = parts[2] < 100 ? 2000 + parts[2] : parts[2]
                    if let d = cal.date(from: DateComponents(year: y, month: parts[0], day: parts[1])) { return (d, 1) }
                }
                return (dated(parts[0], parts[1]), 1)
            }
            return nil
        }

        func dayNumber(_ s: String) -> Int? {
            let digits = s.replacingOccurrences(of: "st", with: "").replacingOccurrences(of: "nd", with: "")
                .replacingOccurrences(of: "rd", with: "").replacingOccurrences(of: "th", with: "")
            guard let n = Int(digits), (1...31).contains(n) else { return nil }
            return n
        }

        /// That month and day, this year, or next year once it has passed.
        func dated(_ month: Int, _ d: Int) -> Date {
            let y = cal.component(.year, from: today)
            let date = cal.date(from: DateComponents(year: y, month: month, day: d))!
            return date < today ? cal.date(from: DateComponents(year: y + 1, month: month, day: d))! : date
        }

        func matchTime(at i: Int) -> ((Int, Int), Int)? {
            guard let w = word(i) else { return nil }
            if w == "noon" { return ((12, 0), 1) }
            if w == "midnight" { return ((23, 59), 1) }
            if w == "morning" { return ((9, 0), 1) }
            if w == "evening" { return ((18, 0), 1) }
            // "5pm", "5:30pm", "5 pm", "17:00", "at 9"
            var s = w, len = 1
            if let n = word(i + 1), ["am", "pm"].contains(n), Int(s.replacingOccurrences(of: ":", with: "")) != nil {
                s += n; len = 2
            }
            var suffix: String? = nil
            if s.hasSuffix("am") || s.hasSuffix("pm") { suffix = String(s.suffix(2)); s = String(s.dropLast(2)) }
            let hm = s.split(separator: ":").map { Int($0) }
            guard !hm.isEmpty, hm.count <= 2, hm.allSatisfy({ $0 != nil }) else { return nil }
            var h = hm[0]!, m = hm.count == 2 ? hm[1]! : 0
            guard (0...59).contains(m) else { return nil }
            if let suffix {
                guard (1...12).contains(h) else { return nil }
                if suffix == "pm" && h < 12 { h += 12 }
                if suffix == "am" && h == 12 { h = 0 }
            } else if hm.count == 2 {
                guard (0...23).contains(h) else { return nil }
            } else {
                // A bare number is a time only after "at": "at 9".
                guard word(i - 1) == "at", (1...23).contains(h) else { return nil }
                if h < 8 { h += 12 }
                m = 0
            }
            return ((h, m), len)
        }

        var i = 0
        while i < words.count {
            guard let w = word(i) else { i += 1; continue }
            let raw = words[i]

            // Priority: p0–p3
            if w.count == 2, w.first == "p", let n = Int(String(w.last!)), (0...3).contains(n) {
                result.priority = n; use(i...i); i += 1; continue
            }
            // #project and @label
            if raw.hasPrefix("#"), raw.count > 1 {
                result.project = String(raw.dropFirst()).replacingOccurrences(of: "_", with: " ")
                use(i...i); i += 1; continue
            }
            if raw.hasPrefix("@"), raw.count > 1 {
                let l = String(raw.dropFirst()).lowercased()
                if !result.labels.contains(l) { result.labels.append(l) }
                use(i...i); i += 1; continue
            }

            if day == nil, let (d, len) = matchDate(at: i) {
                day = d
                var start = i
                if let prev = word(i - 1), ["on", "by", "due"].contains(prev) { start = i - 1 }
                use(start...(i + len - 1)); i += len; continue
            }
            if time == nil, let (t, len) = matchTime(at: i) {
                time = t
                var start = i
                if let prev = word(i - 1), prev == "at" { start = i - 1 }
                use(start...(i + len - 1)); i += len; continue
            }
            i += 1
        }

        if let (h, m) = time {
            var base = day ?? today
            if day == nil, let t = cal.date(bySettingHour: h, minute: m, second: 0, of: today), t < now {
                base = adding(.day, 1)
            }
            result.due = cal.date(bySettingHour: h, minute: m, second: 0, of: base)
            result.hasTime = true
        } else {
            result.due = day
        }

        result.title = words.indices.filter { !used[$0] }.map { words[$0] }.joined(separator: " ")
        return result
    }
}
