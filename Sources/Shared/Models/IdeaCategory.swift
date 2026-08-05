import Foundation
import SwiftData

/// A category, invented by the model rather than shipped with the app.
///
/// Remli deliberately starts with none. A fixed taxonomy would impose someone else's
/// mental model; letting categories emerge from real captures means they end up matching
/// how the person actually thinks. The cost is that the first few captures look
/// unstructured, which the empty state acknowledges rather than hides.
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

    /// The folder this one sits inside, if any.
    ///
    /// Emergent categories answer "what kind of thing is this" — Business, Health, Music.
    /// They do not answer "which of my three businesses". A second level does, without
    /// making the first capture of the day ask you to pick a project first: the model still
    /// files into a top-level folder, and you sort the inside out later, once there is
    /// enough there to be worth sorting.
    ///
    /// Deliberately one level of nesting only (enforced in the picker, not the model —
    /// a stored constraint would be a migration the day it needs relaxing). Deeper trees
    /// are a filing system, and a filing system is the thing this app exists to replace.
    var parent: IdeaCategory?

    @Relationship(deleteRule: .nullify, inverse: \IdeaCategory.parent)
    var children: [IdeaCategory]?

    init(name: String, colorHex: String? = nil, symbolName: String = "lightbulb", parent: IdeaCategory? = nil) {
        self.id = UUID()
        self.createdAt = .now
        self.name = name
        self.symbolName = symbolName
        self.parent = parent
        // A subfolder inherits its parent's colour, so a glance at the list still reads as
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
