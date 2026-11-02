import SwiftUI

extension Notification.Name {
    static let focusQuickAdd = Notification.Name("focusQuickAdd")
    static let completeSelection = Notification.Name("completeSelection")
    static let setPriority = Notification.Name("setPriority")
}

@main
struct MainApp: SwiftUI.App {
    var body: some SwiftUI.Scene {
        WindowGroup("Chores") {
            ContentView()
                .tint(Theme.accent)
        }
        .defaultSize(width: 980, height: 680)
        .commands {
            LampCommands()
            CommandGroup(after: .newItem) {
                Button("Add Task") { NotificationCenter.default.post(name: .focusQuickAdd, object: nil) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandMenu("Task") {
                Button("Complete") { NotificationCenter.default.post(name: .completeSelection, object: nil) }
                    .keyboardShortcut(.return, modifiers: .command)
                Divider()
                ForEach(0..<5) { level in
                    Button(level == 4 ? "No Priority" : "Priority \(level)") {
                        NotificationCenter.default.post(name: .setPriority, object: level == 4 ? nil : level)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(level)")), modifiers: [.command, .option])
                }
                Divider()
                ClearExamplesButton()
            }
        }
    }
}

/// Clear Examples in the Task menu, there while the first launch's examples are.
struct ClearExamplesButton: View {
    @ObservedObject private var store = TaskStore.shared

    var body: some View {
        Button("Clear Examples") { withAnimation { store.clearExamples() } }
            .disabled(!store.hasExamples)
    }
}
