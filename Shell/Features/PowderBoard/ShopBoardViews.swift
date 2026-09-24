import PowderCoatingRunEngine
import SwiftUI

struct ShopBoardProvider: FeatureCanvasProviding {
    let shop: ShopBoardModel

    func makeCanvas(for destination: ShellDestination, context: FeatureCanvasContext) -> AnyView {
        AnyView(ShopBoardCanvas(destination: destination.id, shop: shop, requestUpgrade: context.requestUpgrade))
    }
}

private struct ShopBoardCanvas: View {
    let destination: String
    let shop: ShopBoardModel
    let requestUpgrade: () -> Void
    @Environment(\.scenePhase) private var phase

    var body: some View {
        Group {
            switch destination {
            case "jobs": JobsBoard(shop: shop, requestUpgrade: requestUpgrade)
            case "oven": OvenBoard(shop: shop)
            default: HistoryBoard(shop: shop)
            }
        }
        .task { await shop.start() }
        .onChange(of: phase) { _, next in if next == .active { Task { await shop.refresh() } } }
        .alert("Check this entry", isPresented: Binding(
            get: { shop.errorMessage != nil },
            set: { if !$0 { shop.errorMessage = nil } }
        )) { Button("OK") { shop.errorMessage = nil } } message: {
            Text(shop.errorMessage ?? "")
        }
    }
}

private struct JobsBoard: View {
    let shop: ShopBoardModel
    let requestUpgrade: () -> Void
    @State private var showingJob = false

    var body: some View {
        List {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(shop.ledger.jobs.filter { $0.closedAt == nil }.count)")
                            .font(.largeTitle.bold())
                        Text("jobs in progress").font(.subheadline)
                    }
                    Spacer()
                    Text("\(shop.ledger.batches.filter { $0.exitedAt == nil }.count) active oven loads")
                        .font(.caption.weight(.semibold))
                        .padding(8).background(.white, in: RoundedRectangle(cornerRadius: 8))
                }
                .foregroundStyle(Color(red: 0.08, green: 0.38, blue: 0.42))
                .padding(.vertical, 6)
                .listRowBackground(Color(red: 0.87, green: 0.94, blue: 0.95))
            }
            if shop.ledger.jobs.isEmpty {
                ContentUnavailableView("No jobs yet", systemImage: "shippingbox",
                                       description: Text("Enter a job and its first physical item group."))
            } else {
                Section("Needs an action") {
                    ForEach(shop.ledger.jobs.filter { $0.closedAt == nil }, id: \.id) { job in
                        NavigationLink {
                            JobDetails(jobID: job.id, shop: shop)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(job.reference).font(.headline)
                                Text(job.items.map { "\($0.quantity) × \($0.identity)" }.joined(separator: " · "))
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Text(jobNextAction(job, ledger: shop.ledger))
                                    .font(.caption.weight(.semibold)).foregroundStyle(ShellConfiguration.tint)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                if shop.ledger.jobs.allSatisfy({ $0.closedAt != nil }) {
                    ContentUnavailableView("All jobs handed off", systemImage: "checkmark.circle",
                                           description: Text("Enter a job to start another run."))
                }
            }
            Section {
                HStack {
                    Text("Free first-pass runs left")
                    Spacer()
                    Text("\(shop.freeRunsRemaining) of 5").foregroundStyle(.secondary)
                }
            } footer: {
                Text("After five runs, Pro is needed to enter a new job. Existing jobs, rework and records remain available.")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                if shop.mayEnterNewJob { showingJob = true }
                else { requestUpgrade() }
            } label: {
                Label(shop.mayEnterNewJob ? "Enter new job" : "Subscribe to enter a job", systemImage: "plus")
                    .frame(maxWidth: .infinity).frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(shop.busy)
            .padding(.horizontal).padding(.vertical, 8)
            .background(.bar)
        }
        .sheet(isPresented: $showingJob) { NavigationStack { NewJobForm(shop: shop) } }
        .refreshable { await shop.refresh() }
    }
}

private func jobNextAction(_ job: ShopJob, ledger: ShopLedger) -> String {
    let links = ledger.links.filter { $0.jobID == job.id }
    let runs = links.compactMap { link in ledger.runs.first { $0.id == link.runID } }
    if runs.contains(where: { $0.qualityHold }) { return "Quality hold · review" }
    if runs.contains(where: { $0.stage == .heating || $0.stage == .dwelling }) { return "Take part-metal reading" }
    if runs.contains(where: { $0.stage == .cooling || $0.stage == .inspection }) { return "Inspect after unload" }
    if runs.contains(where: { $0.stage == .applied }) { return "Ready for oven load" }
    if runs.contains(where: { $0.stage == .preparing }) { return "Coat prepared parts" }
    return "Record prep or start a run"
}

private struct NewJobForm: View {
    let shop: ShopBoardModel
    @Environment(\.dismiss) private var dismiss
    @State private var reference = ""
    @State private var customer = ""
    @State private var item = ""
    @State private var quantity = ""
    @State private var substrate = ""
    @State private var finish = ""
    @State private var selectedPresetID: UUID?

    var body: some View {
        Form {
            Section("Work order") {
                TextField("Job reference", text: $reference).textInputAutocapitalization(.characters)
                TextField("Customer reference (optional)", text: $customer)
            }
            Section {
                if !shop.ledger.presets.isEmpty {
                    Picker("Shop setup (optional)", selection: $selectedPresetID) {
                        Text("Enter part manually").tag(Optional<UUID>.none)
                        ForEach(shop.ledger.presets, id: \.id) { preset in
                            Text(preset.title).tag(Optional(preset.id))
                        }
                    }
                }
                TextField("Part identity", text: $item)
                TextField("Quantity", text: $quantity).keyboardType(.numberPad)
                TextField("Substrate", text: $substrate)
                TextField("Requested finish", text: $finish)
            } header: {
                Text("First physical item group")
            } footer: {
                Text("Other item groups can be added to this job. Record actual quantity and finish, not a preset guess.")
            }
        }
        .navigationTitle("New job")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPresetID) { _, id in
            guard let preset = shop.ledger.presets.first(where: { $0.id == id }) else { return }
            item = preset.partIdentity; substrate = preset.substrate; finish = preset.finish
            // Quantity and customer remain new, observed job facts.
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let count = Int(quantity) else { return }
                    let ref = reference.trimmingCharacters(in: .whitespacesAndNewlines)
                    let part = item.trimmingCharacters(in: .whitespacesAndNewlines)
                    let material = substrate.trimmingCharacters(in: .whitespacesAndNewlines)
                    let colour = finish.trimmingCharacters(in: .whitespacesAndNewlines)
                    let customerValue = customer.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task {
                        let success = await shop.perform { ledger in
                            let item = try Item(identity: part, quantity: count, substrate: material, finish: colour)
                            let job = try ShopJob(reference: ref,
                                                  customerReference: customerValue.isEmpty ? nil : customerValue,
                                                  items: [item])
                            try ledger.addJob(job)
                        }
                        if success { dismiss() }
                    }
                }
                .disabled(reference.isEmpty || item.isEmpty || Int(quantity) == nil || substrate.isEmpty || finish.isEmpty || shop.busy)
            }
        }
    }
}

