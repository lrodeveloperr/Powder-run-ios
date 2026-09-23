import Foundation
#if canImport(ImageIO)
import ImageIO
#endif

public enum PhotoPurpose: String, Codable, Sendable { case intake, preparation, defect, handoff }

public struct Photo: Codable, Equatable, Sendable {
    public let id: UUID
    public let caption: String
    public let jpeg: Data
    public let purpose: PhotoPurpose
    public let runID: UUID?
    public let operatorName: String?
    public let capturedAt: Date?
    public init(id: UUID = UUID(), caption: String, jpeg: Data, purpose: PhotoPurpose = .intake,
                runID: UUID? = nil, operatorName: String? = nil, capturedAt: Date? = nil) throws {
        guard Self.validJPEG(jpeg) else {
            throw RunError.invalid("Attach a complete JPEG no larger than 5 MB.")
        }
        guard purpose != .defect || (runID != nil && !(operatorName ?? "").isEmpty && capturedAt != nil) else {
            throw RunError.invalid("Defect evidence needs a run, operator and capture time.")
        }
        self.id = id; self.caption = caption; self.jpeg = jpeg
        self.purpose = purpose; self.runID = runID
        self.operatorName = operatorName; self.capturedAt = capturedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, caption, jpeg, purpose, runID, operatorName, capturedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: c.decode(UUID.self, forKey: .id), caption: c.decode(String.self, forKey: .caption),
                      jpeg: c.decode(Data.self, forKey: .jpeg),
                      purpose: c.decodeIfPresent(PhotoPurpose.self, forKey: .purpose) ?? .intake,
                      runID: c.decodeIfPresent(UUID.self, forKey: .runID),
                      operatorName: c.decodeIfPresent(String.self, forKey: .operatorName),
                      capturedAt: c.decodeIfPresent(Date.self, forKey: .capturedAt))
    }

    public static func validJPEG(_ data: Data) -> Bool {
        guard data.count >= 32, data.count <= 5_000_000,
              data.starts(with: [0xFF, 0xD8]), data.suffix(2).elementsEqual([0xFF, 0xD9]) else {
            return false
        }
        let bytes = Array(data)
        let markers = Set(zip(bytes, bytes.dropFirst()).compactMap { pair -> UInt8? in
            pair.0 == 0xFF ? pair.1 : nil
        })
        guard markers.contains(0xDA), markers.contains(0xC0) || markers.contains(0xC1) ||
              markers.contains(0xC2) else { return false }
        #if canImport(ImageIO)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as NSDictionary?,
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 12_000, height <= 12_000,
              width <= 40_000_000 / height else { return false }
        #endif
        return true
    }
}

public struct Item: Codable, Equatable, Sendable {
    public let id: UUID
    public var identity: String
    public var quantity: Int
    public var substrate: String
    public var finish: String
    public var photos: [Photo]
    public init(id: UUID = UUID(), identity: String, quantity: Int, substrate: String,
                finish: String, photos: [Photo] = []) throws {
        guard !identity.isEmpty, !substrate.isEmpty, !finish.isEmpty, quantity > 0,
              quantity <= 1_000_000, photos.count <= 20 else {
            throw RunError.invalid("Item identity, substrate, finish and a valid quantity are required.")
        }
        self.id = id; self.identity = identity; self.quantity = quantity
        self.substrate = substrate; self.finish = finish; self.photos = photos
    }
}

public struct Checkpoint: Codable, Equatable, Sendable {
    public let itemID: UUID
    public let name: String
    public let completedAt: Date
    public let operatorName: String
    public let note: String
}

public struct ShopJob: Codable, Equatable, Sendable {
    public let id: UUID
    public var reference: String
    public var customerReference: String?
    public var dueAt: Date?
    public var items: [Item]
    public var checkpoints: [Checkpoint]
    public var closedAt: Date?
    public var handoff: String?
    public var handoffMethod: HandoffMethod?
    public init(id: UUID = UUID(), reference: String, customerReference: String? = nil,
                dueAt: Date? = nil, items: [Item]) throws {
        guard !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !items.isEmpty, Set(items.map(\.id)).count == items.count else {
            throw RunError.invalid("A job needs a reference and unique physical item groups.")
        }
        self.id = id; self.reference = reference; self.customerReference = customerReference
        self.dueAt = dueAt; self.items = items; self.checkpoints = []
    }
}

public enum HandoffMethod: String, Codable, Sendable { case pickup, delivery, courier }

public struct ShopSettings: Codable, Equatable, Sendable {
    public var requiredPreparationCheckpoints: [String]
    public init() { requiredPreparationCheckpoints = [] }
    public init(requiredPreparationCheckpoints: [String]) throws {
        guard Set(requiredPreparationCheckpoints).count == requiredPreparationCheckpoints.count,
              requiredPreparationCheckpoints.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw RunError.invalid("Checkpoint names must be unique and nonempty.")
        }
        self.requiredPreparationCheckpoints = requiredPreparationCheckpoints
    }
}

public struct RunLink: Codable, Equatable, Sendable {
    public let runID: UUID
    public let jobID: UUID
    public let itemID: UUID
    public var powderLot: String
    public var booth: String
    public let parentRunID: UUID?
    public var batchID: UUID?
}

