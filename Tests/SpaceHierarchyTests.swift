import Foundation
import SwiftData
import Testing

@testable import Remli

/// The first tests this project has had.
///
/// Development happens on a machine with no Swift compiler and no simulator, so until now
/// "verified" could only ever mean "it compiled". These run headless in CI on every push,
/// which makes them the only claim about behaviour that is checked by something other than
/// reading the code.
///
/// Scope is deliberately the pure logic — hierarchy, counting, chip ordering. Anything
/// needing a live view or a real device is still verified on the phone, and pretending
/// otherwise would be the same lie in a new costume.
@Suite("Space hierarchy")
struct SpaceHierarchyTests {

    /// An in-memory container, so nothing here can touch a real store or CloudKit.
    private func makeContext() throws -> ModelContext {
        let container = try RemliSchema.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    @Test("A Space with no parent is a Space, and anything under it is a Collection")
    func spaceAndCollectionRoles() throws {
        let context = try makeContext()

        let business = IdeaCategory(name: "Business")
        let mealPrep = IdeaCategory(name: "Meal Prep", parent: business)
        context.insert(business)
        context.insert(mealPrep)

        #expect(business.isSpace)
        #expect(!business.isCollection)
        #expect(business.depth == 0)
        #expect(business.kindLabel == "Space")

        #expect(mealPrep.isCollection)
        #expect(!mealPrep.isSpace)
        #expect(mealPrep.depth == 1)
        #expect(mealPrep.kindLabel == "Collection")
        #expect(mealPrep.rootFolder.id == business.id)
    }

    @Test("A Collection inherits its Space's colour")
    func collectionInheritsColour() throws {
        let context = try makeContext()

        let business = IdeaCategory(name: "Business", colorHex: "1F6F63")
        let mealPrep = IdeaCategory(name: "Meal Prep", parent: business)
        context.insert(business)
        context.insert(mealPrep)

        #expect(mealPrep.colorHex == "1F6F63")
    }

    @Test("An explicit colour beats the inherited one")
    func explicitColourWins() throws {
        let context = try makeContext()

        let business = IdeaCategory(name: "Business", colorHex: "1F6F63")
        let mealPrep = IdeaCategory(name: "Meal Prep", colorHex: "A03D5B", parent: business)
        context.insert(business)
        context.insert(mealPrep)

        #expect(mealPrep.colorHex == "A03D5B")
    }

    /// The bug this guards: a Space whose ideas have all been moved down into Collections
    /// would otherwise show a count of zero while visibly containing everything.
    @Test("A Space counts the ideas in its Collections as well as its own")
    func totalCountIncludesCollections() throws {
        let context = try makeContext()

        let business = IdeaCategory(name: "Business")
        let mealPrep = IdeaCategory(name: "Meal Prep", parent: business)
        let bartending = IdeaCategory(name: "Bartending", parent: business)
        context.insert(business)
        context.insert(mealPrep)
        context.insert(bartending)

        let direct = Idea(text: "Something general about the business")
        direct.category = business
        let inMealPrep = Idea(text: "Sunday batch cooking service")
        inMealPrep.category = mealPrep
        let inBartending = Idea(text: "Mobile cocktail bar for weddings")
        inBartending.category = bartending

        for idea in [direct, inMealPrep, inBartending] { context.insert(idea) }

        #expect(business.ideaCount == 1)
        #expect(business.totalIdeaCount == 3)
        #expect(mealPrep.totalIdeaCount == 1)
    }

    @Test("Collections are listed in a stable alphabetical order")
    func childrenAreSorted() throws {
        let context = try makeContext()

        let business = IdeaCategory(name: "Business")
        context.insert(business)
        for name in ["Pricing", "Equipment", "Marketing"] {
            context.insert(IdeaCategory(name: name, parent: business))
        }

        #expect(business.sortedChildren.map(\.name) == ["Equipment", "Marketing", "Pricing"])
    }

    @Test("The display path names the Space a Collection sits in")
    func displayPath() throws {
        let context = try makeContext()

        let business = IdeaCategory(name: "Business")
        let mealPrep = IdeaCategory(name: "Meal Prep", parent: business)
        context.insert(business)
        context.insert(mealPrep)

        #expect(business.displayPath == "Business")
        #expect(mealPrep.displayPath == "Business › Meal Prep")
    }

    /// A cycle should be impossible — the picker never offers it — but a corrupt or badly
    /// merged CloudKit record must not be able to spin these forever, because they run
    /// inside view bodies.
    @Test("Walking up a cycle terminates instead of hanging")
    func cycleIsBounded() throws {
        let context = try makeContext()

        let a = IdeaCategory(name: "A")
        let b = IdeaCategory(name: "B")
        context.insert(a)
        context.insert(b)
        a.parent = b
        b.parent = a

        #expect(a.depth <= 8)
        _ = a.rootFolder
        _ = a.displayPath
    }

    @Test("A Space the model invented is not user-owned until someone claims it")
    func ownershipDefaultsToModel() throws {
        let context = try makeContext()

        let proposed = IdeaCategory(name: "Business")
        let claimed = IdeaCategory(name: "Macrova", isUserOwned: true)
        context.insert(proposed)
        context.insert(claimed)

        #expect(!proposed.isUserOwned)
        #expect(claimed.isUserOwned)
    }
}
