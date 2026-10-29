package com.chrisallenclark.remli.model

import java.util.UUID

/** A typed, explained edge between two ideas. Port of IdeaLink.swift. */
data class IdeaLink(
    val id: String = UUID.randomUUID().toString(),
    val createdAt: Long = System.currentTimeMillis(),
    val kindRaw: String = LinkKind.RelatesTo.raw,
    val rationale: String = "",
    val strength: Double = 0.0,
    val confirmedByUser: Boolean = false,
    val confidence: Double = 1.0,
    val originRaw: String = LinkOrigin.Ai.raw,
    val reviewStateRaw: String = LinkReviewState.Accepted.raw,
    val sourceId: String? = null,
    val targetId: String? = null,
) {
    val kind: LinkKind get() = LinkKind.from(kindRaw)
    val reviewState: LinkReviewState get() = LinkReviewState.from(reviewStateRaw)

    /** Whether this link is real — drawn, counted, shown as fact. A proposal is not. */
    val isActive: Boolean get() = reviewState == LinkReviewState.Accepted
}
