import Foundation

struct TaskItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var projectID: UUID? = nil
    var labels: [String] = []
    /// 0 is most urgent, 3 least; nil is no priority.
    var priority: Int? = nil
    var due: Date? = nil
    var hasTime = false
    var done = false
    var completedAt: Date? = nil
    var created = Date()
    var notes: String? = nil
    /// One of the first launch's examples, which Clear Examples removes; editing it makes it the person's.
    var isExample: Bool? = nil
}

struct Project: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var colorIndex: Int = 0
    var order: Int = 0
    var isExample: Bool? = nil
}

enum ProjectPalette {
    static let colors: [(Double, Double, Double)] = [
        (0.83, 0.37, 0.22), (0.27, 0.53, 0.32), (0.88, 0.55, 0.22), (0.81, 0.31, 0.23),
        (0.56, 0.74, 0.31), (0.82, 0.62, 0.15), (0.62, 0.36, 0.26), (0.55, 0.53, 0.50),
    ]
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    var endOfDay: Date { Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)! }
}

enum DueText {
    /// "Today", "Tomorrow", "Fri", "Nov 14", plus the time when it has one.
    static func short(_ date: Date, hasTime: Bool) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: Date().startOfDay, to: date.startOfDay).day ?? 0
        var s: String
        switch days {
        case 0: s = "Today"
        case 1: s = "Tomorrow"
        case -1: s = "Yesterday"
        case 2...6: s = date.formatted(.dateTime.weekday(.abbreviated))
        default:
            s = cal.isDate(date, equalTo: Date(), toGranularity: .year)
                ? date.formatted(.dateTime.month(.abbreviated).day())
                : date.formatted(.dateTime.month(.abbreviated).day().year())
        }
        if hasTime { s += " " + date.formatted(date: .omitted, time: .shortened) }
        return s
    }

    static func isOverdue(_ date: Date, hasTime: Bool) -> Bool {
        hasTime ? date < Date() : date < Date().startOfDay
    }
}