private struct JobDetails: View {
    let jobID: UUID
    let shop: ShopBoardModel
    @State private var prepItem: UUID?
    @State private var runItem: UUID?
    @State private var showingHandoff = false
    @State private var showingAddItem = false

    var body: some View {
        Group {
            if let job = shop.ledger.jobs.first(where: { $0.id == jobID }) {
                List {
                    if job.closedAt != nil {
                        Section { Label("Handed off · read only", systemImage: "checkmark.seal") }
                    }
                    ForEach(job.items, id: \.id) { item in
                        Section(item.identity) {
                            LabeledContent("Intake", value: "\(item.quantity) · \(item.substrate) · \(item.finish)")
                            if let summary = try? shop.ledger.summary(jobID: jobID, itemID: item.id) {
                                LabeledContent("Released / rework / scrap", value: "\(summary.released) / \(summary.reworkPending) / \(summary.scrapped)")
                            }
                            let checks = job.checkpoints.filter { $0.itemID == item.id }
                            if !checks.isEmpty { Text("Prep: " + checks.map(\.name).joined(separator: ", ")).font(.subheadline).foregroundStyle(.secondary) }
                            if job.closedAt == nil {
                                Button("Record preparation") { prepItem = item.id }
                                Button("Set up first pass or rework") { runItem = item.id }
                                    .disabled(checks.isEmpty)
                                if checks.isEmpty { Text("Record an actual preparation check before setup.").font(.caption).foregroundStyle(.secondary) }
                            }
                            ForEach(shop.ledger.links.filter { $0.jobID == jobID && $0.itemID == item.id }, id: \.runID) { link in
                                if let run = shop.ledger.runs.first(where: { $0.id == link.runID }) {
                                    NavigationLink {
                                        RunDetails(runID: run.id, shop: shop)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("\(run.quantity) × \(run.recipe.productCode)").font(.headline)
                                            Text("\(link.parentRunID == nil ? "First pass" : "Rework") · \(run.stage.rawValue)\(run.qualityHold ? " · HOLD" : "")")
                                                .font(.subheadline).foregroundColor(run.qualityHold ? .red : .secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if job.closedAt == nil {
                        Section {
                            Button("Add item group") { showingAddItem = true }
                            Button("Review handoff") { showingHandoff = true }
                        }
                    }
                }
            } else { ContentUnavailableView("Job unavailable", systemImage: "exclamationmark.triangle") }
        }
        .navigationTitle(shop.ledger.jobs.first(where: { $0.id == jobID })?.reference ?? "Job")
        .sheet(item: $prepItem) { id in NavigationStack { PrepForm(shop: shop, jobID: jobID, itemID: id) } }
        .sheet(item: $runItem) { id in NavigationStack { NewRunForm(shop: shop, jobID: jobID, itemID: id) } }
        .sheet(isPresented: $showingHandoff) { NavigationStack { HandoffForm(shop: shop, jobID: jobID) } }
        .sheet(isPresented: $showingAddItem) { NavigationStack { AddItemForm(shop: shop, jobID: jobID) } }
    }
}

// Allows UUIDs to be used as typed sheet selections without a parallel Boolean.
extension UUID: @retroactive Identifiable { public var id: UUID { self } }

private struct PrepForm: View {
    let shop: ShopBoardModel
    let jobID: UUID
    let itemID: UUID
    @Environment(\.dismiss) private var dismiss
    @AppStorage("powder.lastOperator") private var operatorName = ""
    @State private var name = ""
    @State private var note = ""

    var body: some View {
        Form {
            Section("Check actually performed") {
                TextField("Preparation check", text: $name)
                TextField("Observation (optional)", text: $note)
                TextField("Operator", text: $operatorName)
            }
            Section {
                ForEach(["Surface cleaned", "Dry and ready", "Masking confirmed"], id: \.self) { choice in
                    Button(choice) { name = choice }
                }
            } header: { Text("Recent shop choices") } footer: { Text("Choices only fill the label. Save only a check that was actually done for this item.") }
        }
        .navigationTitle("Record prep")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Record") {
                    let check = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let person = operatorName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let details = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task { if await shop.perform({ try $0.checkpoint(jobID: jobID, itemID: itemID, name: check, operatorName: person, note: details) }) { dismiss() } }
                }.disabled(name.isEmpty || operatorName.isEmpty || shop.busy)
            }
        }
    }
}

private struct AddItemForm: View {
    let shop: ShopBoardModel
    let jobID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var identity = ""
    @State private var quantity = ""
    @State private var substrate = ""
    @State private var finish = ""
    var body: some View {
        Form {
            TextField("Part identity", text: $identity)
            TextField("Quantity", text: $quantity).keyboardType(.numberPad)
            TextField("Substrate", text: $substrate)
            TextField("Finish", text: $finish)
        }
        .navigationTitle("Add item group")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let count = Int(quantity) else { return }
                    let identity = identity, substrate = substrate, finish = finish
                    Task { if await shop.perform({ ledger in
                        try ledger.addItem(try Item(identity: identity, quantity: count, substrate: substrate, finish: finish), to: jobID)
                    }) { dismiss() } }
                }.disabled(identity.isEmpty || Int(quantity) == nil || substrate.isEmpty || finish.isEmpty || shop.busy)
            }
        }
    }
}

