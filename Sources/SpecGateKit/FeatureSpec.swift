/// A single acceptance criterion from a spec — the atomic unit an agent (or a
/// human) can be held to. The `id` is stable across spec revisions so checks,
/// diffs, and review comments can all reference the same line of intent.
public struct AcceptanceCriterion: Equatable, Hashable, Sendable {
    /// Stable identifier, e.g. "AC-1". Must be unique within a spec.
    public let id: String
    /// Human-readable statement of the required behavior.
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

/// A parsed feature spec: the durable artifact that survives the chat session
/// that produced it. Goals say why, non-goals fence the scope, constraints
/// bound the solution space, and acceptance criteria are the testable surface.
public struct FeatureSpec: Equatable, Sendable {
    public let title: String
    public let goals: [String]
    public let nonGoals: [String]
    public let constraints: [String]
    public let criteria: [AcceptanceCriterion]

    public init(
        title: String,
        goals: [String],
        nonGoals: [String] = [],
        constraints: [String] = [],
        criteria: [AcceptanceCriterion]
    ) {
        self.title = title
        self.goals = goals
        self.nonGoals = nonGoals
        self.constraints = constraints
        self.criteria = criteria
    }

    /// Looks up a criterion by id. Returns nil rather than trapping when the
    /// id is unknown — callers decide how to treat dangling references.
    public func criterion(withID id: String) -> AcceptanceCriterion? {
        return criteria.first { $0.id == id }
    }
}
