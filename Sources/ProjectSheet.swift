import SwiftUI

/// Make a new project, or rename and recolor one.
struct ProjectSheet: View {
    var project: Project?
    var onSave: (UUID) -> Void = { _ in }
    @ObservedObject private var store = TaskStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var colorIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(project == nil ? "New Project" : "Edit Project").font(.system(size: 20, weight: .black))
            TextField("Name", text: $name).textFieldStyle(.roundedBorder).font(.system(size: 14))
            HStack(spacing: 10) {
                ForEach(ProjectPalette.colors.indices, id: \.self) { i in
                    let c = ProjectPalette.colors[i]
                    Circle()
                        .fill(Color(red: c.0, green: c.1, blue: c.2))
                        .frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(.primary.opacity(colorIndex == i ? 0.8 : 0), lineWidth: 2).padding(-3))
                        .onTapGesture { colorIndex = i }
                        .accessibilityLabel("Color \(i + 1)")
                        .accessibilityAddTraits(.isButton)
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(project == nil ? "Create" : "Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 360)
        .onAppear {
            name = project?.name ?? ""
            colorIndex = project?.colorIndex ?? store.projects.count % ProjectPalette.colors.count
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if var p = project {
            p.name = trimmed; p.colorIndex = colorIndex; p.isExample = nil
            store.updateProject(p)
            onSave(p.id)
        } else {
            var p = store.addProject(trimmed)
            p.colorIndex = colorIndex
            store.updateProject(p)
            onSave(p.id)
        }
        dismiss()
    }
}
