import Foundation

public enum RunError: Error, Equatable, CustomStringConvertible {
    case invalid(String)
    case wrongState(String)
    case staleRevision
    case unsupportedVersion
    case duplicateID

    public var description: String {
        switch self {
        case .invalid(let message), .wrongState(let message): return message
        case .staleRevision: return "Run changed on another screen; reload before saving."
        case .unsupportedVersion: return "This backup needs a newer app version."
        case .duplicateID: return "A run with this identifier already exists."
        }
    }
}

public enum TemperatureUnit: String, Codable, Sendable { case celsius, fahrenheit }

public struct CureRecipe: Codable, Equatable, Sendable {
    public var powderName: String
    public var productCode: String
    public var source: String
    public var targetMetalCelsius: Decimal
    public var dwellSeconds: Int
    public var maximumMetalCelsius: Decimal?

    public init(powderName: String, productCode: String, source: String,
                targetMetalCelsius: Decimal, dwellSeconds: Int,
                maximumMetalCelsius: Decimal? = nil) throws {
        guard !powderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !productCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              // This engine models thermal oven cure. Lower-temperature and UV
              // processes require a different validated workflow.
              targetMetalCelsius >= 120, targetMetalCelsius <= 300,
              dwellSeconds >= 60, dwellSeconds <= 14_400,
              maximumMetalCelsius == nil || maximumMetalCelsius! >= targetMetalCelsius else {
            throw RunError.invalid("Enter a powder code, source, and manufacturer-approved thermal metal temperature (120–300 °C) and dwell time.")
        }
        self.powderName = powderName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.productCode = productCode.trimmingCharacters(in: .whitespacesAndNewlines)
        self.source = source.trimmingCharacters(in: .whitespacesAndNewlines)
        self.targetMetalCelsius = targetMetalCelsius
        self.dwellSeconds = dwellSeconds
        self.maximumMetalCelsius = maximumMetalCelsius
    }

    public func validate() throws {
        _ = try CureRecipe(powderName: powderName, productCode: productCode,
                           source: source, targetMetalCelsius: targetMetalCelsius,
                           dwellSeconds: dwellSeconds, maximumMetalCelsius: maximumMetalCelsius)
    }
}

public enum RunStage: String, Codable, Sendable {
    case preparing, applied, heating, dwelling, cooling, inspection, accepted, rework, scrapped
}

public enum ObservationKind: String, Codable, Sendable { case ovenAir, partMetal }

public struct TemperatureObservation: Codable, Equatable, Sendable {
    public let kind: ObservationKind
    public let celsius: Decimal
    public let recordedAt: Date
    public let location: String
    public let method: String
}

public struct ObservationCorrection: Codable, Equatable, Sendable {
    public let originalIndex: Int
    public let correctedCelsius: Decimal
    public let reason: String
    public let operatorName: String
    public let recordedAt: Date
}

public enum InspectionOutcome: String, Codable, Sendable { case pass, mixed, fail }
public enum DefectCode: String, Codable, Sendable {
    case appearance, thinFilm, adhesion, contamination, physicalDamage, cure, other
}

public struct Inspection: Codable, Equatable, Sendable {
    public let checkedAt: Date
    public let operatorName: String
    public let visual: InspectionOutcome
    public let thickness: InspectionOutcome?
    public let adhesion: InspectionOutcome?
    public let note: String

    public init(checkedAt: Date, operatorName: String, visual: InspectionOutcome,
                thickness: InspectionOutcome?, adhesion: InspectionOutcome?, note: String) {
        self.checkedAt = checkedAt
        self.operatorName = operatorName
        self.visual = visual
        self.thickness = thickness
        self.adhesion = adhesion
        self.note = note
    }
}

public struct Disposition: Codable, Equatable, Sendable {
    public let passed: Int
    public let rework: Int
    public let scrapped: Int
    public let reason: String
    public let defectCode: DefectCode?
}

public struct RunEvent: Codable, Equatable, Sendable {
    public let id: UUID
    public let at: Date
    public let kind: String
    public let detail: String
}

public struct CoatingRun: Codable, Equatable, Sendable {
    public let id: UUID
    public let jobReference: String
    public let partDescription: String
    public let quantity: Int
    public let operatorName: String
    public let recipe: CureRecipe  // Snapshot: later recipe edits cannot rewrite a run.
    public private(set) var stage: RunStage
    public private(set) var revision: Int
    public private(set) var createdAt: Date
    public private(set) var observations: [TemperatureObservation]
    public private(set) var observationCorrections: [ObservationCorrection]
    public private(set) var qualityHold: Bool
    public private(set) var dwellStartedAt: Date?
    public private(set) var dwellEndedAt: Date?
    public private(set) var inspection: Inspection?
    public private(set) var disposition: Disposition?
    public private(set) var events: [RunEvent]

