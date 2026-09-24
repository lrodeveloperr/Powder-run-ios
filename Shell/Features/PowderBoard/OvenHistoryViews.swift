import PowderCoatingRunEngine
import Observation
import SwiftUI
import UniformTypeIdentifiers

struct OvenBoard: View {
    @Bindable var shop: ShopBoardModel
    @State private var showingLoad = false
    private var active: [OvenBatch] { shop.ledger.batches.filter { $0.exitedAt == nil } }
    private var applied: [CoatingRun] { shop.ledger.runs.filter { $0.stage == .applied } }

    var body: some View {
        List {
            if active.isEmpty && applied.isEmpty {
                ContentUnavailableView("No active oven load", systemImage: "flame",
                                       description: Text("Coat a run from Jobs, then assemble a shared batch here."))
            }
            Section("Active batches") {
                ForEach(active, id: \.id) { batch in
                    NavigationLink {
                        BatchDetails(batchID: batch.id, shop: shop)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(batch.loadIdentity).font(.headline)
                            Text("\(batch.equipment) · \(batch.runIDs.count) runs")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text(batch.runIDs.contains(where: { id in
                                shop.ledger.runs.contains(where: { $0.id == id && ($0.stage == .heating || $0.stage == .dwelling) })
                            }) ? "Part-metal readings / dwell due" : "Ready for unload review")
                                .font(.caption.weight(.semibold)).foregroundStyle(ShellConfiguration.tint)
                        }.padding(.vertical, 4)
                    }
                    .listRowBackground(Color(red: 0.87, green: 0.94, blue: 0.95))
                }
            }
            if !applied.isEmpty {
                Section("Ready to load") {
                    ForEach(applied, id: \.id) { run in
                        Text("\(run.jobReference) · \(run.quantity) × \(run.partDescription)")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !applied.isEmpty {
                Button { showingLoad = true } label: {
                    Label("Load oven batch", systemImage: "plus")
                        .frame(maxWidth: .infinity).frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent).disabled(shop.busy)
                .padding(.horizontal).padding(.vertical, 8).background(.bar)
            }
        }
        .sheet(isPresented: $showingLoad) { NavigationStack { LoadBatchForm(shop: shop) } }
        .navigationDestination(item: $shop.deepLinkedBatchID) { id in
            BatchDetails(batchID: id, shop: shop)
        }
        .refreshable { await shop.refresh() }
    }
}

private struct LoadBatchForm: View {
    let shop: ShopBoardModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var equipment = ""
    @State private var selected = Set<UUID>()
    private var available: [CoatingRun] { shop.ledger.runs.filter { $0.stage == .applied } }
    var body: some View {
        Form {
            Section("Shared oven load") {
                TextField("Batch ID or rack ID", text: $name)
                TextField("Actual oven", text: $equipment)
            }
            Section {
                ForEach(available, id: \.id) { run in
                    Button {
                        if !selected.insert(run.id).inserted { selected.remove(run.id) }
                    } label: {
                        HStack {
                            Text("\(run.jobReference) · \(run.quantity) × \(run.partDescription)")
                            Spacer()
                            if selected.contains(run.id) { Image(systemName: "checkmark.circle.fill") }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: { Text("Select runs physically loaded together") } footer: { Text("Each run keeps its own powder TDS and part-metal cure record.") }
        }
        .navigationTitle("Load batch")
        .onChange(of: selected) { _, ids in
            let suggestions: [String] = ids.compactMap { suggestedOven(for: $0) }
            let ovens = Set(suggestions)
            if ovens.count == 1, let suggestion = ovens.first { equipment = suggestion }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Record load") {
                    let name = name, equipment = equipment, ids = available.map(\.id).filter { selected.contains($0) }
                    Task { if await shop.perform({ ledger in
                        _ = try ledger.loadBatch(loadIdentity: name, equipment: equipment, runIDs: ids)
                    }) { dismiss() } }
                }.disabled(name.isEmpty || equipment.isEmpty || selected.isEmpty || shop.busy)
            }
        }
    }

    private func suggestedOven(for runID: UUID) -> String? {
        guard let used = shop.ledger.events.last(where: { $0.kind == "presetUsed" && $0.subjectID == runID }) else { return nil }
        return shop.ledger.presets.first(where: { used.detail.hasPrefix($0.id.uuidString) })?.suggestedOven
    }
}

private struct BatchDetails: View {
    let batchID: UUID
    let shop: ShopBoardModel
    @State private var showingAir = false
    @State private var showingUnload = false
    private var batch: OvenBatch? { shop.ledger.batches.first { $0.id == batchID } }

    var body: some View {
        Group {
            if let batch {
                List {
                    Section("Load") {
                        LabeledContent("Oven", value: batch.equipment)
                        LabeledContent("Entered", value: batch.enteredAt.formatted(date: .abbreviated, time: .shortened))
                        if let exit = batch.exitedAt {
                            LabeledContent("Unloaded", value: exit.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                    Section("Runs · open each for its next reading") {
                        ForEach(batch.runIDs, id: \.self) { id in
                            if let run = shop.ledger.runs.first(where: { $0.id == id }) {
                                NavigationLink {
                                    RunDetails(runID: id, shop: shop)
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("\(run.jobReference) · \(run.partDescription)").font(.headline)
                                        Text("\(run.recipe.productCode) · target \(run.recipe.targetMetalCelsius)°C · \(run.stage.rawValue)")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    Section("Oven air · context only") {
                        ForEach(batch.airReadings.indices, id: \.self) { index in
                            let observation = batch.airReadings[index]
                            LabeledContent(observation.recordedAt.formatted(date: .omitted, time: .shortened),
                                           value: "\(observation.celsius) °C")
                        }
                        if batch.exitedAt == nil { Button("Record oven-air reading") { showingAir = true } }
                    }
                    if batch.exitedAt == nil {
                        Section {
                            Button("Review unload") { showingUnload = true }
                        } footer: { Text("Every run must complete a valid dwell or be scrapped/reworked before unloading.") }
                    }
                }
            } else { ContentUnavailableView("Batch unavailable", systemImage: "exclamationmark.triangle") }
        }
        .navigationTitle(batch?.loadIdentity ?? "Batch")
        .sheet(isPresented: $showingAir) { NavigationStack { AirReadingForm(shop: shop, batchID: batchID) } }
        .sheet(isPresented: $showingUnload) { NavigationStack { UnloadForm(shop: shop, batchID: batchID) } }
    }
}

private struct AirReadingForm: View {
    let shop: ShopBoardModel
    let batchID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var reading = ""
    @State private var location = ""
    @State private var method = ""
    var body: some View {
        Form {
            TextField("Oven-air °C", text: $reading).keyboardType(.decimalPad)
            TextField("Sensor location", text: $location)
            TextField("Instrument / method", text: $method)
            Text("Air readings give oven context; only part-metal readings qualify each run's dwell.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("Oven air")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Record") {
                    guard let value = Decimal(string: reading.replacingOccurrences(of: ",", with: ".")) else { return }
                    let place = location, method = method
                    Task { if await shop.perform({ try $0.recordOvenAir(batchID: batchID, celsius: value, location: place, method: method) }) { dismiss() } }
                }.disabled(reading.isEmpty || location.isEmpty || method.isEmpty || shop.busy)
            }
        }
    }
}

private struct UnloadForm: View {
    let shop: ShopBoardModel
    let batchID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    var body: some View {
        Form {
            Section {
                TextField("Unloading note / operator", text: $note)
            } header: { Text("Confirm physical unload") } footer: { Text("The engine will reject an unload while any run still needs its dwell completed.") }
        }
        .navigationTitle("Unload batch")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Record unload") {
                    let note = note
                    Task { if await shop.perform({ try $0.unloadBatch(batchID: batchID, note: note) }) { dismiss() } }
                }.disabled(note.isEmpty || shop.busy)
            }
        }
    }
}

struct HistoryBoard: View {
    let shop: ShopBoardModel
    @State private var restoreURL: URL?
    @State private var showingImporter = false
    @State private var confirmRestore = false

    var body: some View {
        List {
            Section("Closed jobs") {
                if shop.ledger.jobs.allSatisfy({ $0.closedAt == nil }) { Text("No jobs handed off yet.").foregroundStyle(.secondary) }
                ForEach(shop.ledger.jobs.filter { $0.closedAt != nil }, id: \.id) { job in
                    NavigationLink {
                        HistoryJobDetails(jobID: job.id, shop: shop)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(job.reference).font(.headline)
                            Text(job.closedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section {
                Button("Prepare backup and CSV exports") { Task { await shop.export() } }
                    .disabled(shop.busy)
                if let url = shop.backupURL { ShareLink("Share full backup JSON", item: url) }
                if let url = shop.jobsCSVURL { ShareLink("Share job totals CSV", item: url) }
                if let url = shop.batchCSVURL { ShareLink("Share oven-run CSV", item: url) }
                Button("Restore validated backup") { showingImporter = true }
                    .disabled(shop.busy)
            } header: { Text("Your data") } footer: {
                Text("Keep a backup outside this device. Restore replaces the current ledger only after validation; purchases are verified separately by Apple.")
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case let .success(url): restoreURL = url; confirmRestore = true
            case let .failure(error): shop.errorMessage = error.localizedDescription
            }
        }
        .confirmationDialog("Replace the local ledger?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Restore selected backup", role: .destructive) {
                if let url = restoreURL { Task { await shop.restore(from: url) } }
            }
        } message: { Text("Export a current backup first. A restore cannot grant Pro access.") }
    }
}

private struct HistoryJobDetails: View {
    let jobID: UUID
    let shop: ShopBoardModel
    var body: some View {
        List {
            if let job = shop.ledger.jobs.first(where: { $0.id == jobID }) {
                Section("Handoff") {
                    LabeledContent("Reference", value: job.reference)
                    LabeledContent("Method", value: job.handoffMethod?.rawValue.capitalized ?? "")
                    LabeledContent("Details", value: job.handoff ?? "")
                    Button("Prepare job PDF") { Task { await shop.prepareReport(jobID: jobID) } }
                    if let url = shop.reportURLs[jobID] { ShareLink("Share job PDF", item: url) }
                }
                ForEach(job.items, id: \.id) { item in
                    Section(item.identity) {
                        ForEach(shop.ledger.links.filter { $0.jobID == jobID && $0.itemID == item.id }, id: \.runID) { link in
                            if let run = shop.ledger.runs.first(where: { $0.id == link.runID }) {
                                NavigationLink {
                                    RunDetails(runID: run.id, shop: shop)
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text("\(run.quantity) × \(run.recipe.productCode)")
                                        if run.qualityHold {
                                            Text("Post-handoff quality alert · follow up with customer")
                                                .font(.subheadline).foregroundStyle(.red)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Job record")
    }
}
