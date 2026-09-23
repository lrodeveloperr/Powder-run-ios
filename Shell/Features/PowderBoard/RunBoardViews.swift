import PowderCoatingRunEngine
import SwiftUI

struct NewRunForm: View {
    let shop: ShopBoardModel
    let jobID: UUID
    let itemID: UUID
    @Environment(\.dismiss) private var dismiss
    @AppStorage("powder.lastOperator") private var operatorName = ""
    @State private var count = ""
    @State private var powderName = ""
    @State private var code = ""
    @State private var source = ""
    @State private var target = ""
    @State private var dwellMinutes = ""
    @State private var maximum = ""
    @State private var lot = ""
    @State private var booth = ""
    @State private var confirmedSource = false
    @State private var presetID: UUID?
    @State private var parentRunID: UUID?

    private var item: Item? { shop.ledger.jobs.first(where: { $0.id == jobID })?.items.first(where: { $0.id == itemID }) }
    private var eligiblePresets: [ShopPreset] {
        guard let item else { return [] }
        return shop.ledger.presets.filter { $0.partIdentity == item.identity && $0.substrate == item.substrate && $0.finish == item.finish }
    }
    private var eligibleParents: [CoatingRun] {
        shop.ledger.links.filter { $0.jobID == jobID && $0.itemID == itemID }
            .compactMap { link in shop.ledger.runs.first(where: { $0.id == link.runID && ($0.disposition?.rework ?? 0) > 0 }) }
    }