public struct OvenBatch: Codable, Equatable, Sendable {
    public let id: UUID
    public var loadIdentity: String
    public var equipment: String
    public let runIDs: [UUID]
    public let enteredAt: Date
    public var exitedAt: Date?
    public var airReadings: [TemperatureObservation]
    public var notes: [RunEvent]
}

public struct LedgerEvent: Codable, Equatable, Sendable {
    public let id: UUID
    public let at: Date
    public let kind: String
    public let subjectID: UUID
    public let detail: String
    public let correctsEventID: UUID?
}

public struct QuantitySummary: Equatable, Sendable {
    public let intake: Int
    public let released: Int
    public let reworkPending: Int
    public let scrapped: Int
    public let notProcessed: Int
}

public struct ShopLedger: Codable, Sendable {
    public static let schemaVersion = 1
    public let schemaVersion: Int
    public private(set) var jobs: [ShopJob]
    public private(set) var runs: [CoatingRun]
    public private(set) var links: [RunLink]
    public private(set) var batches: [OvenBatch]
    public private(set) var events: [LedgerEvent]
    public private(set) var settings: ShopSettings
    public private(set) var presets: [ShopPreset]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, jobs, runs, links, batches, events, settings, presets
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        jobs = try c.decode([ShopJob].self, forKey: .jobs)
        runs = try c.decode([CoatingRun].self, forKey: .runs)
        links = try c.decode([RunLink].self, forKey: .links)
        batches = try c.decode([OvenBatch].self, forKey: .batches)
        events = try c.decode([LedgerEvent].self, forKey: .events)
        settings = try c.decode(ShopSettings.self, forKey: .settings)
        presets = try c.decodeIfPresent([ShopPreset].self, forKey: .presets) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(jobs, forKey: .jobs)
        try c.encode(runs, forKey: .runs)
        try c.encode(links, forKey: .links)
        try c.encode(batches, forKey: .batches)
        try c.encode(events, forKey: .events)
        try c.encode(settings, forKey: .settings)
        try c.encode(presets, forKey: .presets)
    }

    public init() {
        schemaVersion = Self.schemaVersion
        jobs = []; runs = []; links = []; batches = []; events = []
        settings = ShopSettings(); presets = []
    }

    public func validate() throws {
        guard schemaVersion == Self.schemaVersion else { throw RunError.unsupportedVersion }
        guard Set(jobs.map(\.id)).count == jobs.count,
              Set(jobs.map(\.reference)).count == jobs.count,
              Set(runs.map(\.id)).count == runs.count,
              Set(batches.map(\.id)).count == batches.count,
              Set(links.map(\.runID)).count == links.count,
              Set(runs.map(\.id)) == Set(links.map(\.runID)) else { throw RunError.duplicateID }
        for run in runs { try run.validate() }
        guard Set(presets.map(\.id)).count == presets.count,
              Set(presets.map(\.title)).count == presets.count else { throw RunError.duplicateID }
        for preset in presets { try preset.validate() }
        _ = try ShopSettings(requiredPreparationCheckpoints: settings.requiredPreparationCheckpoints)
        for link in links {
            guard let run = runs.first(where: { $0.id == link.runID }),
                  jobs.contains(where: { $0.id == link.jobID && $0.items.contains(where: { $0.id == link.itemID }) }),
                  link.batchID == nil || batches.contains(where: { $0.id == link.batchID && $0.runIDs.contains(link.runID) }) else {
                throw RunError.invalid("Broken job, item or oven-batch link.")
            }
            let ovenEntry = run.events.first(where: { $0.kind == "ovenEntered" })?.at
            guard (ovenEntry == nil) == (link.batchID == nil) else {
                throw RunError.invalid("Oven activity requires a matching load.")
            }
            if let batchID = link.batchID, let batch = batches.first(where: { $0.id == batchID }) {
                guard ovenEntry == batch.enteredAt,
                      run.observations.allSatisfy({ $0.recordedAt >= batch.enteredAt &&
                          (batch.exitedAt == nil || $0.recordedAt <= batch.exitedAt!) }),
                      batch.exitedAt == nil || (run.stage != .heating && run.stage != .dwelling),
                      run.inspection == nil || (batch.exitedAt != nil && run.inspection!.checkedAt >= batch.exitedAt!) else {
                    throw RunError.invalid("Run facts contradict oven entry, exit or inspection.")
                }
            }
            if let parentID = link.parentRunID {
                guard parentID != link.runID,
                      let parent = runs.first(where: { $0.id == parentID }),
                      links.contains(where: { $0.runID == parentID && $0.jobID == link.jobID && $0.itemID == link.itemID }),
                      parent.disposition != nil, parent.disposition!.rework > 0 else {
                    throw RunError.invalid("Invalid rework parent.")
                }
            }
        }
        for batch in batches {
            guard Set(batch.runIDs).count == batch.runIDs.count,
                  batch.runIDs.allSatisfy({ id in links.contains(where: { $0.runID == id && $0.batchID == batch.id }) }),
                  batch.exitedAt == nil || batch.exitedAt! >= batch.enteredAt else {
                throw RunError.invalid("Batch membership is inconsistent.")
            }
            if let exit = batch.exitedAt {
                guard batch.airReadings.allSatisfy({ $0.recordedAt >= batch.enteredAt && $0.recordedAt <= exit }),
                      batch.runIDs.allSatisfy({ id in
                          guard let run = runs.first(where: { $0.id == id }) else { return false }
                          return run.dwellEndedAt == nil || run.dwellEndedAt! <= exit
                      }) else { throw RunError.invalid("Oven exit precedes a measurement or dwell end.") }
            }
        }
        for job in jobs {
            guard !job.reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !job.items.isEmpty, Set(job.items.map(\.id)).count == job.items.count else {
                throw RunError.invalid("Invalid job items.")
            }
            for item in job.items {
                guard item.quantity > 0, item.quantity <= 1_000_000,
                      !item.identity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !item.substrate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !item.finish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      item.photos.count <= 20,
                      Set(item.photos.map(\.id)).count == item.photos.count,
                      item.photos.allSatisfy({ photo in Photo.validJPEG(photo.jpeg) &&
                          (photo.purpose != .defect || (photo.runID != nil && photo.capturedAt != nil &&
                            !(photo.operatorName ?? "").isEmpty)) &&
                          (photo.runID == nil || links.contains(where: { link in
                              link.runID == photo.runID && link.jobID == job.id && link.itemID == item.id
                          })) }) else {
                    throw RunError.invalid("Invalid item quantity or photo.")
                }
                let original = links.filter { $0.itemID == item.id && $0.jobID == job.id && $0.parentRunID == nil }
                    .compactMap { link in runs.first(where: { $0.id == link.runID })?.quantity }.reduce(0, +)
                guard original <= item.quantity else { throw RunError.invalid("Allocated units exceed intake.") }
                for parent in links.filter({ $0.itemID == item.id && $0.jobID == job.id }) {
                    let childCount = links.filter { $0.parentRunID == parent.runID }
                        .compactMap { link in runs.first(where: { $0.id == link.runID })?.quantity }.reduce(0, +)
                    let rework = runs.first(where: { $0.id == parent.runID })?.disposition?.rework ?? 0
                    guard childCount <= rework else { throw RunError.invalid("Rework exceeds parent count.") }
                }
                if job.closedAt != nil {
                    let summary = try self.summary(jobID: job.id, itemID: item.id)
                    guard summary.released + summary.scrapped == summary.intake,
                          summary.reworkPending == 0, summary.notProcessed == 0 else {
                        throw RunError.invalid("Closed job no longer reconciles.")
                    }
                }
            }
            if job.closedAt != nil {
                guard job.handoffMethod != nil, job.handoff != nil,
                      links.filter({ $0.jobID == job.id }).allSatisfy({ link in
                          guard let run = runs.first(where: { $0.id == link.runID }) else { return false }
                          return !run.qualityHold || events.contains(where: {
                              $0.kind == "postHandoffQualityAlert" && $0.subjectID == run.id &&
                              $0.at >= job.closedAt!
                          })
                      }) else {
                    throw RunError.invalid("Closed job needs a handoff record.")
                }
            }
        }
    }

    public mutating func addJob(_ job: ShopJob, at: Date = Date()) throws {
        guard !jobs.contains(where: { $0.id == job.id || $0.reference == job.reference }) else { throw RunError.duplicateID }
        jobs.append(job)
        log("jobCreated", subject: job.id, detail: job.reference, at: at)
    }

    /// Additional physical groups stay within the same customer job. Intake
    /// quantities must be recorded before the job is handed off.
    public mutating func addItem(_ item: Item, to jobID: UUID, at: Date = Date()) throws {
        guard let index = jobs.firstIndex(where: { $0.id == jobID && $0.closedAt == nil }),
              !jobs[index].items.contains(where: { $0.id == item.id }),
              at >= (events.first(where: { $0.kind == "jobCreated" && $0.subjectID == jobID })?.at ?? .distantPast) else {
            throw RunError.invalid("An open job, a unique item and chronological intake are required.")
        }
        jobs[index].items.append(item)
        log("itemAdded", subject: item.id, detail: "\(item.identity): \(item.quantity) units", at: at)
    }

    /// Presets contain only shop-authored reusable facts. A replacement must
    /// increment its revision; a used run keeps its own cure-recipe snapshot.
    public mutating func savePreset(_ preset: ShopPreset, at: Date = Date()) throws {
        try preset.validate()
        guard preset.reviewedAt <= at,
              !presets.contains(where: { $0.id != preset.id && $0.title == preset.title }) else {
            throw RunError.invalid("Review the current recipe source and use a unique preset name.")
        }
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            guard presets[index].revision < Int.max - 1,
                  preset.revision == presets[index].revision + 1,
                  at >= presets[index].reviewedAt else { throw RunError.staleRevision }
            presets[index] = preset
        } else {
            guard preset.revision == 1 else { throw RunError.invalid("New preset revision must be one.") }
            presets.append(preset)
        }
        log("presetSaved", subject: preset.id,
            detail: "\(preset.title) rev \(preset.revision); source \(preset.recipe.source) reviewed by \(preset.sourceReviewedBy)", at: at)
    }

    public mutating func removePreset(id: UUID, operatorName: String, at: Date = Date()) throws {
        guard !operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let index = presets.firstIndex(where: { $0.id == id }) else {
            throw RunError.invalid("Existing preset and operator required.")
        }
        let removed = presets.remove(at: index)
        log("presetRemoved", subject: id, detail: "\(removed.title) by \(operatorName)", at: at)
    }

    /// An explicit lot, quantity, operator and source confirmation are still
    /// required for each run. Matching item and completed checks prevent a
    /// preset intended for one process from silently being used for another.
    public mutating func createRunFromPreset(jobID: UUID, itemID: UUID, presetID: UUID,
                                             quantity: Int, powderLot: String,
                                             actualBooth: String, operatorName: String,
                                             sourceConfirmed: Bool,
                                             parentRunID: UUID? = nil,
                                             at: Date = Date()) throws -> UUID {
        guard let preset = presets.first(where: { $0.id == presetID }),
              sourceConfirmed, at >= preset.reviewedAt,
              !powderLot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !actualBooth.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let job = jobs.first(where: { $0.id == jobID && $0.closedAt == nil }),
              let item = job.items.first(where: { $0.id == itemID }),
              item.identity == preset.partIdentity, item.substrate == preset.substrate,
              item.finish == preset.finish,
              preset.requiredPreparationCheckpoints.allSatisfy({ name in
                  job.checkpoints.contains(where: { $0.itemID == itemID && $0.name == name &&
                      $0.completedAt >= (events.first(where: { $0.kind == "jobCreated" && $0.subjectID == jobID })?.at ?? .distantPast) &&
                      $0.completedAt <= at })
              }) else {
            throw RunError.invalid("Match the part and completed prep checks, then confirm the current recipe source.")
        }
        var next = self
        let id = try next.createRun(jobID: jobID, itemID: itemID, quantity: quantity,
                                    recipe: preset.recipe,
                                    powderLot: powderLot.trimmingCharacters(in: .whitespacesAndNewlines),
                                    booth: actualBooth.trimmingCharacters(in: .whitespacesAndNewlines),
                                    operatorName: operatorName,
                                    parentRunID: parentRunID, at: at)
        next.log("presetUsed", subject: id,
                 detail: "\(preset.id) rev \(preset.revision); \(preset.title); source \(preset.recipe.source) confirmed by \(operatorName)", at: at)
        self = next
        return id
    }

    private func requireCorrection(_ reason: String, _ operatorName: String) throws {
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RunError.invalid("Correction reason and operator are required.")
        }
    }

    private func requireAfterHandoff(jobID: UUID, at: Date) throws {
        if let creation = events.first(where: { $0.kind == "jobCreated" && $0.subjectID == jobID })?.at,
           at < creation { throw RunError.invalid("Correction cannot predate job intake.") }
        if let handoff = jobs.first(where: { $0.id == jobID })?.closedAt, at < handoff {
            throw RunError.invalid("Correction cannot predate a completed handoff.")
        }
    }

    public mutating func correctJob(jobID: UUID, reference: String? = nil,
                                    customerReference: String? = nil, dueAt: Date? = nil,
                                    clearDueAt: Bool = false, reason: String,
                                    operatorName: String, at: Date = Date()) throws {
        try requireCorrection(reason, operatorName)
        try requireAfterHandoff(jobID: jobID, at: at)
        guard let i = jobs.firstIndex(where: { $0.id == jobID }) else { throw RunError.invalid("Job not found.") }
        let old = jobs[i]
        if let reference {
            let next = reference.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !next.isEmpty, !jobs.contains(where: { $0.id != jobID && $0.reference == next }) else {
                throw RunError.invalid("Corrected job reference must be unique and nonempty.")
            }
            jobs[i].reference = next
        }
        if let customerReference { jobs[i].customerReference = customerReference }
        if let dueAt { jobs[i].dueAt = dueAt }
        if clearDueAt { jobs[i].dueAt = nil }
        guard jobs[i] != old else { throw RunError.invalid("No job fact changed.") }
        log("jobCorrected", subject: jobID,
            detail: "\(operatorName): reference \(old.reference) -> \(jobs[i].reference); customer \(old.customerReference ?? "") -> \(jobs[i].customerReference ?? ""); due \(String(describing: old.dueAt)) -> \(String(describing: jobs[i].dueAt)); reason: \(reason)", at: at)
    }

    public mutating func correctItem(jobID: UUID, itemID: UUID, identity: String? = nil,
                                     quantity: Int? = nil, substrate: String? = nil,
                                     finish: String? = nil, reason: String,
                                     operatorName: String, at: Date = Date()) throws {
        try requireCorrection(reason, operatorName)
        try requireAfterHandoff(jobID: jobID, at: at)
        guard let j = jobs.firstIndex(where: { $0.id == jobID }),
              let i = jobs[j].items.firstIndex(where: { $0.id == itemID }) else {
            throw RunError.invalid("Item not found.")
        }
        let old = jobs[j].items[i]
        var corrected = old
        if jobs[j].closedAt != nil && quantity != nil && quantity != old.quantity {
            throw RunError.invalid("Delivered quantity is historical; document a discrepancy in an audit addendum instead of changing intake.")
        }
        if let identity { corrected.identity = identity.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let substrate { corrected.substrate = substrate.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let finish { corrected.finish = finish.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let quantity {
            let allocated = links.filter { $0.jobID == jobID && $0.itemID == itemID && $0.parentRunID == nil }
                .compactMap { link in runs.first(where: { $0.id == link.runID })?.quantity }.reduce(0, +)
            guard quantity >= allocated, quantity > 0, quantity <= 1_000_000 else {
                throw RunError.invalid("Corrected intake must cover allocated runs and remain in range.")
            }
            corrected.quantity = quantity
        }
        guard !corrected.identity.isEmpty, !corrected.substrate.isEmpty,
              !corrected.finish.isEmpty, corrected != old else {
            throw RunError.invalid("Corrected item facts must be nonempty and changed.")
        }
        jobs[j].items[i] = corrected
        let now = corrected
        log("itemCorrected", subject: itemID,
            detail: "\(operatorName): identity \(old.identity) -> \(now.identity); quantity \(old.quantity) -> \(now.quantity); substrate \(old.substrate) -> \(now.substrate); finish \(old.finish) -> \(now.finish); reason: \(reason)", at: at)
    }

    public mutating func correctRunSetup(runID: UUID, powderLot: String? = nil,
                                         booth: String? = nil, reason: String,
                                         operatorName: String, at: Date = Date()) throws {
        try requireCorrection(reason, operatorName)
        guard let i = links.firstIndex(where: { $0.runID == runID }) else { throw RunError.invalid("Run not found.") }
        try requireAfterHandoff(jobID: links[i].jobID, at: at)
        guard let run = runs.first(where: { $0.id == runID }), at >= (run.events.last?.at ?? run.createdAt) else {
            throw RunError.invalid("Setup correction cannot predate run activity.")
        }
        let old = links[i]
        if let powderLot { links[i].powderLot = powderLot.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let booth { links[i].booth = booth.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !links[i].powderLot.isEmpty, !links[i].booth.isEmpty, links[i] != old else {
            links[i] = old
            throw RunError.invalid("Corrected powder lot and booth must be nonempty and changed.")
        }
        log("runSetupCorrected", subject: runID,
            detail: "\(operatorName): lot \(old.powderLot) -> \(links[i].powderLot); booth \(old.booth) -> \(links[i].booth); reason: \(reason)", at: at)
    }

    public mutating func correctBatch(batchID: UUID, loadIdentity: String? = nil,
                                      equipment: String? = nil, reason: String,
                                      operatorName: String, at: Date = Date()) throws {
        try requireCorrection(reason, operatorName)
        guard let i = batches.firstIndex(where: { $0.id == batchID }) else { throw RunError.invalid("Batch not found.") }
        guard at >= batches[i].enteredAt else { throw RunError.invalid("Batch correction cannot predate loading.") }
        for link in links where link.batchID == batchID {
            try requireAfterHandoff(jobID: link.jobID, at: at)
        }
        let old = batches[i]
        if let loadIdentity {
            let next = loadIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !batches.contains(where: { $0.id != batchID && $0.loadIdentity == next }) else {
                throw RunError.invalid("Load identity must be unique.")
            }
            batches[i].loadIdentity = next
        }
        if let equipment { batches[i].equipment = equipment.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !batches[i].loadIdentity.isEmpty, !batches[i].equipment.isEmpty, batches[i] != old else {
            batches[i] = old
            throw RunError.invalid("Corrected batch facts must be nonempty and changed.")
        }
        log("batchCorrected", subject: batchID,
            detail: "\(operatorName): load \(old.loadIdentity) -> \(batches[i].loadIdentity); equipment \(old.equipment) -> \(batches[i].equipment); reason: \(reason)", at: at)
    }

    public mutating func configure(_ newSettings: ShopSettings, at: Date = Date()) {
        settings = newSettings
        log("settingsChanged", subject: UUID(), detail: newSettings.requiredPreparationCheckpoints.joined(separator: ", "), at: at)
    }

    public mutating func addPhoto(_ photo: Photo, jobID: UUID, itemID: UUID,
                                  at: Date = Date()) throws {
        guard let j = jobs.firstIndex(where: { $0.id == jobID && $0.closedAt == nil }),
              let i = jobs[j].items.firstIndex(where: { $0.id == itemID }),
              jobs[j].items[i].photos.count < 20,
              !jobs[j].items[i].photos.contains(where: { $0.id == photo.id }),
              photo.runID == nil || links.contains(where: {
                  $0.runID == photo.runID && $0.jobID == jobID && $0.itemID == itemID
              }),
              at >= (events.first(where: { $0.kind == "jobCreated" && $0.subjectID == jobID })?.at ?? .distantPast),
              photo.capturedAt == nil || photo.capturedAt! <= at else {
            throw RunError.invalid("Open item, matching run and chronological photo required.")
        }
        jobs[j].items[i].photos.append(photo)
        log("photoAttached", subject: itemID, detail: photo.caption, at: at)
    }

    public mutating func deletePhoto(photoID: UUID, jobID: UUID, itemID: UUID,
                                     reason: String, operatorName: String,
                                     at: Date = Date()) throws {
        try requireCorrection(reason, operatorName)
        guard let j = jobs.firstIndex(where: { $0.id == jobID }),
              let i = jobs[j].items.firstIndex(where: { $0.id == itemID }),
              let p = jobs[j].items[i].photos.firstIndex(where: { $0.id == photoID }) else {
            throw RunError.invalid("Photo not found.")
        }
        let removed = jobs[j].items[i].photos[p]
        if let captured = removed.capturedAt, at < captured {
            throw RunError.invalid("Deletion cannot predate photo capture.")
        }
        jobs[j].items[i].photos.remove(at: p)
        log("photoDeleted", subject: itemID,
            detail: "\(operatorName): \(removed.id) deleted; reason: \(reason)", at: at)
    }

    public mutating func checkpoint(jobID: UUID, itemID: UUID, name: String, operatorName: String,
                                    note: String = "", at: Date = Date()) throws {
        guard let index = jobs.firstIndex(where: { $0.id == jobID && $0.closedAt == nil }),
              jobs[index].items.contains(where: { $0.id == itemID }),
              !name.isEmpty, !operatorName.isEmpty,
              at >= (events.first(where: { $0.kind == "jobCreated" && $0.subjectID == jobID })?.at ?? .distantPast) else {
            throw RunError.invalid("Open job, chronological checkpoint and operator required.")
        }
        jobs[index].checkpoints.append(Checkpoint(itemID: itemID, name: name, completedAt: at,
                                                   operatorName: operatorName, note: note))
        log("checkpoint", subject: itemID, detail: "\(name): \(note)", at: at)
    }

    public mutating func createRun(jobID: UUID, itemID: UUID, quantity: Int,
                                   recipe: CureRecipe, powderLot: String, booth: String,
                                   operatorName: String, parentRunID: UUID? = nil,
                                   at: Date = Date()) throws -> UUID {
        guard let job = jobs.first(where: { $0.id == jobID && $0.closedAt == nil }),
              let item = job.items.first(where: { $0.id == itemID }),
              at >= (events.first(where: { $0.kind == "jobCreated" && $0.subjectID == jobID })?.at ?? .distantPast),
              !powderLot.isEmpty, !booth.isEmpty, quantity > 0 else {
            throw RunError.invalid("Open job, item, powder lot, booth and quantity required.")
        }
        if let parentRunID {
            guard let parent = runs.first(where: { $0.id == parentRunID }),
                  let parentLink = links.first(where: { $0.runID == parentRunID }),
                  parentLink.jobID == jobID, parentLink.itemID == itemID,
                  parent.disposition != nil, parent.disposition!.rework > 0 else {
                throw RunError.invalid("Rework must reference a disposed run of the same item.")
            }
            let alreadyAssigned = links.filter { $0.parentRunID == parentRunID }
                .compactMap { link in runs.first(where: { $0.id == link.runID })?.quantity }.reduce(0, +)
            guard quantity <= parent.disposition!.rework - alreadyAssigned else {
                throw RunError.invalid("Rework quantity exceeds the parent run's rework count.")
            }
        } else {
            let alreadyAssigned = links.filter { $0.itemID == itemID && $0.parentRunID == nil }
                .compactMap { link in runs.first(where: { $0.id == link.runID })?.quantity }.reduce(0, +)
            guard quantity <= item.quantity - alreadyAssigned else {
                throw RunError.invalid("Run quantity exceeds item intake.")
            }
        }
        let run = try CoatingRun(jobReference: job.reference, partDescription: item.identity,
                                 quantity: quantity, operatorName: operatorName, recipe: recipe, at: at)
        runs.append(run)
        links.append(RunLink(runID: run.id, jobID: jobID, itemID: itemID,
                             powderLot: powderLot, booth: booth, parentRunID: parentRunID))
        log("runCreated", subject: run.id, detail: "Lot \(powderLot), \(quantity) units", at: at)
        return run.id
    }

    public mutating func action(runID: UUID, _ action: RunAction, expectedRevision: Int,
                                at: Date = Date()) throws {
        guard let index = runs.firstIndex(where: { $0.id == runID }) else { throw RunError.invalid("Run not found.") }
        guard let jobID = links.first(where: { $0.runID == runID })?.jobID,
              let job = jobs.first(where: { $0.id == jobID }) else {
            throw RunError.invalid("Run has no matching job.")
        }
        let closed = job.closedAt
        if let closed {
            guard at >= closed else { throw RunError.invalid("A correction cannot predate the recorded handoff.") }
            switch action {
            case .correctObservation, .resolveHold: break
            default: throw RunError.invalid("Delivered work is historical; only reading corrections and hold review are allowed.")
            }
        }
        if case .markApplied = action {
            guard let link = links.first(where: { $0.runID == runID }),
                  let job = jobs.first(where: { $0.id == link.jobID }),
                  settings.requiredPreparationCheckpoints.allSatisfy({ name in
                      job.checkpoints.contains(where: { $0.itemID == link.itemID &&
                          $0.name == name && $0.completedAt <= at })
                  }) else { throw RunError.invalid("Complete the configured preparation checkpoints before coating.") }
        }
        if case .enterOven = action { throw RunError.invalid("Load runs through an oven batch.") }
        if case .beginInspection = action {
            guard let batchID = links.first(where: { $0.runID == runID })?.batchID,
                  batches.contains(where: { $0.id == batchID && $0.exitedAt != nil && at >= $0.exitedAt! }) else {
                throw RunError.invalid("Unload the oven batch before inspection.")
            }
        }
        let wasHeld = runs[index].qualityHold
        var updated = runs[index]
        try updated.apply(action, at: at, expectedRevision: expectedRevision)
        runs[index] = updated
        if closed != nil && !wasHeld && updated.qualityHold {
            log("postHandoffQualityAlert", subject: runID,
                detail: "Delivered run has a corrected cure reading outside the recorded window; notify the customer and follow shop procedure.", at: at)
        } else if closed != nil && wasHeld && !updated.qualityHold {
            log("postHandoffQualityResolved", subject: runID,
                detail: "Held delivered run reviewed; see run correction and hold resolution audit.", at: at)
        }
    }

    public mutating func loadBatch(loadIdentity: String, equipment: String, runIDs: [UUID],
                                   at: Date = Date()) throws -> UUID {
        guard !loadIdentity.isEmpty, !equipment.isEmpty, !runIDs.isEmpty,
              Set(runIDs).count == runIDs.count,
              !batches.contains(where: { $0.loadIdentity == loadIdentity }) else {
            throw RunError.invalid("Unique load, equipment and unassigned runs required.")
        }
        for id in runIDs {
            guard let run = runs.first(where: { $0.id == id }), run.stage == .applied,
                  links.contains(where: { $0.runID == id && $0.batchID == nil }) else {
                throw RunError.invalid("Every run must be applied and unassigned before loading.")
            }
        }
        var next = self
        let batchID = UUID()
        for id in runIDs {
            let i = next.runs.firstIndex(where: { $0.id == id })!
            let revision = next.runs[i].revision
            try next.runs[i].apply(.enterOven, at: at, expectedRevision: revision)
            let link = next.links.firstIndex(where: { $0.runID == id })!
            next.links[link].batchID = batchID
        }
        next.batches.append(OvenBatch(id: batchID, loadIdentity: loadIdentity, equipment: equipment,
                                      runIDs: runIDs, enteredAt: at, airReadings: [], notes: []))
        next.log("batchLoaded", subject: batchID, detail: "\(runIDs.count) item groups", at: at)
        self = next
        return batchID
    }

    public mutating func recordOvenAir(batchID: UUID, celsius: Decimal, location: String,
                                       method: String, at: Date = Date()) throws {
        guard let i = batches.firstIndex(where: { $0.id == batchID && $0.exitedAt == nil }),
              celsius >= -50 && celsius <= 600, !location.isEmpty, !method.isEmpty,
              at >= batches[i].enteredAt,
              at >= (batches[i].airReadings.last?.recordedAt ?? batches[i].enteredAt) else {
            throw RunError.invalid("Active batch and chronological air reading required.")
        }
        batches[i].airReadings.append(TemperatureObservation(kind: .ovenAir, celsius: celsius,
                                      recordedAt: at, location: location, method: method))
        log("ovenAir", subject: batchID, detail: "\(celsius) °C at \(location)", at: at)
    }

    public mutating func unloadBatch(batchID: UUID, note: String, at: Date = Date()) throws {
        guard let i = batches.firstIndex(where: { $0.id == batchID && $0.exitedAt == nil }),
              at >= batches[i].enteredAt else { throw RunError.invalid("Active oven batch required.") }
        guard batches[i].runIDs.allSatisfy({ id in
            runs.contains(where: { $0.id == id && ($0.stage == .cooling || $0.stage == .scrapped || $0.stage == .rework) })
        }) else { throw RunError.invalid("Complete or scrap every run's dwell before unloading.") }
        let latestRunEvent = batches[i].runIDs.compactMap { id in
            runs.first(where: { $0.id == id })?.events.last?.at
        }.max() ?? batches[i].enteredAt
        guard at >= latestRunEvent,
              at >= (batches[i].airReadings.last?.recordedAt ?? batches[i].enteredAt) else {
            throw RunError.invalid("Oven exit cannot precede a run or oven observation.")
        }
        batches[i].exitedAt = at
        log("batchUnloaded", subject: batchID, detail: note, at: at)
    }

    public func summary(jobID: UUID, itemID: UUID) throws -> QuantitySummary {
        guard let item = jobs.first(where: { $0.id == jobID })?.items.first(where: { $0.id == itemID }) else {
            throw RunError.invalid("Item not found.")
        }
        let itemLinks = links.filter { $0.jobID == jobID && $0.itemID == itemID }
        let all = itemLinks.compactMap { link in runs.first(where: { $0.id == link.runID }) }
        let firstPass = itemLinks.filter { $0.parentRunID == nil }
            .compactMap { link in runs.first(where: { $0.id == link.runID }) }
        let processed = firstPass.reduce(0) { $0 + $1.quantity }
        // After handoff, released counts units physically delivered. A later
        // quality alert must not erase that historical transfer.
        let delivered = jobs.first(where: { $0.id == jobID })?.closedAt != nil
        let released = all.reduce(0) { $0 + (delivered || !$1.qualityHold ? ($1.disposition?.passed ?? 0) : 0) }
        let scrapped = all.reduce(0) { $0 + ($1.disposition?.scrapped ?? 0) }
        let pending = all.reduce(0) { $0 + ($1.disposition?.rework ?? 0) }
            - itemLinks.filter { $0.parentRunID != nil }.reduce(0) { total, link in
                total + (runs.first(where: { $0.id == link.runID })?.quantity ?? 0)
            }
        return QuantitySummary(intake: item.quantity, released: released,
                               reworkPending: pending, scrapped: scrapped,
                               notProcessed: item.quantity - processed)
    }

    public mutating func closeJob(jobID: UUID, method: HandoffMethod,
                                  handoff: String, at: Date = Date()) throws {
        guard let i = jobs.firstIndex(where: { $0.id == jobID && $0.closedAt == nil }), !handoff.isEmpty else {
            throw RunError.invalid("Open job and handoff are required.")
        }
        let latestRunEvent = links.filter { $0.jobID == jobID }.compactMap { link in
            runs.first(where: { $0.id == link.runID })?.events.last?.at
        }.max() ?? .distantPast
        let itemIDs = Set(jobs[i].items.map(\.id))
        let runIDs = Set(links.filter { $0.jobID == jobID }.map(\.runID))
        let batchIDs = Set(links.filter { $0.jobID == jobID }.compactMap(\.batchID))
        let latestLedgerEvent = events.filter { event in
            event.subjectID == jobID || itemIDs.contains(event.subjectID) ||
            runIDs.contains(event.subjectID) || batchIDs.contains(event.subjectID)
        }.map(\.at).max() ?? .distantPast
        let latestBatchExit = links.filter { $0.jobID == jobID }.compactMap { link in
            batches.first(where: { $0.id == link.batchID })?.exitedAt
        }.max() ?? .distantPast
        guard at >= latestRunEvent, at >= latestLedgerEvent, at >= latestBatchExit else {
            throw RunError.invalid("Handoff cannot precede the last job event.")
        }
        for item in jobs[i].items {
            let s = try summary(jobID: jobID, itemID: item.id)
            guard s.notProcessed == 0, s.reworkPending == 0,
                  s.released + s.scrapped == s.intake else {
                throw RunError.invalid("Cannot close: intake, release, scrap and rework do not reconcile.")
            }
        }
        jobs[i].closedAt = at
        jobs[i].handoff = handoff
        jobs[i].handoffMethod = method
        log("jobClosed", subject: jobID, detail: handoff, at: at)
    }

    /// An operator records a customer contact, return request, or other response
    /// without changing the original handoff or claiming a physical rework.
    public mutating func recordPostHandoffFollowup(jobID: UUID, runID: UUID,
                                                    operatorName: String, note: String,
                                                    at: Date = Date()) throws {
        guard let closed = jobs.first(where: { $0.id == jobID })?.closedAt,
              at >= closed,
              links.contains(where: { $0.jobID == jobID && $0.runID == runID }),
              let alert = events.last(where: { $0.subjectID == runID && $0.kind == "postHandoffQualityAlert" }),
              at >= alert.at,
              !operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RunError.invalid("A delivered run with a quality alert, operator and follow-up note is required.")
        }
        log("postHandoffFollowup", subject: runID, detail: "\(operatorName): \(note)", at: at)
    }

    public mutating func correct(eventID: UUID, correctedFact: String, reason: String,
                                 operatorName: String, at: Date = Date()) throws {
        guard let original = events.first(where: { $0.id == eventID }), !correctedFact.isEmpty,
              !reason.isEmpty, !operatorName.isEmpty else {
            throw RunError.invalid("Original event, corrected fact, reason and operator required.")
        }
        guard at >= original.at else { throw RunError.invalid("Correction cannot predate its source.") }
        if let jobID = jobs.first(where: { job in
            job.id == original.subjectID || job.items.contains(where: { $0.id == original.subjectID }) ||
            links.contains(where: { link in link.jobID == job.id &&
                (link.runID == original.subjectID || link.batchID == original.subjectID) })
        })?.id { try requireAfterHandoff(jobID: jobID, at: at) }
        events.append(LedgerEvent(id: UUID(), at: at, kind: "correction", subjectID: original.subjectID,
                                  detail: "\(operatorName): \(correctedFact); reason: \(reason)",
                                  correctsEventID: eventID))
    }

    public func search(_ text: String) -> [ShopJob] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return jobs }
        return jobs.filter { $0.reference.localizedStandardContains(query) ||
            ($0.customerReference?.localizedStandardContains(query) ?? false) ||
            $0.items.contains(where: { $0.identity.localizedStandardContains(query) }) }
    }

    private mutating func log(_ kind: String, subject: UUID, detail: String, at: Date) {
        events.append(LedgerEvent(id: UUID(), at: at, kind: kind,
                                  subjectID: subject, detail: detail, correctsEventID: nil))
    }
}
