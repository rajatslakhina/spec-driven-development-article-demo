/// Errors a spec document can fail with. Every case names the exact defect so
/// a CI job (or an agent) can fix the spec rather than guess.
public enum SpecParseError: Error, Equatable, Sendable {
    case emptyDocument
    case missingTitle
    case missingSection(String)
    case emptyCriteria
    case duplicateCriterionID(String)
    case malformedCriterion(line: String)
}

/// Parses the lightweight Markdown spec format used across this repo:
///
/// ```
/// # Spec: Cart Discount Engine
/// ## Goals
/// - Reward larger orders without manual coupon codes
/// ## Non-Goals
/// - Stacking multiple discounts
/// ## Constraints
/// - Pure function; no I/O in the pricing path
/// ## Acceptance Criteria
/// - [AC-1] Orders of $100.00 or more receive a 10% discount
/// ```
///
/// Rules, chosen deliberately:
/// - `Goals` and `Acceptance Criteria` are mandatory — a spec with no goals is
///   a task list, and a spec with no criteria is a wish.
/// - `Non-Goals` and `Constraints` are optional but parsed when present.
/// - Unknown `##` sections are ignored, so teams can extend the format without
///   breaking older tooling (forward compatibility over strictness).
/// - Criterion IDs must be unique; a duplicated ID is an error, not a warning,
///   because checks and diffs key off the ID.
public struct SpecParser: Sendable {

    public init() {}

    public func parse(_ document: String) throws -> FeatureSpec {
        let lines = document.split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).specTrimmed }

        let nonEmpty = lines.filter { !$0.isEmpty }
        guard !nonEmpty.isEmpty else { throw SpecParseError.emptyDocument }

        var title: String?
        var currentSection: String?
        var goals: [String] = []
        var nonGoals: [String] = []
        var constraints: [String] = []
        var criteria: [AcceptanceCriterion] = []
        var seenCriterionIDs = Set<String>()

        for line in lines {
            if line.isEmpty { continue }

            if line.hasPrefix("# Spec:") {
                let raw = String(line.dropFirst("# Spec:".count))
                    .specTrimmed
                if !raw.isEmpty { title = raw }
                continue
            }

            if line.hasPrefix("## ") {
                currentSection = String(line.dropFirst(3))
                    .specTrimmed
                    .lowercased()
                continue
            }

            guard line.hasPrefix("- ") else { continue }
            let item = String(line.dropFirst(2)).specTrimmed
            if item.isEmpty { continue }

            switch currentSection {
            case "goals":
                goals.append(item)
            case "non-goals":
                nonGoals.append(item)
            case "constraints":
                constraints.append(item)
            case "acceptance criteria":
                let criterion = try parseCriterion(fromItem: item)
                if seenCriterionIDs.contains(criterion.id) {
                    throw SpecParseError.duplicateCriterionID(criterion.id)
                }
                seenCriterionIDs.insert(criterion.id)
                criteria.append(criterion)
            default:
                // Bullet outside a known section (or before any section):
                // ignored on purpose — see forward-compatibility note above.
                continue
            }
        }

        guard let resolvedTitle = title else { throw SpecParseError.missingTitle }
        guard !goals.isEmpty else { throw SpecParseError.missingSection("Goals") }
        guard !criteria.isEmpty else { throw SpecParseError.emptyCriteria }

        return FeatureSpec(
            title: resolvedTitle,
            goals: goals,
            nonGoals: nonGoals,
            constraints: constraints,
            criteria: criteria
        )
    }

    /// Expects `[AC-n] text`. Split into helper so the error can carry the
    /// offending line verbatim.
    private func parseCriterion(fromItem item: String) throws -> AcceptanceCriterion {
        guard item.hasPrefix("["),
              let closingIndex = item.firstIndex(of: "]") else {
            throw SpecParseError.malformedCriterion(line: item)
        }
        let id = String(item[item.index(after: item.startIndex)..<closingIndex])
            .specTrimmed
        let text = String(item[item.index(after: closingIndex)...])
            .specTrimmed
        guard !id.isEmpty, !text.isEmpty else {
            throw SpecParseError.malformedCriterion(line: item)
        }
        return AcceptanceCriterion(id: id, text: text)
    }
}

/// Foundation-free whitespace trimming so the library keeps zero imports —
/// it must build anywhere Swift builds, including Linux CI.
private extension String {
    var specTrimmed: String {
        var view = Substring(self)
        while let first = view.first, first.isWhitespace { view = view.dropFirst() }
        while let last = view.last, last.isWhitespace { view = view.dropLast() }
        return String(view)
    }
}
