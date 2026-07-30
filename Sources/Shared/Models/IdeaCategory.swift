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

    init(name: String, colorHex: String? = nil, symbolName: String = "lightbulb") {
        self.id = UUID()
        self.createdAt = .now
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex ?? Self.suggestedColor(for: name)
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
}
