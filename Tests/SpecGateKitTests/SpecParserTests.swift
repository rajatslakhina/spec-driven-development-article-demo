import XCTest
@testable import SpecGateKit

final class SpecParserTests: XCTestCase {

    private let parser = SpecParser()

    private let validDocument = """
    # Spec: Cart Discount Engine

    ## Goals
    - Reward larger orders without manual coupon codes

    ## Non-Goals
    - Stacking multiple discounts

    ## Constraints
    - Pure function; no I/O in the pricing path

    ## Acceptance Criteria
    - [AC-1] Orders of $100.00 or more receive a 10% discount
    - [AC-2] The applied discount never exceeds 30% of the order total
    """

    func testParsesValidDocument() throws {
        let spec = try parser.parse(validDocument)
        XCTAssertEqual(spec.title, "Cart Discount Engine")
        XCTAssertEqual(spec.goals, ["Reward larger orders without manual coupon codes"])
        XCTAssertEqual(spec.nonGoals, ["Stacking multiple discounts"])
        XCTAssertEqual(spec.constraints, ["Pure function; no I/O in the pricing path"])
        XCTAssertEqual(spec.criteria.count, 2)
        XCTAssertEqual(spec.criteria[0], AcceptanceCriterion(
            id: "AC-1", text: "Orders of $100.00 or more receive a 10% discount"))
        XCTAssertEqual(spec.criteria[1].id, "AC-2")
    }

    func testCriterionLookupByID() throws {
        let spec = try parser.parse(validDocument)
        XCTAssertEqual(spec.criterion(withID: "AC-2")?.id, "AC-2")
        XCTAssertNil(spec.criterion(withID: "AC-99"))
    }

    // MARK: - Edge cases

    func testEmptyDocumentThrows() {
        XCTAssertThrowsError(try parser.parse("")) { error in
            XCTAssertEqual(error as? SpecParseError, .emptyDocument)
        }
        XCTAssertThrowsError(try parser.parse("   \n\n  \t ")) { error in
            XCTAssertEqual(error as? SpecParseError, .emptyDocument)
        }
    }

    func testMissingTitleThrows() {
        let document = """
        ## Goals
        - A goal
        ## Acceptance Criteria
        - [AC-1] Something observable
        """
        XCTAssertThrowsError(try parser.parse(document)) { error in
            XCTAssertEqual(error as? SpecParseError, .missingTitle)
        }
    }

    func testMissingGoalsThrows() {
        let document = """
        # Spec: No Goals
        ## Acceptance Criteria
        - [AC-1] Something observable
        """
        XCTAssertThrowsError(try parser.parse(document)) { error in
            XCTAssertEqual(error as? SpecParseError, .missingSection("Goals"))
        }
    }

    func testMissingCriteriaThrows() {
        let document = """
        # Spec: No Criteria
        ## Goals
        - A goal
        """
        XCTAssertThrowsError(try parser.parse(document)) { error in
            XCTAssertEqual(error as? SpecParseError, .emptyCriteria)
        }
    }

    func testDuplicateCriterionIDThrows() {
        let document = """
        # Spec: Duplicates
        ## Goals
        - A goal
        ## Acceptance Criteria
        - [AC-1] First statement
        - [AC-1] Second statement reusing the ID
        """
        XCTAssertThrowsError(try parser.parse(document)) { error in
            XCTAssertEqual(error as? SpecParseError, .duplicateCriterionID("AC-1"))
        }
    }

    func testMalformedCriterionThrows() {
        let document = """
        # Spec: Malformed
        ## Goals
        - A goal
        ## Acceptance Criteria
        - AC-1 missing the brackets entirely
        """
        XCTAssertThrowsError(try parser.parse(document)) { error in
            XCTAssertEqual(
                error as? SpecParseError,
                .malformedCriterion(line: "AC-1 missing the brackets entirely"))
        }
    }

    func testCriterionWithEmptyTextThrows() {
        let document = """
        # Spec: Empty Text
        ## Goals
        - A goal
        ## Acceptance Criteria
        - [AC-1]
        """
        XCTAssertThrowsError(try parser.parse(document)) { error in
            XCTAssertEqual(error as? SpecParseError, .malformedCriterion(line: "[AC-1]"))
        }
    }

    func testUnknownSectionsAreIgnoredForForwardCompatibility() throws {
        let document = """
        # Spec: Forward Compatible
        ## Goals
        - A goal
        ## Rollout Plan
        - Something a future tool understands
        ## Acceptance Criteria
        - [AC-1] Something observable
        """
        let spec = try parser.parse(document)
        XCTAssertEqual(spec.criteria.count, 1)
        XCTAssertEqual(spec.goals, ["A goal"])
    }

    func testBulletsBeforeAnySectionAreIgnored() throws {
        let document = """
        # Spec: Stray Bullets
        - This bullet belongs to no section
        ## Goals
        - A goal
        ## Acceptance Criteria
        - [AC-1] Something observable
        """
        let spec = try parser.parse(document)
        XCTAssertEqual(spec.goals, ["A goal"])
    }

    func testWhitespaceIsTrimmedThroughout() throws {
        let document = "   # Spec:   Padded Title   \n" +
            "  ## Goals  \n" +
            "  -   A goal with padding   \n" +
            "## Acceptance Criteria\n" +
            "- [ AC-1 ]   Padded criterion text  \n"
        let spec = try parser.parse(document)
        XCTAssertEqual(spec.title, "Padded Title")
        XCTAssertEqual(spec.goals, ["A goal with padding"])
        XCTAssertEqual(spec.criteria[0], AcceptanceCriterion(
            id: "AC-1", text: "Padded criterion text"))
    }
}
