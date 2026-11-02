import SwiftUI

enum SmartList: String, CaseIterable, Identifiable {
    case inbox, today, upcoming, done
    var id: String { rawValue }
    var title: String {
        switch self {
        case .inbox: "Inbox"
        case .today: "Today"
        case .upcoming: "Upcoming"
        case .done: "Completed"
        }
    }
    var symbol: String {
        switch self {
        case .inbox: "tray.fill"
        case .today: "\(Calendar.current.component(.day, from: Date())).square.fill"
        case .upcoming: "calendar"
        case .done: "checkmark.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .inbox: Theme.ember
        case .today: Theme.amber
        case .upcoming: Theme.sun
        case .done: Theme.forest
        }
    }
}

struct SidebarView: View {
    @Binding var selection: String?
    @ObservedObject private var store = TaskStore.shared
    @State private var addingProject = false
    @State private var editingProject: Project? = nil
    @State private var deletingProject: Project? = nil

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(SmartList.allCases) { list in
                    Label {
                        Text(list.title)
                    } icon: {
                        Image(systemName: list.symbol).foregroundStyle(list.color)
                    }
                        .badge(store.count(for: "smart:" + list.rawValue))
                        .tag("smart:" + list.rawValue)
                        .dropDestination(for: String.self) { ids, _ in
                            drop(ids, on: list); return list != .upcoming
                        }
                }
            }
            Section("Projects") {
                ForEach(store.projects) { p in
                    let c = ProjectPalette.colors[p.colorIndex % ProjectPalette.colors.count]
                    Label {
                        Text(p.name)
                    } icon: {
                        Image(systemName: "number").foregroundStyle(Color(red: c.0, green: c.1, blue: c.2))
                    }
                    .badge(store.count(for: "project:" + p.id.uuidString))
                    .tag("project:" + p.id.uuidString)
                    .dropDestination(for: String.self) { ids, _ in
                        move(ids, to: p.id); return true
                    }
                    .contextMenu {
                        Button("Edit Project…") { editingProject = p }
                        Button("Delete Project…", role: .destructive) { deletingProject = p }
                    }
                }
                .onMove { store.moveProjects(from: $0, to: $1) }
            }
            if !store.allLabels.isEmpty {
                Section("Labels") {
                    ForEach(store.allLabels, id: \.self) { l in
                        Label {
                            Text(l)
                        } icon: {
                            Image(systemName: "at").foregroundStyle(Theme.leaf)
                        }
                        .tag("label:" + l)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        .safeAreaInset(edge: .bottom) {
            Button { addingProject = true } label: {
                Label("New Project", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .sheet(item: $editingProject) { ProjectSheet(project: $0) }
        .confirmationDialog("Delete \(deletingProject?.name ?? "")?", isPresented: Binding(
            get: { deletingProject != nil }, set: { if !$0 { deletingProject = nil } })) {
            Button("Delete Project", role: .destructive) {
                if let p = deletingProject {
                    if selection == "project:" + p.id.uuidString { selection = "smart:inbox" }
                    store.deleteProject(p.id)
                }
            }
        } message: {
            Text("Its tasks move to the Inbox.")
        }
        .sheet(isPresented: $addingProject) {
            ProjectSheet(project: nil) { selection = "project:" + $0.uuidString }
        }
    }

    /// Dropping on Inbox clears the project, on Today sets today, on Completed completes.
    private func drop(_ ids: [String], on list: SmartList) {
        let set = Set(ids.compactMap(UUID.init))
        withAnimation {
            switch list {
            case .inbox: store.edit(set) { $0.projectID = nil }
            case .today: store.edit(set) { $0.due = Date().startOfDay; $0.hasTime = false }
            case .done: store.edit(set) { $0.done = true; $0.completedAt = Date() }
            case .upcoming: break
            }
        }
    }

    private func move(_ ids: [String], to project: UUID?) {
        withAnimation { store.edit(Set(ids.compactMap(UUID.init))) { $0.projectID = project } }
    }
}
