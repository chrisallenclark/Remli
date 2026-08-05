import Foundation

/// Which Claude model to use. Opus is the default; the others exist because model choice
/// is the user's call, not the app's — they are paying for it.
enum ClaudeModel: String, Codable, CaseIterable, Sendable {
    case opus = "claude-opus-5"
    case sonnet = "claude-sonnet-5"
    case haiku = "claude-haiku-4-5"

    var displayName: String {
        switch self {
        case .opus: return "Opus — best quality"
        case .sonnet: return "Sonnet — balanced"
        case .haiku: return "Haiku — fastest, cheapest"
        }
    }
}

/// Optional enrichment via the Anthropic Messages API.
///
/// **Off unless the user explicitly turns it on**, behind a consent screen, because this
/// is the only path in Remli where an idea leaves the phone. That is a product decision
/// first and an App Review requirement second (Guideline 5.1.2(i), Nov 2025).
///
/// Swift has no official Anthropic SDK, so this talks to `/v1/messages` directly over
/// URLSession.
struct ClaudeIntelligence: IdeaIntelligence {

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let apiVersion = "2023-06-01"

    /// Opts into server-side fallbacks. Claude's safety classifiers can decline a
    /// request, and a captured idea about, say, security research is exactly the kind of
    /// benign input that can trip one. With this set, the API silently re-runs the
    /// request on a fallback model instead of handing back a refusal.
    private static let fallbackBeta = "server-side-fallback-2026-07-01"

    let model: ClaudeModel
    private let apiKey: String?
    private let session: URLSession

    init(model: ClaudeModel = .opus, apiKey: String? = KeychainStore.read(), session: URLSession = .shared) {
        self.model = model
        self.apiKey = apiKey
        self.session = session
    }

    var displayName: String { "Claude (\(model.rawValue))" }

    var isAvailable: Bool { apiKey != nil }

    // MARK: - Enrichment

    func enrich(text: String, existingCategories: [String]) async throws -> IdeaEnrichment {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw IntelligenceError.emptyInput }

        var prompt = ""
        if !existingCategories.isEmpty {
            let list = existingCategories.prefix(24).joined(separator: ", ")
            prompt += "Categories already in use: \(list)\n"
            prompt += "Reuse one of these exactly if it fits. Invent a new one only if none do.\n\n"
        }
        prompt += "Thought:\n\(trimmed)"

        let json = try await send(
            system: Self.enrichmentInstructions,
            prompt: prompt,
            schema: Self.enrichmentSchema
        )

