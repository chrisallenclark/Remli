import Foundation
import SwiftData
import Testing

@testable import Remli

/// The chips above the ideas list.
///
/// Worth testing because the ordering rules are the kind that look obviously right and are
/// quietly wrong: a Space has to outrank its own Collections, a Space with no ideas of its
/// own still has to appear, and selecting a Space has to include everything filed beneath
/// it. Each of those has a test because each of them would be invisible until you had
/// enough ideas for it to matter.
@Suite("Smart collections")
struct SmartCollectionTests {

    private func makeContext() throws -> ModelContext {
        let container = try RemliSchema.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    private func idea(_ text: String, in place: IdeaCategory? = nil, context: ModelContext) -> Idea {
        let idea = Idea(text: text)
        idea.category = place
        context.insert(idea)
        return idea
    }

    @Test("Selecting a Space includes the ideas inside its Collections")
    func spaceMatchesItsCollections() throws {
        let context = try makeContext()

        let business = IdeaCategory(name: "Business")
        let mealPrep = IdeaCategory(name: "Meal Prep", parent: business)
        context.insert(business)
        context.insert(mealPrep)

        let nested = idea("Sunday batch cooking", in: mealPrep, context: context)

        let spaceChip = SmartCollection.category(id: business.id, name: "Business", isCollection: false)
        #expect(spaceChip.matches(nested))
    }

    @Test("Selecting a Collection does not reach back up into its Space")
    func collectionDoesNotMatchSiblings() throws {
        let context = try makeContext()

        let business = IdeaCategory(name: "Business")
        let mealPrep = IdeaCategory(name: "Meal Prep", parent: business)
        context.insert(business)
        context.insert(mealPrep)

        let general = idea("Something general", in: business, context: context)

        let collectionChip = SmartCollection.category(id: mealPrep.id, name: "Meal Prep", isCollection: true)
        #expect(!collectionChip.matches(general))
    }

    @Test("An idea with no Space matches only All")
    func unfiledIdea() throws {
        let context = try makeContext()
        let loose = idea("Unfiled thought", context: context)

        #expect(SmartCollection.all.matches(loose))
        #expect(!SmartCollection.category(id: UUID(), name: "Business", isCollection: false).matches(loose))
    }

    @Test("Each Space is followed immediately by its own Collections")
    func orderingKeepsCollectionsWithTheirSpace() throws {
        let context = try makeContext()

        let business = IdeaCategory(name: "Business")
        let mealPrep = IdeaCategory(name: "Meal Prep", parent: business)
        let health = IdeaCategory(name: "Health")
        context.insert(business)
        context.insert(mealPrep)
        context.insert(health)

        var ideas: [Idea] = []
        ideas.append(idea("Batch cooking", in: mealPrep, context: context))
        ideas.append(idea("Supplier list", in: mealPrep, context: context))
        ideas.append(idea("Marathon plan", in: health, context: context))

        let available = SmartCollection.available(for: ideas)
        let labels = available.map(\.label)

        let businessIndex = try #require(labels.firstIndex(of: "Business"))
        let mealPrepIndex = try #require(labels.firstIndex(of: "Meal Prep"))
        let healthIndex = try #require(labels.firstIndex(of: "Health"))

        // Business (2, via its Collection) outranks Health (1), and Meal Prep sits directly
        // under Business rather than being sorted away from it by its own count.
        #expect(businessIndex < mealPrepIndex)
        #expect(mealPrepIndex < healthIndex)
    }

    /// The regression this guards: a Space whose ideas have all moved into Collections has
    /// no idea pointing directly at it, so a naive tally would drop its chip entirely.
    @Test("A Space with no direct ideas still gets a chip")
    func emptySpaceStillAppears() throws {
        let context = try makeContext()

        let business = IdeaCategory(name: "Business")
        let mealPrep = IdeaCategory(name: "Meal Prep", parent: business)
        context.insert(business)
        context.insert(mealPrep)

        let ideas = [idea("Batch cooking", in: mealPrep, context: context)]
        let labels = SmartCollection.available(for: ideas).map(\.label)

        #expect(labels.contains("Business"))
        #expect(labels.contains("Meal Prep"))
    }

    @Test("A chip that would show nothing is never offered")
    func emptyChipsAreOmitted() throws {
        let context = try makeContext()
        let ideas = [idea("Just a thought", context: context)]

        let labels = SmartCollection.available(for: ideas).map(\.label)
        #expect(labels == ["All"])
    }

    @Test("To-dos get their own chip and ideas do not appear in it")
    func tasksAreSeparate() throws {
        let context = try makeContext()

        let thought = idea("An idea worth keeping", context: context)
        let chore = idea("Call the dentist", context: context)
        chore.kind = .task

        #expect(SmartCollection.tasks.matches(chore))
        #expect(!SmartCollection.tasks.matches(thought))
    }
}
