import Foundation
import PowderCoatingRunEngine
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

func demo() throws -> ShopLedger {
    let t = Date(timeIntervalSince1970: 1_700_000_000)
    let recipe = try CureRecipe(powderName: "Sample polyester", productCode: "SAMPLE-1",
                                source: "Sample only; replace with manufacturer data", targetMetalCelsius: 190,
                                dwellSeconds: 600, maximumMetalCelsius: 210)
    let item1 = try Item(identity: "Rail", quantity: 2, substrate: "steel", finish: "black")
    let item2 = try Item(identity: "Bracket", quantity: 1, substrate: "aluminum", finish: "black")
    let job1 = try ShopJob(reference: "SAMPLE-J1", items: [item1])
    let job2 = try ShopJob(reference: "SAMPLE-J2", items: [item2])
    var ledger = ShopLedger()
    ledger.configure(try ShopSettings(requiredPreparationCheckpoints: ["cleaning", "masking"]), at: t)
    try ledger.addJob(job1, at: t)
    try ledger.addJob(job2, at: t)
    for job in [job1, job2] {
        let itemID = job.items[0].id
        try ledger.checkpoint(jobID: job.id, itemID: itemID, name: "cleaning", operatorName: "Sample Operator", at: t)
        try ledger.checkpoint(jobID: job.id, itemID: itemID, name: "masking", operatorName: "Sample Operator", at: t)
    }
    let r1 = try ledger.createRun(jobID: job1.id, itemID: item1.id, quantity: 2, recipe: recipe,
                                  powderLot: "LOT-A", booth: "Booth 1", operatorName: "Sample Operator", at: t)
    let r2 = try ledger.createRun(jobID: job2.id, itemID: item2.id, quantity: 1, recipe: recipe,
                                  powderLot: "LOT-B", booth: "Booth 1", operatorName: "Sample Operator", at: t)
    for id in [r1, r2] {
        try ledger.action(runID: id, .markApplied(note: "sprayed"), expectedRevision: 0, at: t.addingTimeInterval(1))
    }
    let batch = try ledger.loadBatch(loadIdentity: "LOAD-01", equipment: "Oven 1",
                                     runIDs: [r1, r2], at: t.addingTimeInterval(2))
    try ledger.recordOvenAir(batchID: batch, celsius: 200, location: "oven", method: "probe", at: t.addingTimeInterval(3))
    for id in [r1, r2] {
        var rev = ledger.runs.first(where: { $0.id == id })!.revision
        try ledger.action(runID: id, .observe(kind: .partMetal, celsius: 190,
            location: "thickest part", method: "probe"), expectedRevision: rev, at: t.addingTimeInterval(4))
        rev += 1
        try ledger.action(runID: id, .startDwell, expectedRevision: rev, at: t.addingTimeInterval(4))
        rev += 1
        try ledger.action(runID: id, .observe(kind: .partMetal, celsius: 192,
            location: "thickest part", method: "probe"), expectedRevision: rev, at: t.addingTimeInterval(604))
        rev += 1
        try ledger.action(runID: id, .endDwell(operatorConfirmed: true), expectedRevision: rev,
                          at: t.addingTimeInterval(604))
    }
    try ledger.unloadBatch(batchID: batch, note: "unloaded", at: t.addingTimeInterval(605))
    for id in [r1, r2] {
        let rev = ledger.runs.first(where: { $0.id == id })!.revision
        try ledger.action(runID: id, .beginInspection, expectedRevision: rev, at: t.addingTimeInterval(606))
        try ledger.action(runID: id, .inspect(Inspection(checkedAt: t.addingTimeInterval(607),
            operatorName: "Sample Operator", visual: .pass, thickness: nil, adhesion: nil, note: "")),
            expectedRevision: rev + 1, at: t.addingTimeInterval(607))
        try ledger.action(runID: id, .accept, expectedRevision: rev + 2, at: t.addingTimeInterval(608))
    }
    try ledger.closeJob(jobID: job1.id, method: .pickup, handoff: "Sample pickup", at: t.addingTimeInterval(610))
    try ledger.closeJob(jobID: job2.id, method: .delivery, handoff: "Sample delivery", at: t.addingTimeInterval(610))
    return ledger
}

do {
    let args = Array(CommandLine.arguments.dropFirst())
    let command = args.first ?? "help"
    switch command {
    case "demo":
        let ledger = try demo()
        print("Multi-job oven batch: \(ledger.batches[0].loadIdentity)")
        print(try LedgerArchive.jobsCSV(ledger))
        if args.count > 1 {
            try LedgerFileStore(url: URL(fileURLWithPath: args[1])).save(ledger)
            print("Saved sample archive to \(args[1])")
        }
    case "inspect", "jobs-csv", "batches-csv":
        guard args.count == 2 else { throw RunError.invalid("Provide an archive JSON path.") }
        let ledger = try LedgerFileStore(url: URL(fileURLWithPath: args[1])).load()
        if command == "inspect" {
            for job in ledger.jobs {
                print("\(job.reference): \(job.closedAt == nil ? "open" : "closed")")
                for item in job.items {
                    let s = try ledger.summary(jobID: job.id, itemID: item.id)
                    print("  \(item.identity): intake \(s.intake), released \(s.released), rework \(s.reworkPending), scrap \(s.scrapped), not processed \(s.notProcessed)")
                }
            }
        } else if command == "jobs-csv" { print(try LedgerArchive.jobsCSV(ledger), terminator: "") }
        else { print(try LedgerArchive.batchCSV(ledger), terminator: "") }
    default:
        print("powder-run-harness demo [archive.json] | inspect archive.json | jobs-csv archive.json | batches-csv archive.json")
        print("The demo is synthetic. All values require the actual powder technical data sheet before real use.")
    }
} catch {
    FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
    exit(1)
}
