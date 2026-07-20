import XCTest
@testable import SpecGateKit

final class SpecDiffTests: XCTestCase {

    private func makeSpec(_ pairs: [(String, String)]) -> FeatureSpec {
        return FeatureSpec(
            title: "Diffed Feature",
            goals: ["g"],
            criteria: pairs.map { AcceptanceCriterion(id: $0.0, text: $0.1) }
        )
    }

    func testIdenticalSpecsProduceEmptyDiff() {
        let spec = makeSpec([("AC-1", "a"), ("AC-2", "b")])
        let diff = SpecDiff.between(old: spec, new: spec)
        XCTAssertTrue(diff.isEmpty)
    }

    func testAddedRemovedAndRewordedAreAllDetected() {
        let old = makeSpec([("AC-1", "original text"), ("AC-2", "kept as is")])
        let new = makeSpec([("AC-1", "revised text"), ("AC-3", "brand new")])

        let diff = SpecDiff.between(old: old, new: new)

        XCTAssertEqual(diff.addedCriteria, [AcceptanceCriterion(id: "AC-3", text: "brand new")])
        XCTAssertEqual(diff.removedCriteria, [AcceptanceCriterion(id: "AC-2", text: "kept as is")])
        XCTAssertEqual(diff.rewordedCriteria, [
            RewordedCriterion(id: "AC-1", oldText: "original text", newText: "revised text")
        ])
        XCTAssertFalse(diff.isEmpty)
    }

    func testDiffOutputIsSortedByIDForDeterminism() {
        let old = makeSpec([])
        let new = makeSpec([("AC-9", "z"), ("AC-2", "y"), ("AC-5", "x")])

        let diff = SpecDiff.between(old: old, new: new)

        XCTAssertEqual(diff.addedCriteria.map { $0.id }, ["AC-2", "AC-5", "AC-9"])
    }

    // MARK: - Edge cases

    func testEmptyToEmptyIsEmptyDiff() {
        let diff = SpecDiff.between(old: makeSpec([]), new: makeSpec([]))
        XCTAssertTrue(diff.isEmpty)
    }

    func testEverythingRemoved() {
        let old = makeSpec([("AC-1", "a"), ("AC-2", "b")])
        let diff = SpecDiff.between(old: old, new: makeSpec([]))
        XCTAssertEqual(diff.removedCriteria.count, 2)
        XCTAssertTrue(diff.addedCriteria.isEmpty)
        XCTAssertTrue(diff.rewordedCriteria.isEmpty)
    }

    func testDuplicateIDsInHandBuiltSpecDoNotTrap() {
        // The parser forbids duplicate IDs, but FeatureSpec's initializer
        // cannot — the diff must degrade gracefully instead of crashing.
        let old = makeSpec([("AC-1", "first"), ("AC-1", "second")])
        let new = makeSpec([("AC-1", "first")])

        let diff = SpecDiff.between(old: old, new: new)

        XCTAssertTrue(diff.addedCriteria.isEmpty)
        XCTAssertTrue(diff.rewordedCriteria.isEmpty)
    }
}
