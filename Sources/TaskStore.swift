import SwiftUI

/// All tasks and projects, kept in LampStore one item at a time.
final class TaskStore: ObservableObject {
    static let shared = TaskStore()

    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var projects: [Project] = []

    private let taskDB = LampStore.collection("tasks", of: TaskItem.self)
    private let projectDB = LampStore.collection("projects", of: Project.self)

    init() {
        tasks = taskDB.all()
        projects = projectDB.all().sorted { $0.order < $1.order }
        if tasks.isEmpty && projects.isEmpty { seed() }
    }

    // MARK: Projects

    func project(_ id: UUID?) -> Project? { id.flatMap { id in projects.first { $0.id == id } } }

    func project(named name: String) -> Project? {
        projects.first { $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    @discardableResult
    func addProject(_ name: String) -> Project {
        if let existing = project(named: name) { return existing }
        let p = Project(name: name, colorIndex: projects.count % ProjectPalette.colors.count,
                        order: (projects.map(\.order).max() ?? -1) + 1)
        projects.append(p)
        projectDB.put(p)
        return p
    }

    func updateProject(_ p: Project) {
        guard let i = projects.firstIndex(where: { $0.id == p.id }) else { return }
        projects[i] = p
        projectDB.put(p)
    }

    func deleteProject(_ id: UUID) {
        // Its tasks go back to the Inbox rather than disappearing.
        for t in tasks where t.projectID == id { var c = t; c.projectID = nil; update(c) }
        projects.removeAll { $0.id == id }
        projectDB.delete(id)
    }

    func moveProjects(from: IndexSet, to: Int) {
        projects.move(fromOffsets: from, toOffset: to)
        for (i, var p) in projects.enumerated() { p.order = i; projects[i] = p }
        projectDB.put(projects)
    }

    // MARK: Tasks

    var allLabels: [String] {
        Array(Set(tasks.filter { !$0.done }.flatMap(\.labels))).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func add(_ t: TaskItem) {
        tasks.append(t)
        taskDB.put(t)
    }

    func update(_ t: TaskItem) {
        guard let i = tasks.firstIndex(where: { $0.id == t.id }) else { return }
        tasks[i] = t
        taskDB.put(t)
    }

    func task(_ id: UUID) -> TaskItem? { tasks.first { $0.id == id } }

    func toggle(_ id: UUID) {
        guard var t = task(id) else { return }
        t.done.toggle()
        t.completedAt = t.done ? Date() : nil
        update(t)
    }

    func delete(_ ids: Set<UUID>) {
        tasks.removeAll { ids.contains($0.id) }
        ids.forEach(taskDB.delete)
    }

    func edit(_ ids: Set<UUID>, _ change: (inout TaskItem) -> Void) {
        for id in ids { if var t = task(id) { change(&t); update(t) } }
    }

    // MARK: Lists

    static func sorted(_ list: [TaskItem]) -> [TaskItem] {
        list.sorted { a, b in
            let pa = a.priority ?? 9, pb = b.priority ?? 9
            if pa != pb { return pa < pb }
            switch (a.due, b.due) {
            case let (x?, y?) where x != y: return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.created < b.created
            }
        }
    }

    func tasks(for key: String) -> [TaskItem] {
        let open = tasks.filter { !$0.done }
        let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return [] }
        switch (parts[0], parts[1]) {
        case ("smart", "inbox"): return Self.sorted(open.filter { $0.projectID == nil })
        case ("smart", "today"): return Self.sorted(open.filter { ($0.due ?? .distantFuture) < Date().endOfDay })
        case ("smart", "upcoming"): return open.filter { $0.due != nil }.sorted { $0.due! < $1.due! }
        case ("smart", "done"): return tasks.filter(\.done).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        case ("project", let id): return Self.sorted(open.filter { $0.projectID?.uuidString == id })
        case ("label", let name): return Self.sorted(open.filter { $0.labels.contains { $0.caseInsensitiveCompare(name) == .orderedSame } })
        default: return []
        }
    }

    func count(for key: String) -> Int { key == "smart:done" ? 0 : tasks(for: key).count }

    // MARK: Examples

    var hasExamples: Bool { tasks.contains { $0.isExample == true } || projects.contains { $0.isExample == true } }

    /// Removes the examples the first launch wrote, keeping anything the person added or edited, and any example
    /// project that now holds a task of theirs.
    func clearExamples() {
        delete(Set(tasks.filter { $0.isExample == true }.map(\.id)))
        for p in projects where p.isExample == true && !tasks.contains(where: { $0.projectID == p.id }) {
            deleteProject(p.id)
        }
    }

    private func seed() {
        var home = addProject("Home"), work = addProject("Work")
        home.isExample = true; updateProject(home)
        work.isExample = true; updateProject(work)
        let today = Date().startOfDay
        let cal = Calendar.current
        let examples = [
            TaskItem(title: "Pay the bills", projectID: home.id, priority: 1, due: today),
            TaskItem(title: "Ship the launch deck", projectID: work.id, priority: 0, due: today),
            TaskItem(title: "Pick up dry cleaning", projectID: home.id, labels: ["errands"],
                     due: cal.date(byAdding: .day, value: 1, to: today)),
            TaskItem(title: "Review Q4 roadmap", projectID: work.id, priority: 2,
                     due: cal.date(byAdding: .day, value: 3, to: today)),
            TaskItem(title: "Try typing in the box below: call mom friday 6pm p2 #Home"),
        ]
        for var t in examples { t.isExample = true; add(t) }
    }
}