    var body: some View {
        Form {
            Section("Actual run") {
                TextField("Quantity", text: $count).keyboardType(.numberPad)
                TextField("New powder lot", text: $lot)
                TextField("Booth used", text: $booth)
                TextField("Operator", text: $operatorName)
                if !eligibleParents.isEmpty {
                    Picker("Run type", selection: $parentRunID) {
                        Text("First pass").tag(Optional<UUID>.none)
                        ForEach(eligibleParents, id: \.id) { run in
                            Text("Rework · \(run.partDescription) · \(run.quantity) units").tag(Optional(run.id))
                        }
                    }
                }
            }
            if !eligiblePresets.isEmpty {
                Section("Matching shop preset") {
                    Picker("Setup", selection: $presetID) {
                        Text("Enter current recipe").tag(Optional<UUID>.none)
                        ForEach(eligiblePresets, id: \.id) { preset in
                            Text(preset.title).tag(Optional(preset.id))
                        }
                    }
                    if let preset = eligiblePresets.first(where: { $0.id == presetID }) {
                        Text("\(preset.recipe.productCode) · \(preset.recipe.targetMetalCelsius)°C · \(preset.recipe.dwellSeconds / 60) min")
                        Text("Source: \(preset.recipe.source)").font(.subheadline).foregroundStyle(.secondary)
                        Text("Prep required: " + preset.requiredPreparationCheckpoints.joined(separator: ", "))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            if presetID == nil {
                Section("Manufacturer's current cure instruction") {
                    TextField("Powder name", text: $powderName)
                    TextField("Product code", text: $code)
                    TextField("TDS or procedure source", text: $source)
                    TextField("Target part metal °C", text: $target).keyboardType(.decimalPad)
                    TextField("Dwell minutes", text: $dwellMinutes).keyboardType(.numberPad)
                    TextField("Maximum metal °C (if specified)", text: $maximum).keyboardType(.decimalPad)
                } footer: { Text("Use the manufacturer's instruction for this powder. Oven-air temperature is not a cure target.") }
            }
            Section {
                Toggle("I checked the current source for this run", isOn: $confirmedSource)
            } footer: { Text("Presets never copy a previous lot, quantity, operator or observation.") }
        }
        .navigationTitle("Set up run")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if count.isEmpty, let item {
                let assigned = shop.ledger.links.filter { $0.jobID == jobID && $0.itemID == itemID && $0.parentRunID == nil }
                    .compactMap { link in shop.ledger.runs.first(where: { $0.id == link.runID })?.quantity }.reduce(0, +)
                count = String(max(0, item.quantity - assigned))
            }
        }
        .onChange(of: presetID) { _, id in
            if let preset = eligiblePresets.first(where: { $0.id == id }) { booth = preset.suggestedBooth }
            confirmedSource = false
        }
        .onChange(of: parentRunID) { _, id in
            if let id, let parent = eligibleParents.first(where: { $0.id == id }) {
                let allocated = shop.ledger.links.filter { $0.parentRunID == id }
                    .compactMap { link in shop.ledger.runs.first(where: { $0.id == link.runID })?.quantity }.reduce(0, +)
                count = String(max(0, (parent.disposition?.rework ?? 0) - allocated))
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { save() }
                    .disabled((Int(count) ?? 0) <= 0 || lot.isEmpty || booth.isEmpty || operatorName.isEmpty || !confirmedSource || shop.busy)
            }
        }
    }

    private func save() {
        guard let quantity = Int(count) else { return }
        let chosenPreset = presetID, parent = parentRunID
        let lot = lot, booth = booth, person = operatorName
        let name = powderName, code = code, source = source
        let temperature = Decimal(string: target.replacingOccurrences(of: ",", with: "."))
        let maxTemperature = maximum.isEmpty ? nil : Decimal(string: maximum.replacingOccurrences(of: ",", with: "."))
        let minutes = Int(dwellMinutes)
        let maximumWasEmpty = maximum.isEmpty
        let confirmed = confirmedSource
        Task {
            let saved = await shop.perform { ledger in
                if let chosenPreset {
                    _ = try ledger.createRunFromPreset(jobID: jobID, itemID: itemID, presetID: chosenPreset,
                        quantity: quantity, powderLot: lot, actualBooth: booth, operatorName: person,
                        sourceConfirmed: confirmed, parentRunID: parent)
                } else {
                    guard let temperature, let minutes, minutes > 0, minutes <= 240,
                          maximumWasEmpty || maxTemperature != nil else {
                        throw RunError.invalid("Enter numeric metal temperature and dwell minutes from the current source.")
                    }
                    let recipe = try CureRecipe(powderName: name, productCode: code, source: source,
                        targetMetalCelsius: temperature, dwellSeconds: minutes * 60,
                        maximumMetalCelsius: maxTemperature)
                    _ = try ledger.createRun(jobID: jobID, itemID: itemID, quantity: quantity,
                        recipe: recipe, powderLot: lot, booth: booth, operatorName: person, parentRunID: parent)
                }
            }
            if saved { dismiss() }
        }
    }
}

struct RunDetails: View {
    let runID: UUID
    let shop: ShopBoardModel
    @State private var reading = false
    @State private var inspection = false
    @State private var disposition = false
    @State private var preset = false
    @State private var correction = false
    @State private var holdReview = false
    @State private var interruption = false
    @State private var followup = false
    @State private var scrap = false

    private var run: CoatingRun? { shop.ledger.runs.first { $0.id == runID } }
    private var link: RunLink? { shop.ledger.links.first { $0.runID == runID } }
    private var batch: OvenBatch? { shop.ledger.batches.first { $0.id == link?.batchID } }
    private var closed: Bool { shop.ledger.jobs.first { $0.id == link?.jobID }?.closedAt != nil }

    var body: some View {
        Group {
            if let run {
                List {
                    Section("Run") {
                        LabeledContent("Status", value: run.qualityHold ? "QUALITY HOLD" : run.stage.rawValue.capitalized)
                        LabeledContent("Quantity", value: "\(run.quantity) · \(link?.parentRunID == nil ? "first pass" : "rework")")
                        LabeledContent("Powder", value: run.recipe.productCode)
                        LabeledContent("Lot", value: link?.powderLot ?? "")
                        LabeledContent("TDS / procedure", value: run.recipe.source)
                    }
                    if let batch {
                        Section("Cure evidence · \(batch.loadIdentity)") {
                            LabeledContent("Target part metal", value: "\(run.recipe.targetMetalCelsius) °C")
                            LabeledContent("Dwell", value: "\(run.recipe.dwellSeconds / 60) min minimum")
                            if let start = run.dwellStartedAt { LabeledContent("Started", value: start.formatted(date: .omitted, time: .shortened)) }
                            if let end = run.dwellEndedAt { LabeledContent("Ended", value: end.formatted(date: .omitted, time: .shortened)) }
                            ForEach(Array(run.observations.enumerated()), id: \.offset) { entry in
                                let observation = entry.element
                                if observation.kind == .partMetal {
                                    LabeledContent(observation.recordedAt.formatted(date: .omitted, time: .shortened),
                                        value: "\(observation.celsius) °C · \(observation.location)")
                                }
                            }
                            if batch.exitedAt == nil && (run.stage == .heating || run.stage == .dwelling) {
                                Button("Record part-metal reading") { reading = true }
                            }
                        }
                    }
                    Section("Next action") {
                        if run.stage == .preparing && !closed {
                            Button("Confirm coating applied") { act(.markApplied(note: "Operator confirmed coating applied"), revision: run.revision) }
                        }
                        if run.stage == .applied { Text("Select this run when loading an oven batch.").foregroundStyle(.secondary) }
                        if run.stage == .cooling && batch?.exitedAt != nil && !closed {
                            Button("Start inspection") { act(.beginInspection, revision: run.revision) }
                        }
                        if run.stage == .inspection && !closed {
                            if run.inspection == nil { Button("Record inspection") { inspection = true } }
                            else if run.disposition == nil {
                                if run.inspection?.visual == .pass && !run.qualityHold {
                                    Button("Accept all \(run.quantity) parts") { act(.accept, revision: run.revision) }
                                }
                                Button("Allocate pass / rework / scrap") { disposition = true }
                            }
                        }
                        if run.qualityHold { Label("Do not release held parts. Review the readings and shop procedure.", systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                        if run.qualityHold && !closed { Button("Review quality hold") { holdReview = true } }
                        if (run.stage == .heating || run.stage == .dwelling) && !closed {
                            Button("Record oven interruption") { interruption = true }
                        }
                        if !closed && run.stage != .accepted && run.stage != .scrapped && run.stage != .rework {
                            Button("Scrap damaged run") { scrap = true }
                        }
                        if closed && run.qualityHold { Button("Record customer follow-up") { followup = true } }
                        if run.stage == .accepted || run.stage == .rework || run.stage == .scrapped {
                            if let decision = run.disposition {
                                Text("\(decision.passed) passed · \(decision.rework) rework · \(decision.scrapped) scrap")
                            }
                        }
                    }
                    Section("Record maintenance") {
                        Button("Review or correct a reading") { correction = true }
                        if !closed { Button("Save this setup as a shop preset") { preset = true } }
                    }
                }
            } else { ContentUnavailableView("Run unavailable", systemImage: "exclamationmark.triangle") }
        }
        .navigationTitle(run?.partDescription ?? "Run")
        .sheet(isPresented: $reading) { NavigationStack { ReadingForm(shop: shop, runID: runID) } }
        .sheet(isPresented: $inspection) { NavigationStack { InspectionForm(shop: shop, runID: runID) } }
        .sheet(isPresented: $disposition) { NavigationStack { DispositionForm(shop: shop, runID: runID) } }
        .sheet(isPresented: $preset) { NavigationStack { PresetForm(shop: shop, runID: runID) } }
        .sheet(isPresented: $correction) { NavigationStack { CorrectionForm(shop: shop, runID: runID) } }
        .sheet(isPresented: $holdReview) { NavigationStack { HoldReviewForm(shop: shop, runID: runID) } }
        .sheet(isPresented: $interruption) { NavigationStack { InterruptionForm(shop: shop, runID: runID) } }
        .sheet(isPresented: $followup) { NavigationStack { FollowupForm(shop: shop, runID: runID) } }
        .sheet(isPresented: $scrap) { NavigationStack { ScrapForm(shop: shop, runID: runID) } }
    }

    private func act(_ action: RunAction, revision: Int) {
        Task { await shop.perform { try $0.action(runID: runID, action, expectedRevision: revision) } }
    }
}

private struct ReadingForm: View {
    let shop: ShopBoardModel
    let runID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var reading = ""
    @State private var unit: TemperatureUnit = .celsius
    @State private var point = ""
    @State private var method = ""
    @State private var transition = false
    @State private var continuousDwellConfirmed = false
    private var run: CoatingRun? { shop.ledger.runs.first { $0.id == runID } }

    var body: some View {
        Form {
            Section("Actual part-metal measurement") {
                TextField("Temperature", text: $reading).keyboardType(.decimalPad)
                Picker("Unit", selection: $unit) { Text("°C").tag(TemperatureUnit.celsius); Text("°F").tag(TemperatureUnit.fahrenheit) }
                TextField("Measurement point on part", text: $point)
                TextField("Instrument or method", text: $method)
            } footer: { Text("Record part metal. An oven-air reading cannot start or end qualifying dwell.") }
            if let run {
                Section("Dwell") {
                    LabeledContent("Target", value: "\(run.recipe.targetMetalCelsius) °C · \(run.recipe.dwellSeconds / 60) min")
                    if run.stage == .heating {
                        Toggle("Start dwell with this reading", isOn: $transition)
                    } else if run.stage == .dwelling {
                        Toggle("End dwell with this reading", isOn: $transition)
                        if transition { Toggle("I confirm the part stayed at the required temperature throughout", isOn: $continuousDwellConfirmed) }
                    }
                }
            }
        }
        .navigationTitle("Part-metal reading")
        .onAppear {
            guard let run else { return }
            if let previous = run.observations.last(where: { $0.kind == .partMetal }) {
                point = previous.location; method = previous.method
            } else if let used = shop.ledger.events.last(where: { $0.kind == "presetUsed" && $0.subjectID == runID }),
                      let preset = shop.ledger.presets.first(where: { used.detail.hasPrefix($0.id.uuidString) }) {
                point = preset.measurementPoint; method = preset.measurementMethod
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Record") { save() }
                    .disabled(reading.isEmpty || point.isEmpty || method.isEmpty || (run?.stage == .dwelling && transition && !continuousDwellConfirmed) || shop.busy)
            }
        }
    }

    private func save() {
        guard let run, let value = Decimal(string: reading.replacingOccurrences(of: ",", with: ".")) else { return }
        let celsius = Units.celsius(value, from: unit)
        let point = point, method = method, revision = run.revision
        let next = transition, end = run.stage == .dwelling, confirmed = continuousDwellConfirmed
        let timestamp = Date()
        Task {
            let success = await shop.perform { ledger in
                try ledger.action(runID: runID, .observe(kind: .partMetal, celsius: celsius,
                    location: point, method: method), expectedRevision: revision, at: timestamp)
                if next {
                    try ledger.action(runID: runID, end ? .endDwell(operatorConfirmed: confirmed) : .startDwell,
                                      expectedRevision: revision + 1, at: timestamp)
                }
            }
            if success { dismiss() }
        }
    }
}

private struct InspectionForm: View {
    let shop: ShopBoardModel
    let runID: UUID
    @Environment(\.dismiss) private var dismiss
    @AppStorage("powder.lastOperator") private var operatorName = ""
    @State private var visual: InspectionOutcome = .pass
    @State private var thickness: InspectionOutcome?
    @State private var adhesion: InspectionOutcome?
    @State private var note = ""
    private var run: CoatingRun? { shop.ledger.runs.first { $0.id == runID } }
    var body: some View {
        Form {
            Section("Observed checks") {
                Picker("Visual", selection: $visual) { Text("Pass").tag(InspectionOutcome.pass); Text("Mixed").tag(InspectionOutcome.mixed); Text("Fail").tag(InspectionOutcome.fail) }
                Picker("Thickness", selection: $thickness) { Text("Not tested").tag(Optional<InspectionOutcome>.none); Text("Pass").tag(Optional(InspectionOutcome.pass)); Text("Mixed").tag(Optional(InspectionOutcome.mixed)); Text("Fail").tag(Optional(InspectionOutcome.fail)) }
                Picker("Adhesion", selection: $adhesion) { Text("Not tested").tag(Optional<InspectionOutcome>.none); Text("Pass").tag(Optional(InspectionOutcome.pass)); Text("Mixed").tag(Optional(InspectionOutcome.mixed)); Text("Fail").tag(Optional(InspectionOutcome.fail)) }
                TextField("Inspection note", text: $note)
                TextField("Operator", text: $operatorName)
            }
        }
        .navigationTitle("Inspect run")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Record") {
                    guard let revision = run?.revision else { return }
                    let visual = visual, thickness = thickness, adhesion = adhesion, note = note, person = operatorName, now = Date()
                    Task { if await shop.perform({ ledger in
                        let result = Inspection(checkedAt: now, operatorName: person, visual: visual,
                                                thickness: thickness, adhesion: adhesion, note: note)
                        try ledger.action(runID: runID, .inspect(result), expectedRevision: revision, at: now)
                    }) { dismiss() } }
                }.disabled(operatorName.isEmpty || shop.busy)
            }
        }
    }
}

private struct DispositionForm: View {
    let shop: ShopBoardModel
    let runID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var passed = ""
    @State private var rework = "0"
    @State private var scrapped = "0"
    @State private var code: DefectCode = .appearance
    @State private var reason = ""
    private var run: CoatingRun? { shop.ledger.runs.first { $0.id == runID } }
    var body: some View {
        Form {
            Section("Allocate every coated part") {
                TextField("Passed", text: $passed).keyboardType(.numberPad)
                TextField("Rework", text: $rework).keyboardType(.numberPad)
                TextField("Scrap", text: $scrapped).keyboardType(.numberPad)
                if let count = run?.quantity { Text("Must total \(count)").foregroundStyle(.secondary) }
            }
            if (Int(rework) ?? 0) > 0 || (Int(scrapped) ?? 0) > 0 {
                Section("Rejected parts") {
                    Picker("Defect", selection: $code) {
                        ForEach([DefectCode.appearance, .thinFilm, .adhesion, .contamination,
                                 .physicalDamage, .cure, .other], id: \.self) { defect in
                            Text(defect.rawValue).tag(defect)
                        }
                    }
                    TextField("Reason", text: $reason)
                }
            }
        }
        .navigationTitle("Disposition")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Record") {
                    guard let run, let p = Int(passed), let r = Int(rework), let s = Int(scrapped) else { return }
                    let reason = reason, defect = (r > 0 || s > 0) ? code : nil, revision = run.revision
                    Task { if await shop.perform({ try $0.action(runID: runID,
                        .closeInspection(passed: p, rework: r, scrapped: s, code: defect, reason: reason),
                        expectedRevision: revision) }) { dismiss() } }
                }.disabled(Int(passed) == nil || Int(rework) == nil || Int(scrapped) == nil ||
                    (Int(passed) ?? -1) + (Int(rework) ?? -1) + (Int(scrapped) ?? -1) != run?.quantity || shop.busy)
            }
        }
    }
}

