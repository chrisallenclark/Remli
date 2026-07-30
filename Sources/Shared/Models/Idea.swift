import Foundation
import SwiftData

/// A captured thought.
///
/// **Every stored property has a default and every relationship is optional.** That is not
/// stylistic — it is what CloudKit requires of a SwiftData model. Getting this wrong only
/// shows up when sync is switched on, at which point fixing it means a migration, so the
/// constraint is honoured from the first commit even though CloudKit arrives later.
///
/// Note also that there are no `@Attribute(.unique)` constraints anywhere in the schema:
/// CloudKit does not support them.
@Model
final class Idea {

    // MARK: Identity

    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    // MARK: Content

    /// A short human title. Written by the model during enrichment; until then it is
    /// empty and the UI falls back to the first line of `text`.
    var title: String = ""

    /// The idea itself, as the user will read it back.
    var text: String = ""

    /// For voice captures, the untouched transcript before any clean-up. Kept so a bad
    /// tidy-up is always recoverable. The audio itself is never retained.
    var transcriptRaw: String?

    // MARK: Classification

    var kindRaw: String = IdeaKind.idea.rawValue
    var statusRaw: String = IdeaStatus.seed.rawValue
    var captureModeRaw: String = CaptureMode.text.rawValue

    var tags: [String] = []

    /// 0–1, written during enrichment. Feeds the resurfacing score.
    var importanceScore: Double = 0

    /// Rough effort in minutes. Used to match an idea to a gap in the calendar — there is
    /// no point suggesting a two-day project for a twenty-minute window.
    var estimatedMinutes: Int = 0

    var pinned: Bool = false

    // MARK: Resurfacing state

    /// Set when the user explicitly snoozes an idea to a date.
    var remindAt: Date?
    var lastSurfacedAt: Date?
    var surfaceCount: Int = 0

    // MARK: Machine state

    /// False until the intelligence layer has been over this idea. Capture writes the
    /// record immediately and enrichment patches it afterwards, so an un-enriched idea is
    /// a completely normal state, not an error.
    var isEnriched: Bool = false

    /// Counts failed enrichment attempts so a thought the model consistently chokes on
    /// gets left alone rather than retried on every single app launch forever.
    var enrichmentAttempts: Int = 0

    /// Sentence embedding, stored as packed little-endian `Float32`. `Data` rather than
    /// `[Double]` keeps the record small enough that CloudKit sync stays cheap.
    var embedding: Data?

    // MARK: Relationships

    var category: IdeaCategory?

    @Relationship(deleteRule: .cascade, inverse: \IdeaLink.source)
    var outgoingLinks: [IdeaLink]?

    @Relationship(deleteRule: .cascade, inverse: \IdeaLink.target)
    var incomingLinks: [IdeaLink]?

    // MARK: Init

    init(
        text: String,
        kind: IdeaKind = .idea,
        captureMode: CaptureMode = .text,
        transcriptRaw: String? = nil
    ) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.text = text
        self.kindRaw = kind.rawValue
        self.captureModeRaw = captureMode.rawValue
        self.transcriptRaw = transcriptRaw
    }
}

// MARK: - Typed accessors

extension Idea {
    var kind: IdeaKind {
        get { IdeaKind(rawValue: kindRaw) ?? .idea }
        set { kindRaw = newValue.rawValue }
    }

    var status: IdeaStatus {
        get { IdeaStatus(rawValue: statusRaw) ?? .seed }
        set { statusRaw = newValue.rawValue }
    }

    var captureMode: CaptureMode {
        get { CaptureMode(rawValue: captureModeRaw) ?? .text }
        set { captureModeRaw = newValue.rawValue }
    }

    /// What to show as a heading. Enrichment may not have run — or may have failed — so
    /// this always has something sensible to fall back on.
    var displayTitle: String {
        if !title.isEmpty { return title }

        let firstLine = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""

        if firstLine.isEmpty { return "Untitled" }
        return firstLine.count <= 60 ? firstLine : String(firstLine.prefix(60)) + "…"
    }

    /// Every link touching this idea, in either direction.
    var allLinks: [IdeaLink] {
        (outgoingLinks ?? []) + (incomingLinks ?? [])
    }

    func touch() {
        updatedAt = .now
    }
}
