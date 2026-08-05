import SwiftData
import SwiftUI

/// The idea map.
///
/// Drawn with `Canvas` rather than a stack of views: at a few hundred nodes and edges,
/// SwiftUI's diffing becomes the bottleneck, whereas an immediate-mode draw stays smooth
/// while panning and zooming.
struct MapView: View {

    @Query(sort: \Idea.createdAt, order: .reverse)
    private var ideas: [Idea]

    @State private var graph = IdeaGraph()
    @State private var layout: [UUID: CGPoint] = [:]
    @State private var layoutBounds: CGRect = .zero
    @State private var isLayingOut = false

    @State private var zoom: CGFloat = 1
    @State private var committedZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var committedPan: CGSize = .zero

    /// Whether the person has moved the map themselves. Until they have, the view frames
    /// itself around the content on every relayout; afterwards it leaves their view alone,
    /// because yanking the camera back while somebody is reading is worse than an
    /// imperfect frame.
    @State private var hasAdjusted = false
    @State private var viewSize: CGSize = .zero

    @State private var selection: UUID?

    private var selectedNode: GraphNode? {
        selection.flatMap { graph.node($0) }
    }

    private var highlighted: Set<UUID> {
        guard let selection else { return [] }
        return graph.neighbours(of: selection).union([selection])
    }

