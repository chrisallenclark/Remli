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

    /// Nil shows everything. Otherwise only the ideas in one Space and its Collections.
    ///
    /// The map's problem at any real size is that "all of it at once" answers no question.
    /// Filtering to a Space turns it from a picture of your library into a picture of one
    /// thing you are working on, which is the only version anyone looks at twice.
    @State private var focusedSpaceID: UUID?

    private var selectedNode: GraphNode? {
        selection.flatMap { graph.node($0) }
    }

    /// Every Space that has at least one idea in it, busiest first.
    private var spaces: [IdeaCategory] {
        var counts: [UUID: Int] = [:]
        var byID: [UUID: IdeaCategory] = [:]

        for idea in ideas where idea.kind == .idea {
            guard let place = idea.category else { continue }
            let space = place.rootFolder
            counts[space.id, default: 0] += 1
            byID[space.id] = space
        }

        var result: [IdeaCategory] = []
        for (id, space) in byID {
            _ = id
            result.append(space)
        }
        result.sort { lhs, rhs in
            let left = counts[lhs.id] ?? 0
            let right = counts[rhs.id] ?? 0
            if left == right { return lhs.name < rhs.name }
            return left > right
        }
        return result
    }

    /// The ideas the map should show, after the Space filter.
    private var visibleIdeas: [Idea] {
        guard let focusedSpaceID else { return ideas }
        return ideas.filter { idea in
            guard let place = idea.category else { return false }
            return place.rootFolder.id == focusedSpaceID
        }
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
        .safeAreaInset(edge: .top) {
            if spaces.count > 1 {
                spaceFilter
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        // Opening the Map always shows everything.
        //
        // Panning and zooming used to persist across visits, on the theory that returning
        // to where you left off is respectful. In practice it means one stray pinch leaves
        // the tab looking empty forever, and the way out — a small button in the corner —
        // is the last thing anyone finds. Framing the whole graph on arrival costs a
        // gesture to get back to a detail, and saves ever landing on a blank screen.
        .onAppear {
            hasAdjusted = false
            fitToContent()
        }
        .task(id: ideas.count) { await rebuild() }
        .task(id: focusedSpaceID) { await rebuild() }
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

                    // A gentle arc rather than a straight line. Two nodes joined by a
                    // segment read as a diagram; the same pair joined by a curve reads as
                    // something grown. The control point is perpendicular to the midpoint
                    // and always bends the same way, so the picture stays stable.
                    let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                    let span = CGPoint(x: b.x - a.x, y: b.y - a.y)
                    let length = max(hypot(span.x, span.y), 0.01)
                    let bend = min(length * 0.12, 34)
                    let control = CGPoint(
                        x: mid.x - span.y / length * bend,
                        y: mid.y + span.x / length * bend
                    )

                    var path = Path()
                    path.move(to: a)
                    path.addQuadCurve(to: b, control: control)

                    let edgeTint = self.color(for: edge.source)

                    context.stroke(
                        path,
                        with: .color(edgeTint.opacity(isLit ? 0.22 + edge.strength * 0.5 : 0.06)),
                        style: StrokeStyle(
                            lineWidth: 0.8 + edge.strength * 2,
                            lineCap: .round,
                            // Dashed for the "tension with" edges, so a disagreement
                            // between two ideas is legible without tapping.
                            dash: edge.kind == .contradicts ? [4, 5] : []
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

                    // The halo. An idea is a light source here, not a dot — which is what
                    // separates a map you want to look at from a scatter plot, and is only
                    // possible because the app committed to a dark ground.
                    let haloRadius = radius * 3.4
                    let haloRect = CGRect(
                        x: point.x - haloRadius,
                        y: point.y - haloRadius,
                        width: haloRadius * 2,
                        height: haloRadius * 2
                    )
                    context.fill(
                        Circle().path(in: haloRect),
                        with: .radialGradient(
                            Gradient(colors: [
                                color.opacity(isLit ? 0.34 : 0.06),
                                color.opacity(0),
                            ]),
                            center: point,
                            startRadius: radius * 0.5,
                            endRadius: haloRadius
                        )
                    )

                    context.fill(
                        Circle().path(in: rect),
                        with: .color(color.opacity(isLit ? (node.status == .done ? 0.28 : 0.92) : 0.14))
                    )

                    // A finished idea reads as an outline — present, no longer burning.
                    if node.status == .done {
                        context.stroke(
                            Circle().path(in: rect),
                            with: .color(color.opacity(isLit ? 0.9 : 0.2)),
                            lineWidth: 1.5
                        )
                    } else {
                        // A hot centre, so bigger nodes do not read as flat discs.
                        let coreRadius = radius * 0.45
                        let coreRect = CGRect(
                            x: point.x - coreRadius,
                            y: point.y - coreRadius,
                            width: coreRadius * 2,
                            height: coreRadius * 2
                        )
                        context.fill(
                            Circle().path(in: coreRect),
                            with: .color(.white.opacity(isLit ? 0.5 : 0.08))
                        )
                    }

                    if isLit, showsAllLabels || committedZoom * zoom > 0.75 {
                        context.draw(
                            Text(node.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.Palette.ink),
                            at: CGPoint(x: point.x, y: point.y + radius + 6),
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
            // One composed gesture rather than `.gesture` plus `.simultaneousGesture`.
            //
            // With two separate recognisers the drag would claim the interaction and
            // cancel the magnify, and a cancelled gesture never calls `onEnded` — so the
            // committed zoom was never written and the map sprang back to its previous
            // scale the instant you lifted your fingers. `SimultaneousGesture` gives both
            // recognisers the same events and one end callback that always fires.
            .gesture(
                SimultaneousGesture(DragGesture(minimumDistance: 0), MagnifyGesture())
                    .onChanged { value in
                        if let drag = value.first {
                            pan = drag.translation
                        }
                        if let magnify = value.second {
                            zoom = magnify.magnification
                        }
                    }
                    .onEnded { _ in
                        committedPan.width += pan.width
                        committedPan.height += pan.height
                        pan = .zero

                        committedZoom = min(max(committedZoom * zoom, Self.minZoom), Self.maxZoom)
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
    ///
    /// Capped at 1× rather than letting a small library magnify itself. With four ideas the
    /// bounds are tiny, so "fit" wanted to zoom to 2.5× — which put the camera *inside* the
    /// cluster, pushing every node past the edges. A map that has zoomed into empty space
    /// is indistinguishable from a broken one.
    private func fitToContent() {
        guard
            !hasAdjusted,
            viewSize.width > 0, viewSize.height > 0,
            layoutBounds.width > 0, layoutBounds.height > 0
        else { return }

        let margin: CGFloat = 72
        let usableWidth = max(viewSize.width - margin * 2, 40)
        let usableHeight = max(viewSize.height - margin * 2, 40)
        let scale = min(usableWidth / layoutBounds.width, usableHeight / layoutBounds.height)

        committedZoom = min(max(scale, Self.minZoom), 1)
        committedPan = .zero
    }

    /// Low enough that a pinch can always reach "everything on screen", even on a small
    /// phone with a wide graph. The previous floor of 0.3 was above what some layouts
    /// needed, so zooming out simply stopped before the ideas came into view.
    static let minZoom: CGFloat = 0.12
    static let maxZoom: CGFloat = 4

    /// Above this many nodes, labels are drawn only when zoomed in. Below it, every idea is
    /// named all the time — a handful of anonymous dots is not a map of anything.
    private static let labelAllThreshold = 45

    /// Node size in *view* points, deliberately independent of zoom.
    ///
    /// Scaling radius with zoom meant a fitted map of four ideas drew 5-point dots, which
    /// reads as a blank screen with some dust on it. Keeping size fixed means zoom controls
    /// how much you can see, not whether you can see it, and every node stays a finger-sized
    /// target at any scale.
    private func radius(for node: GraphNode) -> CGFloat {
        11 + CGFloat(node.importance) * 9
    }

    private var showsAllLabels: Bool {
        graph.nodes.count <= Self.labelAllThreshold
    }

    /// A node's Space colour, used for its halo and for the edges leaving it — so a cluster
    /// belonging to one Space glows as one thing rather than as unrelated points.
    private func color(for id: UUID) -> Color {
        guard let node = graph.node(id) else { return Theme.Palette.ember }
        return node.colorHex.flatMap { Color(hex: $0) } ?? Theme.Palette.ember
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

    private var spaceFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.xs) {
                filterChip(label: "All", color: Theme.Palette.ember, isSelected: focusedSpaceID == nil) {
                    focusedSpaceID = nil
                }

                ForEach(spaces) { space in
                    filterChip(
                        label: space.name,
                        color: Color(hex: space.colorHex) ?? Theme.Palette.ember,
                        isSelected: focusedSpaceID == space.id
                    ) {
                        focusedSpaceID = focusedSpaceID == space.id ? nil : space.id
                    }
                }
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.xs)
        }
        .background(.ultraThinMaterial)
    }

    private func filterChip(
        label: String,
        color: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            // Re-framing on every change of filter, because the remaining ideas occupy a
            // completely different part of the canvas and leaving the camera where it was
            // would show empty space.
            hasAdjusted = false
            selection = nil
            withAnimation(Theme.Motion.standard) { action() }
        } label: {
            Text(label)
                .font(Theme.Typography.meta)
                .foregroundStyle(isSelected ? Theme.Palette.canvas : Theme.Palette.inkMuted)
                .padding(.horizontal, Theme.Space.sm)
                .padding(.vertical, 6)
                .background(Capsule().fill(isSelected ? color : Theme.Palette.surface))
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : Theme.Palette.hairline,
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private func rebuild() async {
        let snapshot = IdeaGraph(ideas: visibleIdeas)
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
