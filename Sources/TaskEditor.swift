import SwiftUI

/// Edit one task: title, notes, priority, due date and time, project, labels.
struct TaskEditor: View {
    @State var task: TaskItem
    @ObservedObject private var store = TaskStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var labelText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Task", text: $task.title, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .bold))
                .padding([.horizontal, .top], 22)
                .padding(.bottom, 12)
            Form {
                Picker("Priority", selection: $task.priority) {
                    ForEach(0..<4) { p in
                        Text("P\(p)").tag(Int?.some(p))
                    }
                    Text("None").tag(Int?.none)
                }
                .pickerStyle(.segmented)

                Picker("Project", selection: $task.projectID) {
                    Label("Inbox", systemImage: "tray").tag(UUID?.none)
                    ForEach(store.projects) { p in Text(p.name).tag(UUID?.some(p.id)) }
                }

                Toggle("Due date", isOn: Binding(
                    get: { task.due != nil },
                    set: { task.due = $0 ? (task.due ?? Date().startOfDay) : nil; if !$0 { task.hasTime = false } }))
                if task.due != nil {
                    DatePicker("Date", selection: Binding(get: { task.due ?? Date() }, set: { task.due = $0 }),
                               displayedComponents: task.hasTime ? [.date, .hourAndMinute] : [.date])
                    Toggle("At a time", isOn: Binding(
                        get: { task.hasTime },
                        set: { on in
                            task.hasTime = on
                            if let d = task.due {
                                task.due = on ? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: d) : d.startOfDay
                            }
                        }))
                }

                LabeledContent("Labels") {
                    HStack(spacing: 6) {
                        ForEach(task.labels, id: \.self) { l in
                            Button { task.labels.removeAll { $0 == l } } label: {
                                Tag(text: l, symbol: "xmark", color: .secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Remove label")
                        }
                        TextField("Add", text: $labelText)
                            .textFieldStyle(.plain)
                            .frame(minWidth: 60)
                            .onSubmit {
                                let l = labelText.trimmingCharacters(in: CharacterSet(charactersIn: "@ ")).lowercased()
                                if !l.isEmpty, !task.labels.contains(l) { task.labels.append(l) }
                                labelText = ""
                            }
                    }
                }

                TextField("Notes", text: Binding(get: { task.notes ?? "" }, set: { task.notes = $0.isEmpty ? nil : $0 }),
                          axis: .vertical)
                    .lineLimit(3...8)
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            HStack {
                Button("Delete", role: .destructive) { store.delete([task.id]); dismiss() }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { task.isExample = nil; store.update(task); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(task.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 460)
    }
}
