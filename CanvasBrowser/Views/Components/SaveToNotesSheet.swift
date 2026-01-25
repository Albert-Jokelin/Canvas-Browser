import SwiftUI

/// Sheet for saving content to Apple Notes with folder selection
struct SaveToNotesSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var notesManager = NotesManager.shared

    let initialTitle: String
    let content: String
    let sourceURL: URL?

    @State private var title: String = ""
    @State private var selectedFolder: String = "Notes"
    @State private var includeSource: Bool = true
    @State private var isSaving: Bool = false

    init(title: String, content: String, sourceURL: URL? = nil) {
        self.initialTitle = title
        self.content = content
        self.sourceURL = sourceURL
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Text("Save to Notes")
                    .font(.headline)

                Spacer()

                Button("Save") { saveNote() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(title.isEmpty || isSaving)
            }
            .padding()

            Divider()

            Form {
                Section("Note Details") {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)

                    Picker("Folder", selection: $selectedFolder) {
                        ForEach(notesManager.folders, id: \.self) { folder in
                            Text(folder).tag(folder)
                        }
                    }
                }

                Section("Preview") {
                    ScrollView {
                        Text(content)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 150)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                }

                if sourceURL != nil {
                    Section {
                        Toggle("Include source URL", isOn: $includeSource)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(width: 450, height: 420)
        .onAppear {
            title = initialTitle
            notesManager.loadFolders()
        }
    }

    func saveNote() {
        isSaving = true

        var finalContent = content

        if includeSource, let url = sourceURL {
            finalContent += "\n\n---\nSource: \(url.absoluteString)"
        }

        notesManager.createNote(title: title, body: finalContent, folder: selectedFolder)

        isSaving = false
        dismiss()

        // Show toast
        ToastManager.shared.show(ToastData(
            message: "Saved to Notes",
            icon: "note.text",
            style: .success
        ))
    }
}

/// Sheet for saving a GenTab to Apple Notes
struct SaveGenTabToNotesSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var notesManager = NotesManager.shared

    let genTab: GenTab

    @State private var title: String = ""
    @State private var selectedFolder: String = "Notes"
    @State private var includeSources: Bool = true
    @State private var isSaving: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Text("Save GenTab to Notes")
                    .font(.headline)

                Spacer()

                Button("Save") { saveGenTab() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(title.isEmpty || isSaving)
            }
            .padding()

            Divider()

            Form {
                Section("Note Details") {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)

                    Picker("Folder", selection: $selectedFolder) {
                        ForEach(notesManager.folders, id: \.self) { folder in
                            Text(folder).tag(folder)
                        }
                    }
                }

                Section("GenTab Preview") {
                    HStack {
                        Image(systemName: genTab.icon)
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading) {
                            Text(genTab.title)
                                .font(.headline)
                            Text("\(genTab.components.count) components")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                if !genTab.sourceURLs.isEmpty {
                    Section {
                        Toggle("Include source URLs (\(genTab.sourceURLs.count))", isOn: $includeSources)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(width: 450, height: 380)
        .onAppear {
            title = genTab.title
            notesManager.loadFolders()
        }
    }

    func saveGenTab() {
        isSaving = true

        // Generate markdown content from GenTab
        var content = ""

        for component in genTab.components {
            content += componentToText(component) + "\n\n"
        }

        if includeSources && !genTab.sourceURLs.isEmpty {
            content += "\n---\nSources:\n"
            for source in genTab.sourceURLs {
                content += "- \(source.title): \(source.url)\n"
            }
        }

        notesManager.createNote(title: title, body: content, folder: selectedFolder)

        isSaving = false
        dismiss()

        ToastManager.shared.show(ToastData(
            message: "GenTab saved to Notes",
            icon: "note.text",
            style: .success
        ))
    }

    func componentToText(_ component: GenTabComponent) -> String {
        switch component {
        case .header(let text):
            return "## \(text)"
        case .paragraph(let text):
            return text
        case .bulletList(let items):
            return items.map { "• \($0)" }.joined(separator: "\n")
        case .numberedList(let items):
            return items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        case .table(let columns, let rows):
            var result = columns.joined(separator: " | ") + "\n"
            result += String(repeating: "-", count: result.count) + "\n"
            for row in rows {
                result += row.joined(separator: " | ") + "\n"
            }
            return result
        case .keyValue(let pairs):
            return pairs.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        case .callout(let type, let text):
            let prefix: String
            switch type {
            case .info: prefix = "ℹ️"
            case .warning: prefix = "⚠️"
            case .tip: prefix = "💡"
            case .price: prefix = "💰"
            case .success: prefix = "✅"
            case .error: prefix = "❌"
            }
            return "\(prefix) \(text)"
        case .link(let title, let url):
            return "\(title): \(url)"
        case .cardGrid(let cards):
            return cards.map { card in
                var text = "**\(card.title)**"
                if let subtitle = card.subtitle {
                    text += " - \(subtitle)"
                }
                if let description = card.description {
                    text += "\n\(description)"
                }
                return text
            }.joined(separator: "\n\n")
        case .map(let locations):
            return "📍 Locations:\n" + locations.map { "- \($0.title)" }.joined(separator: "\n")
        case .divider:
            return "---"
        case .image(_, let caption):
            return caption ?? "[Image]"
        }
    }
}

/// Sheet for creating reminders from a GenTab
struct CreateRemindersFromGenTabSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var remindersManager = RemindersManager.shared

    let genTab: GenTab

    @State private var listName: String = ""
    @State private var selectedItems: Set<String> = []
    @State private var isCreating: Bool = false

    var extractedItems: [String] {
        var items: [String] = []

        for component in genTab.components {
            switch component {
            case .bulletList(let listItems):
                items.append(contentsOf: listItems)
            case .numberedList(let listItems):
                items.append(contentsOf: listItems)
            case .cardGrid(let cards):
                items.append(contentsOf: cards.map { $0.title })
            default:
                break
            }
        }

        return items
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }

                Spacer()

                Text("Create Reminders")
                    .font(.headline)

                Spacer()

                Button("Create") { createReminders() }
                    .disabled(selectedItems.isEmpty || isCreating)
            }
            .padding()

            Divider()

            Form {
                Section("Reminder List") {
                    TextField("List Name", text: $listName)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Select Items (\(selectedItems.count) selected)") {
                    if extractedItems.isEmpty {
                        Text("No actionable items found in this GenTab")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        List(extractedItems, id: \.self, selection: $selectedItems) { item in
                            Text(item)
                                .lineLimit(2)
                        }
                        .frame(height: 200)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(width: 450, height: 420)
        .onAppear {
            listName = "Canvas: \(genTab.title)"
            selectedItems = Set(extractedItems)
        }
    }

    func createReminders() {
        isCreating = true

        Task {
            _ = await remindersManager.requestAccess()

            await MainActor.run {
                for item in selectedItems {
                    _ = remindersManager.createReminder(title: item)
                }

                isCreating = false
                dismiss()

                ToastManager.shared.show(ToastData(
                    message: "\(selectedItems.count) reminders created",
                    icon: "checklist",
                    style: .success
                ))
            }
        }
    }
}