private struct CorrectionForm: View {
    let shop: ShopBoardModel
    let runID: UUID
    @Environment(\.dismiss) private var dismiss
    @AppStorage("powder.lastOperator") private var operatorName = ""
    @State private var index = 0
    @State private var corrected = ""
    @State private var reason = ""
    private var run: CoatingRun? { shop.ledger.runs.first { $0.id == runID } }
    var body: some View {
        Form {
            if let run, !run.observations.isEmpty {
                Picker("Original reading", selection: $index) {
                    ForEach(run.observations.indices, id: \.self) { i in
                        Text("#\(i + 1) · \(run.observations[i].celsius) °C · \(run.observations[i].location)").tag(i)
                    }
                }
                TextField("Corrected °C", text: $corrected).keyboardType(.decimalPad)
                TextField("Reason for correction", text: $reason)
                TextField("Operator", text: $operatorName)
                Text("The original remains in the audit trail. A cure-invalidating change places released work on quality alert.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else { Text("No readings to correct.") }
        }
        .navigationTitle("Correct reading")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Correct") {
                    guard let run, let value = Decimal(string: corrected.replacingOccurrences(of: ",", with: ".")) else { return }
                    let index = index, reason = reason, person = operatorName, revision = run.revision
                    Task { if await shop.perform({ try $0.action(runID: runID,
                        .correctObservation(index: index, celsius: value, reason: reason, operatorName: person),
                        expectedRevision: revision) }) { dismiss() } }
                }.disabled(run?.observations.isEmpty != false || corrected.isEmpty || reason.isEmpty || operatorName.isEmpty || shop.busy)
            }
        }
    }
}

