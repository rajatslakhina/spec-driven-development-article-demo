/// The outcome an executable check reports. Evidence is mandatory on success:
/// "it passed" without saying what was observed is how verification theater
/// starts.
public enum CheckOutcome: Equatable, Sendable {
    case passed(evidence: String)
    case failed(reason: String)
}

/// One executable check bound to one criterion ID. The body may throw; a
/// thrown error is recorded as a failure with the error's description, never
/// swallowed.
public struct GateCheck: Sendable {
    public let criterionID: String
    private let body: @Sendable () throws -> CheckOutcome

    public init(criterionID: String, body: @escaping @Sendable () throws -> CheckOutcome) {
        self.criterionID = criterionID
        self.body = body
    }

    func run() -> CheckOutcome {
        do {
            return try body()
        } catch {
            return .failed(reason: "Check threw: \(error)")
        }
    }
}

/// Status of a criterion after evaluation. `unverified` is the state this
/// whole library exists to make visible: the criterion is in the spec, but no
/// executable check backs it — it is a hope, not a requirement.
public enum CriterionStatus: Equatable, Sendable {
    case passed(evidence: String)
    case failed(reason: String)
    case unverified
}

public struct VerificationEntry: Equatable, Sendable {
    public let criterion: AcceptanceCriterion
    public let status: CriterionStatus

    public init(criterion: AcceptanceCriterion, status: CriterionStatus) {
        self.criterion = criterion
        self.status = status
    }
}

/// The report a gate evaluation produces. Entries preserve spec order so the
/// report reads like the spec, annotated.
public struct VerificationReport: Equatable, Sendable {
    public let specTitle: String
    public let entries: [VerificationEntry]

    public init(specTitle: String, entries: [VerificationEntry]) {
        self.specTitle = specTitle
        self.entries = entries
    }

    public var passedCount: Int {
        return entries.filter {
            if case .passed = $0.status { return true } else { return false }
        }.count
    }

    public var failedCount: Int {
        return entries.filter {
            if case .failed = $0.status { return true } else { return false }
        }.count
    }

    public var unverifiedCount: Int {
        return entries.filter { $0.status == .unverified }.count
    }

    /// Fraction of criteria backed by an executable check (passed or failed —
    /// a failing check still counts as covered; an absent one does not).
    /// Guarded: an empty report has zero coverage, not a division by zero.
    public var coverage: Double {
        guard !entries.isEmpty else { return 0 }
        let checked = entries.count - unverifiedCount
        return Double(checked) / Double(entries.count)
    }

    /// True only when every criterion has a check and every check passed.
    /// Deliberately strict: unverified criteria block a green light.
    public var allVerifiedAndPassing: Bool {
        return !entries.isEmpty && failedCount == 0 && unverifiedCount == 0
    }

    public func summaryLine() -> String {
        let percent = Int((coverage * 100).rounded())
        return "\(specTitle): \(passedCount) passed, \(failedCount) failed, "
            + "\(unverifiedCount) unverified — coverage \(percent)%"
    }
}

public enum GateError: Error, Equatable, Sendable {
    case duplicateCheck(criterionID: String)
}

/// Binds executable checks to a spec's criteria and evaluates them.
///
/// Two failure directions are surfaced, not just one:
/// - a criterion with no check → `unverified` in the report;
/// - a check whose criterion is not in the spec → `orphanedCheckIDs`, which is
///   drift in the other direction: verified behavior nobody specified.
public struct AcceptanceGate: Sendable {
    private var checks: [String: GateCheck] = [:]

    public init() {}

    /// Registers a check. Duplicate registration for the same criterion ID is
    /// an error: silently replacing a check is how a strong check gets
    /// swapped for a weak one without review noticing.
    public mutating func register(_ check: GateCheck) throws {
        if checks[check.criterionID] != nil {
            throw GateError.duplicateCheck(criterionID: check.criterionID)
        }
        checks[check.criterionID] = check
    }

    /// Check IDs that reference no criterion in the given spec, sorted for
    /// deterministic output.
    public func orphanedCheckIDs(for spec: FeatureSpec) -> [String] {
        let specIDs = Set(spec.criteria.map { $0.id })
        return checks.keys.filter { !specIDs.contains($0) }.sorted()
    }

    /// Runs every registered check against the spec's criteria, in spec
    /// order. Criteria without checks come back `unverified`.
    public func evaluate(_ spec: FeatureSpec) -> VerificationReport {
        let entries = spec.criteria.map { criterion -> VerificationEntry in
            guard let check = checks[criterion.id] else {
                return VerificationEntry(criterion: criterion, status: .unverified)
            }
            switch check.run() {
            case .passed(let evidence):
                return VerificationEntry(criterion: criterion, status: .passed(evidence: evidence))
            case .failed(let reason):
                return VerificationEntry(criterion: criterion, status: .failed(reason: reason))
            }
        }
        return VerificationReport(specTitle: spec.title, entries: entries)
    }
}
