import Foundation
import NaturalLanguage

/// The floor. No model, no network, no Apple Intelligence required.
///
/// This exists so the app is never *broken* — on an older iPhone, with Apple Intelligence
/// switched off, or while the system model is still downloading, ideas still get a title,
/// a few tags and a home. It is deliberately modest: it does not pretend to understand the
/// thought, it just organises it enough to be findable.
struct HeuristicIntelligence: IdeaIntelligence {

    var displayName: String { "Basic (no AI)" }

    /// Always. That is the entire point of a fallback.
    var isAvailable: Bool { true }

    func enrich(text: String, existingCategories: [String]) async throws -> IdeaEnrichment {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw IntelligenceError.emptyInput }

        let keywords = Self.keywords(in: trimmed)

        return IdeaEnrichment(
            kind: Self.looksLikeTask(trimmed) ? .task : .idea,
            title: Self.title(from: trimmed),
            // No inference is attempted here. Guessing a category badly is worse than
            // admitting there isn't one — and "Unfiled" is honest and re-filable later
            // once a real model is available.
            categoryName: "Unfiled",
            categorySymbol: "tray",
            tags: keywords,
            importance: 0.5,
            estimatedMinutes: 30
        )
    }

    /// Without a language model there is no way to say *why* two ideas connect, and an
    /// invented reason would be worse than none. So this reports only what it can actually
    /// justify — the specific words the two ideas share — and only for the strongest
    /// candidate, which the recall stage already ranked first.
    func judgeConnections(
        source: IdeaSummary,
        candidates: [IdeaSummary]
    ) async throws -> [ProposedLink] {
        guard let best = candidates.first else { return [] }

        let sourceWords = Similarity.significantWords(in: "\(source.title) \(source.excerpt)")
        let targetWords = Similarity.significantWords(in: "\(best.title) \(best.excerpt)")
        let shared = sourceWords.intersection(targetWords).sorted().prefix(3)

        guard shared.count >= 2 else { return [] }

        return [
            ProposedLink(
                targetID: best.id,
                kind: .relatesTo,
                rationale: "Both mention \(ListFormatter.localizedString(byJoining: Array(shared))).",
                strength: Similarity.jaccard(sourceWords, targetWords)
            )
        ]
    }

    // MARK: - Task detection

    /// Openers that reliably mean "chore", not "idea". Kept deliberately narrow: a false
    /// positive buries a real idea outside the graph, which is the more costly mistake.
    private static let taskOpeners = [
        "remind me", "remember to", "need to", "have to", "must ",
        "todo", "to-do", "don't forget", "dont forget", "book ",
        "call ", "email ", "text ", "buy ", "pick up", "schedule ",
    ]

    static func looksLikeTask(_ text: String) -> Bool {
        let lowered = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Only check the opening — "an app that reminds me to stretch" is an idea, and the
        // phrase appears mid-sentence there.
        let opening = String(lowered.prefix(40))
        return taskOpeners.contains { opening.hasPrefix($0) || opening.hasPrefix("i \($0)") }
    }

    // MARK: - Title

    static func title(from text: String) -> String {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var firstSentence = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            firstSentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            return false
        }

        let cleaned = firstSentence.trimmingCharacters(in: CharacterSet(charactersIn: ".,;: "))
        guard !cleaned.isEmpty else { return String(text.prefix(60)) }
        return cleaned.count <= 70 ? cleaned : String(cleaned.prefix(70)) + "…"
    }

    // MARK: - Tags

    /// Nouns, in order of appearance, deduplicated. Crude, but it produces tags a person
    /// would plausibly search for, which is all a tag needs to do.
    static func keywords(in text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        var seen = Set<String>()
        var result: [String] = []

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitPunctuation, .omitWhitespace, .omitOther]
        ) { tag, range in
            guard tag == .noun else { return true }

            let word = String(text[range]).lowercased()
            guard word.count > 3, word.count <= 24, !Self.stopWords.contains(word) else { return true }
            guard seen.insert(word).inserted else { return true }

            result.append(word)
            return result.count < 4
        }

        return result
    }

    private static let stopWords: Set<String> = [
        "thing", "things", "stuff", "idea", "ideas", "note", "notes",
        "something", "anything", "someone", "people", "time", "way", "ways",
        "lot", "bit", "kind", "sort", "today", "tomorrow", "yesterday",
    ]
    // MARK: - Working an idea forward

    /// With no model available, only the questions are honest.
    ///
    /// A heuristic cannot propose a step specific to an idea it does not understand, and a
    /// generic step — "research the market", "make a plan" — is worse than nothing: it looks
    /// like help and teaches the person that the feature is filler. Questions do not have
    /// that problem. They make no claim about the idea, and answering one produces a step
    /// the person wrote themselves, which was always the better step anyway.
    func developIdea(_ idea: IdeaSummary, related: [IdeaSummary]) async throws -> IdeaDevelopment {
        var questions = [
            "What is the smallest version of this you could put in front of one person this week?",
            "Who is the first person who would use this, by name?",
            "What has to be true for this to work — and how would you find out cheaply?",
        ]

        // The one thing a heuristic genuinely knows: what else is connected. Naming it is
        // real information rather than a guess dressed up as advice.
        if let first = related.first {
            questions.append("Does \(first.title) belong inside this, or is it a separate thing?")
        }

        return IdeaDevelopment(
            restatement: idea.title,
            steps: [],
            questions: questions
        )
    }
}
