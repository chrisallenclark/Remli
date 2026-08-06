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
    struct Draft {

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

    // MARK: - Connections

    @Generable
    struct LinkDraft {

        @Guide(description: "The number of the related idea, taken from the numbered list.", .range(1...12))
        var ideaNumber: Int

        @Guide(description: "How the new idea relates to that one.", .anyOf([
            "relatesTo", "buildsOn", "prerequisiteFor", "variantOf", "contradicts",
        ]))
        var relationship: String

        @Guide(description: "One sentence, at most twenty words, naming the specific thing the two share. Refer to concrete details from both. Never say they are 'related' or 'similar' without saying how.")
        var reason: String

        @Guide(description: "1 means a tenuous stretch, 5 means they are obviously the same thread of thinking.", .range(1...5))
        var strength: Int
    }

    @Generable
    struct LinkJudgement {
        @Guide(description: "Only genuinely meaningful connections. Most pairs of ideas are unrelated, so returning an empty list is normal and correct.", .maximumCount(4))
        var links: [LinkDraft]
    }

    private static let connectionInstructions = """
        You find real relationships between someone's captured ideas.

        You are strict. A shared topic is not a relationship. Two ideas are connected only \
        if knowing one would genuinely change how the person thinks about or acts on the \
        other. When in doubt, leave it out — a wrong connection costs far more trust than \
        a missed one.

        Relationship meanings:
        - prerequisiteFor: the new idea must happen before the other one can
        - buildsOn: the new idea extends or elaborates the other
        - variantOf: another approach to the same underlying goal
        - contradicts: acting on both is inconsistent
        - relatesTo: genuinely same territory, but none of the above
        """

    func judgeConnections(
        source: IdeaSummary,
        candidates: [IdeaSummary]
    ) async throws -> [ProposedLink] {
        guard isAvailable else { throw IntelligenceError.unavailable }
        guard !candidates.isEmpty else { return [] }

        let shortlist = Array(candidates.prefix(12))

        var prompt = "New idea:\n\(source.title)\n\(source.excerpt)\n\nExisting ideas:\n"
        for (offset, candidate) in shortlist.enumerated() {
            prompt += "\(offset + 1). \(candidate.title) — \(candidate.excerpt)\n"
        }

        let session = LanguageModelSession(instructions: Self.connectionInstructions)
        let response = try await session.respond(
            to: prompt,
            generating: LinkJudgement.self,
            options: GenerationOptions(temperature: 0.2)
        )

        var seen = Set<UUID>()
        var results: [ProposedLink] = []

        for draft in response.content.links {
            // The range guide constrains this to 1...12, but the shortlist may be
            // shorter than twelve, so the bound still has to be checked.
            let index = draft.ideaNumber - 1
            guard shortlist.indices.contains(index) else { continue }

            let target = shortlist[index]
            guard seen.insert(target.id).inserted else { continue }

            let reason = draft.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            // A link whose explanation is missing or vacuous is not worth showing.
            guard reason.count >= 12 else { continue }

            results.append(
                ProposedLink(
                    targetID: target.id,
                    kind: LinkKind(rawValue: draft.relationship) ?? .relatesTo,
                    rationale: reason,
                    strength: (Double(draft.strength) - 1) / 4
                )
            )
        }

        return results
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

extension FoundationModelsIntelligence {

    // MARK: - Working an idea forward

    @Generable
    struct DevelopmentDraft {

        @Guide(description: "The idea said back in one plain sentence. Strip the hedging and the thinking-out-loud, keep the substance. Do not add anything that was not there.")
        var restatement: String

        @Guide(description: "Concrete things to do next, smallest first. Each must be doable in an afternoon and specific to this idea — never generic advice like 'do market research'.", .maximumCount(5))
        var steps: [StepDraft]

        @Guide(description: "Questions whose answers would genuinely unblock this. Ask about the things you cannot know: who it is for, what the cheapest test is, what would make it fail. Never ask something the idea already answers.", .maximumCount(3))
        var questions: [String]
    }

    @Generable
    struct StepDraft {
        @Guide(description: "An action, starting with a verb. Under ten words.")
        var title: String

        @Guide(description: "One short sentence on why this step comes now rather than later.")
        var reason: String
    }

    func developIdea(_ idea: IdeaSummary, related: [IdeaSummary]) async throws -> IdeaDevelopment {
        guard isAvailable else { throw IntelligenceError.unavailable }

        let session = LanguageModelSession(instructions: Self.developmentInstructions)

        let draft = try await session.respond(
            to: Self.developmentPrompt(for: idea, related: related),
            generating: DevelopmentDraft.self,
            // Warmer than filing. Filing should be repeatable; this should be useful, and
            // the interesting step is rarely the most probable one.
            options: GenerationOptions(temperature: 0.7)
        ).content

        let steps = draft.steps
            .map { step in
                DevelopmentStep(
                    title: step.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    reason: step.reason.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            .filter { !$0.title.isEmpty }

        let questions = draft.questions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let restatement = draft.restatement.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !steps.isEmpty || !questions.isEmpty else {
            throw IntelligenceError.unusableResult
        }

        return IdeaDevelopment(
            restatement: restatement.isEmpty ? idea.title : restatement,
            steps: steps,
            questions: questions
        )
    }

    private static let developmentInstructions = """
        You help someone move one of their own ideas forward.

        You are not a consultant and you are not writing a business plan. Everything you \
        suggest must be small enough to start this week and specific enough that they could \
        not have written it about any other idea.

        IMPORTANT: some ideas are a few words long, or named with a joke or a pun. If you \
        cannot tell what the thing actually is or who it is for, do not guess and do not \
        invent a business around the name. Ask. A question like "what does this actually \
        involve day to day?" is far more useful than five confident steps for the wrong \
        idea. Suggest no steps at all rather than steps built on a guess.

        Never suggest research, brainstorming, or "define your goals". Never pad the list — \
        two real steps beat five vague ones. If their other ideas are relevant, refer to \
        them by name.
        """

    private static func developmentPrompt(for idea: IdeaSummary, related: [IdeaSummary]) -> String {
        var prompt = """
            The idea:
            \(idea.title)
            \(idea.excerpt)
            """

        // Everything cheap that disambiguates a short or oddly-named idea. Without this the
        // model is reading a pun with no context and filling the gap with invention.
        if let space = idea.spaceName {
            prompt += "\n\nFiled under: \(space)"
        }
        if !idea.tags.isEmpty {
            prompt += "\nTagged: \(idea.tags.joined(separator: ", "))"
        }

        if !related.isEmpty {
            // Their own material. This is the difference between a generic plan and one
            // that can say "you already thought of this".
            let list = related.prefix(6)
                .map { "- \($0.title): \($0.excerpt)" }
                .joined(separator: "\n")

            prompt += """


                Other ideas they have already captured that connect to this one:
                \(list)
                """
        }

        return prompt
    }
}
