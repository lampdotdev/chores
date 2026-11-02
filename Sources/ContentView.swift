import SwiftUI

struct ContentView: View {
    @SceneStorage("selection") private var selectionKey: String = "smart:today"

    private var selection: Binding<String?> {
        Binding(get: { selectionKey }, set: { if let v = $0 { selectionKey = v } })
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: selection)
        } detail: {
            TaskListView(key: selectionKey)
        }
        .frame(minWidth: 720, minHeight: 460)
    }
}
