Kind: tool, styled like a crisp task manager in a warm sunset palette (ember, amber, sun and leaf greens), heavy
headlines and small monospaced tags for dates, projects and labels.

# Chores

A to-do list where a task is typed in plain words. The box at the bottom of the list reads a line like "call mom
friday 6pm p2 #Home @errands" as it's typed and shows what it understood as chips (the title, the due date, the
priority, the project and labels) before Return adds it. The sidebar has four smart lists (Inbox, Today, Upcoming,
Completed), the person's projects, each with a color, and every label in use. Upcoming groups tasks by day, with
anything overdue first. Tasks are dragged onto a list to move them (onto Today to make them due today, onto Completed
to complete them, onto a project to move them there); a double click opens the editor, and a right-click has
priority, due date, project and Delete.

## How the code is organized

- `Sources/App.swift`: the window (980×680 by default), Add Task (⇧⌘N), and the Task menu: Complete (⌘Return),
  Priority 0–3 and No Priority (⌥⌘0–⌥⌘4), Clear Examples (`ClearExamplesButton`). Menu commands reach the list
  through notifications (`focusQuickAdd`, `completeSelection`, `setPriority`).
- `Sources/ContentView.swift`: the split view; the chosen list is a string key kept per window ("smart:today",
  "project:<id>", "label:<name>").
- `Sources/Models.swift`: `TaskItem`, `Project`, `ProjectPalette` (the eight project colors), and `DueText`, which
  writes a due date as "Today", "Tomorrow", "Fri" or "Nov 14" and says when it's overdue.
- `Sources/TaskStore.swift`: the one shared store (`TaskStore.shared`). Adds, edits, completes and deletes tasks
  and projects, saves each change, and answers what each list holds (`tasks(for:)`, sorted by priority, then due
  date, then when added). It writes the examples on the first launch and clears them.
- `Sources/QuickParser.swift`: turns a typed line into a `ParsedTask` with plain rules, no AI: p0–p3, #project,
  @label, and dates and times in everyday words ("today", "tmrw", "friday", "next week", "in 3 days", "nov 14",
  "5pm", "noon").
- `Sources/QuickAddBar.swift`: the box, its live chips, and where a task lands: in the project or label being
  shown, and due today when added in Today. A #project that doesn't exist yet is made.
- `Sources/SidebarView.swift`: `SmartList`, the projects (reordered by dragging, edited or deleted from a
  right-click; a deleted project's tasks go to the Inbox), the labels, New Project, and dropping tasks on a list.
- `Sources/TaskListView.swift`: the list's headline and count line, the rows (by day in Upcoming), the empty
  state, and `TaskMenu`, the right-click menu.
- `Sources/TaskRow.swift`: one task: the round checkbox in its priority's color, the title, and its tags.
- `Sources/TaskEditor.swift`: the sheet that edits a task: title, priority, project, due date and time, labels,
  notes.
- `Sources/ProjectSheet.swift`: making a project, or renaming and recoloring one.
- `Sources/Theme.swift`: the palette, the priority colors, the monospaced label font, the headline, and `Tag`, the
  small chip used for every date, project, label and priority.

## Data

Everything is in LampStore: the collection "tasks" holds one `TaskItem` each and "projects" one `Project` each.
Priority 0 is the most urgent and nil is none. A due date with no time is the start of that day (`hasTime` false).
Labels are kept lowercased. A completed task keeps `completedAt`, which orders Completed.

## Sample data and Clear Examples

On the first launch (no tasks and no projects), `TaskStore.seed` writes two projects, Home and Work, and five tasks
due around today, one of them inviting the person to try the box. Each is marked `isExample`; saving a task in the
editor or a project in its sheet clears its mark. Clear Examples (beside the headline while there are examples, and
in the Task menu) removes the marked tasks, then any marked project left with no tasks, so whatever the person
added stays.

## Easy to change

- Colors and fonts: `Theme.swift`; project colors: `ProjectPalette` in `Models.swift`.
- What the box understands: `QuickParser` (a new keyword is a case in `matchDate` or `matchTime`, or a prefix
  like `#` and `@` in `parse`).
- A new smart list: a case in `SmartList` (title, symbol, color) and its filter in `TaskStore.tasks(for:)`.
- Something new on a task (a repeat, a duration, subtasks): an optional property on `TaskItem` (old tasks still
  load), a field in `TaskEditor`, a tag in `TaskRow.meta`, and, to type it, a rule in `QuickParser`.
- Sample content: `TaskStore.seed()`.
