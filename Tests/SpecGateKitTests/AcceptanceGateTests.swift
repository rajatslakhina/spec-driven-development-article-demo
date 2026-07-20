import XCTest
@testable import SpecGateKit

final class AcceptanceGateTests: XCTestCase {

    private func makeSpec(ids: [String]) -> FeatureSpec {
        return FeatureSpec(
            title: "Test Feature",
            goals: ["Exercise the gate"],
            criteria: ids.map { AcceptanceCriterion(id: $0, text: "Criterion \($0)") }
        )
    }

    func testMixedOutcomesPreserveSpecOrder() throws {
        let spec = makeSpec(ids: ["AC-1", "AC-2", "AC-3"])
        var gate = AcceptanceGate()
        try gate.register(GateCheck(criterionID: "AC-1") {
            .passed(evidence: "observed 90.0 for a 100.0 order")
        })
        try gate.register(GateCheck(criterionID: "AC-2") {
            .failed(reason: "expected 70.0, got 65.0")
        })
        // AC-3 deliberately has no check.

        let report = gate.evaluate(spec)

        XCTAssertEqual(report.entries.count, 3)
        XCTAssertEqual(report.entries[0].status,
                       .passed(evidence: "observed 90.0 for a 100.0 order"))
        XCTAssertEqual(report.entries[1].status,
                       .failed(reason: "expected 70.0, got 65.0"))
        XCTAssertEqual(report.entries[2].status, .unverified)
        XCTAssertEqual(report.passedCount, 1)
        XCTAssertEqual(report.failedCount, 1)
        XCTAssertEqual(report.unverifiedCount, 1)
        XCTAssertFalse(report.allVerifiedAndPassing)
    }

    func testThrowingCheckBecomesFailureNotCrash() throws {
        struct Boom: Error {}
        let spec = makeSpec(ids: ["AC-1"])
        var gate = AcceptanceGate()
        try gate.register(GateCheck(criterionID: "AC-1") { throw Boom() })

        let report = gate.evaluate(spec)

        guard case .failed(let reason) = report.entries[0].status else {
            return XCTFail("Expected a failure, got \(report.entries[0].status)")
        }
        XCTAssertTrue(reason.contains("Check threw"))
    }

    func testDuplicateRegistrationThrows() throws {
        var gate = AcceptanceGate()
        try gate.register(GateCheck(criterionID: "AC-1") { .passed(evidence: "first") })
        XCTAssertThrowsError(
            try gate.register(GateCheck(criterionID: "AC-1") { .passed(evidence: "second") })
        ) { error in
            XCTAssertEqual(error as? GateError, .duplicateCheck(criterionID: "AC-1"))
        }
    }

    func testOrphanedChecksAreReportedSorted() throws {
        let spec = makeSpec(ids: ["AC-1"])
        var gate = AcceptanceGate()
        try gate.register(GateCheck(criterionID: "AC-9") { .passed(evidence: "e") })
        try gate.register(GateCheck(criterionID: "AC-5") { .passed(evidence: "e") })
        try gate.register(GateCheck(criterionID: "AC-1") { .passed(evidence: "e") })

        XCTAssertEqual(gate.orphanedCheckIDs(for: spec), ["AC-5", "AC-9"])
    }

    // MARK: - Coverage and report math

    func testCoverageCountsFailedChecksAsCovered() throws {
        let spec = makeSpec(ids: ["AC-1", "AC-2", "AC-3", "AC-4"])
        var gate = AcceptanceGate()
        try gate.register(GateCheck(criterionID: "AC-1") { .passed(evidence: "e") })
        try gate.register(GateCheck(criterionID: "AC-2") { .failed(reason: "r") })

        let report = gate.evaluate(spec)

        XCTAssertEqual(report.coverage, 0.5, accuracy: 0.0001)
    }

    func testEmptySpecReportHasZeroCoverageWithoutDividingByZero() {
        let spec = FeatureSpec(title: "Empty", goals: ["g"], criteria: [])
        let report = AcceptanceGate().evaluate(spec)

        XCTAssertEqual(report.coverage, 0)
        XCTAssertFalse(report.allVerifiedAndPassing,
                       "An empty spec must not read as a green light")
    }

    func testAllVerifiedAndPassingRequiresFullCoverage() throws {
        let spec = makeSpec(ids: ["AC-1", "AC-2"])
        var gate = AcceptanceGate()
        try gate.register(GateCheck(criterionID: "AC-1") { .passed(evidence: "e") })

        XCTAssertFalse(gate.evaluate(spec).allVerifiedAndPassing,
                       "One unverified criterion must block the green light")

        try gate.register(GateCheck(criterionID: "AC-2") { .passed(evidence: "e") })
        XCTAssertTrue(gate.evaluate(spec).allVerifiedAndPassing)
    }

    func testSummaryLineFormat() throws {
        let spec = makeSpec(ids: ["AC-1", "AC-2"])
        var gate = AcceptanceGate()
        try gate.register(GateCheck(criterionID: "AC-1") { .passed(evidence: "e") })

        let summary = gate.evaluate(spec).summaryLine()

        XCTAssertEqual(
            summary,
            "Test Feature: 1 passed, 0 failed, 1 unverified — coverage 50%")
    }
}