private struct PresetForm: View {
    let shop: ShopBoardModel
    let runID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var oven = ""
    @State private var point = ""
    @State private var method = ""
    @AppStorage("powder.lastOperator") private var reviewedBy = ""

    var body: some View {
        Form {
            TextField("Preset name", text: $title)
            TextField("Suggested oven", text: $oven)
            TextField("Suggested measurement point", text: $point)
            TextField("Suggested method", text: $method)
            TextField("Source reviewer", text: $reviewedBy)
            Text("A preset copies setup and source, never the lot, quantities, readings or outcomes. Review the manufacturer's source again before each use.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("Save shop preset")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let link = shop.ledger.links.first(where: { $0.runID == runID }),
                          let job = shop.ledger.jobs.first(where: { $0.id == link.jobID }),
                          let item = job.items.first(where: { $0.id == link.itemID }),
                          let run = shop.ledger.runs.first(where: { $0.id == runID }) else { return }
                    let checks = Array(Set(job.checkpoints.filter { $0.itemID == item.id }.map(\.name))).sorted()
                    let title = title, oven = oven, point = point, method = method, reviewer = reviewedBy
                    Task { if await shop.perform({ ledger in
                        let preset = try ShopPreset(title: title, partIdentity: item.identity,
                            substrate: item.substrate, finish: item.finish,
                            requiredPreparationCheckpoints: checks, recipe: run.recipe,
                            suggestedBooth: link.booth, suggestedOven: oven,
                            measurementPoint: point, measurementMethod: method,
                            sourceReviewedBy: reviewer)
                        try ledger.savePreset(preset)
                    }) { dismiss() } }
                }.disabled(title.isEmpty || oven.isEmpty || point.isEmpty || method.isEmpty || reviewedBy.isEmpty || shop.busy)
            }
        }
    }
}