private struct HandoffForm: View {
    let shop: ShopBoardModel
    let jobID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var method: HandoffMethod = .pickup
    @State private var note = ""

    var body: some View {
        Form {
            Section("Release only when all quantities reconcile") {
                Picker("Method", selection: $method) {
                    Text("Pickup").tag(HandoffMethod.pickup)
                    Text("Delivery").tag(HandoffMethod.delivery)
                    Text("Courier").tag(HandoffMethod.courier)
                }
                TextField("Handoff reference or recipient", text: $note)
            }
            if let job = shop.ledger.jobs.first(where: { $0.id == jobID }) {
                Section("Item totals") {
                    ForEach(job.items, id: \.id) { item in
                        if let summary = try? shop.ledger.summary(jobID: jobID, itemID: item.id) {
                            LabeledContent(item.identity, value: "\(summary.released) released · \(summary.scrapped) scrap · \(summary.reworkPending) rework · \(summary.notProcessed) pending")
                        }
                    }
                }
            }
        }
        .navigationTitle("Handoff")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Close job") {
                    let method = method, note = note
                    Task { if await shop.perform({ try $0.closeJob(jobID: jobID, method: method, handoff: note) }) { dismiss() } }
                }.disabled(note.isEmpty || shop.busy)
            }
        }
    }
}
