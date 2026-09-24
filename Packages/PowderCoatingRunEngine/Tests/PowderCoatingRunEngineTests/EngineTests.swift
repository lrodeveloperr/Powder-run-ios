import XCTest
@testable import PowderCoatingRunEngine

final class EngineTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func recipe() throws -> CureRecipe {
        try CureRecipe(powderName: "Black polyester", productCode: "B-10", source: "Maker TDS rev 2",
                       targetMetalCelsius: 190, dwellSeconds: 600, maximumMetalCelsius: 210)
    }

    func testShopPresetNeedsFreshRunFactsAndKeepsHistoricalRecipeSnapshot() throws {
        var ledger = ShopLedger()
        let part = try Item(identity: "Steel rail brackets", quantity: 3,
                            substrate: "Mild steel", finish: "Satin black")
        let job = try ShopJob(reference: "J-PRESET", items: [part])
        try ledger.addJob(job, at: t0)
        let first = try ShopPreset(title: "Rail brackets · shop process", partIdentity: part.identity,
                                   substrate: part.substrate, finish: part.finish,
                                   requiredPreparationCheckpoints: ["Clean", "Mask"],
                                   recipe: recipe(), suggestedBooth: "Booth 1", suggestedOven: "Oven 1",
                                   measurementPoint: "Thickest part", measurementMethod: "Contact probe",
                                   sourceReviewedBy: "Pat", reviewedAt: t0)
        try ledger.savePreset(first, at: t0)
        XCTAssertThrowsError(try ledger.createRunFromPreset(jobID: job.id, itemID: part.id,
            presetID: first.id, quantity: 3, powderLot: "LOT-1", actualBooth: "Booth 1",
            operatorName: "Pat", sourceConfirmed: true, at: t0.addingTimeInterval(1)))
        try ledger.checkpoint(jobID: job.id, itemID: part.id, name: "Clean", operatorName: "Pat",
                              at: t0.addingTimeInterval(1))
        try ledger.checkpoint(jobID: job.id, itemID: part.id, name: "Mask", operatorName: "Lee",
                              at: t0.addingTimeInterval(2))
        XCTAssertThrowsError(try ledger.createRunFromPreset(jobID: job.id, itemID: part.id,
            presetID: first.id, quantity: 3, powderLot: "", actualBooth: "Booth 1",
            operatorName: "Pat", sourceConfirmed: true, at: t0.addingTimeInterval(3)))
        XCTAssertThrowsError(try ledger.createRunFromPreset(jobID: job.id, itemID: part.id,
            presetID: first.id, quantity: 3, powderLot: "LOT-1", actualBooth: "Booth 1",
            operatorName: "Pat", sourceConfirmed: false, at: t0.addingTimeInterval(3)))
        let id = try ledger.createRunFromPreset(jobID: job.id, itemID: part.id,
            presetID: first.id, quantity: 3, powderLot: "LOT-1", actualBooth: "Booth 1",
            operatorName: "Pat", sourceConfirmed: true, at: t0.addingTimeInterval(3))
        XCTAssertEqual(ledger.runs.first(where: { $0.id == id })?.recipe, first.recipe)
        XCTAssertEqual(ledger.links.first(where: { $0.runID == id })?.powderLot, "LOT-1")
        let revisedRecipe = try CureRecipe(powderName: "Shop polyester", productCode: "SHOP-2",
                                           source: "Shop TDS rev 3", targetMetalCelsius: 195,
                                           dwellSeconds: 660)
        let second = try ShopPreset(id: first.id, revision: 2, title: first.title,
                                    partIdentity: first.partIdentity, substrate: first.substrate,
                                    finish: first.finish, requiredPreparationCheckpoints: first.requiredPreparationCheckpoints,
                                    recipe: revisedRecipe, suggestedBooth: first.suggestedBooth,
                                    suggestedOven: first.suggestedOven, measurementPoint: first.measurementPoint,
                                    measurementMethod: first.measurementMethod, sourceReviewedBy: "Lee",
                                    reviewedAt: t0.addingTimeInterval(4))
        try ledger.savePreset(second, at: t0.addingTimeInterval(4))
        XCTAssertEqual(ledger.runs.first(where: { $0.id == id })?.recipe, first.recipe)
        XCTAssertThrowsError(try ledger.savePreset(first, at: t0))
        try ledger.removePreset(id: first.id, operatorName: "Lee", at: t0.addingTimeInterval(5))
        XCTAssertEqual(ledger.runs.first(where: { $0.id == id })?.recipe, first.recipe)
        try ledger.validate()
    }

    func testOldLedgerArchiveWithoutPresetsStillDecodes() throws {
        let old = ShopLedger()
        let data = try JSONEncoder().encode(old)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "presets")
        let oldData = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(ShopLedger.self, from: oldData)
        XCTAssertTrue(restored.presets.isEmpty)
        try restored.validate()
    }

    private func advance(_ run: inout CoatingRun, _ action: RunAction, _ seconds: TimeInterval) throws {
        try run.apply(action, at: t0.addingTimeInterval(seconds), expectedRevision: run.revision)
    }

    func testOvenAirCannotStartCureAndTimeCannotEndEarly() throws {
        var run = try CoatingRun(jobReference: "J1", partDescription: "Frame", quantity: 3,
                                 operatorName: "Pat", recipe: recipe(), at: t0)
        try advance(&run, .markApplied(note: "coat"), 1)
        try advance(&run, .enterOven, 2)
        try advance(&run, .observe(kind: .ovenAir, celsius: 200, location: "oven", method: "probe"), 3)
        XCTAssertThrowsError(try advance(&run, .startDwell, 3))
        XCTAssertEqual(run.revision, 3) // Failed commands cannot partially mutate.
        try advance(&run, .observe(kind: .partMetal, celsius: 190, location: "thickest part", method: "probe"), 4)
        try advance(&run, .startDwell, 4)
        try advance(&run, .observe(kind: .partMetal, celsius: 192, location: "thickest part", method: "probe"), 603)
        XCTAssertThrowsError(try advance(&run, .endDwell(operatorConfirmed: true), 603))
        try advance(&run, .observe(kind: .partMetal, celsius: 191, location: "thickest part", method: "probe"), 604)
        try advance(&run, .endDwell(operatorConfirmed: true), 604)
        XCTAssertEqual(run.stage, .cooling)
        XCTAssertTrue(run.requiredDwellSatisfied)
    }

    func testBelowTargetReadingResetsDwellAndCorrectionHoldsRelease() throws {
        var run = try CoatingRun(jobReference: "J1", partDescription: "Frame", quantity: 1,
                                 operatorName: "Pat", recipe: recipe(), at: t0)
        try advance(&run, .markApplied(note: "coat"), 1)
        try advance(&run, .enterOven, 2)
        try advance(&run, .observe(kind: .partMetal, celsius: 190, location: "part", method: "probe"), 3)
        try advance(&run, .startDwell, 3)
        try advance(&run, .observe(kind: .partMetal, celsius: 189, location: "part", method: "probe"), 100)
        XCTAssertEqual(run.stage, .heating)
        XCTAssertNil(run.dwellStartedAt)
        try advance(&run, .observe(kind: .partMetal, celsius: 190, location: "part", method: "probe"), 120)
        try advance(&run, .startDwell, 120)
        try advance(&run, .observe(kind: .partMetal, celsius: 191, location: "part", method: "probe"), 720)
        try advance(&run, .endDwell(operatorConfirmed: true), 720)
        try advance(&run, .correctObservation(index: 3, celsius: 180, reason: "probe misread", operatorName: "Pat"), 721)
        XCTAssertTrue(run.qualityHold)
        try advance(&run, .beginInspection, 722)
        try advance(&run, .inspect(Inspection(checkedAt: t0.addingTimeInterval(723), operatorName: "Pat",
                                             visual: .pass, thickness: nil, adhesion: nil, note: "")), 723)
        XCTAssertThrowsError(try advance(&run, .accept, 724))
    }

    func testMixedJobBatchReworkAndBackup() throws {
        var ledger = ShopLedger()
        let itemA = try Item(identity: "Rail", quantity: 2, substrate: "steel", finish: "black")
        let itemB = try Item(identity: "Bracket", quantity: 1, substrate: "aluminum", finish: "black")
        let a = try ShopJob(reference: "A", items: [itemA])
        let b = try ShopJob(reference: "B", items: [itemB])
        try ledger.addJob(a, at: t0)
        try ledger.addJob(b, at: t0)
        let r1 = try ledger.createRun(jobID: a.id, itemID: itemA.id, quantity: 2,
                                      recipe: recipe(), powderLot: "LOT1", booth: "1", operatorName: "Pat", at: t0)
        let r2 = try ledger.createRun(jobID: b.id, itemID: itemB.id, quantity: 1,
                                      recipe: recipe(), powderLot: "LOT2", booth: "1", operatorName: "Pat", at: t0)
        try ledger.action(runID: r1, .markApplied(note: "sprayed"), expectedRevision: 0, at: t0.addingTimeInterval(1))
        try ledger.action(runID: r2, .markApplied(note: "sprayed"), expectedRevision: 0, at: t0.addingTimeInterval(1))
        let batch = try ledger.loadBatch(loadIdentity: "Load 1", equipment: "Oven A", runIDs: [r1, r2], at: t0.addingTimeInterval(2))
        try ledger.recordOvenAir(batchID: batch, celsius: 200, location: "top", method: "probe", at: t0.addingTimeInterval(3))
        for id in [r1, r2] {
            var rev = ledger.runs.first(where: { $0.id == id })!.revision
            try ledger.action(runID: id, .observe(kind: .partMetal, celsius: 190, location: "part", method: "probe"), expectedRevision: rev, at: t0.addingTimeInterval(4))
            rev += 1
            try ledger.action(runID: id, .startDwell, expectedRevision: rev, at: t0.addingTimeInterval(4))
            rev += 1
            try ledger.action(runID: id, .observe(kind: .partMetal, celsius: 191, location: "part", method: "probe"), expectedRevision: rev, at: t0.addingTimeInterval(604))
            rev += 1
            try ledger.action(runID: id, .endDwell(operatorConfirmed: true), expectedRevision: rev, at: t0.addingTimeInterval(604))
        }
        try ledger.unloadBatch(batchID: batch, note: "unloaded", at: t0.addingTimeInterval(605))
        try ledger.action(runID: r1, .beginInspection, expectedRevision: 6, at: t0.addingTimeInterval(606))
        try ledger.action(runID: r1, .inspect(Inspection(checkedAt: t0.addingTimeInterval(607), operatorName: "Pat", visual: .mixed,
                                                  thickness: nil, adhesion: nil, note: "")), expectedRevision: 7, at: t0.addingTimeInterval(607))
        try ledger.action(runID: r1, .closeInspection(passed: 1, rework: 1, scrapped: 0,
                                                      code: .physicalDamage, reason: "chip"),
                          expectedRevision: 8, at: t0.addingTimeInterval(608))
        let s = try ledger.summary(jobID: a.id, itemID: itemA.id)
        XCTAssertEqual(s.released, 1)
        XCTAssertEqual(s.reworkPending, 1)
        XCTAssertThrowsError(try ledger.closeJob(jobID: a.id, method: .pickup, handoff: "pickup", at: t0.addingTimeInterval(610)))
        let child = try ledger.createRun(jobID: a.id, itemID: itemA.id, quantity: 1,
                                         recipe: recipe(), powderLot: "LOT1", booth: "1", operatorName: "Pat",
                                         parentRunID: r1, at: t0.addingTimeInterval(611))
        XCTAssertNotNil(ledger.links.first(where: { $0.runID == child })?.parentRunID)
        XCTAssertEqual(JobAccessPolicy.firstPassRuns(in: ledger), 2)
        XCTAssertEqual(JobAccessPolicy.freeRunsRemaining(in: ledger), 3)
        let restored = try LedgerArchive.decode(LedgerArchive.encode(ledger))
        XCTAssertEqual(restored.jobs.count, 2)
        XCTAssertEqual(restored.batches.first?.runIDs.count, 2)
        XCTAssertTrue(try LedgerArchive.batchCSV(restored).contains("LOT2"))
    }

    func testInvalidRevisionAndBadBackup() throws {
        var ledger = ShopLedger()
        let item = try Item(identity: "Rail", quantity: 1, substrate: "steel", finish: "black")
        let job = try ShopJob(reference: "J", items: [item])
        try ledger.addJob(job, at: t0)
        let id = try ledger.createRun(jobID: job.id, itemID: item.id, quantity: 1,
                                      recipe: recipe(), powderLot: "L", booth: "1", operatorName: "P", at: t0)
        try ledger.action(runID: id, .markApplied(note: ""), expectedRevision: 0, at: t0)
        XCTAssertThrowsError(try ledger.action(runID: id, .markApplied(note: ""), expectedRevision: 0, at: t0))
        XCTAssertEqual(ledger.runs[0].revision, 1)
        XCTAssertThrowsError(try LedgerArchive.decode(Data("{}".utf8)))
    }

    func testConfiguredCheckpointsAndOverTemperatureHold() throws {
        var ledger = ShopLedger()
        ledger.configure(try ShopSettings(requiredPreparationCheckpoints: ["blast"]), at: t0)
        let item = try Item(identity: "Rail", quantity: 1, substrate: "steel", finish: "black")
        let job = try ShopJob(reference: "J", items: [item])
        try ledger.addJob(job, at: t0)
        let id = try ledger.createRun(jobID: job.id, itemID: item.id, quantity: 1,
                                      recipe: recipe(), powderLot: "L", booth: "B", operatorName: "P", at: t0)
        XCTAssertThrowsError(try ledger.action(runID: id, .markApplied(note: "done"), expectedRevision: 0, at: t0))
        try ledger.checkpoint(jobID: job.id, itemID: item.id, name: "blast", operatorName: "P", at: t0)
        try ledger.action(runID: id, .markApplied(note: "done"), expectedRevision: 0, at: t0)
        let batch = try ledger.loadBatch(loadIdentity: "L1", equipment: "O1", runIDs: [id], at: t0.addingTimeInterval(1))
        XCTAssertThrowsError(try ledger.loadBatch(loadIdentity: "L2", equipment: "O1", runIDs: [id], at: t0.addingTimeInterval(2)))
        try ledger.action(runID: id, .observe(kind: .partMetal, celsius: 211, location: "part", method: "probe"), expectedRevision: 2, at: t0.addingTimeInterval(2))
        XCTAssertTrue(ledger.runs[0].qualityHold)
        try ledger.action(runID: id, .holdToRework(reason: "over temperature", operatorName: "P"), expectedRevision: 3, at: t0.addingTimeInterval(3))
        try ledger.unloadBatch(batchID: batch, note: "removed", at: t0.addingTimeInterval(4))
        XCTAssertEqual(try ledger.summary(jobID: job.id, itemID: item.id).reworkPending, 1)
    }

    func testCSVQuotesPotentialFormulas() throws {
        var ledger = ShopLedger()
        let item = try Item(identity: "=SUM(1,1)", quantity: 1, substrate: "steel", finish: "black")
        try ledger.addJob(try ShopJob(reference: "J", items: [item]), at: t0)
        let csv = try LedgerArchive.jobsCSV(ledger)
        XCTAssertTrue(csv.contains("\"'=SUM(1,1)\""))
    }

    func testCorrectionsChangeAuthoritativeRecordsAndPreserveAudit() throws {
        var ledger = ShopLedger()
        let item = try Item(identity: "Rail wrong", quantity: 10, substrate: "steel", finish: "blue")
        let job = try ShopJob(reference: "J-wrong", dueAt: t0, items: [item])
        try ledger.addJob(job, at: t0)
        try ledger.correctJob(jobID: job.id, reference: "J-right", dueAt: t0.addingTimeInterval(86_400),
                              reason: "ticket typo", operatorName: "Pat", at: t0.addingTimeInterval(1))
        try ledger.correctItem(jobID: job.id, itemID: item.id, identity: "Rail", quantity: 12,
                               finish: "black", reason: "recount", operatorName: "Pat", at: t0.addingTimeInterval(2))
        let id = try ledger.createRun(jobID: job.id, itemID: item.id, quantity: 12, recipe: recipe(),
                                      powderLot: "LOT-wrong", booth: "B", operatorName: "Pat", at: t0.addingTimeInterval(3))
        try ledger.correctRunSetup(runID: id, powderLot: "LOT-right", reason: "label checked",
                                   operatorName: "Pat", at: t0.addingTimeInterval(4))
        XCTAssertEqual(ledger.search("J-right").count, 1)
        XCTAssertEqual(try ledger.summary(jobID: job.id, itemID: item.id).intake, 12)
        XCTAssertEqual(ledger.links[0].powderLot, "LOT-right")
        XCTAssertTrue(try LedgerArchive.jobsCSV(ledger).contains("J-right"))
        XCTAssertTrue(ledger.events.contains(where: { $0.kind == "itemCorrected" && $0.detail.contains("10 -> 12") }))
        let prior = ledger.jobs[0].items[0]
        XCTAssertThrowsError(try ledger.correctItem(jobID: job.id, itemID: item.id, identity: "Wrong again",
                                                     quantity: 8, reason: "invalid", operatorName: "Pat"))
        XCTAssertEqual(ledger.jobs[0].items[0], prior)
    }

    func testNoBackdatedUnloadInspectionOrHandoff() throws {
        var ledger = ShopLedger()
        let item = try Item(identity: "Rail", quantity: 1, substrate: "steel", finish: "black")
        let job = try ShopJob(reference: "J", items: [item])
        try ledger.addJob(job, at: t0)
        let id = try ledger.createRun(jobID: job.id, itemID: item.id, quantity: 1, recipe: recipe(),
                                      powderLot: "L", booth: "B", operatorName: "Pat", at: t0)
        try ledger.action(runID: id, .markApplied(note: "coat"), expectedRevision: 0, at: t0.addingTimeInterval(1))
        let batch = try ledger.loadBatch(loadIdentity: "Load", equipment: "Oven", runIDs: [id], at: t0.addingTimeInterval(2))
        try ledger.action(runID: id, .observe(kind: .partMetal, celsius: 190, location: "part", method: "probe"), expectedRevision: 2, at: t0.addingTimeInterval(4))
        try ledger.action(runID: id, .startDwell, expectedRevision: 3, at: t0.addingTimeInterval(4))
        try ledger.action(runID: id, .observe(kind: .partMetal, celsius: 190, location: "part", method: "probe"), expectedRevision: 4, at: t0.addingTimeInterval(604))
        try ledger.action(runID: id, .endDwell(operatorConfirmed: true), expectedRevision: 5, at: t0.addingTimeInterval(604))
        XCTAssertThrowsError(try ledger.unloadBatch(batchID: batch, note: "backdated", at: t0.addingTimeInterval(10)))
        try ledger.unloadBatch(batchID: batch, note: "actual", at: t0.addingTimeInterval(605))
        XCTAssertThrowsError(try ledger.action(runID: id, .beginInspection, expectedRevision: 6, at: t0.addingTimeInterval(604)))
        try ledger.action(runID: id, .beginInspection, expectedRevision: 6, at: t0.addingTimeInterval(606))
        try ledger.action(runID: id, .inspect(Inspection(checkedAt: t0.addingTimeInterval(607), operatorName: "Pat", visual: .pass,
                                                 thickness: nil, adhesion: nil, note: "passed")), expectedRevision: 7, at: t0.addingTimeInterval(607))
        try ledger.action(runID: id, .accept, expectedRevision: 8, at: t0.addingTimeInterval(608))
        XCTAssertThrowsError(try ledger.closeJob(jobID: job.id, method: .pickup, handoff: "received",
                                                 at: t0.addingTimeInterval(100)))
        try ledger.closeJob(jobID: job.id, method: .pickup, handoff: "received", at: t0.addingTimeInterval(610))
    }

    func testMistakenCorrectionCanBeReviewedAndResolved() throws {
        var run = try CoatingRun(jobReference: "J", partDescription: "Rail", quantity: 1,
                                 operatorName: "Pat", recipe: recipe(), at: t0)
        try advance(&run, .markApplied(note: ""), 1)
        try advance(&run, .enterOven, 2)
        try advance(&run, .observe(kind: .partMetal, celsius: 190, location: "part", method: "probe"), 4)
        try advance(&run, .startDwell, 4)
        try advance(&run, .observe(kind: .partMetal, celsius: 190, location: "part", method: "probe"), 604)
        try advance(&run, .endDwell(operatorConfirmed: true), 604)
        try advance(&run, .correctObservation(index: 0, celsius: 180, reason: "mistyped", operatorName: "Pat"), 605)
        XCTAssertThrowsError(try advance(&run, .resolveHold(reason: "reviewed", operatorName: "Lee"), 606))
        try advance(&run, .correctObservation(index: 0, celsius: 190, reason: "verified original log", operatorName: "Lee"), 607)
        try advance(&run, .resolveHold(reason: "independent check", operatorName: "Lee"), 608)
        XCTAssertFalse(run.qualityHold)
        XCTAssertEqual(run.observations[0].celsius, 190)
        XCTAssertEqual(run.observationCorrections.count, 2)
    }

    func testPhotoEvidenceAndTruncation() throws {
        XCTAssertThrowsError(try Photo(caption: "bad", jpeg: Data([0xFF, 0xD8])))
        let url = try XCTUnwrap(Bundle.module.url(forResource: "sample", withExtension: "jpg"))
        let bytes = try Data(contentsOf: url)
        let item = try Item(identity: "Rail", quantity: 1, substrate: "steel", finish: "black")
        let job = try ShopJob(reference: "J", items: [item])
        var ledger = ShopLedger()
        try ledger.addJob(job, at: t0)
        let id = try ledger.createRun(jobID: job.id, itemID: item.id, quantity: 1, recipe: recipe(),
                                      powderLot: "L", booth: "B", operatorName: "Pat", at: t0)
        let photo = try Photo(caption: "chip", jpeg: bytes, purpose: .defect,
                              runID: id, operatorName: "Pat", capturedAt: t0)
        try ledger.addPhoto(photo, jobID: job.id, itemID: item.id, at: t0)
        let roundTrip = try LedgerArchive.decode(LedgerArchive.encode(ledger))
        XCTAssertEqual(roundTrip.jobs[0].items[0].photos[0].runID, id)
        try ledger.deletePhoto(photoID: photo.id, jobID: job.id, itemID: item.id,
                               reason: "wrong customer", operatorName: "Pat", at: t0.addingTimeInterval(1))
        XCTAssertEqual(ledger.jobs[0].items[0].photos.count, 0)
        XCTAssertTrue(ledger.events.contains(where: { $0.kind == "photoDeleted" }))
    }

    func testAcceptedRunCanResolveMistakenCorrectionWithoutRework() throws {
        var run = try CoatingRun(jobReference: "J", partDescription: "Rail", quantity: 1,
                                 operatorName: "Pat", recipe: recipe(), at: t0)
        try advance(&run, .markApplied(note: ""), 1)
        try advance(&run, .enterOven, 2)
        try advance(&run, .observe(kind: .partMetal, celsius: 190, location: "part", method: "probe"), 4)
        try advance(&run, .startDwell, 4)
        try advance(&run, .observe(kind: .partMetal, celsius: 190, location: "part", method: "probe"), 604)
        try advance(&run, .endDwell(operatorConfirmed: true), 604)
        try advance(&run, .beginInspection, 605)
        try advance(&run, .inspect(Inspection(checkedAt: t0.addingTimeInterval(606), operatorName: "Pat",
                                             visual: .pass, thickness: nil, adhesion: nil, note: "")), 606)
        try advance(&run, .accept, 607)
        try advance(&run, .correctObservation(index: 1, celsius: 180, reason: "suspected typo", operatorName: "Pat"), 608)
        XCTAssertTrue(run.qualityHold)
        try advance(&run, .correctObservation(index: 1, celsius: 190, reason: "paper record checked", operatorName: "Lee"), 609)
        try advance(&run, .resolveHold(reason: "independent review", operatorName: "Lee"), 610)
        XCTAssertEqual(run.stage, .accepted)
        XCTAssertEqual(run.disposition?.passed, 1)
        XCTAssertFalse(run.qualityHold)
    }

    func testTenThousandAcceleratedLifecyclesAcrossThousandYears() throws {
        var seed: UInt64 = 0x5EED_C0A7
        func next() -> UInt64 {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return seed
        }
        for index in 0..<10_000 {
            let day = Double(index) * 36.525  // About 1,000 simulated years in 10,000 jobs.
            let origin = t0.addingTimeInterval(day * 86_400)
            let target = Decimal(160 + Int(next() % 50))
            let seconds = 60 + Int(next() % 3600)
            let powder = try CureRecipe(powderName: "fixture", productCode: "T", source: "fixture",
                                        targetMetalCelsius: target, dwellSeconds: seconds,
                                        maximumMetalCelsius: target + 20)
            var run = try CoatingRun(jobReference: "J-\(index)", partDescription: "fixture",
                                     quantity: 1, operatorName: "fixture", recipe: powder, at: origin)
            func apply(_ action: RunAction, _ offset: TimeInterval) throws {
                try run.apply(action, at: origin.addingTimeInterval(offset), expectedRevision: run.revision)
            }
            try apply(.markApplied(note: ""), 1)
            try apply(.enterOven, 2)
            try apply(.observe(kind: .partMetal, celsius: target, location: "part", method: "probe"), 3)
            try apply(.startDwell, 3)
            let early = Double(seconds) + 2
            try apply(.observe(kind: .partMetal, celsius: target, location: "part", method: "probe"), early)
            do {
                try apply(.endDwell(operatorConfirmed: true), early)
                XCTFail("Early cure accepted at sequence \(index)")
            } catch let error as RunError {
                guard case .invalid = error else { throw error }
            }
            let finish = Double(seconds) + 3
            try apply(.observe(kind: .partMetal, celsius: target, location: "part", method: "probe"), finish)
            try apply(.endDwell(operatorConfirmed: true), finish)
            XCTAssertTrue(run.requiredDwellSatisfied)
            try run.validate()
        }
    }

    func testThousandSyntheticCustomerIntakeAndCorrectionScenarios() throws {
        for index in 0..<1_000 {
            let when = t0.addingTimeInterval(Double(index) * 86_400)
            let item = try Item(identity: "Part \(index)", quantity: (index % 7) + 1,
                                substrate: index.isMultiple(of: 2) ? "steel" : "aluminum",
                                finish: "finish \(index % 5)")
            let job = try ShopJob(reference: "C-\(index)", dueAt: when.addingTimeInterval(86_400),
                                  items: [item])
            var ledger = ShopLedger()
            try ledger.addJob(job, at: when)
            if index.isMultiple(of: 4) {
                try ledger.correctItem(jobID: job.id, itemID: item.id, identity: "Verified \(index)",
                                       reason: "intake transcription", operatorName: "fixture",
                                       at: when.addingTimeInterval(1))
            }
            let assigned = max(1, item.quantity - (index % 2))
            let runID = try ledger.createRun(jobID: job.id, itemID: item.id,
                                             quantity: assigned, recipe: recipe(),
                                             powderLot: "L\(index % 11)", booth: "B\(index % 3)",
                                             operatorName: "fixture", at: when.addingTimeInterval(2))
            XCTAssertEqual(ledger.links[0].runID, runID)
            let restored = try LedgerArchive.decode(LedgerArchive.encode(ledger))
            let summary = try restored.summary(jobID: job.id, itemID: item.id)
            XCTAssertEqual(summary.intake, item.quantity, "customer \(index)")
            XCTAssertEqual(summary.notProcessed, item.quantity - assigned, "customer \(index)")
        }
    }

    func testForgedAcceptedArchiveWithoutMeasurementsIsRejected() throws {
        var run = try CoatingRun(jobReference: "J", partDescription: "Rail", quantity: 1,
                                 operatorName: "Pat", recipe: recipe(), at: t0)
        try advance(&run, .markApplied(note: ""), 1)
        try advance(&run, .enterOven, 2)
        try advance(&run, .observe(kind: .partMetal, celsius: 190, location: "part", method: "probe"), 4)
        try advance(&run, .startDwell, 4)
        try advance(&run, .observe(kind: .partMetal, celsius: 190, location: "part", method: "probe"), 604)
        try advance(&run, .endDwell(operatorConfirmed: true), 604)
        try advance(&run, .beginInspection, 605)
        try advance(&run, .inspect(Inspection(checkedAt: t0.addingTimeInterval(606), operatorName: "Pat",
                                             visual: .pass, thickness: nil, adhesion: nil, note: "")), 606)
        try advance(&run, .accept, 607)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(run)) as? [String: Any])
        object["observations"] = []
        let forged = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(CoatingRun.self, from: forged)
        XCTAssertThrowsError(try decoded.validate())
    }

    func testTwoRepositoriesDoNotOverwriteEachOther() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("powder-ledger-\(UUID().uuidString).json")
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(atPath: url.path + ".lock")
        }
        let first = try LedgerRepository(url: url)
        let second = try LedgerRepository(url: url)
        let time = t0
        let a = try ShopJob(reference: "A", items: [Item(identity: "A", quantity: 1,
                                                           substrate: "steel", finish: "black")])
        let b = try ShopJob(reference: "B", items: [Item(identity: "B", quantity: 1,
                                                           substrate: "steel", finish: "white")])
        try await first.transact { ledger in try ledger.addJob(a, at: time) }
        try await second.transact(access: .pro) { ledger in try ledger.addJob(b, at: time) }
        let onDisk = try LedgerFileStore(url: url).load()
        let reloaded = try await first.snapshot()
        XCTAssertEqual(onDisk.jobs.count, 2)
        XCTAssertEqual(reloaded.jobs.count, 2)
    }

    func testFiveFreeFirstPassRunsThenNewJobNeedsSubscription() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("powder-access-\(UUID().uuidString).json")
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(atPath: url.path + ".lock")
        }
        let repo = try LedgerRepository(url: url)
        let time = t0
        let a = try ShopJob(reference: "FREE", items: [Item(identity: "A", quantity: 6,
                                                               substrate: "steel", finish: "black")])
        let b = try ShopJob(reference: "SECOND", items: [Item(identity: "B", quantity: 1,
                                                                 substrate: "steel", finish: "white")])
        let c = try ShopJob(reference: "THIRD", items: [Item(identity: "C", quantity: 1,
                                                                substrate: "steel", finish: "red")])
        try await repo.transact { ledger in try ledger.addJob(a, at: time) }
        try await repo.transact { ledger in try ledger.addJob(b, at: time) }
        let initial = try await repo.snapshot()
        XCTAssertEqual(JobAccessPolicy.freeRunsRemaining(in: initial), 5)
        let cure = try recipe()
        for index in 0..<5 {
            try await repo.transact { ledger in
                _ = try ledger.createRun(jobID: a.id, itemID: a.items[0].id, quantity: 1,
                                         recipe: cure, powderLot: "LOT-\(index)", booth: "B",
                                         operatorName: "Pat", at: time.addingTimeInterval(Double(index + 1)))
            }
        }
        let exhausted = try await repo.snapshot()
        XCTAssertEqual(JobAccessPolicy.freeRunsRemaining(in: exhausted), 0)
        do {
            try await repo.transact { ledger in try ledger.addJob(c, at: time) }
            XCTFail("A new job after five first-pass runs must require a subscription")
        } catch {
            let afterRejection = try await repo.snapshot()
            XCTAssertEqual(afterRejection.jobs.map(\.reference), ["FREE", "SECOND"])
        }
        // An existing job may finish its remaining parts after the fifth run.
        try await repo.transact { ledger in
            _ = try ledger.createRun(jobID: a.id, itemID: a.items[0].id, quantity: 1,
                                     recipe: cure, powderLot: "LOT-6", booth: "B",
                                     operatorName: "Pat", at: time.addingTimeInterval(6))
        }
        try await repo.transact(access: .pro) { ledger in try ledger.addJob(c, at: time) }
        let afterUnlock = try await repo.snapshot()
        XCTAssertEqual(afterUnlock.jobs.count, 3)
        XCTAssertEqual(JobAccessPolicy.firstPassRuns(in: afterUnlock), 6)
        // Expiry cannot erase a paid job, and cannot authorize another new job.
        try await repo.transact { ledger in
            _ = try ledger.createRun(jobID: c.id, itemID: c.items[0].id, quantity: 1,
                                     recipe: cure, powderLot: "LOT-C", booth: "B",
                                     operatorName: "Pat", at: time.addingTimeInterval(7))
        }
        let d = try ShopJob(reference: "FOURTH", items: [Item(identity: "D", quantity: 1,
                                                                 substrate: "steel", finish: "blue")])
        do {
            try await repo.transact { ledger in try ledger.addJob(d, at: time) }
            XCTFail("Expiry must block creating new work")
        } catch {
            let stillThree = try await repo.snapshot()
            XCTAssertEqual(stillThree.jobs.count, 3)
        }
    }

    func testAddItemKeepsASecondPhysicalGroupInTheSameOpenJob() throws {
        var ledger = ShopLedger()
        let first = try Item(identity: "Brackets", quantity: 8, substrate: "steel", finish: "black")
        let second = try Item(identity: "Rails", quantity: 3, substrate: "aluminium", finish: "white")
        let job = try ShopJob(reference: "SHARED", items: [first])
        try ledger.addJob(job, at: t0)
        try ledger.addItem(second, to: job.id, at: t0.addingTimeInterval(1))
        XCTAssertEqual(ledger.jobs[0].items.map(\.id), [first.id, second.id])
        XCTAssertEqual(try ledger.summary(jobID: job.id, itemID: second.id).notProcessed, 3)
        try ledger.validate()
        XCTAssertThrowsError(try ledger.addItem(second, to: job.id, at: t0.addingTimeInterval(2)))
    }

    func testClosedJobCorrectionRecordsAlertWithoutReopeningDelivery() throws {
        var ledger = ShopLedger()
        let item = try Item(identity: "Rail", quantity: 1, substrate: "steel", finish: "black")
        let job = try ShopJob(reference: "DELIVERED", items: [item])
        try ledger.addJob(job, at: t0)
        let runID = try ledger.createRun(jobID: job.id, itemID: item.id, quantity: 1,
                                         recipe: recipe(), powderLot: "L", booth: "B",
                                         operatorName: "Pat", at: t0)
        try ledger.action(runID: runID, .markApplied(note: "coat"), expectedRevision: 0, at: t0.addingTimeInterval(1))
        let batch = try ledger.loadBatch(loadIdentity: "Load", equipment: "Oven", runIDs: [runID],
                                         at: t0.addingTimeInterval(2))
        try ledger.action(runID: runID, .observe(kind: .partMetal, celsius: 190, location: "part", method: "probe"),
                          expectedRevision: 2, at: t0.addingTimeInterval(4))
        try ledger.action(runID: runID, .startDwell, expectedRevision: 3, at: t0.addingTimeInterval(4))
        try ledger.action(runID: runID, .observe(kind: .partMetal, celsius: 190, location: "part", method: "probe"),
                          expectedRevision: 4, at: t0.addingTimeInterval(604))
        try ledger.action(runID: runID, .endDwell(operatorConfirmed: true), expectedRevision: 5,
                          at: t0.addingTimeInterval(604))
        try ledger.unloadBatch(batchID: batch, note: "out", at: t0.addingTimeInterval(605))
        try ledger.action(runID: runID, .beginInspection, expectedRevision: 6, at: t0.addingTimeInterval(606))
        try ledger.action(runID: runID, .inspect(Inspection(checkedAt: t0.addingTimeInterval(607),
                            operatorName: "Pat", visual: .pass, thickness: nil, adhesion: nil, note: "")),
                          expectedRevision: 7, at: t0.addingTimeInterval(607))
        try ledger.action(runID: runID, .accept, expectedRevision: 8, at: t0.addingTimeInterval(608))
        let handedOff = t0.addingTimeInterval(610)
        try ledger.closeJob(jobID: job.id, method: .pickup, handoff: "customer collected",
                            at: handedOff)
        try ledger.action(runID: runID,
                          .correctObservation(index: 1, celsius: 180, reason: "probe record discrepancy", operatorName: "Pat"),
                          expectedRevision: 9, at: t0.addingTimeInterval(700))
        XCTAssertEqual(ledger.jobs[0].closedAt, handedOff)
        XCTAssertTrue(ledger.runs[0].qualityHold)
        XCTAssertEqual(try ledger.summary(jobID: job.id, itemID: item.id).released, 1)
        XCTAssertTrue(ledger.events.contains(where: { $0.kind == "postHandoffQualityAlert" && $0.subjectID == runID }))
        XCTAssertFalse(ledger.events.contains(where: { $0.kind == "jobReopened" }))
        XCTAssertTrue(try LedgerArchive.jobsCSV(ledger).contains("\"YES\""))
        XCTAssertTrue(try LedgerArchive.batchCSV(ledger).contains(",\"YES\"\r\n"))
        XCTAssertEqual(try LedgerArchive.decode(LedgerArchive.encode(ledger)).jobs[0].closedAt, handedOff)
        XCTAssertThrowsError(try ledger.action(runID: runID,
            .holdToRework(reason: "parts already delivered", operatorName: "Pat"),
            expectedRevision: 10, at: t0.addingTimeInterval(701)))
        XCTAssertThrowsError(try ledger.correctItem(jobID: job.id, itemID: item.id, quantity: 2,
            reason: "recount", operatorName: "Pat", at: t0.addingTimeInterval(701)))
        XCTAssertThrowsError(try ledger.recordPostHandoffFollowup(jobID: job.id, runID: runID,
            operatorName: "Pat", note: "customer contacted", at: t0.addingTimeInterval(609)))
        try ledger.recordPostHandoffFollowup(jobID: job.id, runID: runID,
            operatorName: "Pat", note: "customer contacted; return requested", at: t0.addingTimeInterval(702))
        try ledger.action(runID: runID,
            .correctObservation(index: 1, celsius: 190, reason: "traceable probe log verified", operatorName: "Lee"),
            expectedRevision: 10, at: t0.addingTimeInterval(703))
        try ledger.action(runID: runID, .resolveHold(reason: "reviewed against traceable log", operatorName: "Lee"),
                          expectedRevision: 11, at: t0.addingTimeInterval(704))
        XCTAssertFalse(ledger.runs[0].qualityHold)
        XCTAssertEqual(ledger.jobs[0].closedAt, handedOff)
        XCTAssertTrue(ledger.events.contains(where: { $0.kind == "postHandoffQualityResolved" }))
        XCTAssertTrue(try LedgerArchive.jobsCSV(ledger).contains("\"NO\""))
        XCTAssertEqual(try LedgerArchive.decode(LedgerArchive.encode(ledger)).jobs[0].closedAt, handedOff)
    }

    func testThermalRecipeRejectsImplausibleLowEntry() throws {
        for low in [Decimal(40), Decimal(119)] {
            XCTAssertThrowsError(try CureRecipe(powderName: "test", productCode: "T", source: "TDS",
                targetMetalCelsius: low, dwellSeconds: 600))
        }
        let minimum = try CureRecipe(powderName: "test", productCode: "T", source: "TDS",
                                     targetMetalCelsius: 120, dwellSeconds: 600)
        XCTAssertEqual(minimum.targetMetalCelsius, 120)
        var mutable = minimum
        mutable.targetMetalCelsius = 40
        XCTAssertThrowsError(try CoatingRun(jobReference: "J", partDescription: "rail", quantity: 1,
                                             operatorName: "Pat", recipe: mutable, at: t0))
    }
}