    public init(id: UUID = UUID(), jobReference: String, partDescription: String,
                quantity: Int, operatorName: String, recipe: CureRecipe, at: Date = Date()) throws {
        try recipe.validate()
        guard !jobReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !partDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              quantity > 0, quantity <= 1_000_000 else {
            throw RunError.invalid("Job, part, quantity, and operator are required.")
        }
        self.id = id
        self.jobReference = jobReference.trimmingCharacters(in: .whitespacesAndNewlines)
        self.partDescription = partDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        self.quantity = quantity
        self.operatorName = operatorName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.recipe = recipe
        self.stage = .preparing
        self.revision = 0
        self.createdAt = at
        self.observations = []
        self.observationCorrections = []
        self.qualityHold = false
        self.dwellStartedAt = nil
        self.dwellEndedAt = nil
        self.inspection = nil
        self.disposition = nil
        self.events = [RunEvent(id: UUID(), at: at, kind: "created", detail: "Job \(jobReference)")]
    }

    public var requiredDwellSatisfied: Bool {
        guard let start = dwellStartedAt, let end = dwellEndedAt else { return false }
        return end.timeIntervalSince(start) >= Double(recipe.dwellSeconds)
    }

    public func validate() throws {
        try recipe.validate()
        guard quantity > 0, quantity <= 1_000_000, !jobReference.isEmpty, !partDescription.isEmpty,
              revision >= 0, revision < Int.max, events.count >= 1,
              revision <= events.count - 1, events[0].kind == "created", events[0].at == createdAt,
              Set(events.map(\.id)).count == events.count,
              zip(events, events.dropFirst()).allSatisfy({ pair in pair.0.at <= pair.1.at }),
              zip(observations, observations.dropFirst()).allSatisfy({ pair in pair.0.recordedAt <= pair.1.recordedAt }),
              observations.allSatisfy({ $0.recordedAt >= createdAt && $0.recordedAt <= events.last!.at &&
                  $0.celsius >= -50 && $0.celsius <= 600 && !$0.location.isEmpty && !$0.method.isEmpty }),
              events.filter({ $0.kind == "temperature" }).count == observations.count,
              observationCorrections.allSatisfy({ observations.indices.contains($0.originalIndex) &&
                  !$0.reason.isEmpty && !$0.operatorName.isEmpty && $0.recordedAt >= observations[$0.originalIndex].recordedAt }),
              events.filter({ $0.kind == "observationCorrected" }).count == observationCorrections.count,
              (dwellEndedAt == nil || requiredDwellSatisfied),
              (disposition == nil || (disposition!.passed >= 0 && disposition!.rework >= 0 &&
                disposition!.scrapped >= 0 && disposition!.passed <= quantity &&
                disposition!.rework <= quantity && disposition!.scrapped <= quantity &&
                disposition!.passed + disposition!.rework + disposition!.scrapped == quantity)),
              (stage != .accepted || (disposition != nil && disposition!.passed > 0 &&
                 inspection != nil && requiredDwellSatisfied &&
                 events.contains(where: { $0.kind == "accepted" || $0.kind == "disposition" }))) else {
            throw RunError.invalid("Run backup has inconsistent lifecycle or counts.")
        }
        if let start = dwellStartedAt {
            guard events.contains(where: { $0.kind == "dwellStarted" && $0.at == start }),
                  observations.contains(where: { $0.kind == .partMetal && $0.recordedAt == start }) else {
                throw RunError.invalid("Dwell start lacks a part reading or event.")
            }
        }
        if let end = dwellEndedAt {
            guard let start = dwellStartedAt, end >= start,
                  events.contains(where: { $0.kind == "dwellEnded" && $0.at == end }),
                  observations.contains(where: { $0.kind == .partMetal && $0.recordedAt == end }) else {
                throw RunError.invalid("Dwell end lacks a part reading or event.")
            }
            let indices = observations.indices.filter {
                observations[$0].kind == .partMetal && observations[$0].recordedAt >= start &&
                observations[$0].recordedAt <= end
            }
            if !qualityHold {
                guard indices.allSatisfy({ effectiveCelsius(at: $0) >= recipe.targetMetalCelsius &&
                    (recipe.maximumMetalCelsius == nil || effectiveCelsius(at: $0) <= recipe.maximumMetalCelsius!) }) else {
                    throw RunError.invalid("Unheld dwell contains a nonqualifying metal reading.")
                }
            }
        }
        if let inspection {
            guard requiredDwellSatisfied, inspection.checkedAt >= dwellEndedAt!,
                  events.contains(where: { $0.kind == "inspected" && $0.at == inspection.checkedAt }) else {
                throw RunError.invalid("Inspection lacks a completed dwell or event.")
            }
        }
        switch stage {
        case .preparing:
            guard revision == 0, observations.isEmpty, disposition == nil else {
                throw RunError.invalid("Draft run has production activity.")
            }
        case .applied:
            guard observations.isEmpty, disposition == nil, events.contains(where: { $0.kind == "applied" }) else {
                throw RunError.invalid("Applied run history is inconsistent.")
            }
        case .heating:
            guard dwellStartedAt == nil, dwellEndedAt == nil, disposition == nil,
                  events.contains(where: { $0.kind == "ovenEntered" }) else {
                throw RunError.invalid("Heating run history is inconsistent.")
            }
        case .dwelling:
            guard dwellStartedAt != nil, dwellEndedAt == nil, disposition == nil else {
                throw RunError.invalid("Active dwell is inconsistent.")
            }
        case .cooling, .inspection:
            guard requiredDwellSatisfied, disposition == nil else {
                throw RunError.invalid("Cooling or inspection lacks completed dwell.")
            }
        case .accepted: break
        case .rework:
            guard (disposition?.rework ?? 0) > 0 else { throw RunError.invalid("Rework has no units.") }
        case .scrapped:
            guard (disposition?.scrapped ?? 0) > 0 else { throw RunError.invalid("Scrap has no units.") }
        }
    }

