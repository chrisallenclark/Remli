import SwiftData
import SwiftUI

/// The idea map.
///
/// Drawn with `Canvas` rather than a stack of views: at a few hundred nodes and edges,
/// SwiftUI's diffing becomes the bottleneck, whereas an immediate-mode draw stays smooth
/// while panning and zooming.
///
/// The map answers one question: **what am I actually building toward, and what have I
/// quietly let go cold?** Three visual channels carry it, and nothing else does anything:
/// size is how much an idea anchors, brightness is how recently you touched it, colour is
/// its Space. A fourth channel would make the picture unreadable, which is the failure mode
/// of every knowledge graph ever shipped.
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

    /// The idea whose detail sheet is open, which is deliberately not `selection`.
    ///
    /// The first tap focuses and the second opens. Driving the sheet off `selection`
    /// collapsed those into one — every tap threw a sheet over the map, so the gather
    /// animation played behind a card nobody asked for and the focus view was unreachable.
    @State private var openedIdea: UUID?

    /// The idea the orbit is arranged around.
    ///
    /// Distinct from `selection` because it has to outlive it. Releasing a focus sets
    /// `selection` to nil and eases `focusProgress` back to zero, and the return journey
    /// needs to know where it is coming *from* — so this is written when a focus begins
    /// and simply never cleared. At zero progress a stale hub contributes nothing.
    @State private var orbitHub: UUID?

    /// 0 is the map at rest, 1 is fully gathered around `orbitHub`. Everything positional
    /// interpolates on it, which is why the transition is watchable rather than a cut.
    @State private var focusProgress: Double = 0

    /// Dims everything you have touched recently, leaving only what you have abandoned.
    @State private var showsColdOnly = false

    /// Fixed for the life of a layout rather than read per frame, so that "how long since
    /// you touched this" cannot shimmer while you are looking at it.
    @State private var renderedAt = Date.now

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

    /// Nil shows everything. Otherwise only the ideas in one Space and its Collections.
    ///
    /// The map's problem at any real size is that "all of it at once" answers no question.
    /// Filtering to a Space turns it from a picture of your library into a picture of one
    /// thing you are working on, which is the only version anyone looks at twice.
    @State private var focusedSpaceID: UUID?

    /// The ideas the map should show, after the Space filter.
    private var visibleIdeas: [Idea] {
        guard let focusedSpaceID else { return ideas }
        return ideas.filter { idea in
            guard let place = idea.category else { return false }
            return place.rootFolder.id == focusedSpaceID
        }
    }

    private var coldCount: Int {
        graph.nodes.filter { MapMetrics.isCold($0, now: renderedAt) }.count
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
            renderedAt = .now
            release()
            fitToContent()
        }
        .task(id: ideas.count) { await rebuild() }
        .task(id: focusedSpaceID) { await rebuild() }
        .sheet(item: Binding(
            get: { openedIdea.map(IdentifiableID.init) },
            set: { openedIdea = $0?.id }
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
            MapCanvas(
                progress: focusProgress,
                graph: graph,
                layout: layout,
                graphCentre: graphCentre,
                scale: committedZoom * zoom,
                offset: CGSize(
                    width: committedPan.width + pan.width,
                    height: committedPan.height + pan.height
                ),
                orbitHub: orbitHub,
                showsColdOnly: showsColdOnly,
                showsLabels: showsAllLabels || committedZoom * zoom > 0.75,
                now: renderedAt
            )
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
                    SelectionCard(node: selectedNode, graph: graph, now: renderedAt)
                        .padding(Theme.Space.md)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else if showsColdOnly {
                    ColdCard(count: coldCount)
                        .padding(Theme.Space.md)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .topTrailing) {
                controls
            }
            // Nodes with nothing joining them look identical to a broken map, so say which
            // one this is. Connections are found per capture against everything already
            // there, so the honest answer is "keep going", not "something went wrong".
            .overlay(alignment: .top) {
                if graph.edges.isEmpty, selection == nil, !showsColdOnly {
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

    private var controls: some View {
        VStack(spacing: Theme.Space.xs) {
            if isLayingOut {
                ProgressView()
                    .padding(Theme.Space.xxs)
            }

            // Two seconds of genuine use: dim everything you have been near lately, and
            // whatever is still burning is what you abandoned. Nothing else in the app can
            // answer that, because a list sorted by date tells you what is *recent*, never
            // what is missing.
            if coldCount > 0 {
                roundButton(
                    symbol: "moon.stars",
                    isOn: showsColdOnly,
                    label: "Show what has gone cold"
                ) {
                    release()
                    withAnimation(Theme.Motion.standard) { showsColdOnly.toggle() }
                }
            }

            if hasAdjusted {
                roundButton(
                    symbol: "arrow.up.left.and.arrow.down.right",
                    isOn: false,
                    label: "Fit everything on screen"
                ) {
                    withAnimation(Theme.Motion.standard) {
                        hasAdjusted = false
                        fitToContent()
                    }
                }
            }
        }
        .padding(Theme.Space.md)
    }

    private func roundButton(
        symbol: String,
        isOn: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isOn ? Theme.Palette.ember : Theme.Palette.inkMuted)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Theme.Palette.surface))
                .overlay(
                    Circle().strokeBorder(
                        isOn ? Theme.Palette.ember.opacity(0.5) : Theme.Palette.hairline,
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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

    private var showsAllLabels: Bool {
        graph.nodes.count <= Self.labelAllThreshold
    }

    // MARK: - Selection

    private func release() {
        selection = nil
        withAnimation(Theme.Motion.expressive) { focusProgress = 0 }
    }

    private func select(at location: CGPoint, in size: CGSize) {
        // Hit-tested against where the nodes are *drawn*, which while focused is the orbit
        // and not the layout. Anything else would mean tapping a satellite did nothing,
        // or worse, selected whatever used to be underneath it.
        let frame = MapCanvas.Frame(
            graph: graph,
            layout: layout,
            graphCentre: graphCentre,
            scale: committedZoom * zoom,
            offset: CGSize(
                width: committedPan.width + pan.width,
                height: committedPan.height + pan.height
            ),
            orbitHub: orbitHub,
            progress: focusProgress,
            size: size
        )

        var best: (id: UUID, distance: CGFloat)?
        for node in graph.nodes {
            guard let point = frame.position(of: node.id) else { continue }
            let distance = hypot(point.x - location.x, point.y - location.y)
            // A generous target: fingers are not precise, and a small satellite is small.
            guard distance < max(frame.radius(of: node.id) + 14, 26) else { continue }
            if best == nil || distance < best!.distance {
                best = (node.id, distance)
            }
        }

        guard let hit = best?.id else {
            // Tapping the ground releases, which is the cheapest possible way out of a
            // focus and the first thing anyone tries.
            if selection != nil { release() }
            return
        }

        if hit == selection {
            // Second tap on the same idea opens it. That is also where the importance
            // score can be corrected, which is the usual reason to be staring at a node
            // and disagreeing with how big it is.
            openedIdea = hit
            return
        }

        orbitHub = hit
        showsColdOnly = false
        withAnimation(Theme.Motion.expressive) {
            selection = hit
            focusProgress = 1
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
            release()
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
        renderedAt = .now

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

// MARK: - Metrics

/// The rules that turn an idea into a shape. Free functions rather than view methods so the
/// canvas, the hit test and the card all read from one definition.
enum MapMetrics {

    /// Full brightness for a week, then a slow fade to a floor. The floor exists because a
    /// node you cannot see is not information, it is an absence — the point is to notice
    /// the thing you abandoned, not to hide it.
    static func heat(_ node: GraphNode, now: Date) -> Double {
        let days = now.timeIntervalSince(node.updatedAt) / 86_400
        return max(0.18, 1 - max(0, days - 7) / 90)
    }

    static func days(_ node: GraphNode, now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(node.updatedAt) / 86_400))
    }

    /// A month untouched. Long enough not to catch things you are simply between sessions
    /// on, short enough to catch a thing that is genuinely slipping.
    static func isCold(_ node: GraphNode, now: Date) -> Bool {
        days(node, now: now) >= 30
    }

    /// Size at rest: how much this idea anchors, across everything.
    static func idleRadius(_ node: GraphNode, in graph: IdeaGraph) -> CGFloat {
        16 + CGFloat(graph.anchor(node)) * 30
    }

    /// Size while a hub is focused: how strongly this relates to *that*.
    ///
    /// The rule changes because the question changed. At rest you are asking what matters
    /// across the whole library; the moment you tap something you are asking what matters
    /// to it. Since both are answered by size, size has to mean both — and the eased
    /// transition between them is what teaches that, better than any legend would.
    static func focusRadius(
        _ node: GraphNode,
        hub: UUID,
        neighbours: Set<UUID>,
        in graph: IdeaGraph
    ) -> CGFloat {
        let idle = idleRadius(node, in: graph)
        if node.id == hub { return idle * 1.06 }
        guard neighbours.contains(node.id) else { return idle * 0.82 }
        let strength = graph.strength(between: node.id, and: hub)
        return 14 + CGFloat(0.30 * graph.anchor(node) + 0.70 * strength) * 28
    }

    /// Below this, a label cannot be read inside the disc at any font size worth shipping,
    /// so it goes underneath instead. "Lead Follow-Up Automation" is the case that decides
    /// this: shrinking it to fit produces something nobody can read at arm's length.
    static let insideLabelRadius: CGFloat = 25

    // MARK: Labels

    /// Rough advance width for SF Pro Text.
    ///
    /// Measuring properly would mean resolving a `Text` per word per node per frame, which
    /// is real cost during the gather. Being a character out on a line break inside a
    /// circle is not a mistake anyone can see; a dropped frame is.
    static func estimatedWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        CGFloat(text.count) * fontSize * 0.53
    }

    /// Greedy word wrap for a label sitting inside a disc.
    ///
    /// Anything that will not fit collapses onto the last line and is elided, rather than
    /// words silently disappearing off the end — a truncated title is honest, a title
    /// missing its last two words is a lie about what the idea is called.
    static func wrap(
        _ title: String,
        maxWidth: CGFloat,
        fontSize: CGFloat,
        maxLines: Int
    ) -> [String] {
        let words = title.split(separator: " ").map(String.init)
        guard !words.isEmpty, maxLines > 0 else { return [] }

        var lines: [String] = []
        var current = ""
        var index = 0

        while index < words.count {
            let candidate = current.isEmpty ? words[index] : current + " " + words[index]

            if estimatedWidth(candidate, fontSize: fontSize) > maxWidth, !current.isEmpty {
                // This word wants a new line. If there is no new line left, stop here and
                // let everything still unplaced collapse onto the last one.
                if lines.count == maxLines - 1 { break }
                lines.append(current)
                current = ""
                continue
            }

            current = candidate
            index += 1
        }

        if index < words.count {
            current = ([current] + words[index...]).filter { !$0.isEmpty }.joined(separator: " ")
        }

        if !current.isEmpty {
            lines.append(elide(current, maxWidth: maxWidth, fontSize: fontSize))
        }

        return lines
    }

    static func elide(_ text: String, maxWidth: CGFloat, fontSize: CGFloat) -> String {
        guard estimatedWidth(text, fontSize: fontSize) > maxWidth else { return text }
        let fits = max(1, Int(maxWidth / (fontSize * 0.53)) - 1)
        guard text.count > fits else { return text }
        return String(text.prefix(fits)) + "…"
    }
}

// MARK: - Canvas

/// The drawing, and the geometry it shares with hit testing.
///
/// `Animatable` on the view rather than an animation on the state: a plain `@State Double`
/// read inside a `Canvas` closure jumps to its new value instead of interpolating, because
/// nothing in the canvas is an animatable view property. Conforming here hands SwiftUI a
/// value it knows how to walk, and it re-invokes `body` for every step of the walk — which
/// is what makes the satellites *gather* rather than appear.
private struct MapCanvas: View, Animatable {

    var progress: Double

    let graph: IdeaGraph
    let layout: [UUID: CGPoint]
    let graphCentre: CGPoint
    let scale: CGFloat
    let offset: CGSize
    let orbitHub: UUID?
    let showsColdOnly: Bool
    let showsLabels: Bool
    let now: Date

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let frame = Frame(
                graph: graph,
                layout: layout,
                graphCentre: graphCentre,
                scale: scale,
                offset: offset,
                orbitHub: orbitHub,
                progress: progress,
                size: size
            )

            drawStarfield(in: context, size: size)
            drawEdges(in: context, frame: frame)
            drawNodes(in: context, frame: frame)
        }
    }

    // MARK: Ground

    /// A fixed, seeded starfield. Deterministic so the ground is a place rather than noise,
    /// and static so the map is not re-rendering sixty times a second on a screen people
    /// leave open — depth is worth a little; a permanent render loop is not.
    private static let starfield: [(point: CGPoint, radius: CGFloat, tier: Int)] = {
        var seed: UInt64 = 9_781
        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double((seed >> 33) % 100_000) / 100_000
        }
        return (0..<120).map { _ in
            let x = next()
            let y = next()
            let r = next()
            let t = next()
            return (
                point: CGPoint(x: x, y: y),
                radius: CGFloat(r * 1.3 + 0.3),
                tier: min(2, Int(t * 3))
            )
        }
    }()

    private static let starColor = Color(red: 0.81, green: 0.84, blue: 1.0)

    private func drawStarfield(in context: GraphicsContext, size: CGSize) {
        // Batched into three opacity tiers so the whole sky costs three fills rather than
        // a hundred and twenty.
        for tier in 0..<3 {
            var path = Path()
            for star in Self.starfield where star.tier == tier {
                let centre = CGPoint(x: star.point.x * size.width, y: star.point.y * size.height)
                path.addEllipse(in: CGRect(
                    x: centre.x - star.radius,
                    y: centre.y - star.radius,
                    width: star.radius * 2,
                    height: star.radius * 2
                ))
            }
            context.fill(path, with: .color(Self.starColor.opacity(0.10 + Double(tier) * 0.09)))
        }
    }

    // MARK: Edges

    private func drawEdges(in context: GraphicsContext, frame: Frame) {
        for edge in graph.edges {
            guard
                let a = frame.position(of: edge.source),
                let b = frame.position(of: edge.target)
            else { continue }

            let touchesHub = frame.orbitHub != nil
                && (edge.source == frame.orbitHub || edge.target == frame.orbitHub)

            // A gentle arc rather than a straight line. Two nodes joined by a segment read
            // as a diagram; the same pair joined by a curve reads as something grown. The
            // control point is perpendicular to the midpoint and always bends the same way,
            // so the picture stays stable.
            let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            let span = CGPoint(x: b.x - a.x, y: b.y - a.y)
            let length = max(hypot(span.x, span.y), 0.01)
            let bend = min(length * 0.12, 30)
            let control = CGPoint(
                x: mid.x - span.y / length * bend,
                y: mid.y + span.x / length * bend
            )

            var path = Path()
            path.move(to: a)
            path.addQuadCurve(to: b, control: control)

            let resting = 0.10 + edge.strength * 0.24
            let lifted = 0.30 + edge.strength * 0.48
            let faded = 0.05

            let opacity: Double
            let width: CGFloat
            if touchesHub {
                opacity = resting + (lifted - resting) * progress
                width = (0.8 + edge.strength * 1.6) + progress * (0.4 + edge.strength * 0.9)
            } else if frame.orbitHub != nil {
                opacity = resting + (faded - resting) * progress
                width = 0.8 + edge.strength * 1.4
            } else {
                opacity = resting
                width = 0.8 + edge.strength * 1.6
            }

            let tint = graph.node(edge.source)?.colorHex.flatMap { Color(hex: $0) }
                ?? Theme.Palette.ember

            context.stroke(
                path,
                with: .color(tint.opacity(opacity * coldFactor(edge))),
                style: StrokeStyle(
                    lineWidth: width,
                    lineCap: .round,
                    // Dashed for the "tension with" edges, so a disagreement between two
                    // ideas is legible without tapping.
                    dash: edge.kind == .contradicts ? [4, 5] : []
                )
            )
        }
    }

    /// While the cold filter is on, an edge is only as visible as its dimmer end.
    private func coldFactor(_ edge: GraphEdge) -> Double {
        guard showsColdOnly else { return 1 }
        let ends = [edge.source, edge.target].compactMap { graph.node($0) }
        guard ends.count == 2 else { return 0.2 }
        return ends.allSatisfy { MapMetrics.isCold($0, now: now) } ? 1 : 0.15
    }

    // MARK: Nodes

    private func drawNodes(in context: GraphicsContext, frame: Frame) {
        for node in graph.nodes {
            guard let point = frame.position(of: node.id) else { continue }

            let radius = frame.radius(of: node.id)
            let isHub = node.id == frame.orbitHub && progress > 0.01
            let alpha = alpha(for: node, frame: frame)
            let color = node.colorHex.flatMap { Color(hex: $0) } ?? Theme.Palette.ember

            guard alpha > 0.02 else { continue }

            // The halo. An idea is a light source here, not a dot — which is what separates
            // a map you want to look at from a scatter plot, and is only possible because
            // the app committed to a dark ground.
            let haloRadius = radius * 2.5
            context.fill(
                Circle().path(in: CGRect(
                    x: point.x - haloRadius,
                    y: point.y - haloRadius,
                    width: haloRadius * 2,
                    height: haloRadius * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        color.opacity((isHub ? 0.46 : 0.30) * alpha),
                        color.opacity(0),
                    ]),
                    center: point,
                    startRadius: radius * 0.4,
                    endRadius: haloRadius
                )
            )

            let rect = CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            )

            // Translucent body plus a bright ring, rather than a solid dot. The ring is what
            // makes it read as a bubble with a name in it instead of a marker on a chart —
            // and it is what lets a label sit inside without fighting the fill.
            let bodyOpacity = node.status == .done ? 0.06 : (isHub ? 0.24 : 0.16)
            context.fill(Circle().path(in: rect), with: .color(color.opacity(bodyOpacity * alpha)))

            context.stroke(
                Circle().path(in: rect),
                with: .color(color.opacity(0.95 * alpha)),
                style: StrokeStyle(
                    lineWidth: isHub ? 2.4 : 1.6,
                    // A finished idea reads as a dashed outline — present, no longer burning.
                    dash: node.status == .done ? [3, 4] : []
                )
            )

            guard showsLabels, alpha > 0.2 else { continue }
            drawLabel(node.title, in: context, at: point, radius: radius, alpha: alpha)
        }
    }

    private func alpha(for node: GraphNode, frame: Frame) -> Double {
        let full = MapMetrics.heat(node, now: now)

        if showsColdOnly {
            return MapMetrics.isCold(node, now: now) ? full : 0.08
        }

        guard let hub = frame.orbitHub else { return full }
        if node.id == hub || frame.neighbours.contains(node.id) { return full }

        // Everything else recedes rather than disappearing — context is what makes a
        // selection meaningful, and it comes back as the focus is released.
        return full + (0.12 - full) * progress
    }

    /// Anchors hold their name inside the disc; satellites get it underneath.
    ///
    /// Wrapping uses an estimated advance width rather than resolving each word. Measuring
    /// properly would mean a text resolve per word per node per frame, which is real cost
    /// during the gather, and being a character out on a line break inside a circle is not
    /// a mistake anyone can see.
    private func drawLabel(
        _ title: String,
        in context: GraphicsContext,
        at point: CGPoint,
        radius: CGFloat,
        alpha: Double
    ) {
        guard radius >= MapMetrics.insideLabelRadius else {
            context.draw(
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.Palette.ink.opacity(0.82 * alpha)),
                at: CGPoint(x: point.x, y: point.y + radius + 5),
                anchor: .top
            )
            return
        }

        let size = max(9, min(11.5, radius / 3.2))
        let lines = MapMetrics.wrap(title, maxWidth: radius * 1.72, fontSize: size, maxLines: 3)
        guard !lines.isEmpty else { return }

        let lineHeight = size * 1.16
        let top = point.y - (CGFloat(lines.count) - 1) / 2 * lineHeight

        for (index, line) in lines.enumerated() {
            context.draw(
                Text(line)
                    .font(.system(size: size, weight: .medium))
                    .foregroundStyle(Theme.Palette.ink.opacity(0.95 * alpha)),
                at: CGPoint(x: point.x, y: top + CGFloat(index) * lineHeight),
                anchor: .center
            )
        }
    }

    // MARK: Frame

    /// Everything positional for one draw, resolved once.
    ///
    /// Shared with hit testing so that what you tap and what you see can never disagree —
    /// during a focus they are two very different sets of coordinates.
    struct Frame {
        let orbitHub: UUID?
        let neighbours: Set<UUID>

        private let positions: [UUID: CGPoint]
        private let radii: [UUID: CGFloat]

        init(
            graph: IdeaGraph,
            layout: [UUID: CGPoint],
            graphCentre: CGPoint,
            scale: CGFloat,
            offset: CGSize,
            orbitHub: UUID?,
            progress: Double,
            size: CGSize
        ) {
            let hub = progress > 0.001 ? orbitHub : nil
            let neighbourSet = hub.map { graph.neighbours(of: $0) } ?? []
            self.orbitHub = hub
            self.neighbours = neighbourSet

            let viewCentre = CGPoint(x: size.width / 2, y: size.height / 2)
            let home: (CGPoint) -> CGPoint = { point in
                CGPoint(
                    x: (point.x - graphCentre.x) * scale + viewCentre.x + offset.width,
                    y: (point.y - graphCentre.y) * scale + viewCentre.y + offset.height
                )
            }

            // Target sizes first: the ring has to clear the discs it is arranging, so it
            // needs to know how big they will be before it can decide where they go.
            var targetRadii: [UUID: CGFloat] = [:]
            for node in graph.nodes {
                let idle = MapMetrics.idleRadius(node, in: graph)
                guard let hub else {
                    targetRadii[node.id] = idle
                    continue
                }
                let focused = MapMetrics.focusRadius(
                    node,
                    hub: hub,
                    neighbours: neighbourSet,
                    in: graph
                )
                targetRadii[node.id] = idle + (focused - idle) * progress
            }
            self.radii = targetRadii

            guard let hub, let hubNode = graph.node(hub) else {
                var resolved: [UUID: CGPoint] = [:]
                for node in graph.nodes {
                    guard let point = layout[node.id] else { continue }
                    resolved[node.id] = home(point)
                }
                self.positions = resolved
                return
            }

            let satellites = neighbours.map { id in
                MapFocusLayout.Satellite(
                    id: id,
                    strength: graph.strength(between: id, and: hub)
                )
            }

            let orbit = MapFocusLayout.positions(
                hub: hub,
                satellites: satellites,
                centre: viewCentre,
                hubRadius: MapMetrics.focusRadius(
                    hubNode,
                    hub: hub,
                    neighbours: neighbourSet,
                    in: graph
                ),
                satelliteRadius: { id in
                    graph.node(id).map {
                        MapMetrics.focusRadius($0, hub: hub, neighbours: neighbourSet, in: graph)
                    } ?? 20
                },
                in: size
            )

            var resolved: [UUID: CGPoint] = [:]
            for node in graph.nodes {
                guard let point = layout[node.id] else { continue }
                let start = home(point)
                let end = orbit[node.id]
                    ?? MapFocusLayout.pushedAside(start, centre: viewCentre, in: size)
                resolved[node.id] = CGPoint(
                    x: start.x + (end.x - start.x) * progress,
                    y: start.y + (end.y - start.y) * progress
                )
            }
            self.positions = resolved
        }

        func position(of id: UUID) -> CGPoint? { positions[id] }
        func radius(of id: UUID) -> CGFloat { radii[id] ?? 16 }
    }
}