    var body: some View {
        ZStack {
            Theme.Palette.canvas.ignoresSafeArea()

            if graph.nodes.count < 2 {
                NotEnoughIdeasView(count: graph.nodes.count)
            } else {
                canvas
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: ideas.count) { await rebuild() }
        .sheet(item: Binding(
            get: { selection.map(IdentifiableID.init) },
            set: { selection = $0?.id }
        )) { wrapper in
            if let idea = ideas.first(where: { $0.id == wrapper.id }) {
                NavigationStack {
                    IdeaDetailView(idea: idea)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Canvas

    private var canvas: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let transform = self.transform(for: size)

                for edge in graph.edges {
                    guard
                        let from = layout[edge.source],
                        let to = layout[edge.target]
                    else { continue }

                    let a = transform(from)
                    let b = transform(to)

                    // When something is selected, everything else recedes rather than
                    // disappearing — context is what makes a selection meaningful.
                    let isLit = selection == nil
                        || highlighted.contains(edge.source) && highlighted.contains(edge.target)

                    var path = Path()
                    path.move(to: a)
                    path.addLine(to: b)

                    context.stroke(
                        path,
                        with: .color(Theme.Palette.inkMuted.opacity(isLit ? 0.15 + edge.strength * 0.35 : 0.05)),
                        style: StrokeStyle(
                            lineWidth: 0.6 + edge.strength * 1.4,
                            // Dashed for the "tension with" edges, so a disagreement
                            // between two ideas is legible without tapping.
                            dash: edge.kind == .contradicts ? [4, 4] : []
                        )
                    )
                }

                for node in graph.nodes {
                    guard let position = layout[node.id] else { continue }
                    let point = transform(position)
                    let radius = self.radius(for: node)
                    let isLit = selection == nil || highlighted.contains(node.id)

                    let color = node.colorHex.flatMap { Color(hex: $0) } ?? Theme.Palette.ember
                    let rect = CGRect(
                        x: point.x - radius,
                        y: point.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )

                    context.fill(
                        Circle().path(in: rect),
                        with: .color(color.opacity(isLit ? (node.status == .done ? 0.35 : 0.95) : 0.15))
                    )

                    if node.status == .done {
                        context.stroke(
                            Circle().path(in: rect),
                            with: .color(color.opacity(isLit ? 0.9 : 0.2)),
                            lineWidth: 1.5
                        )
                    }

                    // Labels only once there is room for them to be readable.
                    if committedZoom * zoom > 0.75, isLit {
                        context.draw(
                            Text(node.title)
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.Palette.inkMuted),
                            at: CGPoint(x: point.x, y: point.y + radius + 8),
                            anchor: .top
                        )
                    }
                }
            }
            .contentShape(Rectangle())
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                viewSize = size
                fitToContent()
            }
            .gesture(
                DragGesture()
                    .onChanged { pan = $0.translation }
                    .onEnded { _ in
                        committedPan.width += pan.width
                        committedPan.height += pan.height
                        pan = .zero
                        hasAdjusted = true
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { zoom = $0.magnification }
                    .onEnded { _ in
                        committedZoom = min(max(committedZoom * zoom, 0.3), 4)
                        zoom = 1
                        hasAdjusted = true
                    }
            )
            .onTapGesture { location in
                select(at: location, in: proxy.size)
            }
            .overlay(alignment: .bottom) {
                if let selectedNode {
                    SelectionCard(node: selectedNode, graph: graph)
                        .padding(Theme.Space.md)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isLayingOut {
                    ProgressView().padding(Theme.Space.md)
                } else if hasAdjusted {
                    Button {
                        withAnimation(Theme.Motion.standard) {
                            hasAdjusted = false
                            fitToContent()
                        }
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.Palette.inkMuted)
                            .padding(Theme.Space.xs)
                            .background(Circle().fill(Theme.Palette.surface))
                            .overlay(Circle().strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(Theme.Space.md)
                }
            }
            // Nodes with nothing joining them look identical to a broken map, so say which
            // one this is. Connections are found per capture against everything already
            // there, so the honest answer is "keep going", not "something went wrong".
            .overlay(alignment: .top) {
                if graph.edges.isEmpty, selection == nil {
                    Text("No connections found yet — Remli looks for them\nas you capture, so keep adding.")
                        .font(Theme.Typography.meta)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.Palette.inkMuted)
                        .lineSpacing(3)
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.vertical, Theme.Space.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .fill(Theme.Palette.surface.opacity(0.92))
                        )
                        .padding(Theme.Space.md)
                }
            }
        }
    }

    // MARK: - Geometry

    /// The point in graph space that sits at the middle of the screen when pan is zero.
    ///
    /// Previously hard-coded to the centre of the layout's nominal 1000×1000 area, which is
    /// only where the nodes actually are if the layout happens to have settled there.
    /// Anchoring on the real bounds is what makes "no pan" mean "centred on the ideas".
    private var graphCentre: CGPoint {
        guard layoutBounds.width > 0, layoutBounds.height > 0 else {
            return CGPoint(x: 500, y: 500)
        }
        return CGPoint(x: layoutBounds.midX, y: layoutBounds.midY)
    }

    /// Maps graph space into view space. Built once per draw and captured by the closure,
    /// rather than recomputed per node.
    private func transform(for size: CGSize) -> (CGPoint) -> CGPoint {
        let scale = committedZoom * zoom
        let offsetX = committedPan.width + pan.width
        let offsetY = committedPan.height + pan.height
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let origin = graphCentre

        return { point in
            CGPoint(
                x: (point.x - origin.x) * scale + centre.x + offsetX,
                y: (point.y - origin.y) * scale + centre.y + offsetY
            )
        }
    }

    /// Zooms so the whole graph fits, with a margin for the labels that hang below nodes.
    private func fitToContent() {
        guard
            !hasAdjusted,
            viewSize.width > 0, viewSize.height > 0,
            layoutBounds.width > 0, layoutBounds.height > 0
        else { return }

        let margin: CGFloat = 56
        let usableWidth = max(viewSize.width - margin * 2, 40)
        let usableHeight = max(viewSize.height - margin * 2, 40)
        let scale = min(usableWidth / layoutBounds.width, usableHeight / layoutBounds.height)

        committedZoom = min(max(scale, 0.25), 2.5)
        committedPan = .zero
    }

    private func radius(for node: GraphNode) -> CGFloat {
        let scale = committedZoom * zoom
        return (5 + CGFloat(node.importance) * 7) * min(max(scale, 0.6), 1.6)
    }

    private func select(at location: CGPoint, in size: CGSize) {
        let transform = self.transform(for: size)

        var best: (id: UUID, distance: CGFloat)?
        for node in graph.nodes {
            guard let position = layout[node.id] else { continue }
            let point = transform(position)
            let distance = hypot(point.x - location.x, point.y - location.y)
            // A generous target: nodes are small, and fingers are not.
            guard distance < max(radius(for: node) + 16, 24) else { continue }
            if best == nil || distance < best!.distance {
                best = (node.id, distance)
            }
        }

        withAnimation(Theme.Motion.standard) {
            selection = best?.id == selection ? nil : best?.id
        }
    }

    // MARK: - Layout

    private func rebuild() async {
        let snapshot = IdeaGraph(ideas: ideas)
        graph = snapshot

        guard snapshot.nodes.count > 1 else {
            layout = [:]
            layoutBounds = .zero
            return
        }

        isLayingOut = true
        // Off the main actor: a few hundred nodes over 220 iterations is real arithmetic,
        // and it must not stutter the gesture handling.
        let result = await Task.detached(priority: .userInitiated) {
            GraphLayout.compute(graph: snapshot)
        }.value
        layout = result.positions
        layoutBounds = result.bounds
        fitToContent()
        isLayingOut = false
    }
}

/// `sheet(item:)` needs an `Identifiable`, and `UUID` alone is not.
private struct IdentifiableID: Identifiable {
    let id: UUID
}

private struct SelectionCard: View {
    let node: GraphNode
    let graph: IdeaGraph

    private var connectionCount: Int {
        graph.neighbours(of: node.id).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            Text(node.title)
                .font(Theme.Typography.ideaBody)
                .foregroundStyle(Theme.Palette.ink)
                .lineLimit(2)

            Text("\(connectionCount) connection\(connectionCount == 1 ? "" : "s") · tap again to open")
                .font(Theme.Typography.meta)
                .foregroundStyle(Theme.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}

private struct NotEnoughIdeasView: View {
    let count: Int

    var body: some View {
        VStack(spacing: Theme.Space.sm) {
            Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.Palette.ember)

            Text(count == 0 ? "No ideas yet" : "One idea so far")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.ink)

            Text("The map appears once there are a few ideas\nfor Remli to find threads between.")
                .font(Theme.Typography.meta)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.inkMuted)
                .lineSpacing(3)
        }
        .padding(Theme.Space.lg)
    }
}
