import ActivityKit
import Foundation
import LiveActivityKit
import PowderCoatingRunEngine

/// Local-only status for an active shared load. No countdown is presented as
/// cure evidence: each run still requires actual part-metal observations.
@MainActor
final class PowderRunActivityService {
    func sync(with ledger: ShopLedger) async {
        let active = ledger.batches.filter { $0.exitedAt == nil }
        let known = Set(active.map { $0.id.uuidString })
        for activity in Activity<PowderRunActivityAttributes>.activities {
            if let batch = active.first(where: { $0.id.uuidString == activity.attributes.batchID }) {
                await activity.update(content(for: batch, ledger: ledger))
            } else if !known.contains(activity.attributes.batchID) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let existing = Set(Activity<PowderRunActivityAttributes>.activities.map { $0.attributes.batchID })
        for batch in active where !existing.contains(batch.id.uuidString) {
            do {
                _ = try Activity.request(attributes: PowderRunActivityAttributes(batchID: batch.id.uuidString),
                                         content: content(for: batch, ledger: ledger), pushType: nil)
            } catch {
                // The in-app batch remains authoritative when system status is unavailable.
            }
        }
    }

    private func content(for batch: OvenBatch, ledger: ShopLedger) -> ActivityContent<PowderRunActivityAttributes.ContentState> {
        let pending = batch.runIDs.compactMap { id in ledger.runs.first(where: { $0.id == id }) }
            .filter { $0.stage == .heating || $0.stage == .dwelling }
        let now = Date()
        let model = LiveActivityContentModel(
            id: batch.id.uuidString, symbolName: "flame", accessibilityTitle: "Powder coating oven \(batch.equipment)",
            phase: pending.isEmpty ? .completed : .attention,
            title: batch.loadIdentity, subtitle: batch.equipment,
            primaryValue: "\(batch.runIDs.count) runs", secondaryValue: pending.isEmpty ? "Review unload" : "Reading due",
            footnote: "Open the app to record part-metal readings",
            progress: LiveActivityProgress(fraction: 0, label: "Manual evidence", isIndeterminate: true),
            timeline: LiveActivityTimeline(startedAt: now, estimatedEnd: now.addingTimeInterval(8 * 3600),
                                           remainingText: "Open app"),
            leadingLabel: "Oven", trailingLabel: "Runs", accent: .teal
        )
        return ActivityContent(state: PowderRunActivityAttributes.ContentState(model: model),
                               staleDate: now.addingTimeInterval(8 * 3600))
    }
}
