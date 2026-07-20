/// A criterion whose ID survived a revision but whose text changed. Kept as
/// its own type (rather than a pair of criteria) so review tooling can render
/// old/new side by side.
public struct RewordedCriterion: Equatable, Sendable {
    public let id: String
    public let oldText: String
    public let newText: String

    public init(id: String, oldText: String, newText: String) {
        self.id = id
        self.oldText = oldText
        self.newText = newText
    }
}

/// The reviewable delta between two revisions of a spec.
///
/// This is the payoff of specs being durable artifacts: a change of intent is
/// a diff you can put in front of a reviewer, not an archaeology dig through
/// chat history. All arrays are sorted by criterion ID for deterministic
/// output in CI logs and snapshots.
public struct SpecDiff: Equatable, Sendable {
    public let addedCriteria: [AcceptanceCriterion]
    public let removedCriteria: [AcceptanceCriterion]
    public let rewordedCriteria: [RewordedCriterion]

    public var isEmpty: Bool {
        return addedCriteria.isEmpty && removedCriteria.isEmpty && rewordedCriteria.isEmpty
    }

    public init(
        addedCriteria: [AcceptanceCriterion],
        removedCriteria: [AcceptanceCriterion],
        rewordedCriteria: [RewordedCriterion]
    ) {
        self.addedCriteria = addedCriteria
        self.removedCriteria = removedCriteria
        self.rewordedCriteria = rewordedCriteria
    }

    public static func between(old: FeatureSpec, new: FeatureSpec) -> SpecDiff {
        // uniquingKeysWith, not uniqueKeysWithValues: a hand-built FeatureSpec can
        // carry duplicate IDs (the parser forbids them, the initializer cannot),
        // and a diff helper must never trap on bad input.
        let oldByID = Dictionary(old.criteria.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let newByID = Dictionary(new.criteria.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let added = new.criteria
            .filter { oldByID[$0.id] == nil }
            .sorted { $0.id < $1.id }

        let removed = old.criteria
            .filter { newByID[$0.id] == nil }
            .sorted { $0.id < $1.id }

        let reworded = new.criteria.compactMap { newCriterion -> RewordedCriterion? in
            guard let oldCriterion = oldByID[newCriterion.id],
                  oldCriterion.text != newCriterion.text else { return nil }
            return RewordedCriterion(
                id: newCriterion.id,
                oldText: oldCriterion.text,
                newText: newCriterion.text
            )
        }.sorted { $0.id < $1.id }

        return SpecDiff(
            addedCriteria: added,
            removedCriteria: removed,
            rewordedCriteria: reworded
        )
    }
}
