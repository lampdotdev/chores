import SwiftUI

struct TaskRow: View {
    var task: TaskItem
    var showProject = true
    @ObservedObject private var store = TaskStore.shared
    @State private var hover = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            checkbox.alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .strikethrough(task.done, color: .secondary)
                    .foregroundStyle(task.done ? .secondary : .primary)
                    .lineLimit(2)
                if hasMeta { meta }
            }
            Spacer(minLength: 8)
            if let p = task.priority, !task.done {
                Text("P\(p)")
                    .font(Theme.label(10))
                    .foregroundStyle(Theme.priorityColor(p))
            }
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(task.title)
    }

    private var checkbox: some View {
        let color = task.priority == nil ? Color.secondary.opacity(0.55) : Theme.priorityColor(task.priority)
        return Button {
            withAnimation(.snappy(duration: 0.25)) { store.toggle(task.id) }
        } label: {
            ZStack {
                Circle().fill(task.priority == nil || task.done ? Color.clear : color.opacity(0.12))
                Circle().strokeBorder(color, lineWidth: 1.6)
                if task.done {
                    Circle().fill(color)
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(.white)
                } else if hover {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(color)
                }
            }
            .frame(width: 19, height: 19)
            .onHover { hover = $0 }
        }
        .buttonStyle(.plain)
        .help(task.done ? "Mark as not done" : "Complete")
        .accessibilityLabel(task.done ? "Mark \(task.title) as not done" : "Complete \(task.title)")
    }

    private var hasMeta: Bool {
        task.due != nil || !task.labels.isEmpty || (showProject && store.project(task.projectID) != nil)
    }

    private var meta: some View {
        HStack(spacing: 6) {
            if let due = task.due {
                let late = !task.done && DueText.isOverdue(due, hasTime: task.hasTime)
                Tag(text: DueText.short(due, hasTime: task.hasTime),
                    symbol: task.hasTime ? "clock" : "calendar",
                    color: late ? Theme.priorityColor(0) : Theme.accent)
            }
            if showProject, let p = store.project(task.projectID) {
                let c = ProjectPalette.colors[p.colorIndex % ProjectPalette.colors.count]
                Tag(text: p.name, symbol: "number", color: Color(red: c.0, green: c.1, blue: c.2))
            }
            ForEach(task.labels, id: \.self) { Tag(text: $0, symbol: "at", color: .secondary) }
        }
    }
}
