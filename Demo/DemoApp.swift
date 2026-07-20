import SwiftUI
import SpecGateKit

// MARK: - The feature under spec

/// A deliberately small feature so the spec, the implementation, and the gate
/// all fit on one screen. The "Introduce regression" toggle swaps in a buggy
/// discount rate so you can watch AC-1 flip from passed to failed live.
struct DiscountEngine {
    var discountRate: Double = 0.10
    let threshold: Double = 100.0
    let maxDiscountFraction: Double = 0.30

    func total(forOrderOf amount: Double) -> Double? {
        guard amount >= 0 else { return nil }
        guard amount >= threshold else { return amount }
        let discount = min(amount * discountRate, amount * maxDiscountFraction)
        return amount - discount
    }
}

// MARK: - The spec, shipped inside the app it governs

let demoSpecDocument = """
# Spec: Cart Discount Engine

## Goals
- Reward larger orders without manual coupon codes

## Non-Goals
- Stacking multiple discounts

## Constraints
- Pure function; no I/O in the pricing path

## Acceptance Criteria
- [AC-1] Orders of $100.00 or more receive a 10% discount
- [AC-2] Orders under $100.00 are charged in full
- [AC-3] The applied discount never exceeds 30% of the order total
- [AC-4] Negative order amounts are rejected, not clamped
- [AC-5] Totals are rendered in the user's locale currency format
"""

// MARK: - Wiring the gate

func makeReport(engine: DiscountEngine) -> (VerificationReport, [String])? {
    guard let spec = try? SpecParser().parse(demoSpecDocument) else { return nil }
    var gate = AcceptanceGate()
    do {
        try gate.register(GateCheck(criterionID: "AC-1") {
            let observed = engine.total(forOrderOf: 100.0)
            guard observed == 90.0 else {
                return .failed(reason: "expected 90.0 for a 100.0 order, got \(String(describing: observed))")
            }
            return .passed(evidence: "100.0 order came back as 90.0")
        })
        try gate.register(GateCheck(criterionID: "AC-2") {
            let observed = engine.total(forOrderOf: 99.99)
            guard observed == 99.99 else {
                return .failed(reason: "expected 99.99 untouched, got \(String(describing: observed))")
            }
            return .passed(evidence: "99.99 order was charged in full")
        })
        try gate.register(GateCheck(criterionID: "AC-3") {
            let observed = engine.total(forOrderOf: 1_000.0)
            guard let total = observed, (1_000.0 - total) <= 300.0 else {
                return .failed(reason: "discount exceeded 30% cap: \(String(describing: observed))")
            }
            return .passed(evidence: "1000.0 order discounted \(1_000.0 - total), within the 300.0 cap")
        })
        try gate.register(GateCheck(criterionID: "AC-4") {
            guard engine.total(forOrderOf: -5.0) == nil else {
                return .failed(reason: "negative amount was not rejected")
            }
            return .passed(evidence: "-5.0 was rejected as nil")
        })
        // AC-5 intentionally has NO check registered. It shows up in the
        // report as "unverified" — the state this demo exists to make visible.
    } catch {
        return nil
    }
    return (gate.evaluate(spec), gate.orphanedCheckIDs(for: spec))
}

// MARK: - UI

struct SpecGateDashboardView: View {
    @State private var regressionIntroduced = false

    private var engine: DiscountEngine {
        DiscountEngine(discountRate: regressionIntroduced ? 0.05 : 0.10)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let (report, orphans) = makeReport(engine: engine) {
                    reportList(report: report, orphans: orphans)
                } else {
                    ContentUnavailableView(
                        "Spec failed to parse",
                        systemImage: "exclamationmark.triangle",
                        description: Text("The bundled spec document is malformed.")
                    )
                }
            }
            .navigationTitle("SpecGate")
        }
    }

    private func reportList(report: VerificationReport, orphans: [String]) -> some View {
        List {
            Section {
                Toggle("Introduce regression", isOn: $regressionIntroduced)
                    .tint(.red)
                Text(report.summaryLine())
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                ProgressView(value: report.coverage) {
                    Text("Executable coverage \(Int((report.coverage * 100).rounded()))%")
                        .font(.caption)
                }
            } header: {
                Text(report.specTitle)
            }

            Section("Acceptance criteria") {
                ForEach(report.entries, id: \.criterion.id) { entry in
                    row(for: entry)
                }
            }

            if !orphans.isEmpty {
                Section("Orphaned checks (verified but unspecified)") {
                    ForEach(orphans, id: \.self) { id in
                        Label(id, systemImage: "questionmark.circle")
                    }
                }
            }

            Section {
                Text("AC-5 has no executable check on purpose: a spec line without a check is a hope, not a requirement.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func row(for entry: VerificationEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                statusBadge(for: entry.status)
                Text("\(entry.criterion.id)  \(entry.criterion.text)")
                    .font(.subheadline)
            }
            detailText(for: entry.status)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .padding(.leading, 26)
        }
        .padding(.vertical, 2)
    }

    private func statusBadge(for status: CriterionStatus) -> some View {
        switch status {
        case .passed:
            return Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            return Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .unverified:
            return Image(systemName: "circle.dashed").foregroundStyle(.orange)
        }
    }

    private func detailText(for status: CriterionStatus) -> Text {
        switch status {
        case .passed(let evidence):
            return Text(evidence)
        case .failed(let reason):
            return Text(reason)
        case .unverified:
            return Text("No executable check registered")
        }
    }
}

// MARK: - App entry point

@main
struct SpecGateDemoApp: App {
    var body: some Scene {
        WindowGroup {
            SpecGateDashboardView()
        }
    }
}
