import SwiftUI

/// The box at the bottom: type a task in plain words and press Return.
struct QuickAddBar: View {
    /// The list being shown, so a task added there lands in it.
    var context: String
    var onAdd: (UUID) -> Void = { _ in }

    @ObservedObject private var store = TaskStore.shared
    @State private var text = ""
    @FocusState private var focused: Bool

    private var parsed: ParsedTask { QuickParser.parse(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !text.trimmingCharacters(in: .whitespaces).isEmpty { preview.transition(.opacity.combined(with: .move(edge: .bottom))) }
            HStack(spacing: 10) {
                TextField("Pay the bills today p1 #Home @errands", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .focused($focused)
                    .onSubmit(submit)
                    .onExitCommand { text = ""; focused = false }
                if !text.isEmpty {
                    Button(action: submit) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Theme.accent))
                    }
                    .buttonStyle(.plain)
                    .help("Add task (Return)")
                    .accessibilityLabel("Add")
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .frame(minHeight: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.12), radius: 14, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(focused ? Theme.accent.opacity(0.7) : Color.primary.opacity(0.08), lineWidth: 1)
        )
        .animation(.snappy(duration: 0.2), value: text.isEmpty)
        .padding(.horizontal, Theme.gutter - 12)
        .padding(.bottom, 18)
        .onReceive(NotificationCenter.default.publisher(for: .focusQuickAdd)) { _ in focused = true }
    }

    /// Live chips for what the box understood.
    private var preview: some View {
        let p = parsed
        let defaults = contextDefaults
        return HStack(spacing: 6) {
            Text(p.title.isEmpty ? "Chores" : p.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(p.title.isEmpty ? .tertiary : .secondary)
                .lineLimit(1)
            if let due = p.due ?? defaults.due {
                Tag(text: DueText.short(due, hasTime: p.hasTime), symbol: "calendar", color: Theme.accent)
            }
            if let pr = p.priority {
                Tag(text: "P\(pr)", symbol: "flag.fill", color: Theme.priorityColor(pr), filled: true)
            }
            if let name = p.project ?? defaults.project?.name {
                Tag(text: store.project(named: name)?.name ?? name,
                    symbol: store.project(named: name) == nil ? "plus" : "number",
                    color: projectColor(name))
            } else {
                Tag(text: "Inbox", symbol: "tray", color: .secondary)
            }
            ForEach(p.labels, id: \.self) { Tag(text: $0, symbol: "at", color: .secondary) }
            Spacer(minLength: 0)
        }
    }

    private func projectColor(_ name: String) -> Color {
        guard let p = store.project(named: name) else { return .secondary }
        let c = ProjectPalette.colors[p.colorIndex % ProjectPalette.colors.count]
        return Color(red: c.0, green: c.1, blue: c.2)
    }

    private var contextDefaults: (due: Date?, project: Project?) {
        let parts = context.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return (nil, nil) }
        if parts[0] == "project" { return (nil, store.projects.first { $0.id.uuidString == parts[1] }) }
        if context == "smart:today" { return (Date().startOfDay, nil) }
        return (nil, nil)
    }

    private func submit() {
        let p = parsed
        guard !p.title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let defaults = contextDefaults
        var labels = p.labels
        if context.hasPrefix("label:") {
            let l = String(context.dropFirst(6))
            if !labels.contains(l) { labels.append(l) }
        }
        let projectID = p.project.map { store.addProject($0).id } ?? defaults.project?.id
        let task = TaskItem(title: p.title, projectID: projectID, labels: labels, priority: p.priority,
                            due: p.due ?? defaults.due, hasTime: p.due != nil && p.hasTime)
        withAnimation(.snappy) { store.add(task) }
        onAdd(task.id)
        text = ""
    }
}