private struct HoldReviewForm: View {
    let shop: ShopBoardModel
    let runID: UUID
    @Environment(\.dismiss) private var dismiss
    @AppStorage("powder.lastOperator") private var operatorName = ""
    @State private var reason = ""
    private var run: CoatingRun? { shop.ledger.runs.first { $0.id == runID } }

    var body: some View {
        Form {
            Section("Quality hold") {
                Text("Check the recorded part-metal evidence and shop procedure before choosing an outcome.")
                TextField("Review reason", text: $reason)
                TextField("Reviewer", text: $operatorName)
            }
            Section {
                if run?.requiredDwellSatisfied == true {
                    Button("Resolve only if corrected evidence qualifies") { decide(resolve: true) }
                }
                Button("Send held parts to linked rework") { decide(resolve: false) }
                    .foregroundStyle(.red)
            } footer: {
                Text("The engine rechecks the full dwell before releasing a hold. Rework remains linked to this parent run.")
            }
        }
        .navigationTitle("Hold review")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
    }

    private func decide(resolve: Bool) {
        guard let run, !reason.isEmpty, !operatorName.isEmpty else { return }
        let reason = reason, person = operatorName, revision = run.revision
        Task {
            let result = await shop.perform { try $0.action(runID: runID,
                resolve ? .resolveHold(reason: reason, operatorName: person) : .holdToRework(reason: reason, operatorName: person),
                expectedRevision: revision) }
            if result { dismiss() }
        }
    }
}

