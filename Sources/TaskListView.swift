import SwiftUI

struct TaskListView: View {
    var key: String
    @ObservedObject private var store = TaskStore.shared
    @State private var selected = Set<UUID>()
    @State private var editing: TaskItem? = nil

    private var title: String {
        let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return "" }
        switch parts[0] {
        case "smart": return SmartList(rawValue: parts[1])?.title ?? ""
        case "project": return store.projects.first { $0.id.uuidString == parts[1] }?.name ?? "Project"
        default: return "@" + parts[1]
        }
    }

    private var items: [TaskItem] { store.tasks(for: key) }
    private var isProject: Bool { key.hasPrefix("project:") }

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                if items.isEmpty { empty } else { list }
            }
            .frame(maxHeight: .infinity)
            QuickAddBar(context: key) { selected = [$0] }
        }
        .frame(minWidth: 480)
        .onChange(of: key) { selected = [] }
        .onReceive(NotificationCenter.default.publisher(for: .completeSelection)) { _ in
            withAnimation(.snappy) { selected.forEach(store.toggle) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .setPriority)) { note in
            store.edit(selected) { $0.priority = note.object as? Int }
        }
        .sheet(item: $editing) { TaskEditor(task: $0) }
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Theme.headline).tracking(-1).lineLimit(1)
                Text(subtitle).font(Theme.label(11)).foregroundStyle(.secondary).tracking(1)
            }
            Spacer()
            if store.hasExamples {
                Button("Clear Examples") { withAnimation { store.clearExamples() } }
                    .buttonStyle(.borderless)
                    .font(Theme.label(11))
                    .help("Remove the example tasks and projects")
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var subtitle: String {
        let n = items.count
        if key == "smart:done" { return "\(n) DONE" }
        let late = items.filter { $0.due.map { DueText.isOverdue($0, hasTime: false) } ?? false }.count
        var s = String(format: "%02d OPEN", n)
        if late > 0 { s += " · \(late) OVERDUE" }
        if key == "smart:today" { s = Date().formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased() + " · " + s }
        return s
    }

    private var list: some View {
        List(selection: $selected) {
            if key == "smart:upcoming" {
                ForEach(dayGroups, id: \.0) { day, tasks in
                    Section {
                        ForEach(tasks) { row($0) }
                    } header: {
                        Text(dayTitle(day)).font(Theme.label(11)).tracking(1)
                            .foregroundStyle(day < Date().startOfDay ? Theme.priorityColor(0) : .secondary)
                            .padding(.leading, 12)
                    }
                }
            } else {
                ForEach(items) { row($0) }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .contextMenu(forSelectionType: UUID.self) { ids in
            TaskMenu(ids: ids)
        } primaryAction: { ids in
            if let id = ids.first, let t = store.task(id) { editing = t }
        }
        .onDeleteCommand { withAnimation { store.delete(selected) }; selected = [] }
    }

    private func row(_ t: TaskItem) -> some View {
        TaskRow(task: t, showProject: !isProject)
            .tag(t.id)
            .draggable(t.id.uuidString)
            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
    }

    /// Upcoming, grouped by day, overdue first as one group.
    private var dayGroups: [(Date, [TaskItem])] {
        let today = Date().startOfDay
        let grouped = Dictionary(grouping: items) { t -> Date in
            let d = t.due!.startOfDay
            return d < today ? .distantPast : d
        }
        return grouped.keys.sorted().map { ($0, TaskStore.sorted(grouped[$0]!)) }
    }

    private func dayTitle(_ d: Date) -> String {
        if d == .distantPast { return "OVERDUE" }
        let base = DueText.short(d, hasTime: false).uppercased()
        let full = d.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased()
        return base == full ? full : base + " · " + full
    }

    private var empty: some View {
        ContentUnavailableView {
            Label(key == "smart:done" ? "Nothing done yet" : "All clear",
                  systemImage: key == "smart:done" ? "checkmark.circle" : "sparkles")
        } description: {
            Text(key == "smart:done" ? "Finished tasks show up here." : "Type a task in the box below and press Return.")
        }
    }
}

/// The right-click menu for one or more tasks: priority, due date, project, edit, delete.
struct TaskMenu: View {
    var ids: Set<UUID>
    @ObservedObject private var store = TaskStore.shared

    var body: some View {
        if !ids.isEmpty {
            Button(allDone ? "Mark as Not Done" : "Complete") { withAnimation { ids.forEach(store.toggle) } }
            Divider()
            Menu("Priority") {
                ForEach(0..<4) { p in Button("P\(p)") { store.edit(ids) { $0.priority = p } } }
                Button("No Priority") { store.edit(ids) { $0.priority = nil } }
            }
            Menu("Due") {
                Button("Today") { setDue(0) }
                Button("Tomorrow") { setDue(1) }
                Button("Next Week") { setDue(7) }
                Divider()
                Button("No Date") { store.edit(ids) { $0.due = nil; $0.hasTime = false } }
            }
            Menu("Move to") {
                Button("Inbox") { store.edit(ids) { $0.projectID = nil } }
                Divider()
                ForEach(store.projects) { p in Button(p.name) { store.edit(ids) { $0.projectID = p.id } } }
            }
            Divider()
            Button("Delete", role: .destructive) { withAnimation { store.delete(ids) } }
        }
    }

    private var allDone: Bool { ids.allSatisfy { store.task($0)?.done ?? false } }

    private func setDue(_ days: Int) {
        let d = Calendar.current.date(byAdding: .day, value: days, to: Date().startOfDay)!
        store.edit(ids) { $0.due = d; $0.hasTime = false }
    }
}
