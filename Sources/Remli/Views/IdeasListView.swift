import SwiftData
import SwiftUI

struct IdeasListView: View {

    @Query(sort: \Idea.createdAt, order: .reverse)
    private var ideas: [Idea]

    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            if ideas.isEmpty {
                FirstRunView()
            } else {
                list
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Space.sm) {
                ForEach(ideas) { idea in
                    NavigationLink {
                        IdeaDetailView(idea: idea)
                    } label: {
                        IdeaRowView(idea: idea)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            idea.pinned.toggle()
                            idea.touch()
                        } label: {
                            Label(
                                idea.pinned ? "Unpin" : "Pin",
                                systemImage: idea.pinned ? "pin.slash" : "pin"
                            )
                        }

                        Button(role: .destructive) {
                            context.delete(idea)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.top, Theme.Space.xs)
        }
        .scrollContentBackground(.hidden)
    }
}

/// The zero state.
///
/// Categories are emergent, so on day one there is genuinely nothing to show. Rather than
/// pretending otherwise with fake sample content, this says plainly what will happen once
/// there are a few ideas in here.
private struct FirstRunView: View {
    var body: some View {
        VStack(spacing: Theme.Space.md) {
            Spacer(minLength: Theme.Space.xxl)

            Image(systemName: "lightbulb.max")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.Palette.ember)

            Text("Nothing captured yet")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.ink)

            Text("Tap Capture the next time something occurs to you.\nRemli will title it, file it, and start finding\nthe threads between your ideas.")
                .font(Theme.Typography.meta)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.inkMuted)
                .lineSpacing(3)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Space.lg)
    }
}

#Preview {
    NavigationStack {
        IdeasListView()
            .background(Theme.Palette.canvas)
    }
    .modelContainer(try! RemliSchema.makeContainer(inMemory: true))
}