private struct InterruptionForm: View {
    let shop: ShopBoardModel
    let runID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    var body: some View {
        Form {
            TextField("What interrupted this oven cycle?", text: $reason)
            Text("An interruption resets the qualifying dwell. Record another part-metal reading before restarting it.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("Interrupt dwell")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Record") {
                    guard let revision = shop.ledger.runs.first(where: { $0.id == runID })?.revision else { return }
                    let reason = reason
                    Task { if await shop.perform({ try $0.action(runID: runID, .interrupt(reason: reason), expectedRevision: revision) }) { dismiss() } }
                }.disabled(reason.isEmpty || shop.busy)
            }
        }
    }
}

private struct FollowupForm: View {
    let shop: ShopBoardModel
    let runID: UUID
    @Environment(\.dismiss) private var dismiss
    @AppStorage("powder.lastOperator") private var operatorName = ""
    @State private var note = ""
    var body: some View {
        Form {
            Text("This run was already handed off. Record a customer contact or return request without changing the physical handoff history.")
                .font(.subheadline)
            TextField("Follow-up action and details", text: $note)
            TextField("Operator", text: $operatorName)
        }
        .navigationTitle("Customer follow-up")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Record") {
                    guard let jobID = shop.ledger.links.first(where: { $0.runID == runID })?.jobID else { return }
                    let note = note, person = operatorName
                    Task { if await shop.perform({ try $0.recordPostHandoffFollowup(jobID: jobID, runID: runID, operatorName: person, note: note) }) { dismiss() } }
                }.disabled(note.isEmpty || operatorName.isEmpty || shop.busy)
            }
        }
    }
}

private struct ScrapForm: View {
    let shop: ShopBoardModel
    let runID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var confirm = false
    var body: some View {
        Form {
            Section("Scrap every part in this run") {
                TextField("Why can these parts not continue?", text: $reason)
                Toggle("I confirm the full run quantity is scrap", isOn: $confirm)
            } footer: { Text("For a mixture of accepted and rejected parts, inspect and allocate the quantities instead.") }
        }
        .navigationTitle("Scrap run")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Record scrap", role: .destructive) {
                    guard let revision = shop.ledger.runs.first(where: { $0.id == runID })?.revision else { return }
                    let reason = reason
                    Task { if await shop.perform({ try $0.action(runID: runID, .scrap(reason: reason), expectedRevision: revision) }) { dismiss() } }
                }.disabled(reason.isEmpty || !confirm || shop.busy)
            }
        }
    }
}
