import SwiftData
import SwiftUI

/// Moves an idea into a Space, and creates Spaces and Collections on the way.
///
/// Spaces arrive on their own — the model proposes "Business" the first time you capture
/// something that is one. What it cannot know is that two of those are a meal-prep company
/// and a bartending service. That is what Collections are for, and it gets said here, after
/// the fact, once there is enough in a Space to be worth dividing.
///
/// Creating one is deliberately available *inside* the move flow rather than only in a
/// separate manager screen. The moment you want a new Space is the moment you are looking
/// at something that belongs in one.
struct SpacePickerView: View {

    @Bindable var idea: Idea

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \IdeaCategory.name)
    private var allPlaces: [IdeaCategory]

    @State private var newName = ""
    /// Non-nil while naming a Collection; holds the Space it will go inside.
    @State private var creatingInside: IdeaCategory?
    @State private var isCreatingSpace = false

    @FocusState private var nameFieldFocused: Bool

    private var spaces: [IdeaCategory] {
        allPlaces.filter(\.isSpace)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(spaces) { space in
                        row(for: space)

                        ForEach(space.sortedChildren) { collection in
                            row(for: collection)
                        }

                        if creatingInside?.id == space.id {
                            nameField(placeholder: "Name this Collection", indented: true)
                        } else {
                            Button {
                                begin(inside: space)
                            } label: {
                                Label("New Collection in \(space.name)", systemImage: "plus")
                                    .font(Theme.Typography.meta)
                                    .foregroundStyle(Theme.Palette.inkMuted)
                            }
                            .padding(.leading, Theme.Space.md)
                        }
                    }
                } header: {
                    Text(spaces.isEmpty ? "" : "YOUR SPACES")
                }

                Section {
                    if isCreatingSpace {
                        nameField(placeholder: "Name this Space", indented: false)
                    } else {
                        Button {
                            begin(inside: nil)
                        } label: {
                            Label("New Space", systemImage: "square.stack.3d.up")
                        }
                    }

                    if idea.category != nil {
                        Button(role: .destructive) {
                            idea.category = nil
                            idea.touch()
                            dismiss()
                        } label: {
                            Label("Remove from Space", systemImage: "xmark.circle")
                        }
                    }
                }

                if spaces.isEmpty {
                    Section {
                        Text("Spaces appear here as Remli files your ideas. You can make your own too, and put Collections inside them.")
                            .font(Theme.Typography.meta)
                            .foregroundStyle(Theme.Palette.inkMuted)
                    }
                }
            }
            .navigationTitle("Move to a Space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Rows

    private func row(for place: IdeaCategory) -> some View {
        Button {
            idea.category = place
            idea.touch()
            dismiss()
        } label: {
            HStack(spacing: Theme.Space.xs) {
                Image(systemName: place.symbolName)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: place.colorHex) ?? Theme.Palette.ember)
                    .frame(width: 20)

                Text(place.name)
                    .font(Theme.Typography.ideaBody)
                    .foregroundStyle(Theme.Palette.ink)

                Spacer()

                if place.totalIdeaCount > 0 {
                    Text("\(place.totalIdeaCount)")
                        .font(Theme.Typography.meta)
                        .foregroundStyle(Theme.Palette.inkMuted)
                }

                if idea.category?.id == place.id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ember)
                }
            }
            // Indentation is the whole signal that a Collection sits inside the Space above.
            .padding(.leading, place.isSpace ? 0 : Theme.Space.md)
        }
        .buttonStyle(.plain)
    }

    private func nameField(placeholder: String, indented: Bool) -> some View {
        HStack(spacing: Theme.Space.xs) {
            TextField(placeholder, text: $newName)
                .font(Theme.Typography.ideaBody)
                .focused($nameFieldFocused)
                .submitLabel(.done)
                .onSubmit(commit)

            Button("Add", action: commit)
                .font(Theme.Typography.meta)
                .disabled(trimmedName.isEmpty)
        }
        .padding(.leading, indented ? Theme.Space.md : 0)
    }

    // MARK: - Creating

    private var trimmedName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func begin(inside space: IdeaCategory?) {
        newName = ""
        creatingInside = space
        isCreatingSpace = space == nil
        nameFieldFocused = true
    }

    /// Creates the Space or Collection and files the idea into it in one step.
    ///
    /// Reuses an existing one with the same name at the same level rather than making a
    /// second — the model already normalises names this way when it files automatically,
    /// and two Spaces reading identically is a bug you can see.
    ///
    /// Anything created here is marked `isUserOwned`, which is what protects it from being
    /// renamed or merged by a later enrichment pass. You named it; it is yours.
    private func commit() {
        let name = trimmedName
        guard !name.isEmpty else { return }

        let parent = creatingInside
        let siblings = parent.map(\.sortedChildren) ?? spaces
        let normalized = name.lowercased()

        let place: IdeaCategory
        if let existing = siblings.first(where: { $0.name.lowercased() == normalized }) {
            place = existing
            // Choosing an existing one by name is also a claim of ownership.
            place.isUserOwned = true
        } else {
            place = IdeaCategory(
                name: name,
                symbolName: parent?.symbolName ?? "square.stack.3d.up",
                parent: parent,
                isUserOwned: true
            )
            context.insert(place)
        }

        idea.category = place
        idea.touch()
        dismiss()
    }
}
