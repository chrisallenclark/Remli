import SwiftData
import SwiftUI

/// Moves an idea into a folder, and creates folders on the way.
///
/// Categories arrive on their own — the model invents "Business" the first time you capture
/// something that is one. What it cannot know is that two of those are a meal-prep company
/// and a bartending service. This is where that gets said, after the fact, once there is
/// enough in a folder to be worth dividing.
///
/// Creating a folder is deliberately available *inside* the move flow rather than only in a
/// separate manager screen. The moment you want a new folder is the moment you are looking
/// at something that belongs in one.
struct FolderPickerView: View {

    @Bindable var idea: Idea

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \IdeaCategory.name)
    private var allFolders: [IdeaCategory]

    @State private var newFolderName = ""
    /// Non-nil while naming a subfolder; holds the parent it will go under.
    @State private var creatingUnder: IdeaCategory?
    @State private var isCreatingRoot = false

    @FocusState private var nameFieldFocused: Bool

    private var roots: [IdeaCategory] {
        allFolders.filter(\.isRoot)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(roots) { root in
                        row(for: root)

                        ForEach(root.sortedChildren) { child in
                            row(for: child)
                        }

                        if creatingUnder?.id == root.id {
                            nameField(placeholder: "Name this subfolder")
                        } else {
                            Button {
                                begin(under: root)
                            } label: {
                                Label("New subfolder in \(root.name)", systemImage: "plus")
                                    .font(Theme.Typography.meta)
                                    .foregroundStyle(Theme.Palette.inkMuted)
                            }
                            .padding(.leading, Theme.Space.md)
                        }
                    }
                } header: {
                    Text(roots.isEmpty ? "" : "FOLDERS")
                }

                Section {
                    if isCreatingRoot {
                        nameField(placeholder: "Name this folder")
                    } else {
                        Button {
                            begin(under: nil)
                        } label: {
                            Label("New folder", systemImage: "folder.badge.plus")
                        }
                    }

                    if idea.category != nil {
                        Button(role: .destructive) {
                            idea.category = nil
                            idea.touch()
                            dismiss()
                        } label: {
                            Label("Remove from folder", systemImage: "xmark.circle")
                        }
                    }
                }

                if roots.isEmpty {
                    Section {
                        Text("Folders appear here as Remli files your ideas. You can also make your own, and put folders inside them.")
                            .font(Theme.Typography.meta)
                            .foregroundStyle(Theme.Palette.inkMuted)
                    }
                }
            }
            .navigationTitle("Move to folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Rows

    private func row(for folder: IdeaCategory) -> some View {
        Button {
            idea.category = folder
            idea.touch()
            dismiss()
        } label: {
            HStack(spacing: Theme.Space.xs) {
                Image(systemName: folder.symbolName)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: folder.colorHex) ?? Theme.Palette.ember)
                    .frame(width: 20)

                Text(folder.name)
                    .font(Theme.Typography.ideaBody)
                    .foregroundStyle(Theme.Palette.ink)

                Spacer()

                if folder.totalIdeaCount > 0 {
                    Text("\(folder.totalIdeaCount)")
                        .font(Theme.Typography.meta)
                        .foregroundStyle(Theme.Palette.inkMuted)
                }

                if idea.category?.id == folder.id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ember)
                }
            }
            // Indentation is the whole signal that this sits inside the folder above it.
            .padding(.leading, folder.isRoot ? 0 : Theme.Space.md)
        }
        .buttonStyle(.plain)
    }

    private func nameField(placeholder: String) -> some View {
        HStack(spacing: Theme.Space.xs) {
            TextField(placeholder, text: $newFolderName)
                .font(Theme.Typography.ideaBody)
                .focused($nameFieldFocused)
                .submitLabel(.done)
                .onSubmit(commit)

            Button("Add", action: commit)
                .font(Theme.Typography.meta)
                .disabled(trimmedName.isEmpty)
        }
        .padding(.leading, creatingUnder == nil ? 0 : Theme.Space.md)
    }

    // MARK: - Creating

    private var trimmedName: String {
        newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func begin(under parent: IdeaCategory?) {
        newFolderName = ""
        creatingUnder = parent
        isCreatingRoot = parent == nil
        nameFieldFocused = true
    }

    /// Creates the folder and files the idea into it in one step.
    ///
    /// Reuses an existing folder with the same name under the same parent rather than
    /// making a second one — the model already normalises names this way when it files
    /// automatically, and two folders reading identically is a bug you can see.
    private func commit() {
        let name = trimmedName
        guard !name.isEmpty else { return }

        let parent = creatingUnder
        let siblings = parent.map(\.sortedChildren) ?? roots
        let normalized = name.lowercased()

        let folder: IdeaCategory
        if let existing = siblings.first(where: { $0.name.lowercased() == normalized }) {
            folder = existing
        } else {
            folder = IdeaCategory(name: name, symbolName: parent?.symbolName ?? "folder", parent: parent)
            context.insert(folder)
        }

        idea.category = folder
        idea.touch()
        dismiss()
    }
}
