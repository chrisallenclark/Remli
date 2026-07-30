import Foundation
import FoundationModels

/// Enrichment using Apple's on-device model.
///
/// This is the default. It costs nothing, works on a plane, and no idea ever leaves the
/// phone — which is also why it needs no consent screen, unlike the optional Claude
/// provider.
///
/// Output shape is enforced by `@Generable`: the framework constrains decoding at the
/// token level, so the model *cannot* return malformed JSON or a field of the wrong type.
/// That removes the entire class of parsing and repair code these integrations usually need.
struct FoundationModelsIntelligence: IdeaIntelligence {

    var displayName: String { "On-device (Apple Intelligence)" }

    var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Why the model is unavailable, for Settings to explain rather than just grey out.
    static var unavailabilityReason: String? {
        guard case .unavailable(let reason) = SystemLanguageModel.default.availability else {
            return nil
        }
        switch reason {
        case .deviceNotEligible:
            return "This iPhone doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is turned off. Enable it in Settings to let Remli file ideas automatically."
        case .modelNotReady:
            return "Apple Intelligence is still downloading. Remli will start filing ideas once it's ready."
        @unknown default:
            return "Apple Intelligence isn't available right now."
        }
    }

    // MARK: - Generation

    /// Constraining the symbol to a fixed list at generation time is the difference
    /// between a category that always has an icon and one that sometimes renders blank.
    /// The model physically cannot emit a value outside this set.
    @Generable
    private struct Draft {

        @Guide(description: "True only if this is a chore or errand to tick off, like 'call the dentist'. False for anything exploratory, creative or worth developing.")
        var isQuickTask: Bool

        @Guide(description: "A short noun phrase naming the idea. Three to seven words. No trailing punctuation, no quotes.")
        var title: String

        @Guide(description: "One or two words. Broad enough that many future ideas could share it. Prefer an existing category when one fits.")
        var category: String

        @Guide(description: "An icon suiting the category.", .anyOf([
            "lightbulb", "paintbrush", "hammer", "chart.line.uptrend.xyaxis",
            "book", "heart", "figure.run", "dollarsign.circle",
            "person.2", "house", "airplane", "music.note",
            "camera", "gearshape", "leaf", "brain",
            "briefcase", "graduationcap", "fork.knife", "gamecontroller",
        ]))
        var symbol: String

        @Guide(description: "Two to four single-word lowercase tags drawn from the thought itself.", .maximumCount(4))
        var tags: [String]

        @Guide(description: "How much this seems to matter to the person who wrote it. 1 is a passing remark, 5 is something they clearly care about.", .range(1...5))
        var importance: Int

        @Guide(description: "Rough minutes of focused work to make a first meaningful dent in this. Not the whole project.", .range(5...480))
        var estimatedMinutes: Int
    }

    private static let instructions = """
        You file captured thoughts for someone's personal idea journal.

        Be literal. Describe only what is actually in the text — never invent detail, \
        never embellish, never assume a domain that wasn't mentioned. If a thought is \
        vague, a vague title is the correct answer.
        """

    func enrich(text: String, existingCategories: [String]) async throws -> IdeaEnrichment {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw IntelligenceError.emptyInput }
        guard isAvailable else { throw IntelligenceError.unavailable }

        // A fresh session per enrichment. These are independent one-shot calls, so
        // carrying a transcript between them would only burn context and eventually
        // throw `exceededContextWindowSize` for no benefit.
        let session = LanguageModelSession(instructions: Self.instructions)

        let draft: Draft
        do {
            let response = try await session.respond(
                to: Self.prompt(for: trimmed, existingCategories: existingCategories),
                generating: Draft.self,
                // Low temperature: filing should be stable. The same thought captured
                // twice should not land in two different categories.
                options: GenerationOptions(temperature: 0.3)
            )
            draft = response.content
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            // A single capture longer than the context window. Retry on a truncated
            // version rather than giving up — the opening is usually the substance.
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(
                to: Self.prompt(for: String(trimmed.prefix(2000)), existingCategories: existingCategories),
                generating: Draft.self,
                options: GenerationOptions(temperature: 0.3)
            )
            draft = response.content
        }

        return draft.normalized(fallbackTitle: trimmed)
    }

    private static func prompt(for text: String, existingCategories: [String]) -> String {
        var prompt = ""

        if !existingCategories.isEmpty {
            // Listing what already exists is what stops the category set fragmenting into
            // "Business", "business ideas" and "Biz" over a few weeks.
            let list = existingCategories.prefix(24).joined(separator: ", ")
            prompt += """
                Categories already in use: \(list)
                Reuse one of these exactly if it fits. Invent a new one only if none do.


                """
        }

        prompt += """
            Thought:
            \(text)
            """

        return prompt
    }

    /// Warms the model so the first real enrichment isn't paying for cold start.
    /// Called when the capture sheet opens, since a capture almost always follows.
    static func prewarm() {
        guard case .available = SystemLanguageModel.default.availability else { return }
        LanguageModelSession(instructions: instructions).prewarm()
    }
}

// MARK: - Normalisation

private extension FoundationModelsIntelligence.Draft {

    /// Guided generation guarantees the *shape* of the output, not its taste. This is
    /// where a technically-valid-but-scruffy result gets tidied.
    func normalized(fallbackTitle: String) -> IdeaEnrichment {
        IdeaEnrichment(
            kind: isQuickTask ? .task : .idea,
            title: Self.cleanTitle(title, fallback: fallbackTitle),
            categoryName: Self.cleanCategory(category),
            categorySymbol: symbol,
            tags: Self.cleanTags(tags),
            importance: (Double(importance) - 1) / 4,
            estimatedMinutes: estimatedMinutes
        )
    }

    static func cleanTitle(_ raw: String, fallback: String) -> String {
        var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”.,;:"))

        guard !title.isEmpty else {
            return String(fallback.prefix(60))
        }
        return title.count <= 80 ? title : String(title.prefix(80))
    }

    static func cleanCategory(_ raw: String) -> String {
        let category = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”.,;:"))

        guard !category.isEmpty else { return "Unfiled" }

        // Title-case single words so "business" and "Business" never coexist.
        return category.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    static func cleanTags(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for tag in raw {
            let cleaned = tag
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "#\"'.,;:"))
                .lowercased()

            guard !cleaned.isEmpty, cleaned.count <= 24, seen.insert(cleaned).inserted else { continue }
            result.append(cleaned)
        }

        return Array(result.prefix(4))
    }
}
