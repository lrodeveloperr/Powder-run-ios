import Foundation

#if canImport(UIKit)
import UIKit

public enum PDFReport {
    /// Factual local report; it does not certify a coating or infer continuous temperature.
    public static func job(_ ledger: ShopLedger, jobID: UUID) throws -> Data {
        try ledger.validate()
        guard let job = ledger.jobs.first(where: { $0.id == jobID }) else {
            throw RunError.invalid("Job not found.")
        }
        var lines = ["POWDER COATING RUN RECORD", "Job: \(job.reference)",
                     "Customer ref: \(job.customerReference ?? "—")",
                     "Due: \(job.dueAt.map { ISO8601DateFormatter().string(from: $0) } ?? "not set")",
                     "Handoff: \(job.handoffMethod?.rawValue ?? "pending") — \(job.handoff ?? "Pending")", ""]
        for item in job.items {
            let summary = try ledger.summary(jobID: jobID, itemID: item.id)
            lines += ["Part: \(item.identity) (\(item.substrate), \(item.finish))",
                      "Intake \(summary.intake)  Released \(summary.released)  Scrap \(summary.scrapped)  Rework pending \(summary.reworkPending)"]
            if job.closedAt != nil && ledger.links.contains(where: { link in
                link.jobID == jobID && link.itemID == item.id &&
                ledger.runs.contains(where: { $0.id == link.runID && $0.qualityHold })
            }) {
                lines.append("POST-HANDOFF QUALITY ALERT: Delivered units require documented customer follow-up.")
            }
            for checkpoint in job.checkpoints.filter({ $0.itemID == item.id }) {
                lines.append("Preparation: \(checkpoint.name) by \(checkpoint.operatorName) at \(ISO8601DateFormatter().string(from: checkpoint.completedAt)); \(checkpoint.note)")
            }
            for photo in item.photos {
                lines.append("Photo \(photo.id.uuidString): \(photo.purpose.rawValue), run \(photo.runID?.uuidString ?? "item"), \(photo.caption), by \(photo.operatorName ?? "unknown")")
            }
            for link in ledger.links.filter({ $0.itemID == item.id && $0.jobID == jobID }) {
                guard let run = ledger.runs.first(where: { $0.id == link.runID }) else { continue }
                let batch = ledger.batches.first(where: { $0.id == link.batchID })
                let start = run.dwellStartedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "unconfirmed"
                let end = run.dwellEndedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "unconfirmed"
                lines += ["Run \(run.id.uuidString.prefix(8)): \(run.quantity) units, powder \(run.recipe.productCode), lot \(link.powderLot)",
                          "Oven load: \(batch?.loadIdentity ?? "not loaded"), equipment: \(batch?.equipment ?? "not loaded"), entered \(batch?.enteredAt.description ?? "unknown"), exited \(batch?.exitedAt?.description ?? "pending")",
                          "Cure source: \(run.recipe.source). Part target: \(run.recipe.targetMetalCelsius) °C / \(run.recipe.dwellSeconds) s",
                          "Dwell: \(start) to \(end). Quality hold: \(run.qualityHold ? "YES" : "NO")",
                          "QC: \(run.inspection?.visual.rawValue ?? "pending") by \(run.inspection?.operatorName ?? "pending") at \(run.inspection?.checkedAt.description ?? "pending")",
                          "Thickness \(run.inspection?.thickness?.rawValue ?? "not checked"), adhesion \(run.inspection?.adhesion?.rawValue ?? "not checked"); note: \(run.inspection?.note ?? "")",
                          "Pass \(run.disposition?.passed ?? 0), rework \(run.disposition?.rework ?? 0), scrap \(run.disposition?.scrapped ?? 0), defect \(run.disposition?.defectCode?.rawValue ?? "none"); reason: \(run.disposition?.reason ?? "")"]
                for (index, reading) in run.observations.enumerated() {
                    lines.append("  \(ISO8601DateFormatter().string(from: reading.recordedAt)): \(reading.kind.rawValue) original \(reading.celsius) °C, effective \(run.effectiveCelsius(at: index)) °C (\(reading.method), \(reading.location))")
                }
                for correction in run.observationCorrections {
                    lines.append("  CORRECTION to reading \(correction.originalIndex): \(correction.correctedCelsius) °C by \(correction.operatorName) at \(correction.recordedAt); \(correction.reason)")
                }
                for air in batch?.airReadings ?? [] {
                    lines.append("  Oven air: \(air.celsius) °C (\(air.method), \(air.location))")
                }
            }
            lines.append("")
        }
        let relevantIDs = Set([job.id] + job.items.map(\.id) + ledger.links.filter { $0.jobID == jobID }.map(\.runID) +
                              ledger.links.filter { $0.jobID == jobID }.compactMap(\.batchID))
        for event in ledger.events where relevantIDs.contains(event.subjectID) &&
            (event.kind.contains("Corrected") || event.kind == "correction" || event.kind == "photoDeleted" ||
             event.kind.hasPrefix("postHandoff")) {
            lines.append("Audit \(event.at): \(event.kind) — \(event.detail)")
        }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        return renderer.pdfData { context in
            var y: CGFloat = 36
            context.beginPage()
            for line in lines {
                let chars = Array(line)
                let chunks = stride(from: 0, to: max(1, chars.count), by: 100).map {
                    String(chars[$0..<min($0 + 100, chars.count)])
                }
                for chunk in chunks {
                    if y > 742 { context.beginPage(); y = 36 }
                    (chunk as NSString).draw(at: CGPoint(x: 36, y: y), withAttributes: [
                        .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .regular),
                        .foregroundColor: UIColor.black
                    ])
                    y += 14
                }
            }
            for item in job.items {
                for photo in item.photos {
                    if y > 510 { context.beginPage(); y = 36 }
                    let shortRun = photo.runID.map { String($0.uuidString.prefix(8)) } ?? "item"
                    let caption = "\(photo.purpose.rawValue) • \(shortRun) • \(photo.caption)" as NSString
                    caption.draw(at: CGPoint(x: 36, y: y), withAttributes: [
                        .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .regular),
                        .foregroundColor: UIColor.black
                    ])
                    y += 14
                    if let image = UIImage(data: photo.jpeg) {
                        image.draw(in: CGRect(x: 36, y: y, width: 240, height: 180))
                    }
                    y += 200
                }
            }
        }
    }
}
#endif
