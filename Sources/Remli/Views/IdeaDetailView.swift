import SwiftData
import SwiftUI

struct IdeaDetailView: View {

    @Bindable var idea: Idea

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {

                header

                if isEditing {
                    TextEditor(text: $idea.text)
                        .font(Theme.Typography.ideaBody)
                        .foregroundStyle(Theme.Palette.ink)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 220)
                        .cardBackground()
                        .onChange(of: idea.text) { _, _ in idea.touch() }
                } else {
                    Text(idea.text)
                        .font(Theme.Typography.ideaBody)
                        .foregroundStyle(Theme.Palette.ink)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }

                if !idea.tags.isEmpty {
                    TagRow(tags: idea.tags)
                }

                statusControl

                Spacer(minLength: Theme.Space.xxl)
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.top, Theme.Space.md)
        }
        .background(Theme.Palette.canvas)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isEditing.toggle()
                    } label: {
                        Label(isEditing ? "Done editing" : "Edit", systemImage: "pencil")
                    }

                    Button {
                        idea.pinned.toggle()
                        idea.touch()
                    } label: {
                        Label(idea.pinned ? "Unpin" : "Pin", systemImage: idea.pinned ? "pin.slash" : "pin")
                    }

                    Divider()

                    Button(role: .destructive) {
                        context.delete(idea)
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(idea.displayTitle)
                .font(Theme.Typography.display)
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Space.xs) {
                if let category = idea.category {
                    CategoryChip(category: category)
                }
                Text(idea.createdAt, format: .dateTime.day().month(.abbreviated).hour().minute())
                    .font(Theme.Typography.meta)
                    .foregroundStyle(Theme.Palette.inkMuted)
            }
        }
    }

    private var statusControl: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("STATUS")
                .font(Theme.Typography.sectionLabel)
                .foregroundStyle(Theme.Palette.inkMuted)
                .tracking(0.6)

            Picker("Status", selection: Binding(
                get: { idea.status },
                set: { idea.status = $0; idea.touch() }
            )) {
                ForEach(IdeaStatus.allCases, id: \.self) { status in
                    Text(status.label).tag(status)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

struct TagRow: View {
    let tags: [String]

    var body: some View {
        // A simple wrapping row. Tags are short by construction, so a flow layout is
        // overkill here.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.xs) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(Theme.Typography.meta)
                        .foregroundStyle(Theme.Palette.inkMuted)
                        .padding(.horizontal, Theme.Space.xs)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.Palette.hairline))
                }
            }
        }
    }
}