    public mutating func apply(_ action: RunAction, at: Date, expectedRevision: Int) throws {
        guard expectedRevision == revision else { throw RunError.staleRevision }
        guard revision < Int.max else { throw RunError.invalid("Run revision exhausted.") }
        guard at >= (events.last?.at ?? createdAt) else {
            throw RunError.invalid("Event time cannot precede the preceding event. Check the device clock.")
        }
        var copy = self
        try copy.transition(action, at: at)
        copy.revision += 1
        self = copy
    }

    private mutating func record(_ kind: String, _ detail: String, at: Date) {
        events.append(RunEvent(id: UUID(), at: at, kind: kind, detail: detail))
    }

    private mutating func transition(_ action: RunAction, at: Date) throws {
        switch action {
        case .markApplied(let note):
            try require(.preparing)
            stage = .applied
            record("applied", note, at: at)
        case .enterOven:
            try require(.applied)
            stage = .heating
            record("ovenEntered", "Heating; dwell has not started", at: at)
        case .observe(let kind, let celsius, let location, let method):
            guard stage == .heating || stage == .dwelling else { throw RunError.wrongState("Temperature can only be logged in the oven.") }
            guard celsius >= -50, celsius <= 600,
                  !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !method.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RunError.invalid("Enter a valid temperature, measurement location, and method.")
            }
            observations.append(TemperatureObservation(kind: kind, celsius: celsius, recordedAt: at,
                                                       location: location, method: method))
            record("temperature", "\(kind.rawValue): \(celsius) °C at \(location)", at: at)
            // A below-target part reading breaks the claimed continuous dwell.
            if stage == .dwelling && kind == .partMetal && celsius < recipe.targetMetalCelsius {
                stage = .heating
                dwellStartedAt = nil
                dwellEndedAt = nil
                record("dwellReset", "Part metal fell below the recipe threshold", at: at)
            }
            if kind == .partMetal, let maximum = recipe.maximumMetalCelsius, celsius > maximum {
                qualityHold = true
                if stage == .dwelling { stage = .heating; dwellStartedAt = nil; dwellEndedAt = nil }
                record("overTemperature", "Above the recipe maximum; operator review required", at: at)
            }
        case .startDwell:
            try require(.heating)
            guard let index = observations.indices.last(where: { observations[$0].kind == .partMetal }),
                  effectiveCelsius(at: index) >= recipe.targetMetalCelsius,
                  observations[index].recordedAt == at else {
                throw RunError.invalid("Record a qualifying part-metal reading at the dwell start time.")
            }
            guard recipe.maximumMetalCelsius == nil || effectiveCelsius(at: index) <= recipe.maximumMetalCelsius! else {
                throw RunError.invalid("Part metal exceeds the recipe maximum.")
            }
            dwellStartedAt = at
            dwellEndedAt = nil
            stage = .dwelling
            record("dwellStarted", "Part-metal threshold confirmed", at: at)
        case .endDwell(let operatorConfirmed):
            try require(.dwelling)
            guard let start = dwellStartedAt, at.timeIntervalSince(start) >= Double(recipe.dwellSeconds) else {
                throw RunError.invalid("Required dwell time has not elapsed.")
            }
            guard operatorConfirmed else {
                throw RunError.invalid("Operator must confirm the part remained at the required temperature.")
            }
            guard let index = observations.indices.last(where: { observations[$0].kind == .partMetal }),
                  observations[index].recordedAt == at,
                  effectiveCelsius(at: index) >= recipe.targetMetalCelsius,
                  recipe.maximumMetalCelsius == nil || effectiveCelsius(at: index) <= recipe.maximumMetalCelsius! else {
                throw RunError.invalid("Record a qualifying part-metal reading at the dwell end time.")
            }
            dwellEndedAt = at
            stage = .cooling
            record("dwellEnded", "Operator attested continuous dwell; cooling", at: at)
        case .interrupt(let reason):
            guard stage == .heating || stage == .dwelling else { throw RunError.wrongState("No active oven cycle to interrupt.") }
            guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RunError.invalid("Record the interruption reason.") }
            stage = .heating
            dwellStartedAt = nil
            dwellEndedAt = nil
            record("interrupted", reason, at: at)
        case .beginInspection:
            try require(.cooling)
            guard requiredDwellSatisfied else { throw RunError.invalid("A completed dwell is required.") }
            stage = .inspection
            record("inspectionStarted", "Ready for checks after cooling", at: at)
        case .inspect(let result):
            try require(.inspection)
            guard inspection == nil else { throw RunError.invalid("Inspection is already recorded; use a correction note.") }
            guard !result.operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  result.checkedAt == at else { throw RunError.invalid("Inspection operator and time are required.") }
            inspection = result
            record("inspected", "Visual: \(result.visual.rawValue)", at: at)
        case .accept:
            try require(.inspection)
            guard !qualityHold else { throw RunError.invalid("Resolve the quality hold before release.") }
            guard let inspection, inspection.visual == .pass,
                  inspection.thickness != .fail, inspection.adhesion != .fail else {
                throw RunError.invalid("Resolve failed checks before acceptance.")
            }
            stage = .accepted
            disposition = Disposition(passed: quantity, rework: 0, scrapped: 0, reason: "", defectCode: nil)
            record("accepted", "Accepted by \(inspection.operatorName)", at: at)
        case .closeInspection(let passed, let rework, let scrapped, let code, let reason):
            try require(.inspection)
            guard !qualityHold || passed == 0 else { throw RunError.invalid("A held run cannot release parts.") }
            guard inspection != nil else { throw RunError.invalid("Record inspection before disposition.") }
            guard passed >= 0, rework >= 0, scrapped >= 0,
                  passed <= quantity, rework <= quantity, scrapped <= quantity,
                  passed + rework + scrapped == quantity else {
                throw RunError.invalid("Pass + rework + scrap must equal the coated quantity.")
            }
            guard (rework == 0 && scrapped == 0) ||
                  (code != nil && !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) else {
                throw RunError.invalid("Record a defect code and reason.")
            }
            if passed > 0 {
                guard let inspection, inspection.visual != .fail,
                      inspection.thickness != .fail, inspection.adhesion != .fail else {
                    throw RunError.invalid("Passed parts require passing recorded checks; split into separate item groups when checks differ.")
                }
            }
            if rework > 0 || scrapped > 0 {
                guard inspection?.visual != .pass || code != .appearance else {
                    throw RunError.invalid("Record mixed or failed visual inspection for appearance defects.")
                }
            }
            disposition = Disposition(passed: passed, rework: rework, scrapped: scrapped,
                                      reason: reason, defectCode: code)
            stage = passed > 0 ? .accepted : (rework > 0 ? .rework : .scrapped)
            record("disposition", "Pass \(passed), rework \(rework), scrap \(scrapped); \(reason)", at: at)
        case .sendToRework(let reason):
            guard stage == .inspection && inspection != nil else { throw RunError.wrongState("Record inspection before rework.") }
            guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RunError.invalid("Record a rework reason.") }
            stage = .rework
            disposition = Disposition(passed: 0, rework: quantity, scrapped: 0,
                                      reason: reason, defectCode: .other)
            record("rework", reason, at: at)
        case .scrap(let reason):
            guard stage != .accepted && stage != .scrapped else { throw RunError.wrongState("Completed run cannot be scrapped.") }
            guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RunError.invalid("Record a scrap reason.") }
            stage = .scrapped
            disposition = Disposition(passed: 0, rework: 0, scrapped: quantity,
                                      reason: reason, defectCode: .other)
            record("scrapped", reason, at: at)
        case .correctObservation(let index, let value, let reason, let operatorName):
            guard observations.indices.contains(index), value >= -50, value <= 600,
                  !reason.isEmpty, !operatorName.isEmpty else {
                throw RunError.invalid("Existing reading, replacement, reason and operator required.")
            }
            observationCorrections.append(ObservationCorrection(originalIndex: index,
                correctedCelsius: value, reason: reason, operatorName: operatorName, recordedAt: at))
            record("observationCorrected", "Reading \(index) corrected to \(value) °C by \(operatorName): \(reason)", at: at)
            // A corrected measurement can invalidate an earlier cure decision.
            let duringDwell = dwellStartedAt.map { start in
                observations[index].recordedAt >= start &&
                (dwellEndedAt == nil || observations[index].recordedAt <= dwellEndedAt!)
            } ?? false
            if observations[index].kind == .partMetal &&
                ((duringDwell && value < recipe.targetMetalCelsius) ||
                 (recipe.maximumMetalCelsius != nil && value > recipe.maximumMetalCelsius!)) {
                if stage == .dwelling { stage = .heating; dwellStartedAt = nil; dwellEndedAt = nil }
                if stage == .cooling || stage == .inspection || stage == .accepted { qualityHold = true }
            }
        case .holdToRework(let reason, let operatorName):
            guard qualityHold, !reason.isEmpty, !operatorName.isEmpty else {
                throw RunError.invalid("Held run, operator and reason required.")
            }
            let previous = disposition ?? Disposition(passed: quantity, rework: 0, scrapped: 0,
                                                       reason: "", defectCode: nil)
            disposition = Disposition(passed: 0, rework: previous.rework + previous.passed,
                                      scrapped: previous.scrapped, reason: reason, defectCode: .cure)
            stage = .rework
            qualityHold = false
            record("holdToRework", "\(operatorName): \(reason)", at: at)
        case .resolveHold(let reason, let operatorName):
            guard qualityHold, !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  stage == .cooling || stage == .inspection || stage == .accepted,
                  requiredDwellSatisfied, let start = dwellStartedAt, let end = dwellEndedAt else {
                throw RunError.invalid("Completed dwell and a documented reviewer are required to resolve the hold.")
            }
            let relevant = observations.indices.filter {
                observations[$0].kind == .partMetal && observations[$0].recordedAt >= start &&
                observations[$0].recordedAt <= end
            }
            guard !relevant.isEmpty,
                  relevant.contains(where: { observations[$0].recordedAt == start }),
                  relevant.contains(where: { observations[$0].recordedAt == end }),
                  relevant.allSatisfy({ effectiveCelsius(at: $0) >= recipe.targetMetalCelsius &&
                      (recipe.maximumMetalCelsius == nil || effectiveCelsius(at: $0) <= recipe.maximumMetalCelsius!) }),
                  observations.indices.filter({ observations[$0].kind == .partMetal }).allSatisfy({
                      recipe.maximumMetalCelsius == nil || effectiveCelsius(at: $0) <= recipe.maximumMetalCelsius!
                  }) else {
                throw RunError.invalid("Effective metal readings still contradict the recorded dwell.")
            }
            qualityHold = false
            record("holdResolved", "\(operatorName): \(reason)", at: at)
        }
    }

    public func effectiveCelsius(at index: Int) -> Decimal {
        observationCorrections.last(where: { $0.originalIndex == index })?.correctedCelsius ?? observations[index].celsius
    }

    private func require(_ expected: RunStage) throws {
        guard stage == expected else { throw RunError.wrongState("Expected \(expected.rawValue), found \(stage.rawValue).") }
    }
}

public enum RunAction: Sendable {
    case markApplied(note: String)
    case enterOven
    case observe(kind: ObservationKind, celsius: Decimal, location: String, method: String)
    case startDwell
    case endDwell(operatorConfirmed: Bool)
    case interrupt(reason: String)
    case beginInspection
    case inspect(Inspection)
    case accept
    case closeInspection(passed: Int, rework: Int, scrapped: Int, code: DefectCode?, reason: String)
    case sendToRework(reason: String)
    case scrap(reason: String)
    case correctObservation(index: Int, celsius: Decimal, reason: String, operatorName: String)
    case holdToRework(reason: String, operatorName: String)
    case resolveHold(reason: String, operatorName: String)
}

public enum Units {
    public static func celsius(_ value: Decimal, from unit: TemperatureUnit) -> Decimal {
        unit == .celsius ? value : (value - 32) * 5 / 9
    }
    public static func fahrenheit(_ celsius: Decimal) -> Decimal { celsius * 9 / 5 + 32 }
}
