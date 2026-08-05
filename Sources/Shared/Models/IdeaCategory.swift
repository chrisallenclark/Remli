import Foundation
import SwiftData

/// A **Space** — or, one level down, a **Collection** inside one.
///
/// Both are this one type, distinguished only by whether `parent` is set. Two levels is
/// the whole hierarchy, deliberately: Space → Collection → Idea, with tags cutting across
/// all of it. Anything deeper is a filing system, and a filing system is the thing this
/// app exists to replace.
///
/// Remli ships with no Spaces at all. A fixed taxonomy would impose someone else's mental
/// model; letting Spaces emerge from real captures means they end up matching how the
/// person actually thinks. The cost is that the first few captures look unstructured,
/// which the empty state acknowledges rather than hides.
///
/// **The type is still called `IdeaCategory` on purpose.** A SwiftData model's class name
/// is its CloudKit record type, so renaming this would orphan every record already synced
/// to a device. "Space" is the language in the interface; the schema keeps the name it was
/// born with. Do not rename it without a migration plan.
@Model
final class IdeaCategory {

    var id: UUID = UUID()
    var createdAt: Date = Date.now

    var name: String = ""

    /// Six-digit RRGGBB, no leading hash. Assigned round-robin from `Self.palette` when
    /// the category is created, so the colour set stays harmonious no matter what the
    /// model names things.
    var colorHex: String = "B4561A"

    /// An SF Symbol name chosen at creation. Validated before use — a hallucinated symbol
    /// name would otherwise render as a blank space.
    var symbolName: String = "lightbulb"

    @Relationship(deleteRule: .nullify, inverse: \Idea.category)
    var ideas: [Idea]?

    /// The Space this Collection sits inside. Nil means this *is* a Space.
    ///
    /// A Space answers "what part of my life is this" — Business, Health, Macrova. It does
    /// not answer "which of my three businesses". A Collection does, without making the
    /// first capture of the day ask you to pick a project: the model still files into a
    /// Space, and you sort the inside out later, once there is enough there to be worth
    /// sorting.
    var parent: IdeaCategory?

    @Relationship(deleteRule: .nullify, inverse: \IdeaCategory.parent)
    var children: [IdeaCategory]?

    /// True when a person named this, false when the model proposed it.
    ///
    /// This is what stops Spaces being quietly reshaped underneath you. The model may
    /// suggest a Space, and until you touch it, it stays a suggestion that later passes are
    /// free to rename or merge. The moment you create or rename one yourself it becomes
    /// yours, and enrichment may file *into* it but never edits it.
    ///
    /// Defaults to false so every Space that already exists — all of them model-invented —
    /// keeps its current behaviour after the migration.
    var isUserOwned: Bool = false

    init(
        name: String,
        colorHex: String? = nil,
        symbolName: String = "lightbulb",
        parent: IdeaCategory? = nil,
        isUserOwned: Bool = false
    ) {
        self.id = UUID()
        self.createdAt = .now
        self.name = name
        self.symbolName = symbolName
        self.parent = parent
        self.isUserOwned = isUserOwned
        // A Collection inherits its Space's colour, so a glance at the list still reads as
        // "these three things are all Business" before you read a single word.
        self.colorHex = colorHex ?? parent?.colorHex ?? Self.suggestedColor(for: name)
    }
}

extension IdeaCategory {

    /// A deliberately small, harmonious set. Restricting the model to these keeps the app
    /// looking designed rather than letting it pick arbitrary colours.
    static let palette: [String] = [
        "B4561A", // ember
        "1F6F63", // pine
        "5B4B8A", // iris
        "A03D5B", // rose
        "3A6EA5", // slate blue
        "7A6220", // olive
        "8A4B2A", // clay
        "45636F", // steel
    ]

    /// Stable per name, so a category keeps its colour across devices without needing the
    /// choice synced, and the same name never flickers between colours.
    static func suggestedColor(for name: String) -> String {
        guard !palette.isEmpty else { return "B4561A" }
        var hash: UInt64 = 5381
        for byte in name.lowercased().utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        return palette[Int(hash % UInt64(palette.count))]
    }

    var ideaCount: Int { ideas?.count ?? 0 }

    // MARK: - Hierarchy

    /// How deep this sits. 0 for a top-level folder.
    ///
    /// Every walk up the chain is bounded. A parent cycle should be impossible — the picker
    /// refuses to create one — but a corrupt or badly merged CloudKit record must not be
    /// able to hang the UI, and these run inside view bodies.
    var depth: Int {
        var count = 0
        var current = parent
        while let node = current, count < 8 {
            count += 1
            current = node.parent
        }
        return count
    }

    var isRoot: Bool { parent == nil }

    /// A Space is a top-level container; a Collection lives inside one. Same type, and the
    /// only thing separating them is `parent`.
    var isSpace: Bool { parent == nil }
    var isCollection: Bool { parent != nil }

    /// What to call this in the interface, so copy never has to branch on `parent` itself.
    var kindLabel: String { isSpace ? "Space" : "Collection" }

    /// The top-level folder this belongs to — itself, when it is already top-level.
    var rootFolder: IdeaCategory {
        var current = self
        var guardCount = 0
        while let next = current.parent, guardCount < 8 {
            current = next
            guardCount += 1
        }
        return current
    }

    var sortedChildren: [IdeaCategory] {
        (children ?? []).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// "Business › Meal Prep", or just "Business" at the top level.
    var displayPath: String {
        guard let parent else { return name }
        return "\(parent.name) › \(name)"
    }

    /// Ideas filed here plus everything in the subfolders, which is what a count next to a
    /// parent folder has to mean — otherwise "Business 0" sits above three subfolders that
    /// between them hold everything.
    var totalIdeaCount: Int {
        ideaCount + (children ?? []).reduce(0) { $0 + $1.ideaCount }
    }

    /// True when `other` is this folder or one of its subfolders. Used to keep the picker
    /// from reparenting a folder into its own descendant.
    func contains(_ other: IdeaCategory) -> Bool {
        if other.id == id { return true }
        return (children ?? []).contains { $0.id == other.id }
    }
}