/// `sheet(item:)` needs an `Identifiable`, and `UUID` alone is not.
private struct IdentifiableID: Identifiable {
    let id: UUID
}

// MARK: - Cards

private struct SelectionCard: View {
    let node: GraphNode
    let graph: IdeaGraph
    let now: Date

    /// Strongest first, so the card reads in the same order as the ring.
    private var attached: [(node: GraphNode, edge: GraphEdge)] {
        graph.edges
            .compactMap { edge -> (GraphNode, GraphEdge)? in
                let otherID: UUID
                if edge.source == node.id { otherID = edge.target }
                else if edge.target == node.id { otherID = edge.source }
                else { return nil }
                guard let other = graph.node(otherID) else { return nil }
                return (other, edge)
            }
            .sorted { $0.1.strength > $1.1.strength }
    }

    /// Why this node is the size it is, in the terms that produced it.
    ///
    /// The importance score has driven what resurfaces since the first build and has never
    /// been shown anywhere. Naming it here is half the fix; the other half is that tapping
    /// again opens the idea, where it can be disagreed with.
    private var reason: String {
        var parts: [String] = []
        if node.isGoal { parts.append("you're pursuing it") }
        if node.connections > 0 {
            parts.append("\(node.connections) connection\(node.connections == 1 ? "" : "s")")
        }
        parts.append("importance \(ImportanceLevel.nearest(to: node.importance).name.lowercased())")
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            Text(node.title)
                .font(Theme.Typography.ideaBody)
                .foregroundStyle(Theme.Palette.ink)
                .lineLimit(2)

            let days = MapMetrics.days(node, now: now)
            Text("\(attached.count) attached · \(days == 0 ? "touched today" : "\(days)d untouched")")
                .font(Theme.Typography.meta)
                .foregroundStyle(Theme.Palette.inkMuted)

            if let first = attached.first {
                Text("\(first.edge.kind.label) \(first.node.title) — \(first.edge.rationale)")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .lineLimit(2)
                    .padding(.top, 2)
            }

            Text(reason)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Theme.Palette.ember.opacity(0.85))
                .padding(.top, 2)

            Text("Tap again to open")
                .font(Theme.Typography.meta)
                .foregroundStyle(Theme.Palette.inkMuted.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}

private struct ColdCard: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            Text("\(count) idea\(count == 1 ? "" : "s") gone cold")
                .font(Theme.Typography.ideaBody)
                .foregroundStyle(Theme.Palette.ink)

            Text("Untouched for a month or more. Anything large here\nis something that mattered and then stopped.")
                .font(Theme.Typography.meta)
                .foregroundStyle(Theme.Palette.inkMuted)
                .lineSpacing(2)
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