        let draft = try JSONDecoder().decode(EnrichmentDraft.self, from: json)
        return draft.normalized(fallbackTitle: trimmed)
    }

    // MARK: - Connections

    func judgeConnections(
        source: IdeaSummary,
        candidates: [IdeaSummary]
    ) async throws -> [ProposedLink] {
        guard !candidates.isEmpty else { return [] }
        let shortlist = Array(candidates.prefix(12))

        var prompt = "New idea:\n\(source.title)\n\(source.excerpt)\n\nExisting ideas:\n"
        for (offset, candidate) in shortlist.enumerated() {
            prompt += "\(offset + 1). \(candidate.title) — \(candidate.excerpt)\n"
        }

        let json = try await send(
            system: Self.connectionInstructions,
            prompt: prompt,
            schema: Self.connectionSchema
        )

        let judgement = try JSONDecoder().decode(LinkJudgement.self, from: json)

        var seen = Set<UUID>()
        var results: [ProposedLink] = []

        for draft in judgement.links {
            let index = draft.ideaNumber - 1
            guard shortlist.indices.contains(index) else { continue }

            let target = shortlist[index]
            guard seen.insert(target.id).inserted else { continue }

            let reason = draft.reason.trimmingCharacters(in: .whitespacesAndNewlines)
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

    // MARK: - Transport

    /// Sends one request and returns the raw JSON body of the reply.
    ///
    /// `output_config.format` constrains the response to the given JSON Schema, which is
    /// the direct analogue of `@Generable` on the on-device path — the model cannot return
    /// a malformed shape, so there is no parsing-and-repair layer here either.
    private func send(system: String, prompt: String, schema: [String: Any]) async throws -> Data {
        guard let apiKey else { throw IntelligenceError.unavailable }

        let body: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 2048,
            "system": system,
            "messages": [["role": "user", "content": prompt]],
            // Thinking is on by default on Opus 5 and deliberately left on: disabling it
            // is a documented source of stray internal tags leaking into the output,
            // which would corrupt the JSON. Low effort keeps it cheap instead.
            "output_config": ["effort": "low", "format": schema],
            "fallbacks": "default",
        ]
        // Note: temperature / top_p / top_k are absent on purpose — the current models
        // reject them outright rather than ignoring them.

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(Self.fallbackBeta, forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ClaudeError.transport
        }

        guard http.statusCode == 200 else {
            throw ClaudeError.from(status: http.statusCode, body: data)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let message = try decoder.decode(MessagesResponse.self, from: data)

        // Check the stop reason before touching content. A refused request still returns
        // HTTP 200, with content either empty or partial — indexing into it blindly is
        // the classic way this integration breaks.
        if message.stopReason == "refusal" {
            throw ClaudeError.refused(category: message.stopDetails?.category)
        }

        // Find the text block rather than taking content[0]: with thinking enabled the
        // first block is a thinking block, whose text is empty.
        guard
            let text = message.content.first(where: { $0.type == "text" })?.text,
            let json = text.data(using: .utf8)
        else {
            throw ClaudeError.emptyResponse
        }

        return json
    }

    // MARK: - Wire types

    private struct MessagesResponse: Decodable {
        struct ContentBlock: Decodable {
            let type: String
            let text: String?
        }
        struct StopDetails: Decodable {
            let category: String?
        }
        let content: [ContentBlock]
        let stopReason: String?
        let stopDetails: StopDetails?
    }

    private struct EnrichmentDraft: Decodable {
        var isQuickTask: Bool
        var title: String
        var category: String
        var symbol: String
        var tags: [String]
        var importance: Int
        var estimatedMinutes: Int

        func normalized(fallbackTitle: String) -> IdeaEnrichment {
            var cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanTitle.isEmpty { cleanTitle = String(fallbackTitle.prefix(60)) }

            let cleanCategory = category
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                .joined(separator: " ")

            var seen = Set<String>()
            var cleanTags: [String] = []
            for tag in tags {
                let value = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !value.isEmpty, value.count <= 24, seen.insert(value).inserted else { continue }
                cleanTags.append(value)
            }

            return IdeaEnrichment(
                kind: isQuickTask ? .task : .idea,
                title: String(cleanTitle.prefix(80)),
                categoryName: cleanCategory.isEmpty ? "Unfiled" : cleanCategory,
                categorySymbol: symbol,
                tags: Array(cleanTags.prefix(4)),
                importance: (Double(importance) - 1) / 4,
                estimatedMinutes: estimatedMinutes
            )
        }
    }

    private struct LinkJudgement: Decodable {
        struct Draft: Decodable {
            var ideaNumber: Int
            var relationship: String
            var reason: String
            var strength: Int
        }
        var links: [Draft]
    }
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case transport
    case emptyResponse
    case refused(category: String?)
    case unauthorized
    case rateLimited
    case server(status: Int)
    case badRequest(message: String)

    static func from(status: Int, body: Data) -> ClaudeError {
        switch status {
        case 401, 403:
            return .unauthorized
        case 429:
            return .rateLimited
        case 500...:
            return .server(status: status)
        default:
            // The API's error envelope is { "error": { "type", "message" } }.
            let message = (try? JSONSerialization.jsonObject(with: body) as? [String: Any])
                .flatMap { $0?["error"] as? [String: Any] }
                .flatMap { $0["message"] as? String }
            return .badRequest(message: message ?? "Request rejected (\(status)).")
        }
    }

    var errorDescription: String? {
        switch self {
        case .transport:
            return "Couldn't reach Claude. Remli will file this idea on-device instead."
        case .emptyResponse:
            return "Claude returned nothing usable."
        case .refused:
            return "Claude declined to process this one. It stays filed on-device."
        case .unauthorized:
            return "That API key was rejected. Check it in Settings."
        case .rateLimited:
            return "Claude is rate-limiting your key. Remli will try again later."
        case .server(let status):
            return "Claude is having trouble (\(status)). Remli will try again later."
        case .badRequest(let message):
            return message
        }
    }
}

// MARK: - Prompts and schemas

private extension ClaudeIntelligence {

    static let enrichmentInstructions = """
        You file captured thoughts for someone's personal idea journal.

        Be literal. Describe only what is actually in the text — never invent detail, \
        never embellish, never assume a domain that wasn't mentioned. If a thought is \
        vague, a vague title is the correct answer.
        """

    static let connectionInstructions = """
        You find real relationships between someone's captured ideas.

        You are strict. A shared topic is not a relationship. Two ideas are connected only \
        if knowing one would genuinely change how the person thinks about or acts on the \
        other. When in doubt, leave it out — a wrong connection costs far more trust than \
        a missed one.
        """

    /// Mirrors the on-device `@Generable` shape exactly, so both providers produce
    /// identical `IdeaEnrichment` values and the rest of the app cannot tell them apart.
    static let enrichmentSchema: [String: Any] = [
        "type": "json_schema",
        "schema": [
            "type": "object",
            "properties": [
                "isQuickTask": [
                    "type": "boolean",
                    "description": "True only if this is a chore or errand to tick off, like 'call the dentist'. False for anything exploratory, creative or worth developing.",
                ],
                "title": [
                    "type": "string",
                    "description": "A short noun phrase naming the idea. Three to seven words. No trailing punctuation, no quotes.",
                ],
                "category": [
                    "type": "string",
                    "description": "One or two words. Broad enough that many future ideas could share it. Prefer an existing category when one fits.",
                ],
                "symbol": [
                    "type": "string",
                    "description": "An icon suiting the category.",
                    // Constrained rather than free text: a hallucinated SF Symbol name
                    // renders as blank space in the UI.
                    "enum": [
                        "lightbulb", "paintbrush", "hammer", "chart.line.uptrend.xyaxis",
                        "book", "heart", "figure.run", "dollarsign.circle",
                        "person.2", "house", "airplane", "music.note",
                        "camera", "gearshape", "leaf", "brain",
                        "briefcase", "graduationcap", "fork.knife", "gamecontroller",
                    ],
                ],
                "tags": [
                    "type": "array",
                    "description": "Two to four single-word lowercase tags drawn from the thought itself.",
                    "items": ["type": "string"],
                ],
                "importance": [
                    "type": "integer",
                    "description": "How much this seems to matter to the person who wrote it. 1 is a passing remark, 5 is something they clearly care about.",
                    "enum": [1, 2, 3, 4, 5],
                ],
                "estimatedMinutes": [
                    "type": "integer",
                    "description": "Rough minutes of focused work to make a first meaningful dent in this. Not the whole project.",
                ],
            ],
            "required": ["isQuickTask", "title", "category", "symbol", "tags", "importance", "estimatedMinutes"],
            "additionalProperties": false,
        ],
    ]

    static let connectionSchema: [String: Any] = [
        "type": "json_schema",
        "schema": [
            "type": "object",
            "properties": [
                "links": [
                    "type": "array",
                    "description": "Only genuinely meaningful connections. Most pairs of ideas are unrelated, so an empty list is normal and correct.",
                    "items": [
                        "type": "object",
                        "properties": [
                            "ideaNumber": [
                                "type": "integer",
                                "description": "The number of the related idea, taken from the numbered list.",
                            ],
                            "relationship": [
                                "type": "string",
                                "enum": ["relatesTo", "buildsOn", "prerequisiteFor", "variantOf", "contradicts"],
                            ],
                            "reason": [
                                "type": "string",
                                "description": "One sentence, at most twenty words, naming the specific thing the two share. Never say they are 'related' without saying how.",
                            ],
                            "strength": [
                                "type": "integer",
                                "description": "1 means a tenuous stretch, 5 means they are obviously the same thread of thinking.",
                                "enum": [1, 2, 3, 4, 5],
                            ],
                        ],
                        "required": ["ideaNumber", "relationship", "reason", "strength"],
                        "additionalProperties": false,
                    ],
                ],
            ],
            "required": ["links"],
            "additionalProperties": false,
        ],
    ]
}
